package pr2.runtime;

class FrameRateDebugSignalsTest {
	private static var assertions:Int = 0;
	private static var now:Float = 0;

	public static function main():Void {
		testInitialAndMeasuredSignals();
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameRateDebugSignalsTest")) return;
		testDisabledFlag();
		testUnchangedValuesAreNotRepublished();
		trace('FrameRateDebugSignalsTest passed $assertions assertions');
	}

	private static function testInitialAndMeasuredSignals():Void {
		now = 0;
		var writes:Map<String, String> = new Map();
		var publisher = new FrameRateDebugSignals(function(name:String, value:String):Void writes.set(name, value));
		var settings = FrameRateSettings.fromQuery("?smooth60=1", true);
		var diagnostics = new FrameRateDiagnostics(currentTime);

		publisher.publish(settings, diagnostics);
		assertEquals("60smooth", writes.get("frame-strategy"), "resolved strategy signal");
		assertEquals("1", writes.get("smooth60"), "enabled flag signal");
		assertEquals("60", writes.get("presentation-fps-target"), "enabled presentation-rate target signal");
		assertEquals("pending", writes.get("presentation-fps"), "initial presentation signal");
		assertEquals("pending", writes.get("simulation-fps"), "initial simulation signal");

		for (frame in 0...60) {
			now = frame * (1000 / 60);
			diagnostics.recordPresentedFrame();
			if (frame % 2 == 0) diagnostics.recordSimulationTick();
		}
		now = 1000;
		diagnostics.refresh();
		publisher.publish(settings, diagnostics);
		assertEquals("60", writes.get("presentation-fps"), "measured presentation signal");
		assertEquals("30", writes.get("simulation-fps"), "measured simulation signal");
		assertEquals("60", writes.get("presentation-frame-samples"), "harness receives exact presented-frame window counts");
		assertEquals("30", writes.get("simulation-tick-samples"), "harness receives exact simulation-tick window counts");

	}

	private static function testDisabledFlag():Void {
		now = 0;
		var value:Null<String> = null;
		var publisher = new FrameRateDebugSignals(function(name:String, signalValue:String):Void {
			if (name == "smooth60") value = signalValue;
		});
		publisher.publish(FrameRateSettings.fromQuery(null, true), new FrameRateDiagnostics(currentTime));
		assertEquals("0", value, "disabled flag signal");
	}

	private static function testUnchangedValuesAreNotRepublished():Void {
		now = 0;
		var writeCount = 0;
		var publisher = new FrameRateDebugSignals(function(_:String, _:String):Void writeCount++);
		var settings = FrameRateSettings.fromQuery(null, true);
		var diagnostics = new FrameRateDiagnostics(currentTime);

		publisher.publish(settings, diagnostics);
		publisher.publish(settings, diagnostics);

		assertEquals(5, writeCount, "five initial attributes written once");
	}

	private static function currentTime():Float {
		return now;
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}
}
