package pr2.gameplay;

import haxe.crypto.Md5;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.geom.Point;
import pr2.Constants;
import pr2.character.CharacterState;
import pr2.character.PhysicsParticle;
import pr2.effects.BlockPiece;
import pr2.effects.ShotEffect;
import pr2.effects.StingEffect;
import pr2.gameplay.GameCommandShell.LocalCharacterInit;
import pr2.gameplay.GameCommandShell.RemoteCharacterInit;
import pr2.gameplay.player.LocalPlayerController;
import pr2.gameplay.player.LocalPlayerInput;
import pr2.gameplay.player.LocalPlayerState;
import pr2.gameplay.presentation.CharacterPresentationLayer;
import pr2.lobby.LobbySession;
import pr2.lobby.dialogs.LevelInfoPopup;
import pr2.level.BlockType;
import pr2.level.Level.LevelBlock;
import pr2.level.ObjectCodes;
import pr2.level.Level;
import pr2.level.Level.LevelBlock;
import pr2.level.LevelDecoder;
import pr2.net.CommandHandler;
import pr2.net.LobbySocket;
import pr2.net.ServerLevelData;
import pr2.net.ServerConfig;
import pr2.runtime.FrameClock;
import pr2.runtime.FrameRateDiagnostics;
import pr2.runtime.FrameRateSettings;

/**
	A3 coverage: the production `Course` shell mounts a decoded level plus the
	authored HUD at Course's verified holder->stage offsets, hosts a character
	layer, and tears everything down on `remove`. Built from a small in-memory m3
	fixture so no network fetch is needed.
**/
@:access(pr2.gameplay.Course)
@:access(pr2.gameplay.MiniMap)
@:access(pr2.level.LevelRenderer)
class GameShellMountTest {
	private static var assertions:Int = 0;

	public static function main():Void {
		var course = buildCourse();

		assertClose(Course.ITEM_X, course.itemDisplay.x, "item display x");
		if (pr2.DeterministicTestMode.finishSmokeSuite("GameShellMountTest")) return;
		assertClose(Course.ITEM_Y, course.itemDisplay.y, "item display y");
		assertClose(Course.MINIMAP_X, course.miniMap.x, "minimap x");
		assertClose(Course.MINIMAP_Y, course.miniMap.y, "minimap y");
		assertClose(Course.STATS_X, course.statsDisplay.x, "stats x");
		assertClose(Course.STATS_Y, course.statsDisplay.y, "stats y");
		assertClose(Course.HEARTS_X, course.hearts.x, "hearts x");
		assertClose(Course.HEARTS_Y, course.hearts.y, "hearts y");
		assertEquals(false, course.hearts.visible, "hearts hidden until deathmatch lives reported");
		assertClose(Course.MUSIC_X, course.musicSelection.x, "music x");
		assertClose(Course.MUSIC_Y, course.musicSelection.y, "music y");
		assertClose(Course.TIMER_X, course.timer.x, "timer x");
		assertClose(Course.TIMER_Y, course.timer.y, "timer y");
		assertEquals("", course.timer.debugText(), "timer starts blank before race init");
		assertClose(Course.CHAT_X, course.raceChat.x, "chat x");
		assertClose(Course.CHAT_Y, course.raceChat.y, "chat y");
		assertClose(Course.DRAWING_X, course.drawingInfo.x, "drawing info x");
		assertClose(Course.DRAWING_Y, course.drawingInfo.y, "drawing info y");

		assertEquals(true, course.levelRenderer != null, "level renderer mounted");
		assertEquals(true, course.characterLayer != null, "character layer present");
		assertEquals(true, course.backCharacterLayer != null, "back character layer present");
		assertEquals(true, course.localCharacter != null, "local character bridge mounted");
		assertEquals(course.blockController, course.localCharacter.controller.blockController,
			"Course owns the block controller shared with the local simulation");
		assertEquals(course.localCharacter, course.characterLayer.getChildAt(0), "local character owns display-list slot");
		var start = @:privateAccess course.level.startBlocks()[0];
		var initialState = course.localCharacter.stateSnapshot();
		assertClose(start.worldX + 15, initialState.x,
			"local character spawns at Flash start center x");
		assertClose(start.worldY + 15, initialState.y,
			"local character spawns at Flash start center y");
		assertEquals(true, course.levelRenderer.worldChildDepth(course.backCharacterLayer) >= 0,
			"back character layer sits inside the rotating world (above the background art)");
		assertBelow(course.levelRenderer.worldChildDepth(course.backCharacterLayer), course.levelRenderer.blockLayerDepth(),
			"back character layer renders below the blocks");
		assertEquals(true, course.levelRenderer.worldChildDepth(course.characterLayer) > course.levelRenderer.blockLayerDepth(),
			"front character layer sits inside the rotating world above the blocks");
		assertBelow(course.levelRenderer.worldChildDepth(course.characterLayer), course.levelRenderer.artLayerDepth(3),
			"front character layer renders below art 0");
		assertBelow(course.levelRenderer.worldChildDepth(course.characterLayer), course.levelRenderer.artLayerDepth(4),
			"front character layer renders below art 00");
		assertEquals(true, course.levelRenderer.worldChildDepth(course.effectBackground) > course.levelRenderer.worldChildDepth(course.characterLayer),
			"effect layer renders above the characters");
		assertBelow(course.levelRenderer.worldChildDepth(course.effectBackground), course.levelRenderer.artLayerDepth(3),
			"effect layer renders below art 0 like Flash");
		testRemoteParentLayerSwitch(course);
		testLocalWaterParentLayerSwitch(course);

		// With no chat interceptor supplied, the shell does not swallow chat.
		assertEquals(false, course.handleRaceChatLine("/debug"), "no interceptor leaves chat unhandled");
		LevelInfoPopup.autoLoadOnCreate = false;
		assertEquals(true, course.handleRaceChatLine(" /level "), "race chat /level opens current level info");
		assertEquals(false, LevelInfoPopup.instance == null, "race chat /level creates a LevelInfoPopup");
		assertEquals(42, LevelInfoPopup.instance.levelId, "race chat /level uses the current course id");
		LevelInfoPopup.instance.remove();
		LevelInfoPopup.autoLoadOnCreate = true;

		course.remove();
		assertEquals(true, course.miniMap == null, "minimap torn down");
		assertEquals(true, course.itemDisplay == null, "item display torn down");
		assertEquals(true, course.statsDisplay == null, "stats display torn down");
		assertEquals(true, course.hearts == null, "hearts torn down");
		assertEquals(true, course.musicSelection == null, "music selection torn down");
		assertEquals(true, course.timer == null, "timer torn down");
		assertEquals(true, course.raceChat == null, "race chat torn down");
		assertEquals(true, course.drawingInfo == null, "drawing info torn down");
		assertEquals(true, course.levelRenderer == null, "level renderer torn down");
		assertEquals(true, course.localCharacter == null, "local character torn down");

		testDeathmatchHeartsShowInitialLives();
		testSwitchingEqualUseItemsRefreshesAmmoDisplay();
		testRoguelikeHudAndInitialState();
		testRoguelikeOnlyEmitsTerminalFinishOnNinthHit();
		testRenderingUsesFreeMoveCamera();
		testFinishDrawingReadinessEmission();
		testLocalFinishBeginsCharacterRemoval();
		testTestModeFinishDelegatesWithoutRaceRemoval();
		testTestModeFinishMaySynchronouslyRemoveCourse();
		testObjectiveModeReportsEachFinishOnce();
		testRotateBlockDisplayKeepsLocalCharacterCentered();
		testCountdownKeepsCameraStill();
		testTournamentStartForcesFirstStartPosition();
		testTimerBeginRaceAndTimeoutBoundary();
		testLiveRaceEmitsMultiplayerUpdates();
		testSharedCommandHandlerCompletesLooseHatPickup();
		testLocalCharacterAnimationAdvancesDuringRace();
		testCourseRunsOnlyOnSimulationFrames();
		testPresentationFrameKeepsGameplayTransitionsDiscrete();
		testMinimapDotsRemainAuthoritativeDuringPresentation();
		testPresentationPoseCapturesAuthoritativeTickBounds();
		testSmoothPresentationExtrapolatesWithoutAdvancingCharacterTimeline();
		testPresentationLifecycleResets();
		testNextDisplacementPredictsThroughContacts();
		testCameraPresentationStateIsDisposable();
		testSpectatedRemoteAndCameraSnapAsOneUnit();
		testSmoothPresentationTeardownClearsCallbacks();
		testSmoothTwinReplayPreservesEverySimulationState();
		testSmoothTwinReplayPreservesMultiplayerCommandStream();
		testCourseLifecyclesMatchAtBothPresentationRates();

		trace('GameShellMountTest passed $assertions assertions');
	}

