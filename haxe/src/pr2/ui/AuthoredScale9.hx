package pr2.ui;

import openfl.display.Shape;
import openfl.geom.Rectangle;
import pr2.assets.NativeAssetIds.StaticSvg;
import pr2.assets.NativeAssets;
import pr2.runtime.SvgAsset;

/**
	Scale-grid factories for the reusable XFL chrome.

	The grid must live on the vector that is resized. OpenFL's HTML5 renderer
	does not apply a child's scale grid when only a wrapper Sprite is scaled.
**/
final class AuthoredScale9 {
	private static inline final SQUARE_PANEL_ASSET = "assets/svg/timeline/ui_popups_outside_levels_bg_d14a954e12/t00_l000_f0000_r00.svg";

	public static function buttonSkin(art:Shape):Shape {
		art.scale9Grid = new Rectangle(7, 5, 68, 11);
		return art;
	}

	public static function halfSquarePanel():Shape {
		return NativeAssets.svg(StaticSvg.HalfSquarePanel);
	}

	public static function shadowPanel():Shape {
		return NativeAssets.svg(StaticSvg.QuantityPanel);
	}

	public static function squarePanel():Shape {
		var art = SvgAsset.create(SQUARE_PANEL_ASSET);
		art.scale9Grid = new Rectangle(5.05, 5.05, 90, 90.1);
		return art;
	}

	public static function colorPickerSkin(art:Shape):Shape {
		art.scale9Grid = new Rectangle(3, 3, 11, 13);
		return art;
	}
}
