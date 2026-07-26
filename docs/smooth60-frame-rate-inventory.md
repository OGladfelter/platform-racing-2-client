# Smooth 60 Frame-Rate Inventory

This inventory is the source of truth for separating the port's authoritative
30 Hz simulation from its optional 60 Hz presentation. It covers production
uses in `haxe/src`, bootstrap configuration in `project.xml`, and tests that
directly dispatch or inspect `ENTER_FRAME`.

The classifications mean:

- **Simulation:** changes authoritative gameplay, consumes input/network state,
  or advances a frame-counted lifecycle observed by gameplay.
- **Presentation:** changes only a disposable visual transform or samples
  current pointer/display state.
- **Authored animation:** advances an XFL/Lottie/native visual timeline whose
  authored duration remains based on the 30 Hz port clock.
- **UI timing:** advances a menu/HUD fade, repeat, progress animation, audio
  fade, or other non-gameplay frame-counted interaction.
- **Loading work:** incrementally constructs or attaches render assets.
- **Diagnostics:** harness, preview, measurement, or frame-rate-governor work
  that must observe the configured rates without becoming simulation.

Some owners are intentionally classified in more than one column because their
current callback couples responsibilities that later tasks must split.

## Frame-Rate Constants And Direct Stage Rates

| Owner | Use | Classification | Required boundary |
| --- | --- | --- | --- |
| `pr2/Constants.hx` | Defines `SIMULATION_FRAME_RATE = 30`, default/smooth presentation rates of 30/60, and `FIXED_TIMESTEP_SECONDS` from the simulation rate | Simulation + presentation (explicitly separated) | Keep the timestep authoritative at 30 Hz and resolve the presentation choice at startup. |
| `Main.hx` | Assigns `stage.frameRate = Constants.DEFAULT_PRESENTATION_FRAME_RATE` during startup | Presentation | Retain 30 Hz bootstrap, then apply the resolved presentation rate. |
| `com/jiggmin/data/SWFStats.hx` | Defines `DEFAULT_TARGET_FRAME_RATE` from the default presentation rate, reads `stage.frameRate`, and writes it once per stats reset | Diagnostics + presentation governor | Target the configured presentation rate; never derive simulation timing from the stage rate. |
| `pr2/gameplay/player/LocalPlayerController.hx` | Aliases `Constants.SIMULATION_FRAME_RATE` for millisecond-to-frame conversions | Simulation | Remain explicitly bound to the 30 Hz simulation rate. |
| `pr2/gameplay/BlockController.hx` | Computes the three-second teleport reset from `SIMULATION_FRAME_RATE` | Simulation | Remain explicitly bound to the 30 Hz simulation rate. |
| `pr2/gameplay/DrawingInfo.hx` | Converts `framesPlaying` to elapsed drawing time with `SIMULATION_FRAME_RATE` | Simulation-derived HUD timing | Use the 30 Hz simulation rate regardless of presentation mode. |
| `pr2/page/CharacterPartCachePreview.hx` | Saves the stage rate, temporarily requests 120 FPS, then restores it | Diagnostics + presentation preview | Treat as an explicit preview-only override and restore the configured presentation rate safely. |
| `project.xml` | Declares both HTML5 and non-HTML5 windows at `fps="30"` | Presentation bootstrap | Keep bootstrap at 30 FPS; do not make the optional query flag a build-time default. |

`haxe/test/pr2/character/LocalCharacterTest.hx` uses
`Constants.SIMULATION_FRAME_RATE` to size a simulation-duration test.

## Production `ENTER_FRAME` Owners

The search currently finds 46 production source files. Each row groups all
listener registration, removal, and callback uses in that owner.

