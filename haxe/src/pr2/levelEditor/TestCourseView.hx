package pr2.levelEditor;

import openfl.display.Sprite;
import pr2.ui.controls.GameButton;
import pr2.ui.AuthoredScale9;
import pr2.ui.view.NativeView;

/** Native in-course overlay actions. */
class TestCourseView extends NativeView {
	public function new() {
		super();
		var background = new Sprite();
		background.name = "background";
		var panel = AuthoredScale9.squarePanel();
		panel.name = "panel";
		panel.x = 87;
		panel.y = 162;
		panel.scaleX = 1.24981689453125;
		panel.scaleY = 0.349990844726562;
		background.addChild(panel);
		addChild(background);
		button("restart_bt", "Restart", 94, 169);
		button("back_bt", "Back", 153, 169);
	}

	private function button(name:String, label:String, x:Float, y:Float):Void {
		var control = ownControl(new GameButton(label));
		control.name = name;
		control.x = x;
		control.y = y;
		control.setSize(54, 22);
		addChild(control);
	}
}
