package pr2.character;

import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.ColorTransform;
import pr2.assets.NativeAssetIds.StaticSvg;
import pr2.assets.NativeAssets;
import pr2.runtime.FrameClock;
import pr2.gameplay.presentation.CharacterPresentationLayer;
import pr2.gameplay.presentation.PresentationPose;

typedef PhysicsParticleParams = {
	var graphic:String;
	var colors:Array<Int>;
	var life:Int;
	var startAlpha:Float;
	var minVelAlpha:Null<Float>;
	var maxVelAlpha:Null<Float>;
	var minVelX:Null<Float>;
	var maxVelX:Null<Float>;
	var minVelY:Null<Float>;
	var maxVelY:Null<Float>;
	var velScaleX:Float;
	var velScaleY:Float;
	var fricX:Null<Float>;
	var fricY:Null<Float>;
	var minOffsetX:Float;
	var maxOffsetX:Float;
	var minOffsetY:Float;
	var maxOffsetY:Float;
	var minScale:Float;
	var maxScale:Float;
	@:optional var minX:Null<Float>;
	@:optional var maxX:Null<Float>;
	@:optional var minY:Null<Float>;
	@:optional var maxY:Null<Float>;
	@:optional var accelX:Null<Float>;
	@:optional var accelY:Null<Float>;
	@:optional var targetAlpha:Null<Float>;
	@:optional var minVelRotation:Null<Float>;
	@:optional var maxVelRotation:Null<Float>;
	@:optional var minRotation:Null<Float>;
	@:optional var maxRotation:Null<Float>;
}

class PhysicsParticle extends Sprite {
	public var graphic(default, null):DisplayObject;
	private var velX:Float;
	private var velY:Float;
	private var fricX:Float;
	private var fricY:Float;
	private var accelX:Float;
	private var accelY:Float;
	private var maxLife:Int;
	private var life:Int;
	private var curAlpha:Float;
	private var velAlpha:Float;
	private var velScaleX:Float;
	private var velScaleY:Float;
	private var velRotation:Float;
	private final random:Void->Float;
	private final presentationPose:PresentationPose = new PresentationPose();
	private var authoritativeX:Float;
	private var authoritativeY:Float;
	private var authoritativeRotation:Float;
	private var authoritativeScaleX:Float;
	private var authoritativeScaleY:Float;
	private var previousScaleX:Float;
	private var previousScaleY:Float;

	public function new(params:PhysicsParticleParams, ?random:Void->Float) {
		super();
		this.random = random == null ? Math.random : random;
		setColor(params.colors);
		x = randRange(params.minX, params.maxX);
		y = randRange(params.minY, params.maxY);
		rotation = randRange(params.minRotation, params.maxRotation);
		scaleX = scaleY = randRange(params.minScale, params.maxScale);
		authoritativeX = x;
		authoritativeY = y;
		authoritativeRotation = rotation;
		authoritativeScaleX = previousScaleX = scaleX;
		authoritativeScaleY = previousScaleY = scaleY;
		velX = randRange(params.minVelX, params.maxVelX);
		velY = randRange(params.minVelY, params.maxVelY);
		fricX = params.fricX == null ? 1 : params.fricX;
		fricY = params.fricY == null ? 1 : params.fricY;
		accelX = params.accelX == null ? 0 : params.accelX;
		accelY = params.accelY == null ? 0 : params.accelY;
		life = maxLife = params.life == 0 ? 10 : params.life;
		curAlpha = alpha = params.startAlpha;
		velAlpha = randRange(params.minVelAlpha, params.maxVelAlpha);
		velScaleX = params.velScaleX;
		velScaleY = params.velScaleY;
		velRotation = randRange(params.minVelRotation, params.maxVelRotation);
		graphic = makeGraphic(params.graphic);
		if (graphic != null) {
			addChild(graphic);
		}
		addEventListener(Event.ENTER_FRAME, tick);
	}

	private function setColor(colors:Array<Int>):Void {
		if (colors == null || colors.length == 0) {
			return;
		}
		var index = Std.int(Math.floor(random() * colors.length));
		if (index >= colors.length) {
			index = colors.length - 1;
		}
		var transform = new ColorTransform();
		transform.color = colors[index];
		this.transform.colorTransform = transform;
	}

	private function makeGraphic(name:String):DisplayObject {
		if (name != "DjinnIceGraphic") throw 'Unsupported native particle graphic $name';
		// The source-derived SVG already contains Symbol 1200's authored 0.100006
		// instance matrix. Applying it again shrinks the 10x10 particle to 1x1.
		return NativeAssets.svg(StaticSvg.DjinnIce);
	}

	private function randRange(min:Null<Float>, max:Null<Float>):Float {
		if (min == null || max == null || Math.isNaN(min) || Math.isNaN(max)) {
			return 0;
		}
		return random() * (max - min) + min;
	}

	@:allow(pr2.character.ParticleEmitterTest)
	private function tick(_:Event):Void {
		if (!FrameClock.shouldRunSimulationFrame()) {
			if (FrameClock.shouldRenderIntermediatePresentationFrame()) renderPresentationFrame();
			return;
		}
		presentationPose.beginSimulationTick(
			authoritativeX,
			authoritativeY,
			authoritativeRotation,
			1,
			CharacterPresentationLayer.Front
		);
		previousScaleX = authoritativeScaleX;
		previousScaleY = authoritativeScaleY;
		authoritativeX += velX;
		authoritativeY += velY;
		velX = (velX + accelX) * fricX;
		velY = (velY + accelY) * fricY;
		authoritativeScaleX += velScaleX;
		authoritativeScaleY += velScaleY;
		authoritativeRotation += velRotation;
		x = authoritativeX;
		y = authoritativeY;
		scaleX = authoritativeScaleX;
		scaleY = authoritativeScaleY;
		rotation = authoritativeRotation;
		presentationPose.finishSimulationTick(
			authoritativeX,
			authoritativeY,
			authoritativeRotation,
			1,
			CharacterPresentationLayer.Front
		);
		curAlpha += velAlpha;
		if (curAlpha > 1) {
			curAlpha = 1;
		}
		alpha = curAlpha * (life / maxLife);
		life--;
		if (life <= 0) {
			remove();
		}
	}

	public function renderPresentationFrame():Void {
		if (!presentationPose.hasSamples) return;
		var factor = presentationPose.discontinuity ? 0.0 : 0.5;
		x = presentationPose.extrapolatedX(factor);
		y = presentationPose.extrapolatedY(factor);
		rotation = presentationPose.extrapolatedRotation(factor);
		scaleX = authoritativeScaleX + factor * (authoritativeScaleX - previousScaleX);
		scaleY = authoritativeScaleY + factor * (authoritativeScaleY - previousScaleY);
	}

	public function remove():Void {
		removeEventListener(Event.ENTER_FRAME, tick);
		if (graphic != null && graphic.parent == this) {
			removeChild(graphic);
		}
		graphic = null;
		if (parent != null) {
			parent.removeChild(this);
		}
	}
}
