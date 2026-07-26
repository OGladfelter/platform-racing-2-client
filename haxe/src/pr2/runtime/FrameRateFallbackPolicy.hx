package pr2.runtime;

/**
	Session-only smooth-presentation support policy.

	The first two complete diagnostic windows are warm-up. After that, three
	consecutive one-second windows averaging 20 ms or slower per presented frame
	classify 60 FPS presentation as unsupported for the rest of the session.
**/
class FrameRateFallbackPolicy {
	public static inline var WARMUP_WINDOWS:Int = 2;
	public static inline var SLOW_PRESENTATION_FRAME_MS:Float = 20;
	public static inline var REQUIRED_CONSECUTIVE_SLOW_WINDOWS:Int = 3;

	public var observedWindows(default, null):Int = 0;
	public var consecutiveSlowWindows(default, null):Int = 0;
	public var unsupported(default, null):Bool = false;
	public var lastAveragePresentationFrameMs(default, null):Float = Math.NaN;

	public function new() {}

	public function observeWindow(presentedFrames:Int, elapsedMs:Float):Bool {
		if (unsupported) {
			return true;
		}
		observedWindows++;
		lastAveragePresentationFrameMs = presentedFrames <= 0 ? Math.POSITIVE_INFINITY : elapsedMs / presentedFrames;
		if (observedWindows <= WARMUP_WINDOWS) {
			consecutiveSlowWindows = 0;
			return false;
		}
		if (lastAveragePresentationFrameMs >= SLOW_PRESENTATION_FRAME_MS) {
			consecutiveSlowWindows++;
		} else {
			consecutiveSlowWindows = 0;
		}
		if (consecutiveSlowWindows >= REQUIRED_CONSECUTIVE_SLOW_WINDOWS) {
			unsupported = true;
		}
		return unsupported;
	}
}
