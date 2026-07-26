package pr2.runtime;

class FrameClockTest {
	private static var assertions:Int = 0;
	private static var now:Float = 0;

	public static function main():Void {
		testDefaultFramesAreSimulationFrames();
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameClockTest")) return;
		testSmoothStartupRunsExactlyOneSimulationFrame();
		testSmoothFramesAlternate();
		testFrameCallbackObservesUpdatedPhase();
		testResetRebasesWithoutSynthesizingTicks();
		testLongRunCadence();
		testRepeatedPhaseResets();
		testPresentationBudgetPreservesVisualFramesAt57Fps();
		testPresentationBudgetPreservesVisualFramesAt55Fps();
		testPresentationBudgetProtects27FpsAt53Fps();
		testHighRefreshDoesNotAccelerateSimulation();
		testTransitionBackTo30FpsPresentation();
		testFallbackImmediatelyAfterSimulationPreservesTickSequence();
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

	private static function testPresentationBudgetPreservesVisualFramesAt57Fps():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 57;
		for (frame in 0...(57 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(285, clock.stageFrameNumber, "57 FPS budget records every available callback");
		assertEquals(143, clock.simulationFrameNumber, "57 FPS budget naturally averages 28.5 physics FPS");
		assertEquals(142, clock.presentationOnlyFrameNumber, "57 FPS budget preserves the natural visual-only half");
	}

	private static function testPresentationBudgetPreservesVisualFramesAt55Fps():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 55;
		for (frame in 0...(55 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(275, clock.stageFrameNumber, "55 FPS budget records every available callback");
		assertEquals(138, clock.simulationFrameNumber, "55 FPS budget naturally averages 27.5 physics FPS");
		assertEquals(137, clock.presentationOnlyFrameNumber, "55 FPS budget preserves the natural visual-only half");
	}

	private static function testPresentationBudgetProtects27FpsAt53Fps():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 53;
		for (frame in 0...(53 * 5)) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(265, clock.stageFrameNumber, "53 FPS budget records every available callback");
		assertEquals(135, clock.simulationFrameNumber, "53 FPS budget protects twenty-seven physics FPS");
		assertEquals(130, clock.presentationOnlyFrameNumber, "53 FPS budget sacrifices five visual-only callbacks");
	}

	private static function testHighRefreshDoesNotAccelerateSimulation():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		var callbackPeriodMs = 1000.0 / 120;
		for (frame in 0...120) clock.advanceFrame(frame * callbackPeriodMs);

		assertEquals(120, clock.stageFrameNumber, "high refresh records every supplied callback");
		assertEquals(30, clock.simulationFrameNumber, "high refresh remains fixed at thirty simulation ticks");
		assertEquals(90, clock.presentationOnlyFrameNumber, "extra high-refresh callbacks remain presentation-only");
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

	private static function testTransitionBackTo30FpsPresentation():Void {
		now = 0;
		var diagnostics = new FrameRateDiagnostics(currentTime);
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), diagnostics);
		clock.advanceFrame();
		clock.advanceFrame();
		assertEquals(false, clock.isSimulationFrame, "transition starts on presentation-only phase");

		clock.use30FpsPresentation();
		assertEquals(false, clock.isSimulationFrame, "transition does not reclassify current frame");
		assertEquals(2, clock.stageFrameNumber, "transition does not synthesize a presented frame");
		assertEquals(1, clock.simulationFrameNumber, "transition does not synthesize a simulation frame");
		assertEquals(30, clock.presentationFrameRate, "transition records 30 FPS presentation");
		assertEquals(false, clock.isSmoothPresentationActive, "transition disables presentation-only phases");

		for (_ in 0...120) {
			clock.advanceFrame();
			assertEquals(true, clock.isSimulationFrame, "every 30 FPS fallback frame simulates");
		}
		assertEquals(122, clock.stageFrameNumber, "fallback presented-frame count remains monotonic");
		assertEquals(121, clock.simulationFrameNumber, "fallback simulation count resumes without a skipped tick");
		assertEquals(1, clock.presentationOnlyFrameNumber, "fallback never adds another presentation-only frame");
		assertEquals(122, diagnostics.totalPresentedFrames, "fallback diagnostics remain monotonic");

		var unflagged = new FrameClock(FrameRateSettings.fromQuery(null, true), new FrameRateDiagnostics(currentTime));
		unflagged.advanceFrame();
		unflagged.use30FpsPresentation();
		unflagged.advanceFrame();
		assertEquals(2, unflagged.simulationFrameNumber, "30 FPS rebase is harmless when already unflagged");
	}

	private static function testFallbackImmediatelyAfterSimulationPreservesTickSequence():Void {
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true),
			new FrameRateDiagnostics(currentTime));
		clock.advanceFrame();
		assertEquals(1, clock.simulationFrameNumber, "fallback fixture begins with authoritative tick one");
		clock.use30FpsPresentation();
		assertEquals(1, clock.simulationFrameNumber, "fallback rebase does not duplicate the current tick");
		clock.advanceFrame();
		assertEquals(2, clock.simulationFrameNumber, "first 30 FPS callback advances exactly to tick two");
		assertEquals(2, clock.stageFrameNumber, "fallback does not insert a synthetic display callback");
		assertEquals(0, clock.presentationOnlyFrameNumber,
			"authoritative-boundary fallback does not consume an orphaned presentation phase");
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
