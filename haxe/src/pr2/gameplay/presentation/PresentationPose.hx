package pr2.gameplay.presentation;

/**
	Reusable previous/current character pose storage.

	This is presentation-only state. Nothing in physics, collisions, networking,
	or the next simulation tick may read coordinates back from this object.
**/
class PresentationPose {
	public var hasSamples(default, null):Bool = false;

	public var previousX(default, null):Float = 0;
	public var previousY(default, null):Float = 0;
	public var previousRotation(default, null):Float = 0;
	public var previousFacing(default, null):Int = 1;
	public var previousLayer(default, null):CharacterPresentationLayer = CharacterPresentationLayer.Front;

	public var currentX(default, null):Float = 0;
	public var currentY(default, null):Float = 0;
	public var currentRotation(default, null):Float = 0;
	public var currentFacing(default, null):Int = 1;
	public var currentLayer(default, null):CharacterPresentationLayer = CharacterPresentationLayer.Front;

	public var discontinuity(default, null):Bool = true;
	private var simulationCaptureOpen:Bool = false;

	public function new() {}

	public function beginSimulationTick(
		x:Float,
		y:Float,
		rotation:Float,
		facing:Int,
		layer:CharacterPresentationLayer
	):Void {
		previousX = x;
		previousY = y;
		previousRotation = rotation;
		previousFacing = facing;
		previousLayer = layer;
		if (!hasSamples) {
			currentX = x;
			currentY = y;
			currentRotation = rotation;
			currentFacing = facing;
			currentLayer = layer;
			discontinuity = true;
		} else {
			discontinuity = false;
		}
		hasSamples = true;
		simulationCaptureOpen = true;
	}

	public function finishSimulationTick(
		x:Float,
		y:Float,
		rotation:Float,
		facing:Int,
		layer:CharacterPresentationLayer,
		discontinuous:Bool = false
	):Void {
		if (!simulationCaptureOpen) {
			beginSimulationTick(x, y, rotation, facing, layer);
		}
		currentX = x;
		currentY = y;
		currentRotation = rotation;
		currentFacing = facing;
		currentLayer = layer;
		discontinuity = discontinuity || discontinuous;
		simulationCaptureOpen = false;
	}

	public function markDiscontinuity():Void {
		discontinuity = true;
	}

	public static inline function shouldSnap(
		pendingLifecycleSnap:Bool,
		movementDiscontinuity:Bool,
		collision:Bool,
		courseRotationChanged:Bool,
		layerChanged:Bool,
		landed:Bool,
		horizontalVelocityReversed:Bool,
		verticalVelocityReversed:Bool,
		movementTooLarge:Bool
	):Bool {
		return pendingLifecycleSnap
			|| movementDiscontinuity
			|| collision
			|| courseRotationChanged
			|| layerChanged
			|| landed
			|| horizontalVelocityReversed
			|| verticalVelocityReversed
			|| movementTooLarge;
	}

	public static inline function velocityReversed(before:Float, after:Float):Bool {
		return before != 0 && after != 0 && (before < 0) != (after < 0);
	}

	public static inline function movementTooLarge(deltaX:Float, deltaY:Float, maxDistance:Float):Bool {
		return deltaX * deltaX + deltaY * deltaY > maxDistance * maxDistance;
	}

	public inline function extrapolatedX(factor:Float):Float {
		return currentX + factor * (currentX - previousX);
	}

	public inline function extrapolatedY(factor:Float):Float {
		return currentY + factor * (currentY - previousY);
	}

	public inline function extrapolatedRotation(factor:Float):Float {
		return currentRotation + factor * (currentRotation - previousRotation);
	}

	public function clear():Void {
		hasSamples = false;
		discontinuity = true;
		simulationCaptureOpen = false;
		previousX = currentX = 0;
		previousY = currentY = 0;
		previousRotation = currentRotation = 0;
		previousFacing = currentFacing = 1;
		previousLayer = currentLayer = CharacterPresentationLayer.Front;
	}
}
