package pr2.runtime;

/**
	User-selectable relationship between browser presentation frames and the
	authoritative 30 Hz simulation.
**/
enum abstract FrameStrategy(String) to String {
	var Smooth30 = "30smooth";
	var Fixed30 = "30fixed";
	var Smooth60 = "60smooth";
	var Fixed60 = "60fixed";

	public static function fromQueryValue(value:Null<String>):Null<FrameStrategy> {
		return switch (value) {
			case "30smooth": Smooth30;
			case "30fixed": Fixed30;
			case "60smooth": Smooth60;
			case "60fixed": Fixed60;
			default: null;
		};
	}

	public var presentationFrameRate(get, never):Int;
	public var usesFixedSimulationClock(get, never):Bool;
	public var rendersIntermediatePresentationFrames(get, never):Bool;
	public var requires60HzPacing(get, never):Bool;

	private inline function get_presentationFrameRate():Int {
		return this == Smooth30 ? 30 : 60;
	}

	private inline function get_usesFixedSimulationClock():Bool {
		return this == Fixed30 || this == Fixed60;
	}

	private inline function get_rendersIntermediatePresentationFrames():Bool {
		return this == Smooth60 || this == Fixed60;
	}

	private inline function get_requires60HzPacing():Bool {
		return presentationFrameRate == 60;
	}
}
