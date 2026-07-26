package pr2.runtime;

import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.FocusEvent;
import pr2.Constants;

/**
	Application-owned classifier for stage frames.

	At the default presentation rate every stage frame is a simulation frame.
	With smooth presentation enabled, simulation targets half the rolling
	five-second presentation rate, clamped to 27-30 Hz. Presentation-only frames
	are sacrificed only after the natural half-rate cadence would fall below the
	27 Hz physics budget.
**/
class FrameClock {
	public static var current(default, null):Null<FrameClock>;

	public final smooth60Enabled:Bool;
	public var presentationFrameRate(default, null):Int;
	public var isSmoothPresentationActive(get, never):Bool;
	public var isSimulationFrame(default, null):Bool = true;
	public var isPresentationOnlyFrame(get, never):Bool;
	public var stageFrameNumber(default, null):Int = 0;
	public var simulationFrameNumber(default, null):Int = 0;
	public var presentationOnlyFrameNumber(default, null):Int = 0;
	public var onFrame:Null<FrameClock->Void>;

	private final diagnostics:FrameRateDiagnostics;
	private static inline var PRESENTATION_RATE_WINDOW_MS:Float = 5000.0;
	private static inline var MIN_SMOOTH_SIMULATION_FRAME_RATE:Float = 27.0;
	private static inline var CREDIT_EPSILON:Float = 0.000001;
	private final recentPresentationFrameTimes:Array<Float> = [];
	private var lastFrameTimeMs:Null<Float>;
	private var simulationCredit:Float = 0;
	private var syntheticFrameTimeMs:Float = 0;
	private var installedStage:Null<Stage>;

	public function new(settings:FrameRateSettings, ?diagnostics:FrameRateDiagnostics) {
		smooth60Enabled = settings.smooth60Enabled;
		presentationFrameRate = settings.presentationFrameRate;
		this.diagnostics = diagnostics == null ? FrameRateDiagnostics.shared : diagnostics;
	}

	public function install(stage:Stage):Void {
		if (installedStage == stage) {
			return;
		}
		if (installedStage != null) {
			uninstall();
		}
		installedStage = stage;
		current = this;
		stage.addEventListener(Event.ENTER_FRAME, onStageFrame, false, 1000);
		stage.addEventListener(Event.ACTIVATE, onPhaseBoundary);
		stage.addEventListener(Event.DEACTIVATE, onPhaseBoundary);
		stage.addEventListener(FocusEvent.FOCUS_OUT, onFocusOut);
	}

	public function uninstall():Void {
		if (installedStage != null) {
			installedStage.removeEventListener(Event.ENTER_FRAME, onStageFrame);
			installedStage.removeEventListener(Event.ACTIVATE, onPhaseBoundary);
			installedStage.removeEventListener(Event.DEACTIVATE, onPhaseBoundary);
			installedStage.removeEventListener(FocusEvent.FOCUS_OUT, onFocusOut);
			installedStage = null;
		}
		if (current == this) {
			current = null;
		}
	}

	/**
		Rebase only the next stage frame to simulation. The current phase and all
		counters remain untouched, so calling this during teardown cannot create a
		synthetic tick or reclassify callbacks still running in the current frame.
	**/
	public function resetPresentationPhase():Void {
		recentPresentationFrameTimes.resize(0);
		lastFrameTimeMs = null;
		simulationCredit = 0;
	}

	/**
		Rebase a requested smooth session to one presented frame per simulation
		tick. Changing the actual Stage rate is the caller's responsibility.
		The current frame is not reclassified and the next 30 FPS frame simulates.
	**/
	public function use30FpsPresentation():Void {
		presentationFrameRate = Constants.DEFAULT_PRESENTATION_FRAME_RATE;
		resetPresentationPhase();
	}

	public static function resetCurrentPresentationPhase():Void {
		if (current != null) {
			current.resetPresentationPhase();
		}
	}

	public static inline function shouldRunSimulationFrame():Bool {
		return current == null || current.isSimulationFrame;
	}

