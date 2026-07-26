package pr2.runtime;

import pr2.Constants;
import pr2.app.QueryParams;

/**
	Immutable frame-rate choices resolved once from the startup query string.

	This object describes intent only. Applying its presentation rate to the
	stage and scheduling 30 Hz simulation ticks are separate responsibilities.
**/
final class FrameRateSettings {
	public final smooth60Enabled:Bool;
	public final presentationFrameRate:Int;

	public static function fromQuery(query:Null<String>, smooth60Supported:Bool):FrameRateSettings {
		var smooth60Enabled = smooth60Supported && QueryParams.get(query, "smooth60") == "1";
		return new FrameRateSettings(
			smooth60Enabled,
			smooth60Enabled ? Constants.SMOOTH_PRESENTATION_FRAME_RATE : Constants.DEFAULT_PRESENTATION_FRAME_RATE
		);
	}

	private function new(smooth60Enabled:Bool, presentationFrameRate:Int) {
		this.smooth60Enabled = smooth60Enabled;
		this.presentationFrameRate = presentationFrameRate;
	}
}