	private static function testSpectatedRemoteAndCameraSnapAsOneUnit():Void {
		var course = buildCourse();
		var remote = course.createRemoteCharacter(remoteInit(1));
		remote.stepFrame();
		course.toggleSpectatePossible(true);
		course.changeSpectate(remote.tempID);

		assertEquals(remote, course.playerSpectating, "spectate switch selects remote target");
		assertEquals(true, @:privateAccess remote.externalPresentationSnapPending,
			"new spectate target receives a persistent presentation snap");
		var cameraPose = @:privateAccess course.cameraPresentationPose;
		assertClose(cameraPose.currentX, cameraPose.presentedX, "spectate switch snaps camera x with remote");
		assertClose(cameraPose.currentY, cameraPose.presentedY, "spectate switch snaps camera y with remote");

		remote.stepFrame();
		assertEquals(true, @:privateAccess remote.presentationPose.discontinuity,
			"remote remains snapped when switch is followed by simulation");
		@:privateAccess remote.renderPresentationFrame();
		assertClose(0, remote.display.x, "spectated remote extra frame stays authoritative during switch");
		assertClose(0, remote.display.y, "spectated remote y stays authoritative during switch");

		course.changeSpectate(-1);
		assertEquals(null, course.playerSpectating, "spectate switch returns to free camera");
		assertEquals(true, @:privateAccess remote.externalPresentationSnapPending,
			"old spectate target also snaps when camera leaves it");
		course.remove();
	}

	private static function testSwitchingEqualUseItemsRefreshesAmmoDisplay():Void {
		var course = buildCourse();
		@:privateAccess course.syncItemDisplay(Items.LASER_GUN, 3);
		assertEquals(3, course.itemDisplay.ammo, "first multi-use item shows all three charges");

		@:privateAccess course.syncItemDisplay(Items.SWORD, 3);
		assertEquals(3, course.itemDisplay.ammo, "switching to another unused three-charge item reapplies all dots");
		course.remove();
	}

	private static function testSmoothPresentationTeardownClearsCallbacks():Void {
		var course = buildCourse();
		var remote = course.createRemoteCharacter(remoteInit(1));
		remote.stepFrame();
		var localPose = @:privateAccess course.localPresentationPose;
		var state = course.localCharacter.stateSnapshot();
		localPose.beginSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		localPose.finishSimulationTick(state.x + 1, state.y, 0, 1, CharacterPresentationLayer.Front);
		var cameraPose = @:privateAccess course.cameraPresentationPose;
		cameraPose.beginAuthoritativeUpdate(0, 0);
		cameraPose.finishAuthoritativeUpdate(1, 0);

		var particle = new PhysicsParticle({
			graphic: "DjinnIceGraphic",
			colors: [0xFFFFFF],
			life: 10,
			startAlpha: 1,
			minVelAlpha: 0,
			maxVelAlpha: 0,
			minVelX: 1,
			maxVelX: 1,
			minVelY: 0,
			maxVelY: 0,
			velScaleX: 0,
			velScaleY: 0,
			fricX: 1,
			fricY: 1,
			minOffsetX: 0,
			maxOffsetX: 0,
			minOffsetY: 0,
			maxOffsetY: 0,
			minScale: 1,
			maxScale: 1,
			minX: 0,
			maxX: 0,
			minY: 0,
			maxY: 0
		}, function():Float return 0.5);
		course.effectBackground.addChild(particle);
		var piece = new BlockPiece("BrickPieceGraphic", 1, 0.95, 0.05, 10, 10, 10, 0, 0, function():Float return 0.5);
		course.levelRenderer.blockLayer.addChild(piece);
		var shot = new ShotEffect(0, 0, 0, 0, -1, "laser");
		var follow = new StingEffect(course.localCharacter);
		course.characterLayer.addChild(follow);

		assertEquals(true, course.hasEventListener(Event.ENTER_FRAME), "course owns its combined simulation/presentation callback before teardown");
		assertEquals(true, remote.hasEventListener(Event.ENTER_FRAME), "remote character owns its combined frame callback before teardown");
		assertEquals(true, particle.hasEventListener(Event.ENTER_FRAME), "physics particle owns its combined frame callback before teardown");
		assertEquals(true, piece.hasEventListener(Event.ENTER_FRAME), "block piece owns its combined frame callback before teardown");
		assertEquals(true, shot.hasEventListener(Event.ENTER_FRAME), "shot owns its combined frame callback before teardown");
		assertEquals(true, follow.hasEventListener(Event.ENTER_FRAME), "follow/fade effect owns its combined frame callback before teardown");

		course.remove();

		assertEquals(false, course.hasEventListener(Event.ENTER_FRAME), "course teardown unregisters its combined frame callback");
		assertEquals(false, localPose.hasSamples, "course teardown clears local presentation pose storage");
		assertEquals(false, cameraPose.hasSamples, "course teardown clears camera presentation pose storage");
		assertEquals(false, @:privateAccess remote.presentationPose.hasSamples, "remote teardown clears presentation pose storage");
		assertEquals(false, remote.hasEventListener(Event.ENTER_FRAME), "remote teardown unregisters its combined frame callback");
		assertEquals(false, particle.hasEventListener(Event.ENTER_FRAME), "effect-layer teardown unregisters physics-particle callbacks");
		assertEquals(false, piece.hasEventListener(Event.ENTER_FRAME), "renderer teardown unregisters block-piece callbacks");
		assertEquals(false, shot.hasEventListener(Event.ENTER_FRAME), "effect-layer teardown unregisters shot callbacks");
		assertEquals(false, follow.hasEventListener(Event.ENTER_FRAME), "renderer teardown unregisters follow/fade callbacks");
		assertEquals(null, particle.parent, "teardown detaches physics-particle presentation owners");
		assertEquals(null, piece.parent, "teardown detaches block-piece presentation owners");
		assertEquals(null, shot.parent, "teardown detaches shot presentation owners");
		assertEquals(null, follow.parent, "teardown detaches follow/fade presentation owners");
	}

	private static function testSmoothTwinReplayPreservesEverySimulationState():Void {
		var baseline = runTwinReplay(false);
		var smooth = runTwinReplay(true);
		assertEquals(180, baseline.states.length, "baseline twin records every requested 30 Hz state");
		assertEquals(180, smooth.states.length, "smooth twin records only its authoritative 30 Hz states");
		assertEquals(180, baseline.stageFrames, "baseline twin presents one frame per simulation tick");
		assertEquals(359, smooth.stageFrames,
			"smooth twin starts with simulation and then alternates one extra presentation frame");
		assertEquals(baseline.simulationFrames, smooth.simulationFrames, "both twins execute the same number of simulation ticks");
		for (index in 0...baseline.states.length) {
			assertEquals(baseline.states[index], smooth.states[index],
				'smooth twin LocalPlayerState diverged at simulation tick $index');
		}
	}

	private static function testSmoothTwinReplayPreservesMultiplayerCommandStream():Void {
		var baseline = runTwinReplay(false);
		var smooth = runTwinReplay(true);
		assertEquals(true, baseline.commandTimeline.length > 0,
			"twin replay exercises multiplayer command emission");
		assertEquals(baseline.commandTimeline.length, smooth.commandTimeline.length,
			"smooth twin emits the same number of multiplayer commands");
		for (index in 0...baseline.commandTimeline.length) {
			assertEquals(baseline.commandTimeline[index], smooth.commandTimeline[index],
				'smooth twin multiplayer command or emission tick diverged at stream index $index');
		}
	}

	private static function testCourseLifecyclesMatchAtBothPresentationRates():Void {
		var baseline = runItemFinishLifecycle(false);
		var smooth = runItemFinishLifecycle(true);
		assertEquals(baseline.states, smooth.states,
			"item use, effect launch, finish, and removal states match at both presentation rates");
		assertEquals(baseline.commands, smooth.commands,
			"item/effect/finish command cadence and payloads match at both presentation rates");
		assertEquals(40, baseline.simulationFrames, "30 FPS item/finish fixture runs forty authoritative frames");
		assertEquals(40, baseline.stageFrames, "30 FPS item/finish fixture runs forty display frames");
		assertEquals(40, smooth.simulationFrames, "60 FPS item/finish fixture keeps forty authoritative frames");
		assertEquals(79, smooth.stageFrames, "60 FPS item/finish fixture inserts presentation-only frames");
		assertEquals(true, baseline.commands.indexOf("add_effect`Laser`") >= 0,
			"lifecycle fixture exercises item effect emission");
		assertEquals(true, baseline.commands.indexOf("finish_race`") >= 0,
			"lifecycle fixture exercises the terminal finish transition");
		assertEquals(true, baseline.finished && smooth.finished,
			"finish remains latched and pauses the timer at both rates");

		var baselineRotation = runRotationLifecycle(false);
		var smoothRotation = runRotationLifecycle(true);
		assertEquals(baselineRotation.result, smoothRotation.result,
			"rotation commits the same authoritative state at both presentation rates");
		assertEquals(baselineRotation.simulationFrames, smoothRotation.simulationFrames,
			"rotation consumes the same number of authoritative frames at both rates");
		assertEquals(baselineRotation.simulationFrames, baselineRotation.stageFrames,
			"30 FPS rotation uses one display frame per authoritative frame");
		assertEquals(smoothRotation.simulationFrames * 2 - 1, smoothRotation.stageFrames,
			"60 FPS rotation inserts one presentation-only frame between authoritative frames");
	}

