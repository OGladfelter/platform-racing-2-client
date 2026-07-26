package pr2.character;

/**
	Explicit remote-player extra-frame policy.

	Delayed interpolation would require rendering the previous simulation pose
	on simulation frames to remain monotonic, adding one full 30 Hz tick of
	latency. Guarded extrapolation keeps the latest authoritative remote pose on
	simulation frames and predicts only the disposable intervening frame.
**/
class RemotePresentationPolicy {
	public static inline var SELECTED:String = "guarded-extrapolation";
	public static inline var EXTRA_FRAME_FACTOR:Float = 0.5;

	public static inline function delayedInterpolation(previous:Float, current:Float):Float {
		return previous + EXTRA_FRAME_FACTOR * (current - previous);
	}

	public static inline function guardedExtrapolation(previous:Float, current:Float, discontinuous:Bool):Float {
		return discontinuous ? current : current + EXTRA_FRAME_FACTOR * (current - previous);
	}

	public static inline function correctionDistance(presented:Float, nextAuthoritative:Float):Float {
		return Math.abs(nextAuthoritative - presented);
	}
}
