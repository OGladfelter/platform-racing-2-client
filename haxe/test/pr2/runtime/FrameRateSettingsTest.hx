package pr2.runtime;

import pr2.Constants;

class FrameRateSettingsTest {
	private static var assertions:Int = 0;

	public static function main():Void {
		testDisabledValues();
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameRateSettingsTest")) return;
		testExactOptIn();
		testExplicitStrategies();
		testNormalQueryParsing();
		testHtml5PresentationPacing();
		trace('FrameRateSettingsTest passed $assertions assertions');
	}

	private static function testDisabledValues():Void {
		for (query in [
			null,
			"",
			"?",
			"?smooth60",
			"?smooth60=",
			"?smooth60=0",
			"?smooth60=true",
			"?smooth60=01",
			"?smooth60=60",
			"?frame_strategy=invalid",
			"?other=1"
		]) {
			assertDisabled(FrameRateSettings.fromQuery(query, true), 'disabled query ${Std.string(query)}');
		}
	}

	private static function testExactOptIn():Void {
		var settings = FrameRateSettings.fromQuery("?smooth60=1", true);
		assertEquals(true, settings.smooth60Enabled, "exact flag enables smooth presentation");
		assertEquals(FrameStrategy.Smooth60, settings.strategy, "legacy flag aliases 60smooth");
		assertEquals(Constants.SMOOTH_PRESENTATION_FRAME_RATE, settings.presentationFrameRate, "enabled presentation rate");
		assertDisabled(FrameRateSettings.fromQuery("?smooth60=1", false), "unsupported target");
	}

	private static function testExplicitStrategies():Void {
		assertStrategy("?frame_strategy=30smooth", FrameStrategy.Smooth30, 30, false, false);
		assertStrategy("?frame_strategy=30fixed", FrameStrategy.Fixed30, 60, true, false);
		assertStrategy("?frame_strategy=60smooth", FrameStrategy.Smooth60, 60, false, true);
		assertStrategy("?frame_strategy=60fixed", FrameStrategy.Fixed60, 60, true, true);
		assertDisabled(FrameRateSettings.fromQuery("?frame_strategy=60fixed", false), "strategies unsupported on target");
	}

	private static function testNormalQueryParsing():Void {
		assertEquals(true, FrameRateSettings.fromQuery("?screen=campaign&smooth60=1", true).smooth60Enabled, "flag composes with other params");
		assertEquals(true, FrameRateSettings.fromQuery("?SMOOTH60=1", true).smooth60Enabled, "query key is case-insensitive");
		assertEquals(true, FrameRateSettings.fromQuery("?smooth60=%31", true).smooth60Enabled, "query value is URL-decoded");
		assertEquals(false, FrameRateSettings.fromQuery("?smooth60=1&smooth60=0", true).smooth60Enabled, "last repeated value wins");
		assertEquals(true, FrameRateSettings.fromQuery("?smooth60=0&smooth60=1", true).smooth60Enabled, "last repeated opt-in wins");
		assertEquals(FrameStrategy.Fixed60,
			FrameRateSettings.fromQuery("?smooth60=1&frame_strategy=60fixed", true).strategy,
			"valid explicit strategy wins over legacy flag");
		assertEquals(FrameStrategy.Smooth60,
			FrameRateSettings.fromQuery("?smooth60=1&frame_strategy=invalid", true).strategy,
			"invalid explicit strategy falls through to legacy flag");
		assertEquals(FrameStrategy.Fixed30,
			FrameRateSettings.fromQuery("?FRAME_STRATEGY=30fixed", true).strategy,
			"strategy query key is case-insensitive");
		assertEquals(FrameStrategy.Fixed60,
			FrameRateSettings.fromQuery("?frame_strategy=30smooth&frame_strategy=60fixed", true).strategy,
			"last repeated strategy wins");
	}

	private static function testHtml5PresentationPacing():Void {
		assertEquals(true, Html5PresentationPacer.shouldCapNativeRefresh(true, 60),
			"requested 60 opts into elapsed-time presentation pacing");
		assertEquals(false, Html5PresentationPacer.shouldCapNativeRefresh(false, 60),
			"disabled pacing does not alter native-refresh behavior");
		assertEquals(false, Html5PresentationPacer.shouldCapNativeRefresh(true, 30),
			"fallback 30 FPS keeps Lime's normal pacing");
		assertClose(1000.0 / 60, Html5PresentationPacer.framePeriodMs(60),
			"smooth presentation uses a 60 Hz millisecond interval");
	}

	private static function assertDisabled(settings:FrameRateSettings, message:String):Void {
		assertEquals(FrameStrategy.Smooth30, settings.strategy, '$message strategy');
		assertEquals(false, settings.smooth60Enabled, '$message enabled state');
		assertEquals(Constants.DEFAULT_PRESENTATION_FRAME_RATE, settings.presentationFrameRate, '$message presentation rate');
	}

	private static function assertStrategy(query:String, expected:FrameStrategy, expectedPresentationRate:Int,
			expectedFixed:Bool, expectedIntermediate:Bool):Void {
		var settings = FrameRateSettings.fromQuery(query, true);
		assertEquals(expected, settings.strategy, '$query strategy');
		assertEquals(expectedPresentationRate, settings.presentationFrameRate, '$query presentation rate');
		assertEquals(expectedFixed, settings.usesFixedSimulationClock, '$query fixed clock');
		assertEquals(expectedIntermediate, settings.rendersIntermediatePresentationFrames, '$query intermediate presentation');
		assertEquals(expectedPresentationRate == 60, settings.requires60HzPacing, '$query Lime pacing');
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}

	private static function assertClose(expected:Float, actual:Float, message:String):Void {
		assertions++;
		if (Math.abs(expected - actual) > 0.000001) throw '$message: expected $expected, got $actual';
	}
}