| Owner / callbacks | Classification | What advances today |
| --- | --- | --- |
| `pr2/gameplay/Course.hx` — `onEnterFrame` | Simulation + presentation + diagnostics | Local input/physics, items, blocks, effects, finish/network state, camera/display placement, HUD synchronization, and debug signals. This is the primary callback that must be split. |
| `pr2/character/RemoteCharacter.hx` — `onEnterFrame`, `go` | Simulation + authored animation | Consumes queued server movement/state, performs catch-up and remote block probes, then advances the character rig. |
| `pr2/character/Character.hx` — `recoveryTick`, `jetPackTick`, `fadeOut` | Simulation | Advances invincibility visibility phases, jet state, and removal lifetime. |
| `pr2/character/PhysicsParticle.hx` — `tick` | Simulation (visual particle) | Integrates velocity/friction/position and lifetime for gameplay particles. |
| `pr2/effects/PhysicsEffect.hx` — `go` | Simulation | Steps a colliding gameplay effect against the level and local player. |
| `pr2/effects/ShotEffect.hx` — `onEnterFrame` | Simulation + authored animation | Advances shot travel/collision/lifetime and its visual state. |
| `pr2/effects/BlockPiece.hx` — `tick` | Simulation (visual particle) | Integrates block-debris motion, bounce, rotation, alpha, and lifetime. |
| `pr2/effects/FollowFadeEffect.hx` — `tick` | Simulation (visual effect) | Follows an authoritative owner and advances a frame-counted fade. |
| `pr2/effects/SegPixel.hx` — `go`, `glint` | Simulation (visual effect) | Eases segment pixels toward targets, then advances glint/fade lifetime. |
| `pr2/effects/StarEffect.hx` — `tick` | Authored animation | Advances fixed star transform keys and effect lifetime. |
| `pr2/effects/ArrowEffect.hx` — `tick` | Authored animation | Advances arrow-effect frames/lifetime. |
| `pr2/effects/TeleportPop.hx` — `tick` | Authored animation | Advances teleport-pop lifetime while its nested timeline also advances. |
| `pr2/effects/MineAppear.hx` — `tick` | Authored animation | Advances the mine-appearance clock and completion callback. |
| `pr2/effects/MineExplosion.hx` — `tick` | Authored animation | Advances the mine-explosion timeline/lifetime. |
| `pr2/effects/NativeEffectAnimation.hx` — `advance` | Authored animation | Advances a native effect frame and dispatches completion. |
| `pr2/effects/LaserShotView.hx` — `advance` | Authored animation | Advances the laser impact timeline. |
| `pr2/effects/Effect.hx` — `onRemoveFrame` | Simulation (effect lifecycle) | Converts a scheduled millisecond removal delay into 30 Hz lifetime frames. |
| `pr2/animation/TimelineClip.hx` — `advance` | Authored animation | Advances Lottie-profile timelines, markers, loops, and completion. |
| `pr2/level/ArrowBlockView.hx` — `advance` | Authored animation | Advances the animated arrow-block artwork. |
| `pr2/level/LevelRenderer.hx` — `drawBlockBatch`, `drawArtBatch` | Loading work | Incrementally constructs block and art display batches. |
| `pr2/level/LevelRenderer.hx` — `onBlockBounceFrame`, `onWaterRippleFrame`, dynamic arrow handlers | Authored animation | Advances per-block bounce, ripple, and arrow visual timelines. |
| `pr2/level/LevelArtRenderCoordinator.hx` — `drawBatch`, `onRasterAttachFrame` | Loading work | Builds art batches incrementally and attaches completed rasters on a later frame. |
| `pr2/character/CharacterView.hx` — `onIdleTick` | Authored animation | Auto-advances character/hat/item animation when no external owner drives it. |
| `pr2/gameplay/Countdown.hx` — `onEnterFrame` | Simulation + authored animation | Advances countdown art and fires the gameplay start transition at an authored frame. |
| `pr2/gameplay/EggView.hx` — `advance` | Authored animation | Advances the egg visual timeline. |
| `pr2/gameplay/ItemDisplay.hx` — `advanceItemArt` | Authored animation | Advances held-item/HUD item artwork. |
| `pr2/gameplay/HappyHour.hx` — `onFrame` | Authored animation | Advances the Happy Hour HUD timeline and completion/removal. |
| `pr2/gameplay/DrawingInfo.hx` — `animateDrawingLabels` | Authored animation + simulation-derived HUD timing | Advances drawing-status labels while displaying elapsed 30 Hz course frames. |
| `pr2/gameplay/CourseTimer.hx` — `go` | UI timing | Advances the timer's frame-based appear/disappear animation; whole-second course time uses a separate timer. |
| `pr2/gameplay/PrizePopupView.hx` — `advanceOverlay` | UI timing + authored animation | Advances prize overlay frames and its completion lifecycle. |
| `pr2/gameplay/ExpGain.hx` — `go` | UI timing | Advances the finished-page experience tween and removal. |
| `pr2/gameplay/QuitButton.hx` — `animateGlow` | UI timing + authored animation | Advances the quit-button hover glow timeline. |
| `pr2/ui/GpNotification.hx` — `advanceFrame` | UI timing + authored animation | Advances the GP notification entrance, hold, exit, and removal frames. |
| `pr2/ui/view/LoadingView.hx` — `onFrame` | UI timing + authored animation | Advances spinner keys and loading-label punctuation. |
| `pr2/ui/view/NativePopupView.hx` — `fadeIn`, `fadeOut` | UI timing | Advances popup alpha and dispatches loaded/removed lifecycle events. |
| `pr2/lobby/dialogs/Popup.hx` — `fadeIn`, `fadeOut` | UI timing | Advances lobby popup alpha and loaded/removed lifecycle events. |
| `pr2/page/LoginFlashPopup.hx` — `fadeIn`, `fadeOut` | UI timing | Advances login error popup alpha and removal. |
| `pr2/page/LoginBackground.hx` — `onEnterFrame` | Authored animation | Advances the login background timeline. |
| `pr2/lobby/dialogs/ProgressBar.hx` — `update` | UI timing + presentation | Eases displayed fill width toward its target. |
| `pr2/ui/CustomScrollBar.hx` — `scroll` | UI timing + interaction | Repeats held scrollbar movement once per frame. |
| `pr2/audio/MenuMusic.hx` — `crossfadeTick`, `volumeFadeTick` | UI timing | Advances menu crossfade and volume ramps. |
| `pr2/lobby/account/CursorEyedropper.hx` — `maybeUpdate` | Presentation + interaction | Polls the current pointer/display stack and samples the visible pixel color. |
| `pr2/levelEditor/LevelEditor.hx` — `keyScroll` | UI timing + interaction | Applies held-key acceleration, friction, and editor camera movement. |
| `pr2/levelEditor/EditorGraphicCursor.hx` — `updateObjectLayerScale` | Presentation | Synchronizes the cursor scale with the current object-layer transform. |
| `pr2/levelEditor/TestCoursePage.hx` — `focusStageEveryFrame` | UI interaction | Reasserts stage focus while the editor test course is active. |
| `pr2/page/CampaignTestScreen.hx` — `onHarnessFrame` | Diagnostics | Publishes harness status and display/physics trace information. |
| `pr2/page/CharacterPartCachePreview.hx` — `animateCharacters` | Diagnostics + presentation preview | Drives a high-rate cache comparison preview under its explicit 120 FPS stage override. |

