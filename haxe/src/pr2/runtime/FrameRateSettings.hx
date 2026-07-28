package pr2.runtime;

import pr2.app.QueryParams;

/**
	Immutable frame-rate choices resolved once from the startup query string.

	This object describes intent only. Applying its presentation rate to the
	stage and scheduling 30 Hz simulation ticks are separate responsibilities.
**/
final class FrameRateSettings {
	public final strategy:FrameStrategy;
	public final smooth60Enabled:Bool;
	public final presentationFrameRate:Int;
	public final usesFixedSimulationClock:Bool;
	public final rendersIntermediatePresentationFrames:Bool;
	public final requires60HzPacing:Bool;

	public static function fromQuery(query:Null<String>, frameStrategiesSupported:Bool):FrameRateSettings {
		var strategy = FrameStrategy.fromQueryValue(QueryParams.get(query, "frame_strategy"));
		if (strategy == null && QueryParams.get(query, "smooth60") == "1") {
			strategy = FrameStrategy.Smooth60;
		}
		if (strategy == null || !frameStrategiesSupported) {
			strategy = FrameStrategy.Smooth30;
		}
		return new FrameRateSettings(strategy);
	}

	private function new(strategy:FrameStrategy) {
		this.strategy = strategy;
		smooth60Enabled = strategy == FrameStrategy.Smooth60;
		presentationFrameRate = strategy.presentationFrameRate;
		usesFixedSimulationClock = strategy.usesFixedSimulationClock;
		rendersIntermediatePresentationFrames = strategy.rendersIntermediatePresentationFrames;
		requires60HzPacing = strategy.requires60HzPacing;
	}
}