	@:allow(pr2.gameplay.GameShellMountTest)
	@:allow(pr2.character.RemoteCharacterConsumeTest)
	@:allow(pr2.character.CharacterBaseTest)
	@:allow(pr2.character.ParticleEmitterTest)
	@:allow(pr2.effects.PhysicsEffectTest)
	@:allow(pr2.effects.ShotEffectTest)
	@:allow(pr2.ui.GpNotificationTest)
	private static function setCurrentForTests(value:Null<FrameClock>):Void {
		current = value;
	}

	/**
		Advances one stage-frame phase. Production passes monotonic wall time.
		Deterministic harnesses may omit it to advance at the configured nominal
		presentation rate.
	**/
	public function advanceFrame(?frameTimeMs:Float):Void {
		var resolvedFrameTimeMs = resolveFrameTime(frameTimeMs);
		isSimulationFrame = !isSmoothPresentationActive || smoothSimulationIsDue(resolvedFrameTimeMs);
		stageFrameNumber++;
		if (isSimulationFrame) {
			simulationFrameNumber++;
		} else {
			presentationOnlyFrameNumber++;
		}
		diagnostics.recordPresentedFrame();
		if (isSimulationFrame) {
			diagnostics.recordSimulationTick();
		}
		if (onFrame != null) {
			onFrame(this);
		}
	}

	private function onStageFrame(_:Event):Void {
		advanceFrame(haxe.Timer.stamp() * 1000.0);
	}

	private function smoothSimulationIsDue(frameTimeMs:Float):Bool {
		recordPresentationFrameTime(frameTimeMs);
		var previousFrameTimeMs = lastFrameTimeMs;
		lastFrameTimeMs = frameTimeMs;
		if (previousFrameTimeMs == null) {
			simulationCredit = 0;
			return true;
		}

		var elapsedMs = Math.max(0, frameTimeMs - previousFrameTimeMs);
		var desiredSimulationRate = rollingDesiredSimulationRate();
		simulationCredit += elapsedMs * desiredSimulationRate / 1000.0;
		if (simulationCredit + CREDIT_EPSILON < 1) {
			return false;
		}
		// Preserve fractional credit so a 27 Hz budget remains exact over the
		// rolling window, but retain at most one whole catch-up tick after a long
		// stall or a callback rate below the physics floor.
		simulationCredit = Math.min(1, Math.max(0, simulationCredit - 1));
		return true;
	}

	private function recordPresentationFrameTime(frameTimeMs:Float):Void {
		recentPresentationFrameTimes.push(frameTimeMs);
		var cutoff = frameTimeMs - PRESENTATION_RATE_WINDOW_MS;
		while (recentPresentationFrameTimes.length > 1 && recentPresentationFrameTimes[0] < cutoff) {
			recentPresentationFrameTimes.shift();
		}
	}

	private function rollingDesiredSimulationRate():Float {
		if (recentPresentationFrameTimes.length < 2) {
			return Constants.SIMULATION_FRAME_RATE;
		}
		var first = recentPresentationFrameTimes[0];
		var last = recentPresentationFrameTimes[recentPresentationFrameTimes.length - 1];
		var elapsedMs = last - first;
		if (elapsedMs <= 0) {
			return Constants.SIMULATION_FRAME_RATE;
		}
		var presentationRate = (recentPresentationFrameTimes.length - 1) * 1000.0 / elapsedMs;
		return Math.max(MIN_SMOOTH_SIMULATION_FRAME_RATE,
			Math.min(Constants.SIMULATION_FRAME_RATE, presentationRate / 2.0));
	}

	private function resolveFrameTime(frameTimeMs:Null<Float>):Float {
		if (frameTimeMs != null) {
			syntheticFrameTimeMs = frameTimeMs + 1000.0 / presentationFrameRate;
			return frameTimeMs;
		}
		var result = syntheticFrameTimeMs;
		syntheticFrameTimeMs += 1000.0 / presentationFrameRate;
		return result;
	}

	private function onPhaseBoundary(_:Event):Void {
		resetPresentationPhase();
	}

	private function onFocusOut(_:FocusEvent):Void {
		resetPresentationPhase();
	}

	private function get_isPresentationOnlyFrame():Bool {
		return !isSimulationFrame;
	}

	private function get_isSmoothPresentationActive():Bool {
		return smooth60Enabled && presentationFrameRate == Constants.SMOOTH_PRESENTATION_FRAME_RATE;
	}
}
