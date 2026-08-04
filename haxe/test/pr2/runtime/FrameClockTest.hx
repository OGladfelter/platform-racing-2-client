package pr2.runtime;

class FrameClockTest {
	private static var assertions:Int = 0;
	private static var now:Float = 0;

	public static function main():Void {
		pr2.DeterministicTestMode.runTest("FrameClockTest.testDefaultFramesAreSimulationFrames", testDefaultFramesAreSimulationFrames);
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameClockTest")) return;
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothStartupRunsExactlyOneSimulationFrame", testSmoothStartupRunsExactlyOneSimulationFrame);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothFramesAlternate", testSmoothFramesAlternate);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testFrameCallbackObservesUpdatedPhase", testFrameCallbackObservesUpdatedPhase);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testResetRebasesWithoutSynthesizingTicks", testResetRebasesWithoutSynthesizingTicks);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testLongRunCadence", testLongRunCadence);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testRepeatedPhaseResets", testRepeatedPhaseResets);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothAlternationAt57Fps", testSmoothAlternationAt57Fps);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothAlternationAt55Fps", testSmoothAlternationAt55Fps);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothDoesNotProtectLowFrameRates", testSmoothDoesNotProtectLowFrameRates);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testSmoothClockReliesOn60HzBrowserPacer", testSmoothClockReliesOn60HzBrowserPacer);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testFixedNominalCadence", testFixedNominalCadence);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testFixedCatchUpAndRemainder", testFixedCatchUpAndRemainder);
		pr2.DeterministicTestMode.runTest("FrameClockTest.testFixedPresentationPolicies", testFixedPresentationPolicies);
		trace('FrameClockTest passed $assertions assertions');
	}

	private static function testLongRunCadence():Void {
		now = 0;
		var smoothDiagnostics = new FrameRateDiagnostics(currentTime);
		var smooth = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), smoothDiagnostics);
		for (_ in 0...6000) smooth.advanceFrame();
		assertEquals(6000, smooth.stageFrameNumber, "smooth long run presented frames");
		assertEquals(3000, smooth.simulationFrameNumber, "smooth long run keeps exact half-rate simulation");
		assertEquals(3000, smooth.presentationOnlyFrameNumber, "smooth long run presentation-only frames");
		assertEquals(6000, smoothDiagnostics.totalPresentedFrames, "clock diagnostics count every presented frame");
		assertEquals(3000, smoothDiagnostics.totalSimulationTicks, "clock diagnostics independently count only simulation phases");

		var unflaggedDiagnostics = new FrameRateDiagnostics(currentTime);
		var unflagged = new FrameClock(FrameRateSettings.fromQuery(null, true), unflaggedDiagnostics);
		for (_ in 0...3000) unflagged.advanceFrame();
		assertEquals(3000, unflagged.stageFrameNumber, "unflagged long run presented frames");
		assertEquals(3000, unflagged.simulationFrameNumber, "unflagged long run simulates every frame");
		assertEquals(0, unflagged.presentationOnlyFrameNumber, "unflagged long run has no extra frames");
		assertEquals(3000, unflaggedDiagnostics.totalSimulationTicks, "unflagged diagnostics count every frame as simulation");
	}

	private static function testSmoothAlternationAt57Fps():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 57;
		for (frame in 0...(57 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(285, clock.stageFrameNumber, "57 FPS smooth mode records every accepted callback");
		assertEquals(143, clock.simulationFrameNumber, "57 FPS smooth mode runs physics on alternating frames");
		assertEquals(142, clock.presentationOnlyFrameNumber, "57 FPS smooth mode preserves strict alternation");
	}

	private static function testSmoothAlternationAt55Fps():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 55;
		for (frame in 0...(55 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(275, clock.stageFrameNumber, "55 FPS smooth mode records every accepted callback");
		assertEquals(138, clock.simulationFrameNumber, "55 FPS smooth mode runs physics on alternating frames");
		assertEquals(137, clock.presentationOnlyFrameNumber, "55 FPS smooth mode preserves strict alternation");
	}

	private static function testSmoothDoesNotProtectLowFrameRates():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 53;
		for (frame in 0...(53 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(265, clock.stageFrameNumber, "53 FPS smooth mode records every accepted callback");
		assertEquals(133, clock.simulationFrameNumber, "53 FPS smooth mode deliberately allows physics below twenty-seven FPS");
		assertEquals(132, clock.presentationOnlyFrameNumber, "53 FPS smooth mode never sacrifices its visual phases");
	}

	private static function testSmoothClockReliesOn60HzBrowserPacer():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 120;
		for (frame in 0...120) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(120, clock.stageFrameNumber, "clock records every callback supplied by its upstream pacer");
		assertEquals(60, clock.simulationFrameNumber, "strict alternation relies on Lime's elapsed-time 60 Hz cap");
		assertEquals(60, clock.presentationOnlyFrameNumber, "strict alternation does not perform a second internal high-refresh cap");
	}

	private static function testFixedNominalCadence():Void {
		for (strategy in ["30fixed", "60fixed"]) {
			var diagnostics = new FrameRateDiagnostics(currentTime);
			var clock = new FrameClock(FrameRateSettings.fromQuery('?frame_strategy=$strategy', true), diagnostics);
			for (_ in 0...6000) clock.advanceFrame();
			assertEquals(6000, clock.stageFrameNumber, '$strategy accepted-frame count');
			assertEquals(3000, clock.simulationFrameNumber, '$strategy exact nominal 30 Hz simulation');
			assertEquals(3000, diagnostics.totalSimulationTicks, '$strategy diagnostics count every fixed tick');
		}
	}

	private static function testFixedCatchUpAndRemainder():Void {
		for (strategy in ["30fixed", "60fixed"]) {
			var clock = new FrameClock(FrameRateSettings.fromQuery('?frame_strategy=$strategy', true),
				new FrameRateDiagnostics(currentTime));
			clock.advanceFrame(0);
			assertEquals(1, clock.simulationTicksThisBrowserFrame, '$strategy starts with an immediate authoritative tick');
			clock.advanceFrame(10);
			assertEquals(0, clock.simulationTicksThisBrowserFrame, '$strategy can spend a callback on presentation only');
			clock.advanceFrame(40);
			assertEquals(1, clock.simulationTicksThisBrowserFrame, '$strategy preserves sub-tick elapsed credit');
			clock.advanceFrame(140);
			assertEquals(2, clock.simulationTicksThisBrowserFrame, '$strategy caps catch-up at two authoritative ticks per browser frame');
			assertEquals(4, clock.simulationFrameNumber, '$strategy defers rather than runs the third due tick');
			clock.advanceFrame(150);
			assertEquals(1, clock.simulationTicksThisBrowserFrame, '$strategy preserves deferred catch-up credit');
			assertEquals(5, clock.simulationFrameNumber, '$strategy catch-up total includes every due tick');
			assertEquals(5, clock.stageFrameNumber, '$strategy catch-up ticks do not become browser frames');
		}
	}

	private static function testFixedPresentationPolicies():Void {
		var fixed30 = new FrameClock(FrameRateSettings.fromQuery("?frame_strategy=30fixed", true),
			new FrameRateDiagnostics(currentTime));
		FrameClock.setCurrentForTests(fixed30);
		fixed30.advanceFrame(0);
		fixed30.advanceFrame(10);
		assertEquals(false, FrameClock.shouldRenderIntermediatePresentationFrame(),
			"30fixed leaves no-tick browser frames on the authoritative pose");

		var fixed60 = new FrameClock(FrameRateSettings.fromQuery("?frame_strategy=60fixed", true),
			new FrameRateDiagnostics(currentTime));
		FrameClock.setCurrentForTests(fixed60);
		fixed60.advanceFrame(0);
		fixed60.advanceFrame(10);
		assertEquals(true, FrameClock.shouldRenderIntermediatePresentationFrame(),
			"60fixed renders an intermediate pose when no physics tick is due");
		FrameClock.setCurrentForTests(null);
	}

	private static function testRepeatedPhaseResets():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), diagnostics);
		clock.advanceFrame();
		clock.advanceFrame();
		for (_ in 0...20) clock.resetPresentationPhase();
		assertEquals(2, clock.stageFrameNumber, "repeated resets do not add presented frames");
		assertEquals(1, clock.simulationFrameNumber, "repeated resets do not add simulation frames");
		assertEquals(2, diagnostics.totalPresentedFrames, "repeated resets do not alter diagnostics");
		assertEquals(1, diagnostics.totalSimulationTicks, "repeated resets do not alter simulation diagnostics");
		clock.advanceFrame();
		assertEquals(true, clock.isSimulationFrame, "repeated resets still rebase next frame to simulation");
		clock.advanceFrame();
		assertEquals(false, clock.isSimulationFrame, "alternation resumes after rebased simulation frame");
	}

	private static function testResetRebasesWithoutSynthesizingTicks():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), diagnostics);
		clock.advanceFrame();
		clock.advanceFrame();
		assertEquals(false, clock.isSimulationFrame, "pre-reset current phase");

		clock.resetPresentationPhase();
		assertEquals(false, clock.isSimulationFrame, "reset does not reclassify current phase");
		assertEquals(2, clock.stageFrameNumber, "reset does not synthesize stage frame");
		assertEquals(1, clock.simulationFrameNumber, "reset does not synthesize simulation frame");
		assertEquals(1, clock.presentationOnlyFrameNumber, "reset does not synthesize presentation frame");
		assertEquals(2, diagnostics.totalPresentedFrames, "reset does not change diagnostics");

		clock.advanceFrame();
		assertEquals(true, clock.isSimulationFrame, "first post-reset frame simulates");
		assertEquals(2, clock.simulationFrameNumber, "post-reset simulation count");
	}

	private static function testSmoothStartupRunsExactlyOneSimulationFrame():Void {
		now = 0;
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(currentTime));

		clock.advanceFrame();
		assertEquals(true, clock.isSimulationFrame, "first smooth frame simulates");
		assertEquals(1, clock.simulationFrameNumber, "first smooth frame advances simulation once");
		assertEquals(0, clock.presentationOnlyFrameNumber, "first smooth frame does not consume presentation phase");

		clock.advanceFrame();
		assertEquals(false, clock.isSimulationFrame, "second smooth frame is presentation-only");
		assertEquals(1, clock.simulationFrameNumber, "second smooth frame does not duplicate simulation");
	}

	private static function testDefaultFramesAreSimulationFrames():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		var clock = new FrameClock(FrameRateSettings.fromQuery(null, true), diagnostics);
		for (_ in 0...4) {
			clock.advanceFrame();
			assertEquals(true, clock.isSimulationFrame, "default stage frame is a simulation frame");
			assertEquals(false, clock.isPresentationOnlyFrame, "default stage frame is not presentation-only");
		}
		assertEquals(4, clock.stageFrameNumber, "default stage frame count");
		assertEquals(4, clock.simulationFrameNumber, "default simulation frame count");
		assertEquals(0, clock.presentationOnlyFrameNumber, "default presentation-only frame count");
		assertEquals(4, diagnostics.totalPresentedFrames, "default presented-frame diagnostics");
	}

	private static function testSmoothFramesAlternate():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), diagnostics);
		var phases:Array<Bool> = [];
		for (_ in 0...6) {
			clock.advanceFrame();
			phases.push(clock.isSimulationFrame);
		}

		assertEquals("true,false,true,false,true,false", phases.join(","), "smooth stage phases");
		assertEquals(6, clock.stageFrameNumber, "smooth stage frame count");
		assertEquals(3, clock.simulationFrameNumber, "smooth simulation frame count");
		assertEquals(3, clock.presentationOnlyFrameNumber, "smooth presentation-only frame count");
		assertEquals(6, diagnostics.totalPresentedFrames, "smooth presented-frame diagnostics");
	}

	private static function testFrameCallbackObservesUpdatedPhase():Void {
		now = 0;
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(currentTime));
		var observed:Array<Bool> = [];
		clock.onFrame = function(frameClock:FrameClock):Void observed.push(frameClock.isSimulationFrame);

		clock.advanceFrame();
		clock.advanceFrame();

		assertEquals("true,false", observed.join(","), "callback phase order");
	}

	private static function currentTime():Float {
		return now;
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}
}
