package pr2.levelEditor;

import openfl.display.Sprite;
import openfl.geom.Rectangle;
import pr2.app.AppStage;
import pr2.lobby.dialogs.AutoDismissController;

class EditorBlockOptionsPopup extends Sprite {
	public final editor:LevelEditor;
	public final block:EditorBlockObject;
	public final art:EditorBlockOptionsView;
	private var autoDismiss:Null<AutoDismissController>;
	private var removed:Bool = false;

	public function new(editor:LevelEditor, block:EditorBlockObject, linkage:String) {
		super();
		this.editor = editor;
		this.block = block;
		art = new EditorBlockOptionsView(linkage);
		addChild(art);
		mountNearBlock();
		autoDismiss = new AutoDismissController(this, remove);
	}

	public function remove():Void {
		if (removed) {
			return;
		}
		removed = true;
		if (autoDismiss != null) {
			autoDismiss.remove();
			autoDismiss = null;
		}
		art.dispose();
		if (parent != null) {
			parent.removeChild(this);
		}
		editor.blockOptionsPopupRemoved(this);
	}

	private function mountNearBlock():Void {
		var host:Null<Sprite> = editor.overlayLayer;
		if (AppStage.stage != null) {
			AppStage.stage.addChild(this);
			var blockBounds = block.getBounds(AppStage.stage);
			placeBeside(blockBounds);
			return;
		}
		if (host != null) {
			host.addChild(this);
			var blockBounds = block.getBounds(host);
			placeBeside(blockBounds);
		}
	}

	private function placeBeside(blockBounds:Rectangle):Void {
		var popupBounds = getBounds(this);
		var popupWidth = popupBounds.width <= 0 ? 236 : popupBounds.width;
		var popupHeight = popupBounds.height <= 0 ? 120 : popupBounds.height;
		// Flash's InfoPopup positions the popup's *visual* left/top beside the
		// block, then subtracts the authored content offset (popupBounds.left/top)
		// so the box does not slide by its own registration. The views here are
		// centered on their origin, so skipping that correction dropped the popup
		// on top of the block instead of next to it.
		var visualLeft = blockBounds.left > popupWidth ? blockBounds.left - popupWidth - 7 : blockBounds.right + 7;
		var visualTop = blockBounds.top;
		if (visualTop < 0) {
			visualTop = 0;
		}
		if (visualTop + popupHeight > 400) {
			visualTop = 400 - popupHeight;
		}
		x = Math.round(visualLeft - popupBounds.left);
		y = Math.round(visualTop - popupBounds.top);
	}

}
