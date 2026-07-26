package pr2.effects;

import openfl.display.DisplayObject;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.events.Event;
import pr2.runtime.FrameClock;
import pr2.gameplay.presentation.CharacterPresentationLayer;
import pr2.gameplay.presentation.PresentationPose;

/**
	Ports `effects/BlockPiece.as`: an authored block fragment with randomized
	linear/angular velocity, friction, gravity, and alpha decay.
**/
class BlockPiece extends Sprite {
	public static inline var GRAVITY:Float = 1;
	public static inline var FRICTION:Float = 0.95;
	public static inline var FADE_RATE:Float = 0.01;

	public var visual(default, null):DisplayObject;
	public var selectedFrame(default, null):Int = 1;
	private var velX:Float;
	private var velY:Float;
	private var rotVel:Float;
	private final gravity:Float;
	private final friction:Float;
	private final fadeRate:Float;
	private var ownsCustomVisual:Bool = false;
	private final presentationPose:PresentationPose = new PresentationPose();
	private var authoritativeX:Float;
	private var authoritativeY:Float;
	private var authoritativeRotation:Float;

	public function new(linkage:Null<String>, gravity:Float = GRAVITY, friction:Float = FRICTION, fadeRate:Float = FADE_RATE, spreadX:Float = 10,
			spreadY:Float = 10, spreadRot:Float = 10, startX:Float = 0, startY:Float = 0, ?random:Void->Float,
			?customVisual:DisplayObject) {
		super();
		var nextRandom = random == null ? Math.random : random;
		if (customVisual != null) {
			visual = customVisual;
			ownsCustomVisual = true;
		} else {
			visual = createAuthoredVisual(linkage, nextRandom);
		}
		addChild(visual);
		x = startX;
		y = startY;
		authoritativeX = x;
		authoritativeY = y;
		this.gravity = gravity;
		this.friction = friction;
		this.fadeRate = fadeRate;
		rotation = nextRandom() * 360;
		authoritativeRotation = rotation;
		velX = nextRandom() * spreadX * 2 - spreadX;
		velY = nextRandom() * spreadY * 2 - spreadY;
		rotVel = nextRandom() * spreadRot * 2 - spreadRot;
		addEventListener(Event.ENTER_FRAME, tick);
	}

	private function createAuthoredVisual(linkage:String, nextRandom:Void->Float):DisplayObject {
		return switch (linkage) {
			case "BrickPieceGraphic":
				selectedFrame = Std.int(nextRandom() * 5) + 1;
				exactFrame("brick_piece", selectedFrame);
			case "CrumblePieceGraphic":
				selectedFrame = 1;
				exactFrame("crumble_piece", selectedFrame);
			case "MinePieceGraphic":
				selectedFrame = Std.int(nextRandom() * 6) + 1;
				makeMinePiece(selectedFrame);
			default:
				throw 'Unsupported block piece graphic $linkage';
		}
	}

	private function exactFrame(kind:String, frame:Int):DisplayObject {
		var path = 'assets/svg/effects/${kind}_${StringTools.lpad(Std.string(frame), "0", 2)}.svg';
		var art = pr2.runtime.SvgAsset.create(path);
		art.name = path;
		return art;
	}

	private function makeMinePiece(frame:Int):DisplayObject {
		if (frame < 1 || frame > 6) throw 'Invalid mine piece frame $frame';
		return exactFrame("mine_piece", frame);
	}

	private function tick(_:Event):Void {
		if (!FrameClock.shouldRunSimulationFrame()) {
			renderPresentationFrame();
			return;
		}
		presentationPose.beginSimulationTick(
			authoritativeX,
			authoritativeY,
			authoritativeRotation,
			1,
			CharacterPresentationLayer.Front
		);
		velX *= friction;
		velY *= friction;
		rotVel *= friction;
		velY += gravity;
		authoritativeX += velX;
		authoritativeY += velY;
		authoritativeRotation += rotVel;
		x = authoritativeX;
		y = authoritativeY;
		rotation = authoritativeRotation;
		presentationPose.finishSimulationTick(
			authoritativeX,
			authoritativeY,
			authoritativeRotation,
			1,
			CharacterPresentationLayer.Front
		);
		alpha -= fadeRate;
		if (alpha <= 0) {
			remove();
		}
	}

	public function renderPresentationFrame():Void {
		if (!presentationPose.hasSamples) return;
		var factor = presentationPose.discontinuity ? 0.0 : 0.5;
		x = presentationPose.extrapolatedX(factor);
		y = presentationPose.extrapolatedY(factor);
		rotation = presentationPose.extrapolatedRotation(factor);
	}

	public function remove():Void {
		removeEventListener(Event.ENTER_FRAME, tick);
		if (visual != null && visual.parent == this) {
			removeChild(visual);
		}
		if (ownsCustomVisual) {
			var bitmap = Std.downcast(visual, Bitmap);
			if (bitmap != null && bitmap.bitmapData != null) {
				bitmap.bitmapData.dispose();
				bitmap.bitmapData = null;
			}
		}
		visual = null;
		ownsCustomVisual = false;
		if (parent != null) {
			parent.removeChild(this);
		}
	}
}