	private static function runItemFinishLifecycle(smooth:Bool):{
		states:String,
		commands:String,
		stageFrames:Int,
		simulationFrames:Int,
		finished:Bool
	} {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		@:privateAccess course.onCountdownFinish();
		course.localCharacter.grantItemForDebug(1);
		var clock = new FrameClock(FrameRateSettings.fromQuery(smooth ? "?smooth60=1" : null, true),
			new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);
		LobbySocket.resetSent();
		var states:Array<String> = [];
		var commands:Array<String> = [];
		var commandCursor = 0;
		var simulationIndex = 0;
		while (simulationIndex < 40) {
			clock.advanceFrame();
			if (clock.isSimulationFrame) {
				@:privateAccess course.input.item = simulationIndex == 1;
				if (simulationIndex == 20) {
					@:privateAccess course.localCharacter.controller.finish(new LevelBlock(1, 1, BlockType.Finish));
				}
			}
			@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
			if (clock.isSimulationFrame) {
				states.push(course.localCharacter.stateSnapshot().serialize());
				while (commandCursor < LobbySocket.sentCommands.length) {
					commands.push('$simulationIndex:' + LobbySocket.sentCommands[commandCursor]);
					commandCursor++;
				}
				simulationIndex++;
			}
		}
		var finished = @:privateAccess course.localFinishHandled && course.timer.debugPaused();
		var result = {
			states: states.join("|"),
			commands: commands.join("|"),
			stageFrames: clock.stageFrameNumber,
			simulationFrames: clock.simulationFrameNumber,
			finished: finished
		};
		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
		return result;
	}

	private static function runRotationLifecycle(smooth:Bool):{
		result:String,
		stageFrames:Int,
		simulationFrames:Int
	} {
		var course = buildRotateCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		@:privateAccess course.onCountdownFinish();
		var clock = new FrameClock(FrameRateSettings.fromQuery(smooth ? "?smooth60=1" : null, true),
			new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);
		var simulationIndex = 0;
		var complete = false;
		while (!complete && simulationIndex < 100) {
			clock.advanceFrame();
			if (clock.isSimulationFrame) {
				var before = course.localCharacter.stateSnapshot();
				@:privateAccess course.input.jump = before.courseRotation == 0 && before.mode != "freeze";
			}
			@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
			if (clock.isSimulationFrame) {
				simulationIndex++;
				var after = course.localCharacter.stateSnapshot();
				complete = after.courseRotation == 90 && after.mode != "freeze";
			}
		}
		var state = course.localCharacter.stateSnapshot();
		var result = '${state.courseRotation}:${state.mode}:${course.localCharacter.rotation}:'
			+ '${course.levelRenderer.debugArtCachingEnabled()}:${course.debugStageQualityForTests()}';
		var output = {
			result: result,
			stageFrames: clock.stageFrameNumber,
			simulationFrames: clock.simulationFrameNumber
		};
		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
		return output;
	}

	private static function runTwinReplay(smooth:Bool):{
		states:Array<String>,
		commandTimeline:Array<String>,
		stageFrames:Int,
		simulationFrames:Int
	} {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		course.createRemoteCharacter(remoteInit(9));
		@:privateAccess course.onCountdownFinish();
		LobbySocket.resetSent();
		var query = smooth ? "?smooth60=1" : null;
		var clock = new FrameClock(FrameRateSettings.fromQuery(query, true), new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);
		var states:Array<String> = [];
		var commandTimeline:Array<String> = [];
		var commandCursor = 0;
		var simulationIndex = 0;
		while (simulationIndex < 180) {
			clock.advanceFrame();
			if (clock.isSimulationFrame) applyTwinReplayInput(course, simulationIndex);
			@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
			if (clock.isSimulationFrame) {
				states.push(course.localCharacter.stateSnapshot().serialize());
				while (commandCursor < LobbySocket.sentCommands.length) {
					commandTimeline.push('$simulationIndex:' + LobbySocket.sentCommands[commandCursor]);
					commandCursor++;
				}
				simulationIndex++;
			}
		}
		var result = {
			states: states,
			commandTimeline: commandTimeline,
			stageFrames: clock.stageFrameNumber,
			simulationFrames: clock.simulationFrameNumber
		};
		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
		return result;
	}

	private static function applyTwinReplayInput(course:Course, tick:Int):Void {
		@:privateAccess course.input.left = tick >= 60 && tick < 100;
		@:privateAccess course.input.right = tick < 60 || (tick >= 100 && tick < 150);
		@:privateAccess course.input.jump = (tick >= 8 && tick < 14) || (tick >= 72 && tick < 78) || (tick >= 132 && tick < 138);
		@:privateAccess course.input.down = tick >= 108 && tick < 116;
		@:privateAccess course.input.item = false;
	}

	private static function testCameraPresentationStateIsDisposable():Void {
		var course = buildCourse();
		var pose = @:privateAccess course.cameraPresentationPose;
		var camera = @:privateAccess course.camera;
		assertEquals(true, pose.hasSamples, "initial authoritative camera update seeds presentation state");
		assertClose(camera.posX, pose.currentX, "camera presentation current x copies authoritative camera");
		assertClose(camera.posY, pose.currentY, "camera presentation current y copies authoritative camera");

		var authoritativeX = camera.posX;
		var authoritativeY = camera.posY;
		pose.present(authoritativeX + 3.25, authoritativeY - 1.75);
		assertClose(authoritativeX, camera.posX, "disposable presented x cannot overwrite CameraFollow");
		assertClose(authoritativeY, camera.posY, "disposable presented y cannot overwrite CameraFollow");
		assertClose(authoritativeX + 3.25, pose.presentedX, "presentation x is stored separately");
		assertClose(authoritativeY - 1.75, pose.presentedY, "presentation y is stored separately");

		@:privateAccess course.updatePlayerDisplay();
		assertClose(camera.posX, pose.currentX, "next authoritative update refreshes camera sample");
		assertClose(camera.posY, pose.currentY, "next authoritative update refreshes camera sample y");
		assertClose(camera.posX, pose.presentedX, "simulation render restores authoritative presented x");
		assertClose(camera.posY, pose.presentedY, "simulation render restores authoritative presented y");
		course.remove();
		assertEquals(false, pose.hasSamples, "course teardown clears camera presentation state");
	}

	private static function testNextDisplacementPredictsThroughContacts():Void {
		var course = buildCourse();
		var pose = @:privateAccess course.localPresentationPose;
		var state = course.localCharacter.stateSnapshot();
		pose.beginSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		@:privateAccess course.localPresentationDiscontinuityPending = false;

		@:privateAccess course.localCharacter.controller.vx = -2;
		@:privateAccess course.localCharacter.controller.vy = 1.5;
		state = course.localCharacter.stateSnapshot();
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		@:privateAccess course.localCharacter.controller.collisionVersion++;
		var expectedDx = course.localCharacter.controller.presentationDeltaX();
		var expectedDy = course.localCharacter.controller.presentationDeltaY();
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		assertEquals(false, pose.discontinuity, "collision contact does not suppress next-displacement prediction");
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(expectedDx * 0.5, course.localCharacter.display.x, "presentation applies half of predicted x displacement");
		assertClose(expectedDy * 0.5, course.localCharacter.display.y, "presentation applies half of predicted y displacement");

		@:privateAccess course.localCharacter.controller.vx = 4;
		@:privateAccess course.localCharacter.controller.vy = 0;
		@:privateAccess course.localCharacter.controller.grounded = false;
		state = course.localCharacter.stateSnapshot();
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		@:privateAccess course.localCharacter.controller.grounded = true;
		var activeFloor:Null<LevelBlock> = null;
		for (block in @:privateAccess course.level.blocks) {
			if (block.type.isSolid()) {
				activeFloor = block;
				break;
			}
		}
		assertEquals(true, activeFloor != null, "contact projection fixture finds an active floor block");
		@:privateAccess course.localCharacter.controller.presentationFloorContact.capture(activeFloor);
		expectedDx = course.localCharacter.controller.presentationDeltaX();
		expectedDy = course.localCharacter.controller.presentationDeltaY();
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		assertEquals(false, pose.discontinuity, "landing does not suppress post-step velocity prediction");
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(expectedDx * 0.5, course.localCharacter.display.x, "landing keeps predicted horizontal displacement smooth");
		assertClose(0, course.localCharacter.display.y, "landing's zero post-step y velocity stays pinned to the floor");

		@:privateAccess course.localCharacter.controller.presentationFloorContact.capture(activeFloor);
		@:privateAccess course.localCharacter.controller.vx = 4;
		@:privateAccess course.localCharacter.controller.vy = 5;
		state = course.localCharacter.stateSnapshot();
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		expectedDx = course.localCharacter.controller.presentationDeltaX();
		@:privateAccess course.finishLocalPresentationPoseCapture(state);
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(expectedDx * 0.5, course.localCharacter.display.x, "active floor contact preserves tangential presentation displacement");
		assertClose(0, course.localCharacter.display.y, "active floor contact removes inward presentation displacement");

		@:privateAccess course.localCharacter.controller.vx = 2;
		@:privateAccess course.localCharacter.controller.vy = 0;
		state = course.localCharacter.stateSnapshot();
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		@:privateAccess course.localCharacter.controller.vx = -2;
		expectedDx = course.localCharacter.controller.presentationDeltaX();
		expectedDy = course.localCharacter.controller.presentationDeltaY();
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(expectedDx * 0.5, course.localCharacter.display.x, "velocity reversal predicts the next applied x displacement");
		assertClose(expectedDy * 0.5, course.localCharacter.display.y, "velocity reversal predicts the next applied y displacement");
		course.remove();
	}

