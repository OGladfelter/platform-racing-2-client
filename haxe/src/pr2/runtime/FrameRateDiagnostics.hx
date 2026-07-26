package pr2.runtime;

import haxe.Timer;

/**
	Counts presentation frames and authoritative simulation ticks independently.

	The shared instance is application diagnostics only. Tests and harnesses can
	construct isolated instances with a deterministic clock.
**/
class FrameRateDiagnostics {
	public static final shared:FrameRateDiagnostics = new FrameRateDiagnostics();

	public var totalPresentedFrames(default, null):Int = 0;
	public var totalSimulationTicks(default, null):Int = 0;
	public var presentedFramesPerSecond(default, null):Float = Math.NaN;
	public var simulationTicksPerSecond(default, null):Float = Math.NaN;
	public var completedWindows(default, null):Int = 0;
	public var lastWindowPresentedFrames(default, null):Int = 0;
	public var lastWindowSimulationTicks(default, null):Int = 0;
	public var lastWindowElapsedMs(default, null):Float = 0;

	private final nowMs:Void->Float;
	private var windowStartedAt:Float;
	private var windowPresentedFrames:Int = 0;
	private var windowSimulationTicks:Int = 0;

	public function new(?nowMs:Void->Float) {
		this.nowMs = nowMs == null ? defaultNowMs : nowMs;
		windowStartedAt = this.nowMs();
	}

	public function recordPresentedFrame():Void {
		refresh();
		totalPresentedFrames++;
		windowPresentedFrames++;
	}

	public function recordSimulationTick():Void {
		refresh();
		totalSimulationTicks++;
		windowSimulationTicks++;
	}

	public function refresh():Void {
		var now = nowMs();
		var elapsed = now - windowStartedAt;
		if (elapsed < 1000) {
			return;
		}
		presentedFramesPerSecond = windowPresentedFrames * 1000 / elapsed;
		simulationTicksPerSecond = windowSimulationTicks * 1000 / elapsed;
		lastWindowPresentedFrames = windowPresentedFrames;
		lastWindowSimulationTicks = windowSimulationTicks;
		lastWindowElapsedMs = elapsed;
		completedWindows++;
		windowStartedAt = now;
		windowPresentedFrames = 0;
		windowSimulationTicks = 0;
	}

	private static function defaultNowMs():Float {
		return Timer.stamp() * 1000;
	}
}
