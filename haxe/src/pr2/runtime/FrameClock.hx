package pr2.runtime;

import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.FocusEvent;
import pr2.Constants;

/**
	Application-owned classifier for stage frames.

	At the default presentation rate every stage frame is a simulation frame.
	With smooth presentation enabled, simulation and presentation-only frames
	alternate. Time-dependent owners migrate to this clock in later stages.
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
	// Startup always begins with one simulation frame. The following stage frame
	// is presentation-only in smooth mode, preventing both an initial skipped
	// gameplay tick and a doubled pair of gameplay ticks.
	private var nextFrameIsSimulation:Bool = true;
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
		nextFrameIsSimulation = true;
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

	/** Advances one stage-frame phase. Public for deterministic clock harnesses. */
	public function advanceFrame():Void {
		isSimulationFrame = !isSmoothPresentationActive || nextFrameIsSimulation;
		if (isSmoothPresentationActive) {
			nextFrameIsSimulation = !nextFrameIsSimulation;
		}
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
		advanceFrame();
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
