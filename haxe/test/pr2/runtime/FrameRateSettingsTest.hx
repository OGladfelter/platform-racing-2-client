package pr2.runtime;

import pr2.Constants;

class FrameRateSettingsTest {
	private static var assertions:Int = 0;

	public static function main():Void {
		testDisabledValues();
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameRateSettingsTest")) return;
		testExactOptIn();
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
			"?other=1"
		]) {
			assertDisabled(FrameRateSettings.fromQuery(query, true), 'disabled query ${Std.string(query)}');
		}
	}

	private static function testExactOptIn():Void {
		var settings = FrameRateSettings.fromQuery("?smooth60=1", true);
		assertEquals(true, settings.smooth60Enabled, "exact flag enables smooth presentation");
		assertEquals(Constants.SMOOTH_PRESENTATION_FRAME_RATE, settings.presentationFrameRate, "enabled presentation rate");
		assertEquals(false, Constants.SMOOTH60_AUTOMATIC_FALLBACK_ENABLED, "automatic fallback disabled for definitive flag testing");
		assertDisabled(FrameRateSettings.fromQuery("?smooth60=1", false), "unsupported target");
	}

	private static function testNormalQueryParsing():Void {
		assertEquals(true, FrameRateSettings.fromQuery("?screen=campaign&smooth60=1", true).smooth60Enabled, "flag composes with other params");
		assertEquals(true, FrameRateSettings.fromQuery("?SMOOTH60=1", true).smooth60Enabled, "query key is case-insensitive");
		assertEquals(true, FrameRateSettings.fromQuery("?smooth60=%31", true).smooth60Enabled, "query value is URL-decoded");
		assertEquals(false, FrameRateSettings.fromQuery("?smooth60=1&smooth60=0", true).smooth60Enabled, "last repeated value wins");
		assertEquals(true, FrameRateSettings.fromQuery("?smooth60=0&smooth60=1", true).smooth60Enabled, "last repeated opt-in wins");
	}

	private static function testHtml5PresentationPacing():Void {
		assertEquals(true, Html5PresentationPacer.shouldCapNativeRefresh(true, 60),
			"smooth 60 opts into elapsed-time presentation pacing");
		assertEquals(false, Html5PresentationPacer.shouldCapNativeRefresh(false, 60),
			"regular mode does not alter native-refresh pacing");
		assertEquals(false, Html5PresentationPacer.shouldCapNativeRefresh(true, 30),
			"fallback 30 FPS keeps Lime's normal pacing");
		assertClose(1000.0 / 60, Html5PresentationPacer.framePeriodMs(60),
			"smooth presentation uses a 60 Hz millisecond interval");
	}

	private static function assertDisabled(settings:FrameRateSettings, message:String):Void {
		assertEquals(false, settings.smooth60Enabled, '$message enabled state');
		assertEquals(Constants.DEFAULT_PRESENTATION_FRAME_RATE, settings.presentationFrameRate, '$message presentation rate');
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
