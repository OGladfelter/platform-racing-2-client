package pr2.runtime;

import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.FocusEvent;
import pr2.Constants;

/**
	Application-owned classifier for stage frames.

	Smooth strategies deliberately tie simulation progress to accepted stage
	frames. Fixed strategies instead schedule zero, one, or two authoritative
	30 Hz ticks from monotonic elapsed time. Extra catch-up ticks are complete
	synthetic ENTER_FRAME broadcasts issued at EXIT_FRAME, before OpenFL renders.
**/
@:access(openfl.display.Stage)
class FrameClock {
	public static var current(default, null):Null<FrameClock>;

	public final strategy:FrameStrategy;
	public final rendersIntermediatePresentationFrames:Bool;
	public final presentationFrameRate:Int;
	public var isSimulationFrame(default, null):Bool = true;
	public var isPresentationOnlyFrame(get, never):Bool;
	public var isBrowserFrame(default, null):Bool = true;
	public var stageFrameNumber(default, null):Int = 0;
	public var simulationFrameNumber(default, null):Int = 0;
	public var presentationOnlyFrameNumber(default, null):Int = 0;
	public var simulationTicksThisBrowserFrame(default, null):Int = 1;
	public var onFrame:Null<FrameClock->Void>;

	private final diagnostics:FrameRateDiagnostics;
	private static inline var CREDIT_EPSILON:Float = 0.000001;
	private static inline var MAX_FIXED_SIMULATION_TICKS_PER_BROWSER_FRAME:Int = 2;
	private var lastFrameTimeMs:Null<Float>;
	private var fixedSimulationCredit:Float = 0;
	private var smoothSimulationNext:Bool = true;
	private var syntheticFrameTimeMs:Float = 0;
	private var installedStage:Null<Stage>;
	private var pendingCatchUpSimulationTicks:Int = 0;
	private var dispatchingCatchUpFrame:Bool = false;

	public function new(settings:FrameRateSettings, ?diagnostics:FrameRateDiagnostics) {
		strategy = settings.strategy;
		rendersIntermediatePresentationFrames = settings.rendersIntermediatePresentationFrames;
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
		stage.addEventListener(Event.EXIT_FRAME, onStageExitFrame, false, 1000);
		stage.addEventListener(Event.ACTIVATE, onPhaseBoundary);
		stage.addEventListener(Event.DEACTIVATE, onPhaseBoundary);
		stage.addEventListener(FocusEvent.FOCUS_OUT, onFocusOut);
	}