	private static function testPresentationLifecycleResets():Void {
		var course = buildCourse();
		var pose = @:privateAccess course.localPresentationPose;
		assertEquals(false, pose.hasSamples, "spawn begins without stale presentation samples");
		var state = course.localCharacter.stateSnapshot();
		pose.beginSimulationTick(state.x, state.y, course.localCharacter.characterRotation, course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x, state.y, course.localCharacter.characterRotation, course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front);
		pose.beginSimulationTick(state.x, state.y, course.localCharacter.characterRotation, course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x + 2, state.y, course.localCharacter.characterRotation, course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front);
		@:privateAccess course.localPresentationDiscontinuityPending = false;
		assertEquals(false, pose.discontinuity, "small continuous movement is eligible for extrapolation");

		var cameraPose = @:privateAccess course.cameraPresentationPose;
		cameraPose.present(cameraPose.currentX + 8, cameraPose.currentY - 4);
		course.levelRenderer.setPresentationCameraOffset(
			Constants.STAGE_WIDTH / 2 + cameraPose.presentedX,
			Constants.STAGE_HEIGHT / 2 + cameraPose.presentedY
		);
		course.levelRenderer.setPresentationCourseTweenRotation(4.5);
		course.localCharacter.display.x = 1;
		course.changeSpectate(-1);
		assertEquals(true, pose.discontinuity, "spectate-target change marks a snap");
		assertClose(0, course.localCharacter.display.x, "spectate change immediately snaps local presentation");
		assertClose(cameraPose.currentX, cameraPose.presentedX, "spectate change immediately snaps camera x");
		assertClose(cameraPose.currentY, cameraPose.presentedY, "spectate change immediately snaps camera y");
		assertClose(course.levelRenderer.courseTweenRotation(), course.levelRenderer.presentationCourseTweenRotation(),
			"spectate change immediately snaps course presentation");

		pose.beginSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x + 2, state.y, 0, 1, CharacterPresentationLayer.Front);
		@:privateAccess course.localPresentationDiscontinuityPending = false;
		@:privateAccess course.toggleKeyScroll(true);
		assertEquals(true, pose.discontinuity, "manual camera scrolling marks a synchronized snap");
		@:privateAccess course.toggleKeyScroll(false);

		state = course.localCharacter.stateSnapshot();
		@:privateAccess course.localCharacter.controller.vx = 6;
		@:privateAccess course.localCharacter.controller.vy = -4;
		@:privateAccess course.localPresentationDiscontinuityPending = false;
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		course.localCharacter.setControllerPosition(state.x + 100, state.y);
		var teleportDx = course.localCharacter.controller.presentationDeltaX();
		var teleportDy = course.localCharacter.controller.presentationDeltaY();
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		assertEquals(false, pose.discontinuity, "explicit teleport does not mark local position prediction as discontinuous");
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(teleportDx * 0.5, course.localCharacter.display.x,
			"teleport predicts from the destination using next applied x displacement");
		assertClose(teleportDy * 0.5, course.localCharacter.display.y,
			"teleport predicts from the destination using next applied y displacement");

		var version = course.localCharacter.controller.movementDiscontinuityVersion;
		course.localCharacter.resetControllerForRaceStart(state.x, state.y);
		assertEquals(version + 1, course.localCharacter.controller.movementDiscontinuityVersion,
			"respawn/start reset publishes a movement discontinuity");