## Tests And Harnesses That Drive `ENTER_FRAME`

These 26 files dispatch synthetic frame events or assert listener ownership.
They are not production clock owners, but their helpers must be taught whether
they are advancing a simulation tick, a presentation frame, or both before
production callbacks are migrated.

| Test/harness file | Current purpose |
| --- | --- |
| `pr2/character/CharacterBaseTest.hx` | Recovery, removal, jet, and character animation lifecycles |
| `pr2/character/CharacterViewTest.hx` | Idle character animation |
| `pr2/character/LocalCharacterTest.hx` | Character effects and frame-duration calculations |
| `pr2/character/ParticleEmitterTest.hx` | Particle and arrow/star lifecycles |
| `pr2/character/RemoteCharacterConsumeTest.hx` | Remote consumption and nested arrow timeline |
| `pr2/effects/MineAppearTest.hx` | Mine appearance lifetime |
| `pr2/effects/PhysicsEffectTest.hx` | Physics-effect activation and teardown |
| `pr2/effects/PixelEffect1Test.hx` | Segment-pixel motion and cleanup |
| `pr2/effects/ShotEffectTest.hx` | Shot travel/lifetime and listener cleanup |
| `pr2/effects/SlashTest.hx` | Slash and mine-explosion timelines |
| `pr2/effects/TeleportPopTest.hx` | Teleport-pop lifetime |
| `pr2/gameplay/CharacterLifecycleTest.hx` | Course, character, effects, snake, rotation, and timeline integration |
| `pr2/gameplay/CourseTimerTest.hx` | Course-timer appear/disappear animation |
| `pr2/gameplay/DrawingInfoTest.hx` | Drawing-label animation |
| `pr2/gameplay/FinishedPageTest.hx` | Experience-gain tween |
| `pr2/gameplay/GameShellMountTest.hx` | Course/frame integration and teardown |
| `pr2/gameplay/MultiplayerRaceStage.hx` | Multiplayer debris-frame harness |
| `pr2/level/LevelRendererTest.hx` | Incremental drawing and block/effect animation lifecycles |
| `pr2/lobby/ColorPickerTest.hx` | Eyedropper per-frame sampling |
| `pr2/lobby/LobbyServicesTest.hx` | Editor scrolling and popup/listing timelines |
| `pr2/lobby/LobbyShellParityTest.hx` | Lobby glow timeline and teardown |
| `pr2/lobby/ProgressBarTest.hx` | Progress interpolation and listener teardown |
| `pr2/page/EditorSettingsTest.hx` | Editor cursor transform synchronization |
| `pr2/page/IntroPageTest.hx` | Intro authored timeline |
| `pr2/ui/GpNotificationTest.hx` | GP notification authored timeline |
| `pr2/ui/NativePresentationFoundationTest.hx` | Native popup fade lifecycles |

## Migration Constraints Revealed By The Inventory

- The stage rate is global. Enabling 60 FPS for a course also affects every
  attached UI, audio, loading, editor, diagnostic, and character listener.
- `Course`, `RemoteCharacter`, `ShotEffect`, `Countdown`, and `LevelRenderer`
  currently mix classifications inside one owner; they require deliberate
  splitting rather than a blanket “skip every other callback.”
- Loading work can remain once per 30 Hz tick initially. Moving it to spare
  presentation frames would change loading order and needs separate evidence.
- Pointer sampling and disposable transform synchronization are the only clear
  existing candidates for true presentation-rate callbacks.
- The 120 FPS character-cache preview is a diagnostic exception and must not
  become an accidental second simulation clock.
- Tests currently equate one synthetic `ENTER_FRAME` with one logical tick.
  Later clock work needs explicit test helpers so this assumption cannot hide a
  doubled gameplay rate.

The inventory can be reproduced with these read-only searches:

```sh
rg -n "SIMULATION_FRAME_RATE|PRESENTATION_FRAME_RATE|stage\.frameRate|Event\.ENTER_FRAME" haxe/src haxe/test project.xml
rg -l "Event\.ENTER_FRAME" haxe/src --glob '*.hx'
rg -l "Event\.ENTER_FRAME" haxe/test --glob '*.hx'
```
