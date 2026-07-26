package pr2.runtime;

import pr2.app.DebugSignal;

/** Publishes frame-rate diagnostics only when their formatted values change. */
class FrameRateDebugSignals {
	private final setSignal:String->String->Void;
	private final published:Map<String, String> = new Map();
	private final presentationFrameSamples:Array<Int> = [];
	private final simulationTickSamples:Array<Int> = [];
	private var lastSampledWindow:Int = 0;
	private static inline var MAX_SAMPLES:Int = 120;

	public function new(?setSignal:String->String->Void) {
		this.setSignal = setSignal == null ? DebugSignal.set : setSignal;
	}

	public function publish(settings:FrameRateSettings, diagnostics:FrameRateDiagnostics,
			?effectivePresentationFrameRate:Int, fallbackActive:Bool = false):Void {
		var effectiveRate = effectivePresentationFrameRate == null
			? settings.presentationFrameRate
			: effectivePresentationFrameRate;
		setIfChanged("smooth60", settings.smooth60Enabled ? "1" : "0");
		setIfChanged("smooth60-fallback", fallbackActive ? "1" : "0");
		setIfChanged("presentation-fps-target", Std.string(effectiveRate));
		setIfChanged("presentation-fps", formatRate(diagnostics.presentedFramesPerSecond));
		setIfChanged("simulation-fps", formatRate(diagnostics.simulationTicksPerSecond));
		if (diagnostics.completedWindows > lastSampledWindow) {
			presentationFrameSamples.push(diagnostics.lastWindowPresentedFrames);
			simulationTickSamples.push(diagnostics.lastWindowSimulationTicks);
			if (presentationFrameSamples.length > MAX_SAMPLES) presentationFrameSamples.shift();
			if (simulationTickSamples.length > MAX_SAMPLES) simulationTickSamples.shift();
			lastSampledWindow = diagnostics.completedWindows;
			setIfChanged("presentation-frame-samples", presentationFrameSamples.join(","));
			setIfChanged("simulation-tick-samples", simulationTickSamples.join(","));
		}
	}

	private function setIfChanged(name:String, value:String):Void {
		if (published.get(name) == value) {
			return;
		}
		published.set(name, value);
		setSignal(name, value);
	}

	private static function formatRate(value:Float):String {
		if (Math.isNaN(value)) {
			return "pending";
		}
		return Std.string(Math.round(value * 10) / 10);
	}
}
