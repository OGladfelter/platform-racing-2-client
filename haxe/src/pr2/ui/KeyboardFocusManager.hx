package pr2.ui;

import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.InteractiveObject;
import openfl.display.Stage;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.ui.Keyboard;
import pr2.ui.controls.NativeControl;

/** Flash-style deterministic Tab traversal for OpenFL's HTML5 target. */
class KeyboardFocusManager {
	private static var installedStage:Null<Stage>;

	private function new() {}

	public static function install(stage:Stage):Void {
		if (installedStage == stage) return;
		if (installedStage != null) {
			installedStage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, true);
			installedStage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			installedStage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, true);
			installedStage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		}
		installedStage = stage;
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, true, 1000);
		// When Stage itself is the event target there is no capture phase.
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 1000);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, true, 1000);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 1000);
	}

	/** Pointer input hides focus rectangles until the next Tab, exactly like Flash. */
	private static function onMouseDown(_:MouseEvent):Void {
		NativeControl.showFocusIndicator = false;
		if (installedStage == null) return;
		var current:Null<DisplayObject> = installedStage.focus;
		while (current != null) {
			var control = Std.downcast(current, NativeControl);
			if (control != null) {
				control.hideFocusIndicator();
				return;
			}
			current = current.parent;
		}
	}

	private static function onKeyDown(event:KeyboardEvent):Void {
		var stage = installedStage;
		if (stage == null || event.keyCode != Keyboard.TAB || event.isDefaultPrevented()) return;
		advanceFocus(stage, event.shiftKey);
		event.preventDefault();
	}

	private static function advanceFocus(stage:Stage, reverse:Bool):Void {
		var candidates = orderedCandidates(stage);
		if (candidates.length == 0) return;
		NativeControl.showFocusIndicator = true;
		var currentIndex = candidateIndex(candidates, stage.focus);
		var offset = reverse ? -1 : 1;
		var nextIndex = currentIndex < 0 ? (reverse ? candidates.length - 1 : 0) : currentIndex + offset;
		if (nextIndex < 0) nextIndex = candidates.length - 1;
		if (nextIndex >= candidates.length) nextIndex = 0;
		stage.focus = candidates[nextIndex];
	}

	private static function orderedCandidates(root:DisplayObjectContainer):Array<InteractiveObject> {
		var entries:Array<FocusEntry> = [];
		collect(root, root, entries);
		var hasAuthoredOrder = false;
		for (entry in entries) {
			if (entry.target.tabIndex >= 0) {
				hasAuthoredOrder = true;
				break;
			}
		}
		if (hasAuthoredOrder) entries = entries.filter(function(entry):Bool return entry.target.tabIndex >= 0);
		entries.sort(hasAuthoredOrder ? compareAuthored : compareAutomatic);
		return [for (entry in entries) entry.target];
	}

	private static function collect(container:DisplayObjectContainer, root:DisplayObjectContainer, entries:Array<FocusEntry>):Void {
		for (i in 0...container.numChildren) {
			var child = container.getChildAt(i);
			if (!child.visible) continue;
			var interactive = Std.downcast(child, InteractiveObject);
			if (interactive != null && interactive.tabEnabled && interactive.mouseEnabled) {
				entries.push(new FocusEntry(interactive, interactive.getBounds(root), entries.length));
			}
			var childContainer = Std.downcast(child, DisplayObjectContainer);
			// Flash UIComponent is one atomic tab stop. OpenFL's HTML5 SVG skin
			// descendants can otherwise surface as a second stop for the same control.
			if (childContainer != null && childContainer.tabChildren && !Std.isOfType(child, NativeControl)) collect(childContainer, root, entries);
		}
	}

	private static function compareAuthored(a:FocusEntry, b:FocusEntry):Int {
		var order = a.target.tabIndex - b.target.tabIndex;
		return order == 0 ? a.serial - b.serial : order;
	}

	private static function compareAutomatic(a:FocusEntry, b:FocusEntry):Int {
		if (a.bounds.y != b.bounds.y) return a.bounds.y < b.bounds.y ? -1 : 1;
		if (a.bounds.x != b.bounds.x) return a.bounds.x < b.bounds.x ? -1 : 1;
		return a.serial - b.serial;
	}

	private static function candidateIndex(candidates:Array<InteractiveObject>, focus:Null<InteractiveObject>):Int {
		var current:Null<DisplayObject> = focus;
		while (current != null) {
			var interactive = Std.downcast(current, InteractiveObject);
			if (interactive != null) {
				var index = candidates.indexOf(interactive);
				if (index >= 0) return index;
			}
			current = current.parent;
		}
		return -1;
	}
}

private class FocusEntry {
	public final target:InteractiveObject;
	public final bounds:Rectangle;
	public final serial:Int;

	public function new(target:InteractiveObject, bounds:Rectangle, serial:Int) {
		this.target = target;
		this.bounds = bounds;
		this.serial = serial;
	}
}
