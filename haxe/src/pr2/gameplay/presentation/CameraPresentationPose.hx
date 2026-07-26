package pr2.gameplay.presentation;

/**
	Separates the 30 Hz logical camera from its disposable rendered position.

	`previous/current` are copies of authoritative CameraFollow output. The
	`presented` coordinates may be changed between ticks and must never be read
	back into CameraFollow.
**/
class CameraPresentationPose {
	public var hasSamples(default, null):Bool = false;
	public var previousX(default, null):Float = 0;
	public var previousY(default, null):Float = 0;
	public var currentX(default, null):Float = 0;
	public var currentY(default, null):Float = 0;
	public var presentedX(default, null):Float = 0;
	public var presentedY(default, null):Float = 0;
	private var authoritativeUpdateOpen:Bool = false;

	public function new() {}

	public function beginAuthoritativeUpdate(x:Float, y:Float):Void {
		previousX = x;
		previousY = y;
		if (!hasSamples) {
			currentX = x;
			currentY = y;
			presentedX = x;
			presentedY = y;
		}
		hasSamples = true;
		authoritativeUpdateOpen = true;
	}

	public function finishAuthoritativeUpdate(x:Float, y:Float):Void {
		if (!authoritativeUpdateOpen) beginAuthoritativeUpdate(x, y);
		currentX = x;
		currentY = y;
		presentedX = x;
		presentedY = y;
		authoritativeUpdateOpen = false;
	}

	public function present(x:Float, y:Float):Void {
		presentedX = x;
		presentedY = y;
	}

	public inline function extrapolatedX(factor:Float):Float {
		return currentX + factor * (currentX - previousX);
	}

	public inline function extrapolatedY(factor:Float):Float {
		return currentY + factor * (currentY - previousY);
	}

	public function clear():Void {
		hasSamples = false;
		authoritativeUpdateOpen = false;
		previousX = currentX = presentedX = 0;
		previousY = currentY = presentedY = 0;
	}
}