		pose.beginSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x + 2, state.y, 0, 1, CharacterPresentationLayer.Front);
		@:privateAccess course.localPresentationDiscontinuityPending = false;
		course.offlineMode = true;
		@:privateAccess course.localCharacter.controller.finished = true;
		@:privateAccess course.maybeHandleLocalFinish(course.localCharacter.stateSnapshot());
		assertEquals(true, pose.discontinuity, "finish/removal lifecycle marks a snap");

		pose.beginSimulationTick(state.x, state.y, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x + 4, state.y + 2, 0, 1, CharacterPresentationLayer.Front);
		course.localCharacter.display.x = 2;
		course.createLocalCharacter(localInit(3));
		assertEquals(false, pose.hasSamples, "local-character rebuild clears pose validity");
		assertClose(0, pose.previousX, "local-character rebuild clears previous sample");
		assertClose(0, pose.currentX, "local-character rebuild clears current sample");
		assertClose(0, course.localCharacter.display.x, "local-character rebuild clears any inner presentation offset");

		assertEquals(true, course.teleportLocalToStage(275, 200), "stage teleport fixture succeeds");
		assertEquals(false, pose.hasSamples, "external teleport invalidates stale pose samples");
		course.remove();
		assertEquals(false, pose.hasSamples, "course removal leaves no presentation samples");
		assertClose(0, pose.previousX, "course removal clears previous sample coordinates");
		assertClose(0, pose.currentX, "course removal clears current sample coordinates");
	}

	private static function testSmoothPresentationExtrapolatesWithoutAdvancingCharacterTimeline():Void {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		@:privateAccess course.onCountdownFinish();
		@:privateAccess course.input.right = true;
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));

		var pose = @:privateAccess course.localPresentationPose;
		assertEquals(true, pose.currentX != pose.previousX || pose.currentY != pose.previousY,
			"fixture produces movement for extrapolation");
		assertClose(0, course.localCharacter.display.x, "simulation frame restores authoritative inner x");
		assertClose(0, course.localCharacter.display.y, "simulation frame restores authoritative inner y");
		var authoritativeX = course.localCharacter.x;
		var authoritativeY = course.localCharacter.y;
		var authoritativeCameraX = @:privateAccess course.camera.posX;
		var authoritativeCameraY = @:privateAccess course.camera.posY;
		var cameraPose = @:privateAccess course.cameraPresentationPose;
		var expectedPresentedCameraX = cameraPose.extrapolatedX(0.5);
		var expectedPresentedCameraY = cameraPose.extrapolatedY(0.5);
		var timelineFrame = course.localCharacter.display.currentFrame;
		var timelineState = course.localCharacter.display.currentState;
		var cachedCharacterSubtree = course.localCharacter.display.effectTarget("head");
		cachedCharacterSubtree.cacheAsBitmap = true;
		cachedCharacterSubtree.cacheAsBitmapMatrix = new Matrix(2, 0, 0, 2, 3, 4);
		var cachedCharacterChildCount = cachedCharacterSubtree.numChildren;

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));

		assertClose(authoritativeX, course.localCharacter.x, "presentation frame leaves authoritative x unchanged");
		assertClose(authoritativeY, course.localCharacter.y, "presentation frame leaves authoritative y unchanged");
		assertClose(authoritativeCameraX, @:privateAccess course.camera.posX,
			"presentation frame leaves authoritative camera x unchanged");
		assertClose(authoritativeCameraY, @:privateAccess course.camera.posY,
			"presentation frame leaves authoritative camera y unchanged");
		assertClose(expectedPresentedCameraX, cameraPose.presentedX,
			"camera extrapolates on the local-player presentation phase");
		assertClose(expectedPresentedCameraY, cameraPose.presentedY,
			"camera y extrapolates on the local-player presentation phase");
		var renderedCameraOffset = course.levelRenderer.presentationCameraOffset();
		assertClose(Constants.STAGE_WIDTH / 2 + expectedPresentedCameraX, renderedCameraOffset.x,
			"renderer receives extrapolated camera x on the same phase");
		assertClose(Constants.STAGE_HEIGHT / 2 + expectedPresentedCameraY, renderedCameraOffset.y,
			"renderer receives extrapolated camera y on the same phase");
		var authoritativeCameraOffset = course.levelRenderer.cameraOffset();
		assertClose(Math.round(Constants.STAGE_WIDTH / 2 + authoritativeCameraX), authoritativeCameraOffset.x,
			"presentation frame leaves renderer authoritative camera x unchanged");
		assertClose(Math.round(Constants.STAGE_HEIGHT / 2 + authoritativeCameraY), authoritativeCameraOffset.y,
			"presentation frame leaves renderer authoritative camera y unchanged");
		var authoritativeState = course.localCharacter.stateSnapshot();
		var predictedDeltaX = @:privateAccess course.localPresentationDeltaX;
		var predictedDeltaY = @:privateAccess course.localPresentationDeltaY;
		var predictedX = authoritativeState.x + predictedDeltaX * 0.5;
		var predictedY = authoritativeState.y + predictedDeltaY * 0.5;
		assertClose(pose.currentX, authoritativeState.x, "presentation offset never enters controller x");
		assertClose(pose.currentY, authoritativeState.y, "presentation offset never enters controller y");
		assertEquals(true, predictedX != authoritativeState.x || predictedY != authoritativeState.y,
			"fixture distinguishes disposable prediction from authoritative state");
		var radians = -pose.currentRotation * Math.PI / 180;
		var worldOffsetX = predictedX - pose.currentX;
		var worldOffsetY = predictedY - pose.currentY;
		assertClose(worldOffsetX * Math.cos(radians) - worldOffsetY * Math.sin(radians), course.localCharacter.display.x,
			"presentation frame applies half-step local x offset");
		assertClose(worldOffsetX * Math.sin(radians) + worldOffsetY * Math.cos(radians), course.localCharacter.display.y,
			"presentation frame applies half-step local y offset");
		assertEquals(timelineFrame, course.localCharacter.display.currentFrame,
			"presentation frame does not advance character art");
		assertEquals(timelineState, course.localCharacter.display.currentState,
			"presentation frame does not select or synthesize a character pose");
		assertEquals(true, cachedCharacterSubtree.cacheAsBitmap,
			"presentation transform preserves flattened character-subtree caching");
		assertEquals(cachedCharacterChildCount, cachedCharacterSubtree.numChildren,
			"presentation transform does not rebuild the cached character subtree");
		assertClose(2, cachedCharacterSubtree.cacheAsBitmapMatrix.a,
			"presentation transform preserves the character cache raster scale");
		assertClose(3, cachedCharacterSubtree.cacheAsBitmapMatrix.tx,
			"presentation transform preserves the character cache registration");

		var stateBeforeNextTick = course.localCharacter.stateSnapshot();
		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		assertClose(stateBeforeNextTick.x, pose.previousX, "next simulation starts from authoritative x, not prediction");
		assertClose(stateBeforeNextTick.y, pose.previousY, "next simulation starts from authoritative y, not prediction");
		assertClose(0, course.localCharacter.display.x, "next simulation frame clears extrapolated x");
		assertClose(0, course.localCharacter.display.y, "next simulation frame clears extrapolated y");
		assertClose(@:privateAccess course.camera.posX, cameraPose.presentedX,
			"next simulation frame restores authoritative camera x");
		assertClose(@:privateAccess course.camera.posY, cameraPose.presentedY,
			"next simulation frame restores authoritative camera y");
		assertEquals(timelineFrame + 1, course.localCharacter.display.currentFrame,
			"next simulation frame advances character art once");

		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
	}

	private static function testPresentationPoseCapturesAuthoritativeTickBounds():Void {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		@:privateAccess course.onCountdownFinish();
		var before = course.localCharacter.stateSnapshot();
		@:privateAccess course.input.right = true;

		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));

		var after = course.localCharacter.stateSnapshot();
		var pose = @:privateAccess course.localPresentationPose;
		assertEquals(true, pose.hasSamples, "simulation tick produces local presentation samples");
		assertClose(before.x, pose.previousX, "pose previous x is captured immediately before simulation");
		assertClose(before.y, pose.previousY, "pose previous y is captured immediately before simulation");
		assertClose(after.x, pose.currentX, "pose current x is captured immediately after simulation");
		assertClose(after.y, pose.currentY, "pose current y is captured immediately after simulation");
		assertClose(course.localCharacter.controller.presentationDeltaX(), @:privateAccess course.localPresentationDeltaX,
			"local presentation captures predicted next authoritative x displacement");
		assertClose(course.localCharacter.controller.presentationDeltaY(), @:privateAccess course.localPresentationDeltaY,
			"local presentation captures predicted next authoritative y displacement");
		assertClose(course.localCharacter.characterRotation, pose.currentRotation, "pose captures authoritative character rotation");
		assertEquals(course.localCharacter.facingScaleX, pose.currentFacing, "pose captures authoritative facing");
		assertEquals(CharacterPresentationLayer.Front, pose.currentLayer, "pose captures the authoritative display layer");
		course.remove();
	}

	private static function testCourseRunsOnlyOnSimulationFrames():Void {
		var course = buildCourse();
		@:privateAccess course.frameCounterActive = true;
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		assertEquals(1, course.framesPlaying, "simulation phase advances Course once");

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		assertEquals(1, course.framesPlaying, "presentation-only phase skips Course");

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		assertEquals(2, course.framesPlaying, "next simulation phase advances Course once");

		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
	}

	private static function testPresentationFrameKeepsGameplayTransitionsDiscrete():Void {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		@:privateAccess course.onCountdownFinish();
		var itemCode = course.itemDisplay.itemCode;
		var itemAmmo = course.itemDisplay.ammo;
		var characterMode = course.localCharacter.stateSnapshot().mode;
		var characterVisible = course.localCharacter.visible;
		var hat = course.addLooseHat(
			Math.round(course.localCharacter.x),
			Math.round(course.localCharacter.y),
			0,
			5,
			0xFFFFFF,
			-1,
			77
		);
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);
		clock.advanceFrame();
		clock.advanceFrame();

		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		course.localCharacter.dispatchEvent(new Event(Event.ENTER_FRAME));
		course.itemDisplay.dispatchEvent(new Event(Event.ENTER_FRAME));

		assertEquals(true, course.looseHats.exists(77), "presentation frame cannot collect a loose-hat pickup");
		assertEquals(course.effectBackground, hat.display.parent, "presentation frame cannot change pickup visibility");
		assertEquals(itemCode, course.itemDisplay.itemCode, "presentation frame cannot change held-item state");
		assertEquals(itemAmmo, course.itemDisplay.ammo, "presentation frame cannot change held-item uses");
		assertEquals(characterMode, course.localCharacter.stateSnapshot().mode,
			"presentation frame cannot select a gameplay state transition");
		assertEquals(characterVisible, course.localCharacter.visible,
			"presentation frame cannot change character visibility");

		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		assertEquals(false, course.looseHats.exists(77), "next simulation frame performs the pending pickup");

		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
	}

	private static function testMinimapDotsRemainAuthoritativeDuringPresentation():Void {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		var remote = course.createRemoteCharacter(remoteInit(1));
		remote.setPos(course.localCharacter.x + 60, course.localCharacter.y + 30);
		course.toggleSpectatePossible(true);
		course.changeSpectate(remote.tempID);
		@:privateAccess course.localCharacter.controller.courseRotation = 90;
		course.updatePlayerDisplay();

		var localDotX = @:privateAccess course.playerDot.x;
		var localDotY = @:privateAccess course.playerDot.y;
		var remoteDotX = remote.mapDot.x;
		var remoteDotY = remote.mapDot.y;
		var minimapRotation = @:privateAccess course.miniMap.holder.rotation;
		var state = course.localCharacter.stateSnapshot();
		var pose = @:privateAccess course.localPresentationPose;
		pose.beginSimulationTick(
			state.x - 8,
			state.y - 4,
			course.localCharacter.characterRotation,
			course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front
		);
		pose.finishSimulationTick(
			state.x - 4,
			state.y - 2,
			course.localCharacter.characterRotation,
			course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front
		);
		pose.beginSimulationTick(
			state.x - 4,
			state.y - 2,
			course.localCharacter.characterRotation,
			course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front
		);
		pose.finishSimulationTick(
			state.x,
			state.y,
			course.localCharacter.characterRotation,
			course.localCharacter.facingScaleX,
			CharacterPresentationLayer.Front
		);
		@:privateAccess course.localPresentationDeltaX = 8;
		@:privateAccess course.localPresentationDeltaY = 4;
		@:privateAccess course.localPresentationDiscontinuityPending = false;
		var clock = new FrameClock(FrameRateSettings.fromQuery("?smooth60=1", true), new FrameRateDiagnostics(function():Float return 0));
		@:privateAccess FrameClock.setCurrentForTests(clock);
		clock.advanceFrame();
		clock.advanceFrame();
		@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));

		assertEquals(true, course.localCharacter.display.x != 0 || course.localCharacter.display.y != 0,
			"fixture presents a character transform distinct from its authoritative minimap pose");
		assertClose(localDotX, @:privateAccess course.playerDot.x,
			"local minimap dot holds its authoritative 30 Hz x on a presentation frame");
		assertClose(localDotY, @:privateAccess course.playerDot.y,
			"local minimap dot holds its authoritative 30 Hz y on a presentation frame");
		assertClose(remoteDotX, remote.mapDot.x,
			"remote minimap dot holds its authoritative network/simulation x while spectating");
		assertClose(remoteDotY, remote.mapDot.y,
			"remote minimap dot holds its authoritative network/simulation y while spectating");
		assertClose(90, minimapRotation, "fixture commits the minimap's authoritative course rotation");
		assertClose(minimapRotation, @:privateAccess course.miniMap.holder.rotation,
			"presentation course rotation does not rotate the minimap between authoritative commits");
		assertEquals(remote, course.playerSpectating, "spectating does not substitute a presented target position into minimap dots");

		course.remove();
		@:privateAccess FrameClock.setCurrentForTests(null);
	}

	private static function testLocalCharacterAnimationAdvancesDuringRace():Void {
		var course = buildCourse();
		course.raceStarted = true;
		course.updatePlayerDisplay();
		var state = course.localCharacter.display.currentState;
		var firstFrame = course.localCharacter.display.currentFrame;
		course.updatePlayerDisplay();
		assertEquals(state, course.localCharacter.display.currentState, "stable race motion keeps the same character animation");
		assertEquals(firstFrame + 1, course.localCharacter.display.currentFrame,
			"stable race motion advances instead of restarting the character animation");
		course.remove();
	}

	private static function testSharedCommandHandlerCompletesLooseHatPickup():Void {
		var handler = new CommandHandler();
		var course = buildCourse();
		course.createLocalCharacter(localInit(4));
		assertEquals(true, handler.hasCommand("setHats4"), "implicit shared command handler registers the local hat-stack reply");
		var hat = course.addLooseHat(Math.round(course.localCharacter.x), Math.round(course.localCharacter.y), 0, 6, 0x123456, -1, 2);
		LobbySocket.resetSent();
		hat.step(course.level, 0, course.localCharacter.x, course.localCharacter.y);
		assertEquals("get_hat`2", LobbySocket.lastSent(), "touching a loose hat requests it from the server");
		assertEquals(true, handler.dispatch("setHats4", ["6", "1193046", "-1"]), "server pickup reply reaches the local character");
		assertEquals(6, course.localCharacter.hat1, "server pickup reply equips the collected hat");
		course.remove();
		assertEquals(false, handler.hasCommand("setHats4"), "course teardown unregisters the shared local hat-stack command");
	}

	private static function testDeathmatchHeartsShowInitialLives():Void {
		var course = buildCourse("deathmatch");
		assertEquals(true, course.hearts.visible, "deathmatch course shows hearts immediately");
		assertEquals(3, course.hearts.getHeartCount(), "deathmatch course starts with three lives");
		course.setLife(2);
		assertEquals(2, course.hearts.getHeartCount(), "setLife updates deathmatch hearts");
		assertEquals(2, course.localCharacter.stateSnapshot().lives, "setLife updates local controller lives");
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		assertEquals(2, course.hearts.getHeartCount(), "setLife value survives the next frame sync");
		LobbySocket.resetSent();
		var zeroLives = new LocalPlayerState(0, 0, 0, 0, false, false, CharacterState.Bumped, null, "hurt", null, null, null, 50, 50,
			50, 0, true, null, null, null, 0);
		@:privateAccess course.maybeHandleLocalFinish(zeroLives);
		assertEquals("finish_race`-1`0`0|set_var`beginRemove`1", LobbySocket.sentCommands.join("|"),
			"deathmatch zero lives emits finish and starts local removal");
		course.remove();
	}

	private static function testRoguelikeHudAndInitialState():Void {
		var course = buildCourse("roguelike");
		var state = course.localCharacter.stateSnapshot();
		assertEquals(true, course.hearts.visible, "roguelike course shows hearts immediately");
		assertEquals(1, course.hearts.getHeartCount(), "roguelike course starts with one heart");
		assertClose(0, state.speedStat, "roguelike live character starts with zero speed");
		assertClose(0, state.accelerationStat, "roguelike live character starts with zero acceleration");
		assertClose(0, state.jumpStat, "roguelike live character starts with zero jumping");
		assertEquals("Finish: 0/9", course.roguelikeProgressText.text, "roguelike HUD shows finish progress");
		course.localCharacter.setHats([6, 0xFFFFFF, -1]);
		assertEquals(1, course.localCharacter.hat1, "roguelike rejects local hat updates");
		var remote = course.createRemoteCharacter(remoteInit(9));
		remote.setHats([7, 0xFFFFFF, -1]);
		assertEquals(1, remote.hat1, "roguelike rejects remote hat updates");
		course.remove();
		assertEquals(true, course.roguelikeProgressText == null, "roguelike progress HUD tears down");
	}

	private static function testRoguelikeOnlyEmitsTerminalFinishOnNinthHit():Void {
		var course = buildCourse("roguelike");
		var finishBlock = new LevelBlock(1, 1, BlockType.Finish);
		course.localCharacter.setLife(9);
		LobbySocket.resetSent();
		for (_ in 1...LocalPlayerController.ROGUELIKE_REQUIRED_FINISH_HITS) {
			@:privateAccess course.localCharacter.controller.finish(finishBlock);
			@:privateAccess course.maybeHandleLocalFinish(course.localCharacter.stateSnapshot());
		}
		assertEquals("", LobbySocket.sentCommands.join("|"), "first eight roguelike hits emit no finish event");
		@:privateAccess course.localCharacter.controller.finish(finishBlock);
		@:privateAccess course.maybeHandleLocalFinish(course.localCharacter.stateSnapshot());
		assertEquals(true, StringTools.startsWith(LobbySocket.sentCommands.join("|"), "finish_race`"),
			"ninth roguelike hit emits the existing finish event");
		course.remove();
	}

	private static function testTimerBeginRaceAndTimeoutBoundary():Void {
		var course = buildCourse();
		var timeoutCalls = 0;
		course.onOutOfTime = function():Void timeoutCalls++;
		course.beginRace();
		assertEquals("2:00", course.timer.debugText(), "beginRace initializes the course timer display");
		course.outOfTimeHandler();
		assertEquals(1, timeoutCalls, "course outOfTimeHandler routes to the host callback");
		course.remove();
	}

	private static function testLiveRaceEmitsMultiplayerUpdates():Void {
		var course = buildCourse();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		course.createRemoteCharacter(remoteInit(9));
		assertEquals(2, course.localCharacter.networkPlayerCount, "remote creation enables multiplayer update cadence");
		assertEquals(null, @:privateAccess course.blockController.moveBlockDeadlineMs,
			"move-block wall-clock schedule stays stopped during loading and countdown");
		@:privateAccess course.onCountdownFinish();
		assertEquals(true, @:privateAccess course.blockController.moveBlockDeadlineMs != null,
			"countdown finish starts the course move-block schedule");
		LobbySocket.resetSent();
		for (_ in 0...5) {
			@:privateAccess course.onEnterFrame(new Event(Event.ENTER_FRAME));
		}
		assertEquals(true, hasSentCommand("p`"), "live race loop emits local position updates for remote players");
		assertEquals(true, hasSentCommand("set_var`state`"), "live race loop emits local appearance state for remote players");
		course.removeRemoteCharacter(9);
		assertEquals(1, course.localCharacter.networkPlayerCount, "remote removal restores solo update cadence");
		course.remove();
	}

	private static function hasSentCommand(prefix:String):Bool {
		for (command in LobbySocket.sentCommands) {
			if (StringTools.startsWith(command, prefix)) {
				return true;
			}
		}
		return false;
	}

	private static function testRenderingUsesFreeMoveCamera():Void {
		var course = buildLargeCourse();
		assertEquals(false, course.levelRenderer.isDrawingComplete(), "large course starts in incremental render mode");
		@:privateAccess course.scrollRight = true;
		var beforeX = @:privateAccess course.camera.posX;

		course.dispatchEvent(new Event(Event.ENTER_FRAME));

		assertEquals(true, course.debugKeyScrollActive(), "rendering course enables free-move camera");
		assertBelow(@:privateAccess course.camera.posX, beforeX, "right arrow free-scrolls the loading level");
		course.remove();
	}

	private static function testRemoteParentLayerSwitch(course:Course):Void {
		var remote = course.createRemoteCharacter(remoteInit(9));
		assertEquals(course.characterLayer, remote.parent, "remote character starts in front character layer");
		var start = @:privateAccess course.startPositions[0];
		assertClose(start.x, remote.x, "remote character keeps its world start x before Go");
		assertClose(start.y, remote.y, "remote character keeps its world start y before Go");
		remote.pos(["30", "15"]);
		for (_ in 0...5) {
			remote.stepFrame();
		}
		assertClose(remote.posX, remote.x, "live remote x remains in Flash-compatible world coordinates");
		assertClose(remote.posY, remote.y, "live remote y remains in Flash-compatible world coordinates");
		var remotePose = @:privateAccess remote.presentationPose;
		remotePose.beginSimulationTick(remote.x - 4, remote.y - 2, remote.rotation, 1, CharacterPresentationLayer.Front);
		remotePose.finishSimulationTick(remote.x - 2, remote.y - 1, remote.rotation, 1, CharacterPresentationLayer.Front);
		remotePose.beginSimulationTick(remote.x - 2, remote.y - 1, remote.rotation, 1, CharacterPresentationLayer.Front);
		remotePose.finishSimulationTick(remote.x, remote.y, remote.rotation, 1, CharacterPresentationLayer.Front);
		remote.renderPresentationFrame();
		assertEquals(true, remote.display.x != 0 || remote.display.y != 0,
			"fixture establishes a remote presentation offset before a water-layer switch");
		remote.onParentChange("backBackground");
		assertEquals(course.backCharacterLayer, remote.parent, "remote water parent moves behind blocks");
		assertEquals(false, course.characterLayer.contains(remote), "remote water switch removes the character from the front layer");
		assertEquals(true, course.backCharacterLayer.contains(remote), "remote water switch leaves exactly one back-layer character instance");
		remote.renderPresentationFrame();
		assertClose(0, remote.display.x, "remote water switch invalidates stale presented x");
		assertClose(0, remote.display.y, "remote water switch invalidates stale presented y");
		remote.onParentChange("frontBackground");
		assertEquals(course.characterLayer, remote.parent, "remote front parent returns above blocks");
		assertEquals(false, course.backCharacterLayer.contains(remote), "remote front switch removes the character from the back layer");
		assertEquals(true, course.characterLayer.contains(remote), "remote front switch leaves exactly one front-layer character instance");
		course.removeRemoteCharacter(9);
	}

	private static function testLocalWaterParentLayerSwitch(course:Course):Void {
		var state = course.localCharacter.stateSnapshot();
		var pose = @:privateAccess course.localPresentationPose;
		pose.beginSimulationTick(state.x - 4, state.y - 2, course.localCharacter.characterRotation, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x - 2, state.y - 1, course.localCharacter.characterRotation, 1, CharacterPresentationLayer.Front);
		pose.beginSimulationTick(state.x - 2, state.y - 1, course.localCharacter.characterRotation, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(state.x, state.y, course.localCharacter.characterRotation, 1, CharacterPresentationLayer.Front);
		@:privateAccess course.localPresentationDeltaX = 4;
		@:privateAccess course.localPresentationDeltaY = 2;
		@:privateAccess course.renderLocalPresentationFrame();
		assertEquals(true, course.localCharacter.display.x != 0 || course.localCharacter.display.y != 0,
			"fixture establishes a local presentation offset before a water-layer switch");
		@:privateAccess course.beginLocalPresentationPoseCapture(state);
		@:privateAccess course.localCharacter.controller.touchedBlock = new LevelBlock(0, 0, BlockType.Water);
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		var waterDx = @:privateAccess course.localPresentationDeltaX;
		var waterDy = @:privateAccess course.localPresentationDeltaY;
		course.updatePlayerDisplay();
		assertEquals(course.backCharacterLayer, course.localCharacter.parent, "local water touch moves behind blocks");
		assertEquals(true, pose.discontinuity, "local water-layer transition marks the presentation pose discontinuous");
		assertEquals(false, course.characterLayer.contains(course.localCharacter),
			"local water switch removes the character from the front layer");
		assertEquals(true, course.backCharacterLayer.contains(course.localCharacter),
			"local water switch leaves exactly one back-layer character instance");
		@:privateAccess course.renderLocalPresentationFrame();
		assertClose(waterDx * 0.5, course.localCharacter.display.x,
			"local water switch discards stale x history but preserves the fresh movement prediction");
		assertClose(waterDy * 0.5, course.localCharacter.display.y,
			"local water switch discards stale y history but preserves the fresh movement prediction");

		@:privateAccess course.beginLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		@:privateAccess course.localCharacter.controller.touchedBlock = null;
		@:privateAccess course.finishLocalPresentationPoseCapture(course.localCharacter.stateSnapshot());
		course.updatePlayerDisplay();
		assertEquals(course.characterLayer, course.localCharacter.parent, "local non-water touch returns above blocks");
		assertEquals(true, pose.discontinuity, "local return-to-front transition also marks a presentation snap");
		assertEquals(false, course.backCharacterLayer.contains(course.localCharacter),
			"local front switch removes the character from the back layer");
		assertEquals(true, course.characterLayer.contains(course.localCharacter),
			"local front switch leaves exactly one front-layer character instance");
	}

	private static function remoteInit(tempId:Int):RemoteCharacterInit {
		return {
			tempId: tempId,
			userName: "Remote",
			hatId: 1,
			headId: 1,
			bodyId: 1,
			feetId: 1,
			group: "g",
			hatColor: 1,
			hatColor2: 2,
			headColor: 3,
			headColor2: 4,
			bodyColor: 5,
			bodyColor2: 6,
			feetColor: 7,
			feetColor2: 8
		};
	}

	private static function localInit(tempId:Int):LocalCharacterInit {
		return {
			tempId: tempId,
			speed: 50,
			accel: 50,
			jump: 50,
			hatColor: 1,
			headColor: 2,
			bodyColor: 3,
			feetColor: 4,
			hatId: 1,
			headId: 1,
			bodyId: 1,
			feetId: 1,
			hatColor2: -1,
			headColor2: -1,
			bodyColor2: -1,
			feetColor2: -1,
			group: ""
		};
	}

	private static function buildCourse(gameMode:String = "race"):Course {
		var dataString = "m3`e0c8b8`334;335;11,1;0;12,0;1;0,1;0";
		var level = LevelDecoder.decode(dataString);

		var vars:Map<String, String> = new Map();
		vars.set("level_id", "42");
		vars.set("title", "Mount Test");
		vars.set("song", "song1");
		vars.set("gravity", "2.5");
		vars.set("max_time", "120");
		vars.set("gameMode", gameMode);
		vars.set("items", "all");
		vars.set("data", dataString);

		var data = new ServerLevelData(vars, true);
		var config = LevelConfig.fromServerData(data);
		return new Course(level, data, config);
	}

	private static function buildLargeCourse():Course {
		var blocks:Array<LevelBlock> = [LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_START1, 0, 0)];
		for (i in 0...120) {
			blocks.push(LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_BASIC1, i * 30, 90));
		}
		var level = Level.fromDecoded(0xFFFFFF, blocks);
		var vars:Map<String, String> = new Map();
		vars.set("level_id", "44");
		vars.set("title", "Large Render Test");
		vars.set("song", "song1");
		vars.set("gravity", "1");
		vars.set("max_time", "120");
		vars.set("gameMode", "race");
		vars.set("items", "all");
		vars.set("data", "large-render-test");
		var data = new ServerLevelData(vars, true);
		return new Course(level, data, LevelConfig.fromServerData(data));
	}

	private static function testTournamentStartForcesFirstStartPosition():Void {
		var previousTournamentMode = LobbySession.tournamentMode;
		LobbySession.tournamentMode = true;
		var level = Level.fromDecoded(0xFFFFFF, [
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_START1, 0, 0),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_START2, 210, 0),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_BASIC1, 0, 30),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_BASIC1, 210, 30)
		]);
		var vars:Map<String, String> = new Map();
		vars.set("level_id", "45");
		vars.set("title", "Tournament Start Test");
		vars.set("song", "song1");
		vars.set("gravity", "1");
		vars.set("max_time", "120");
		vars.set("gameMode", "race");
		vars.set("items", "all");
		vars.set("data", "tournament-start-test");
		var data = new ServerLevelData(vars, true);
		var course = new Course(level, data, LevelConfig.fromServerData(data));
		course.createLocalCharacter({
			tempId: 1,
			speed: 50,
			accel: 50,
			jump: 50,
			hatColor: 1,
			headColor: 2,
			bodyColor: 3,
			feetColor: 4,
			hatId: 1,
			headId: 1,
			bodyId: 1,
			feetId: 1,
			hatColor2: 5,
			headColor2: 6,
			bodyColor2: 7,
			feetColor2: 8,
			group: ""
		});
		var state = course.localCharacter.stateSnapshot();
		assertClose(15, state.x, "tournament local temp 1 uses first start x");
		assertClose(15, state.y, "tournament local temp 1 uses first start y");
		course.remove();
		LobbySession.tournamentMode = previousTournamentMode;
	}

	private static function testFinishDrawingReadinessEmission():Void {
		var dataString = "m3`e0c8b8`0;0;11,1;0;16";
		var level = LevelDecoder.decode(dataString);
		var saveString = "level_id=42&version=7&title=Draw Ready&song=song1&gravity=1&max_time=120&gameMode=race&cowboyChance=25&badHats=4,6&data="
			+ dataString;

		var vars:Map<String, String> = new Map();
		vars.set("level_id", "42");
		vars.set("version", "7");
		vars.set("title", "Draw Ready");
		vars.set("song", "song1");
		vars.set("gravity", "1");
		vars.set("max_time", "120");
		vars.set("gameMode", "race");
		vars.set("cowboyChance", "25");
		vars.set("badHats", "4,6");
		vars.set("data", dataString);

		var data = new ServerLevelData(vars, true, saveString);
		var course = new Course(level, data, LevelConfig.fromServerData(data));
		LobbySocket.resetSent();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		course.dispatchEvent(new Event(Event.ENTER_FRAME));

		var hash = Md5.encode(saveString + "42" + "7" + ServerConfig.LEVEL_HASH_SALT);
		assertEquals(
			'finish_drawing`$hash`race`[{"id":0,"x":45,"y":15}]`1`25`4,6',
			LobbySocket.sentCommands.join("|"),
			"finish_drawing emitted after all drawing completes"
		);
		assertEquals(false, course.drawingInfo.isDrawing(0), "local drawing spinner hidden after readiness emission");
		course.remove();
	}

	private static function testLocalFinishBeginsCharacterRemoval():Void {
		var course = buildCourse("race");
		course.beginRace();
		assertEquals(false, course.timer.debugPaused(), "race timer runs once beginRace arrives");
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		assertEquals(3, course.framesPlaying, "physics-frame measurement advances from the begin-race message");
		LobbySocket.resetSent();
		var finish = new LocalPlayerState(0, 0, 0, 0, false, false, CharacterState.Stand, null, "land", null, null, null, 50, 50,
			50, 0, true, 1, 9945, 9945);
		@:privateAccess course.maybeHandleLocalFinish(finish);
		assertEquals("finish_race`1`9945`9945|set_var`beginRemove`1", LobbySocket.sentCommands.join("|"),
			"race finish reports world coordinates and starts local removal");
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		assertEquals(3, course.framesPlaying, "physics-frame measurement stops when finish_race is emitted");
		assertEquals(true, course.timer.debugPaused(), "race finish freezes the HUD timer");
		assertEquals(false, course.localCharacter.removed, "finish starts fade-out instead of immediate removal");
		assertEquals(CharacterState.Stand, course.localCharacter.state, "finish preserves the character animation instead of showing the ice-blast pose");
		assertEquals("freeze", course.localCharacter.stateSnapshot().mode, "finish pauses character physics with Flash's freeze mode");
		assertEquals(true, course.debugKeyScrollActive(), "finish switches camera to free-move mode");
		var x = course.localCharacter.stateSnapshot().x;
		var y = course.localCharacter.stateSnapshot().y;
		@:privateAccess course.input.right = true;
		course.dispatchEvent(new Event(Event.ENTER_FRAME));
		assertClose(x, course.localCharacter.stateSnapshot().x, "finished character no longer steps horizontally");
		assertClose(y, course.localCharacter.stateSnapshot().y, "finished character no longer steps vertically");
		course.remove();
	}

	private static function testTestModeFinishDelegatesWithoutRaceRemoval():Void {
		var course = buildCourse("race");
		course.offlineMode = true;
		var callbacks = 0;
		course.onFinish = function(_):Void callbacks++;
		LobbySocket.resetSent();
		var finish = new LocalPlayerState(0, 0, 0, 0, false, false, CharacterState.Stand, null, "land", null, null, null, 50, 50,
			50, 0, true, 1, 45, 15);
		@:privateAccess course.maybeHandleLocalFinish(finish);

		assertEquals(1, callbacks, "test-mode finish delegates to the level tester once");
		assertEquals("", LobbySocket.sentCommands.join("|"), "test-mode finish emits no race network commands");
		var alphaBefore = course.localCharacter.alpha;
		course.localCharacter.dispatchEvent(new Event(Event.ENTER_FRAME));
		assertClose(alphaBefore, course.localCharacter.alpha, "test-mode finish does not fade out the character");
		course.remove();
	}

	private static function testTestModeFinishMaySynchronouslyRemoveCourse():Void {
		var course = buildCourse("race");
		course.offlineMode = true;
		course.beginRace();
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		var callbacks = 0;
		course.onFinish = function(_):Void {
			callbacks++;
			course.remove();
		};
		@:privateAccess course.localCharacter.controller.finished = true;

		course.dispatchEvent(new Event(Event.ENTER_FRAME));

		assertEquals(1, callbacks, "test-mode finish permits the level tester to replace its course synchronously");
		assertEquals(null, course.localCharacter, "removed test course does not continue its old frame after the finish callback");
	}

	private static function testObjectiveModeReportsEachFinishOnce():Void {
		var course = buildCourse("objective");
		course.beginRace();
		LobbySocket.resetSent();
		var first = new LocalPlayerState(0, 0, 0, 0, false, false, CharacterState.Stand, null, "land", null, null, null, 50, 50,
			50, 0, true, 1, 9945, 9945);
		var second = new LocalPlayerState(0, 0, 0, 0, false, false, CharacterState.Stand, null, "land", null, null, null, 50, 50,
			50, 0, true, 2, 9975, 9945);
		@:privateAccess course.maybeHandleLocalFinish(first);
		@:privateAccess course.maybeHandleLocalFinish(first);
		@:privateAccess course.maybeHandleLocalFinish(second);
		assertEquals("objective_reached`1`9945`9945|objective_reached`2`9975`9945", LobbySocket.sentCommands.join("|"),
			"objective mode reports each objective in world coordinates once without ending race");
		assertEquals(false, course.localFinishHandled, "objective mode does not latch the race finished");
		assertEquals(false, course.timer.debugPaused(), "objective progress leaves the HUD timer running");
		course.remove();
	}

	private static function testRotateBlockDisplayKeepsLocalCharacterCentered():Void {
		var course = buildRotateCourse();
		for (_ in 0...40) {
			course.localCharacter.step(new LocalPlayerInput(false, false, true));
			if (course.localCharacter.stateSnapshot().mode == "freeze") {
				break;
			}
		}
		assertEquals("freeze", course.localCharacter.stateSnapshot().mode, "local character reaches rotate pause state");

		course.localCharacter.step(new LocalPlayerInput());
		course.updatePlayerDisplay();
		assertEquals(-3, course.localCharacter.rotation, "local character counter-rotates during course tween");
		assertEquals(false, course.levelRenderer.debugArtCachingEnabled(), "rotate tween disables background art caching");
		assertEquals(openfl.display.StageQuality.LOW, course.debugStageQualityForTests(), "rotate tween lowers stage quality");
		assertEquals(course.characterLayer, course.localCharacter.parent, "local character stays in the rotating front layer during tween");
		assertLocalCharacterFeetAnchored(course, "rotate tween keeps local character feet as the visual pivot");
		var tweenFeet = localCharacterFeetOnStage(course);
		assertBetween(0, 550, tweenFeet.x,
			"local character x stays on-stage while the world tween is active");
		assertBetween(0, 400, tweenFeet.y,
			"local character y stays on-stage while the world tween is active");

		for (_ in 0...29) {
			course.localCharacter.step(new LocalPlayerInput());
			course.updatePlayerDisplay();
		}

		var state = course.localCharacter.stateSnapshot();
		assertEquals(90, state.courseRotation, "rotate block commits course rotation");
		assertEquals(0, course.localCharacter.rotation, "local character rotation resets after tween");
		assertEquals(true, course.levelRenderer.debugArtCachingEnabled(), "completed rotate restores background art caching");
		assertEquals(openfl.display.StageQuality.HIGH, course.debugStageQualityForTests(), "completed rotate restores high stage quality");
		var settledFeet = localCharacterFeetOnStage(course);
		assertClose(275, settledFeet.x, "camera snaps local x after rotation");
		assertClose(244.7, settledFeet.y, "camera includes the Flash completion frame's resumed physics");
		course.remove();
	}

	private static function localCharacterFeetOnStage(course:Course):Point {
		return course.localCharacter.localToGlobal(new Point());
	}

	private static function assertLocalCharacterFeetAnchored(course:Course, message:String):Void {
		var state = course.localCharacter.stateSnapshot();
		var worldX = state.x;
		var worldY = state.y;
		var expected = course.levelRenderer.worldToScreen(worldX, worldY);
		var actual = localCharacterFeetOnStage(course);
		assertClose(expected.x, actual.x, '$message x');
		assertClose(expected.y, actual.y, '$message y');
	}

	// Regression: during the 3-2-1 countdown the race has not started, so the
	// local player is never stepped or synced from its controller. Each
	// updatePlayerDisplay still runs and PlayerDisplayPlacement.place() overwrites
	// localCharacter.x/y with the on-screen (feet) coordinate. The camera must
	// therefore follow the controller's authoritative position, not the mutated
	// localCharacter.x/y — otherwise it feeds the previous frame's screen coord
	// back into its target and scrolls away from the player every frame, snapping
	// back only at "Go" (the "player teleports far away during the countdown" bug).
	private static function testCountdownKeepsCameraStill():Void {
		var course = buildCourse("race");
		while (!course.levelRenderer.isDrawingComplete()) {
			course.levelRenderer.dispatchEvent(new Event(Event.ENTER_FRAME));
		}
		// One display frame settles the camera on the player; capture it, then run
		// more countdown frames (no step/sync) and assert the camera does not move.
		course.updatePlayerDisplay();
		// The non-solid start block leaves the player airborne at spawn, so without
		// the wait-state handling the motion state would derive a "jumpAnim"; the
		// countdown must show the idle stand pose instead (Flash mode="wait").
		assertEquals(false, course.localCharacter.grounded, "start block leaves the player airborne at spawn");
		assertEquals("stand", course.localCharacter.display.currentState,
			"local player shows the idle stand pose during the countdown, not a jump");
		var camX = @:privateAccess course.camera.posX;
		var camY = @:privateAccess course.camera.posY;
		for (_ in 0...10) {
			course.updatePlayerDisplay();
		}
		assertClose(camX, @:privateAccess course.camera.posX, "camera x holds steady through the countdown");
		assertClose(camY, @:privateAccess course.camera.posY, "camera y holds steady through the countdown");
		course.remove();
	}

	private static function buildRotateCourse():Course {
		var level = Level.fromDecoded(0xFFFFFF, [
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_START1, 60, 90),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_ROTATE_RIGHT, 60, 30),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_BASIC1, 60, 120),
			LevelBlock.fromWorldPixels(ObjectCodes.BLOCK_FINISH, 120, 120)
		]);

		var vars:Map<String, String> = new Map();
		vars.set("level_id", "43");
		vars.set("title", "Rotate Display Test");
		vars.set("song", "song1");
		vars.set("gravity", "1");
		vars.set("max_time", "120");
		vars.set("gameMode", "race");
		vars.set("items", "all");
		vars.set("data", "rotate-display-test");

		var data = new ServerLevelData(vars, true);
		return new Course(level, data, LevelConfig.fromServerData(data));
	}

	private static function assertClose(expected:Float, actual:Float, message:String):Void {
		assertions++;
		if (Math.abs(expected - actual) > 0.001) {
			throw '$message: expected $expected, got $actual';
		}
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) {
			throw '$message: expected $expected, got $actual';
		}
	}

	private static function assertBelow(actual:Float, expectedUpperBound:Float, message:String):Void {
		assertions++;
		if (!(actual < expectedUpperBound)) {
			throw '$message: expected $actual to be below $expectedUpperBound';
		}
	}

	private static function assertBetween(min:Float, max:Float, actual:Float, message:String):Void {
		assertions++;
		if (actual < min || actual > max) {
			throw '$message: expected $actual to be between $min and $max';
		}
	}
}