	public function uninstall():Void {
		if (installedStage != null) {
			installedStage.removeEventListener(Event.ENTER_FRAME, onStageFrame);
			installedStage.removeEventListener(Event.EXIT_FRAME, onStageExitFrame);
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
		Rebase the next smooth phase or fixed-time origin. The current phase and
		all counters remain untouched, so teardown cannot create a synthetic tick
		or reclassify callbacks still running in the current frame.
	**/
	public function resetPresentationPhase():Void {
		lastFrameTimeMs = null;
		fixedSimulationCredit = 0;
		smoothSimulationNext = true;
		pendingCatchUpSimulationTicks = 0;
	}

	public static function resetCurrentPresentationPhase():Void {
		if (current != null) {
			current.resetPresentationPhase();
		}
	}

	public static inline function shouldRunSimulationFrame():Bool {
		return current == null || current.isSimulationFrame;
	}

	public static inline function shouldRunBrowserFrame():Bool {
		return current == null || current.isBrowserFrame;
	}

	public static inline function shouldRenderIntermediatePresentationFrame():Bool {
		return current != null
			&& current.isBrowserFrame
			&& !current.isSimulationFrame
			&& current.rendersIntermediatePresentationFrames
			&& current.presentationFrameRate == Constants.SMOOTH_PRESENTATION_FRAME_RATE;
	}

	@:allow(pr2.gameplay.GameShellMountTest)
	@:allow(pr2.gameplay.RaceSessionTranscriptTest)
	@:allow(pr2.character.RemoteCharacterConsumeTest)
	@:allow(pr2.character.CharacterBaseTest)
	@:allow(pr2.character.ParticleEmitterTest)
	@:allow(pr2.effects.PhysicsEffectTest)
	@:allow(pr2.effects.ShotEffectTest)
	@:allow(pr2.ui.GpNotificationTest)
	@:allow(pr2.runtime.FrameClockTest)
	private static function setCurrentForTests(value:Null<FrameClock>):Void {
		current = value;
	}

	/**
		Advances one accepted browser-frame phase. Production passes monotonic
		wall time. Deterministic harnesses may omit it to advance at the configured
		nominal presentation rate.
	**/
	public function advanceFrame(?frameTimeMs:Float):Void {
		var simulationTicks = simulationTicksDue(resolveFrameTime(frameTimeMs));
		isBrowserFrame = true;
		simulationTicksThisBrowserFrame = simulationTicks;
		stageFrameNumber++;
		diagnostics.recordPresentedFrame();
		if (simulationTicks == 0) {
			isSimulationFrame = false;
			presentationOnlyFrameNumber++;
		} else {
			for (_ in 0...simulationTicks) {
				recordSimulationTick();
			}
			isBrowserFrame = true;
		}
		if (onFrame != null) {
			onFrame(this);
		}
	}

	private function onStageFrame(_:Event):Void {
		if (dispatchingCatchUpFrame) {
			isBrowserFrame = false;
			recordSimulationTick();
			return;
		}

		var simulationTicks = simulationTicksDue(haxe.Timer.stamp() * 1000.0);
		isBrowserFrame = true;
		simulationTicksThisBrowserFrame = simulationTicks;
		stageFrameNumber++;
		diagnostics.recordPresentedFrame();
		if (simulationTicks == 0) {
			isSimulationFrame = false;
			presentationOnlyFrameNumber++;
			pendingCatchUpSimulationTicks = 0;
		} else {
			recordSimulationTick();
			isBrowserFrame = true;
			pendingCatchUpSimulationTicks = simulationTicks - 1;
		}
		if (onFrame != null) {
			onFrame(this);
		}
	}

	private function onStageExitFrame(_:Event):Void {
		if (pendingCatchUpSimulationTicks <= 0 || installedStage == null) {
			return;
		}
		var catchUpTicks = pendingCatchUpSimulationTicks;
		pendingCatchUpSimulationTicks = 0;
		dispatchingCatchUpFrame = true;
		for (_ in 0...catchUpTicks) {
			installedStage.__broadcastEvent(new Event(Event.ENTER_FRAME));
		}
		dispatchingCatchUpFrame = false;
		isBrowserFrame = true;
		isSimulationFrame = true;
	}

	private function recordSimulationTick():Void {
		isSimulationFrame = true;
		simulationFrameNumber++;
		diagnostics.recordSimulationTick();
	}

	private function simulationTicksDue(frameTimeMs:Float):Int {
		if (presentationFrameRate == Constants.DEFAULT_PRESENTATION_FRAME_RATE) {
			return 1;
		}
		return switch (strategy) {
			case FrameStrategy.Smooth60:
				var due = smoothSimulationNext ? 1 : 0;
				smoothSimulationNext = !smoothSimulationNext;
				due;
			case FrameStrategy.Fixed30, FrameStrategy.Fixed60:
				fixedSimulationTicksDue(frameTimeMs);
			default:
				1;
		};
	}

	private function fixedSimulationTicksDue(frameTimeMs:Float):Int {
		var previousFrameTimeMs = lastFrameTimeMs;
		lastFrameTimeMs = frameTimeMs;
		if (previousFrameTimeMs == null) {
			fixedSimulationCredit = 0;
			return 1;
		}

		var elapsedMs = Math.max(0, frameTimeMs - previousFrameTimeMs);
		fixedSimulationCredit += elapsedMs * Constants.SIMULATION_FRAME_RATE / 1000.0;
		var ticks = Std.int(Math.min(
			MAX_FIXED_SIMULATION_TICKS_PER_BROWSER_FRAME,
			Math.floor(fixedSimulationCredit + CREDIT_EPSILON)
		));
		fixedSimulationCredit = Math.max(0, fixedSimulationCredit - ticks);
		return ticks;
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
		return isBrowserFrame && !isSimulationFrame;
	}

}
