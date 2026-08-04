package pr2.runtime;

class FrameRateDiagnosticsTest {
	private static var assertions:Int = 0;
	private static var now:Float = 0;

	public static function main():Void {
		pr2.DeterministicTestMode.runTest("FrameRateDiagnosticsTest.testCountersAreIndependent", testCountersAreIndependent);
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameRateDiagnosticsTest")) return;
		pr2.DeterministicTestMode.runTest("FrameRateDiagnosticsTest.testSeparateThirtyAndSixtyRates", testSeparateThirtyAndSixtyRates);
		pr2.DeterministicTestMode.runTest("FrameRateDiagnosticsTest.testWindowRolloverPreservesTotals", testWindowRolloverPreservesTotals);
		trace('FrameRateDiagnosticsTest passed $assertions assertions');
	}

	private static function testCountersAreIndependent():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		diagnostics.recordPresentedFrame();
		diagnostics.recordPresentedFrame();
		diagnostics.recordSimulationTick();

		assertEquals(2, diagnostics.totalPresentedFrames, "presented total");
		assertEquals(1, diagnostics.totalSimulationTicks, "simulation total");
		assertTrue(Math.isNaN(diagnostics.presentedFramesPerSecond), "presentation rate waits for a complete window");
		assertTrue(Math.isNaN(diagnostics.simulationTicksPerSecond), "simulation rate waits for a complete window");
	}

	private static function testSeparateThirtyAndSixtyRates():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		for (frame in 0...60) {
			now = frame * (1000 / 60);
			diagnostics.recordPresentedFrame();
			if (frame % 2 == 0) {
				diagnostics.recordSimulationTick();
			}
		}
		now = 1000;
		diagnostics.refresh();

		assertClose(60, diagnostics.presentedFramesPerSecond, "presentation rate");
		assertClose(30, diagnostics.simulationTicksPerSecond, "simulation rate");
		assertEquals(1, diagnostics.completedWindows, "one diagnostic window completed");
		assertEquals(60, diagnostics.lastWindowPresentedFrames, "window records exact presented-frame count");
		assertEquals(30, diagnostics.lastWindowSimulationTicks, "window records exact simulation-tick count");
		assertClose(1000, diagnostics.lastWindowElapsedMs, "window records its wall-clock span");
		assertEquals(60, diagnostics.totalPresentedFrames, "presentation total after rate sample");
		assertEquals(30, diagnostics.totalSimulationTicks, "simulation total after rate sample");
	}

	private static function testWindowRolloverPreservesTotals():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		diagnostics.recordPresentedFrame();
		diagnostics.recordSimulationTick();
		now = 1250;
		diagnostics.refresh();
		assertClose(0.8, diagnostics.presentedFramesPerSecond, "long-window presentation rate");
		assertClose(0.8, diagnostics.simulationTicksPerSecond, "long-window simulation rate");

		diagnostics.recordPresentedFrame();
		assertEquals(2, diagnostics.totalPresentedFrames, "presentation total survives rollover");
		assertEquals(1, diagnostics.totalSimulationTicks, "simulation total survives rollover");
	}

	private static function currentTime():Float {
		return now;
	}

	private static function assertTrue(value:Bool, message:String):Void {
		assertions++;
		if (!value) throw '$message: expected true';
	}

	private static function assertClose(expected:Float, actual:Float, message:String):Void {
		assertions++;
		if (Math.abs(expected - actual) > 0.000000000001) throw '$message: expected $expected, got $actual';
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}
}
