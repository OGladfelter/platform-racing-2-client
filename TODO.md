# Platform Racing 2 Haxe/OpenFL Port TODO

This file tracks only unfinished work. The target is a 1:1 port of the original
Flash client, not a compatible remake: behavior, protocol,
screen flow, layout, animation, sound, and failure states should match the AS3
and XFL sources. Completed work belongs in git history and `README.md`.

#### De-Flash The Haxe/OpenFL Architecture

The production presentation layer has been migrated away from the Animate/XFL
compatibility runtime, but removal of the runtime did not prove visual or
behavioral parity. The current phase is a systematic audit of every migrated
production root against `flash/**/*.as` and
`flash/platform-racing-2-xfl/`. Treat the legacy client as the specification,
not merely as an implementation reference.

Do not mark an audit complete because a native view exists, a linkage is absent,
or the happy path works. Completion requires evidence for the observable parts
that apply: exact layout and registration points, artwork and colors, masks and
filters, layer order, text/font metrics, mouse and keyboard interaction, focus,
disabled/loading/error states, animation frames and timing, sound cues, modal
stacking and fades, teardown, and the resulting navigation or network action.
Add focused deterministic tests plus an HTML5 screenshot or replay sequence that
compares the migrated flow with the AS3/XFL reference.

The migration replaced reflective Flash timeline access with concrete, typed
Haxe views. The historical pattern loaded an authored symbol and discovered its
controls by string name:

```haxe
art = PR2MovieClip.fromLinkage("SomePopupGraphic");
nameBox = LobbyArt.text(art, "nameBox");
button = DisplayUtil.findByName(art, "ok_bt");
```

The current pattern is an ordinary Haxe view whose structure is explicit and
checked by the compiler:

```haxe
class ConfirmDialogView extends Sprite {
	public final message:TextField;
	public final confirmButton:GameButton;
	public final cancelButton:GameButton;

	public function new() {
		super();
		// Explicit construction and layout.
	}
}
```

The original change was intended to affect only code structure and the asset
pipeline. Layout, artwork, animation, sound, timing, behavior, and user flows
must still match. `docs/deflash-symbol-inventory.md` records the generated
production boundary, while `tools/deflash-boundary-allowlist.json` preserves the
historical maximum legacy dependencies for regression detection. `./test.sh`
must continue rejecting new production `PR2MovieClip`, `Fl*`, or generated-XFL
timeline dependencies while the audit uses archival tooling outside production.

Campaign payload reference:

- Campaign lists are fetched from `pr2hub.com/files/lists/campaign/{page}` and
  validated with `MD5(ret.substr(10, len - 53) + "984cn98c54$")`.
- Level data is fetched from `pr2hub.com/levels/{id}.txt?version={v}` and
  validated with `MD5(version + id + levelData + "0kg4%dsw")`.
- The decoded `levelData` is `&`-joined URL-encoded vars passed through
  `validateSaveString`; `data` is backtick-delimited with read mode in
  `data[0]` and the relative-coordinate block string in `data[1]`.

##### Audit Migrated Production Features

Audit the shared primitives first because a single mismatch can affect many
roots. Each item needs comparison evidence, not only a unit test of the native
API.

###### Production root parity audits

This is the former migration boundary from
`docs/deflash-symbol-inventory.md`. Each unchecked item is a new audit of one
unique migrated root, including every production call site. Complete an item
only after its native replacement has been compared with the AS3 owner and XFL
symbol and the applicable visual, behavioral, timing, sound, failure, and
teardown paths are covered by focused tests and screenshot/replay evidence.

##### Compatibility-Runtime Removal Audits

- [ ] Re-run representative end-to-end flows against both archival Flash and the
  native client before declaring the de-flash goal complete; dependency removal
  alone is not an acceptance criterion.
  - Audit note: Focused deterministic tests cover native behavior only; there is no current
    dual-client evidence bundle for intros, login, lobby, gameplay/effects, editor, and
    character flows, so retain this final acceptance audit. The machine-checked matrix in
    `docs/deflash-dual-client-acceptance.json` records the missing shared replays/evidence and
    the current macOS Flash synthetic-click blocker without treating native-only proof as parity.


#### Build Size And HTML5 Payload

- Investigate removing unused generated asset metadata from the final JS.
  `AssetCatalog.media()` and `AssetCatalog.linkageClasses()` do not appear to
  have runtime callers, but their bitmap/sound/linkage literals still survive
  into `PlatformRacing2.js`.
- Investigate dropping `assets/fonts/DejaVuSans-BoldOblique.ttf`. Current
  generated text faces include Verdana, Verdana-Bold, and Verdana-Italic, but no
  Verdana-BoldItalic; the file is about 632 KB raw / 329 KB gzipped.
- Investigate making audio assets non-preloaded. The audio files are needed at
  runtime, but the broad `assets/` include appears to preload about 1.5 MB raw /
  1.28 MB gzipped of sounds up front.
- Revisit lossless SVG minification if the asset payload grows. A conservative
  SVGO 4.0.1 trial across all 2,130 files reduced the SVG tree from 5,512,063 to
  5,061,915 bytes: about 450 KB raw (8.17%), but only 33 KB gzipped (1.76%). The
  ten largest SVGs produced byte-identical 1100-pixel Inkscape renders. Before
  adopting the pass, add OpenFL render coverage and fix the XML-invalid `--`
  inside the comment in `art/svg/login/login_page_no_logo.svg`.

#### Experimental 60 FPS Presentation With 30 FPS Simulation

Add an opt-in `?smooth60=1` HTML5 experiment that draws motion at 60 FPS while
keeping gameplay, input consumption, animation timelines, frame counters,
network emission, and every other authoritative system at exactly 30 ticks per
second. The flag must default off and must not persist to another session. With
the flag absent, the client must retain its current 30 FPS behavior and Flash
parity.

Treat presentation positions as disposable output. Never feed an interpolated
or extrapolated coordinate, velocity, rotation, layer, or camera value back into
physics, collision detection, block activation, item logic, networking, replay
state, or the next simulation tick. For the same initial state and input stream,
the authoritative state and emitted packets after simulation tick N must be
identical with `smooth60` enabled and disabled.

##### Establish The Frame-Rate Boundary

- [ ] Inventory every use of `Constants.FRAME_RATE`, `stage.frameRate`, and
  `Event.ENTER_FRAME`; classify each as simulation, presentation, authored
  animation, UI timing, loading work, or diagnostics before changing timing.
- [ ] Split the current shared frame-rate constant into explicit 30 Hz
  simulation and configurable presentation rates without changing physics
  formulas or frame-duration constants.
- [ ] Parse `smooth60=1` through the normal query-parameter path and expose one
  immutable runtime setting; missing, empty, `0`, and invalid values must leave
  the feature disabled.
- [ ] Keep the project/window bootstrap at 30 FPS, then request a 60 FPS stage
  only after startup has resolved that the HTML5 experiment is enabled.
- [ ] Make native targets ignore `smooth60` until the presentation clock and
  performance have been validated separately on those targets.
- [ ] Update `SWFStats` so its target is the configured presentation rate and it
  cannot force a flagged 60 FPS stage back to 30 FPS.
- [ ] Add separate diagnostic counters for simulation ticks and presented
  frames so a reported 60 FPS cannot hide doubled or slowed physics.
- [ ] Publish the flag state and both measured rates through the existing HTML5
  debug-signal mechanism for deterministic browser-driver assertions.

##### Introduce A 30 Hz Simulation Clock

- [ ] Add one application-owned frame clock, installed before production
  screens, that identifies 30 Hz simulation ticks and intervening presentation
  frames when the stage runs at 60 FPS.
- [ ] Make every stage frame a simulation tick when `smooth60` is disabled so
  the default path retains the current event ordering and behavior.
- [ ] Define and test the clock's initial phase so enabling the experiment does
  not run, skip, or duplicate a simulation tick during startup.
- [ ] Reset presentation phase safely across deactivate/reactivate, focus loss,
  screen replacement, and course teardown without synthesizing gameplay ticks.
- [ ] Move `Course` physics, input copying, items, block synchronization, frame
  counters, finish handling, and network emission onto simulation ticks only.
- [ ] Move remote-character queue consumption and block-touch probes onto
  simulation ticks only; 60 FPS presentation must not consume server updates
  twice as fast.
- [ ] Move character recovery, invincibility flashing, jet animation, and
  removal/fade lifecycles onto simulation ticks only.
- [ ] Move gameplay effects, particles, projectiles, eggs, loose hats, snakes,
  moving-block visuals, and course-rotation progression onto simulation ticks
  only.
- [ ] Move authored timeline clips, HUD animations, UI frame counters, loading
  work, lobby animation, and editor frame handlers onto simulation ticks unless
  a handler is explicitly presentation-only.
- [ ] Add a source-level regression check or narrow allowlist so a future
  time-dependent `ENTER_FRAME` handler cannot silently begin running at 60 Hz.
- [ ] Add clock tests covering long runs, phase resets, flagged/unflagged mode,
  and transitions back to a 30 FPS presentation rate.

##### Build The Local-Player Visual Prototype

- [ ] Introduce a small presentation-pose type containing previous/current
  position, rotation, facing, layer, and a discontinuity marker.
- [ ] Capture the previous authoritative pose immediately before a simulation
  tick and the new authoritative pose immediately after it.
- [ ] Render the normal authoritative pose on simulation frames and, on the
  intervening frame, extrapolate `current + 0.5 * (current - previous)`.
- [ ] Apply the extrapolated offset to the inner character presentation rather
  than overwriting the authoritative `Character.x/y` read by gameplay systems.
- [ ] Keep character pose/timeline advancement at 30 Hz; do not attempt optical
  blending or synthesized in-between body-art frames in this experiment.
- [ ] Mark spawn, teleport, removal, finish, respawn, layer change, spectate
  change, committed course rotation, and unusually large movement as
  discontinuities that snap instead of extrapolating.
- [ ] Suppress unsafe prediction when a landing, wall/ceiling collision,
  velocity reversal, or other contact makes the previous movement delta an
  invalid estimate of the next half-step.
- [ ] Clear both pose samples whenever the course or local character is rebuilt
  so stale coordinates cannot produce a one-frame streak across the level.
- [ ] Add focused pose tests for constant motion, fractional/negative movement,
  stopped motion, direction reversal, and every snap condition.

##### Smooth The Camera And Course Together

- [ ] Separate the authoritative 30 Hz camera state from its disposable
  presentation transform.
- [ ] Extrapolate the camera from its last two authoritative positions on the
  same phase as the local player so player and background do not judder against
  one another.
- [ ] Split `LevelRenderer.setCameraOffset` so 60 Hz presentation updates can
  apply fractional transforms without rebuilding culling and art view windows.
- [ ] Keep block/art culling, visibility decisions, and raster-cache selection
  on authoritative simulation ticks using conservative integer bounds.
- [ ] Preserve fractional presentation camera coordinates instead of rounding
  away the half-frame movement.
- [ ] Interpolate or extrapolate the in-progress course-rotation presentation
  angle while keeping rotation state, collision axes, and rotation completion
  on 30 Hz simulation ticks.
- [ ] Snap camera and course presentation on teleports, spectate-target changes,
  rotation commits, manual editor scrolling, and level-load transitions.
- [ ] Verify spatial audio continues to use a deliberate camera coordinate and
  cannot affect authoritative state; choose logical or presented camera
  position consistently and cover it with a focused test.

##### Extend Presentation Coverage

- [ ] Give remote characters presentation poses without changing their existing
  30 Hz network catch-up algorithm or queued-update semantics.
- [ ] Compare delayed previous/current interpolation with guarded extrapolation
  for remote players and select the approach with the least visible correction;
  do not add latency to the local player as part of that choice.
- [ ] Smooth the spectated character and camera as one unit, including switches
  between local and remote targets.
- [ ] Inventory every moving world-space display object visible during a race
  and record whether it should extrapolate, interpolate, or intentionally snap.
- [ ] Add presentation poses for snake segments, egg projectiles, loose hats,
  physics particles, block pieces, shots, and follow/fade effects one subsystem
  at a time.
- [ ] Keep instantaneous block changes, pickups, state transitions, and
  visibility changes discrete unless the Flash behavior already contains a
  continuous visual tween.
- [ ] Decide whether minimap dots should remain authoritative at 30 Hz or use
  the same presentation pose as their characters, then test rotation and
  spectating in the chosen mode.
- [ ] Verify water/front/back character-layer changes cannot leave a smoothed
  character duplicated, missing, or on the wrong side of level art.
- [ ] Ensure removal and teardown unregister both simulation and presentation
  callbacks so changing screens does not retain pose objects or frame listeners.

##### Performance, Fallback, And Acceptance

- [ ] Make presentation-frame code allocation-free in steady state; reuse pose
  storage and avoid rebuilding matrices, maps, points, or child lists solely to
  draw an in-between frame.
- [ ] Confirm the extra frames do not invalidate static level-art, character,
  or flattened display-tree caches.
- [ ] Extend the FPS harness to assert approximately 60 presented frames and
  exactly 30 simulation ticks per second independently.
- [ ] Add a deterministic twin replay that runs identical inputs with
  `smooth60` off and on and compares every 30 Hz `LocalPlayerState`.
- [ ] Compare the complete emitted multiplayer command stream in that twin
  replay, including update cadence and payload values.
- [ ] Test frame-counted lifecycles at both presentation rates, including
  countdown, recovery, invincibility, fades, rotation, items, effects, finish,
  and out-of-time behavior.
- [ ] Add browser coverage proving the query flag is default-off, enables only
  for `smooth60=1`, requests the intended stage rate, and does not survive a
  navigation without the parameter.
- [ ] Capture side-by-side 30/60 replays for running, jumping, falling, landing,
  wall contact, teleporting, rotating, spectating, multiplayer correction, and
  a particle-heavy scene.
- [ ] Benchmark representative small, large, art-heavy, and multiplayer levels
  on desktop and a lower-powered browser device; record simulation rate,
  presentation rate, frame-time percentiles, and memory/GC behavior.
- [ ] Define a sustained-frame-time threshold for declaring 60 FPS presentation
  unsupported on the current device.
- [ ] Add a safe session-only fallback to 30 FPS presentation when that threshold
  is exceeded; rebasing the presentation clock must not skip or duplicate a
  simulation tick.
- [ ] Show the fallback state in diagnostics and keep `smooth60=1` in the URL so
  performance failures are distinguishable from an unrequested experiment.
- [ ] Run the focused runtime, gameplay, character, effects, network,
  level-rendering, and UI deterministic domains plus the HTML5 replay/performance
  cases; do not substitute a full-suite pass for targeted evidence.
- [ ] Document `?smooth60=1`, its experimental/default-off status, fallback
  behavior, known visual snap cases, and the guarantee that authoritative
  gameplay remains 30 Hz.
- [ ] Keep the experiment opt-in until the state/packet equivalence checks,
  visual replay set, and performance thresholds pass; make any later proposal
  to enable it by default a separate parity and product decision.

#### HTML5 Multiplayer Transport

- Replace the temporary hard-coded `wss://pr2hub.com/gameservers/{server_id}`
  browser routing hack with a configured, server-advertised WebSocket endpoint.
  `ServerInfo.websocketUrl()` currently discards the advertised address and port
  so the HTML5 client can connect through the PR2Hub relay.

#### Native Mobile Targets

- Add an explicit mobile build configuration for the native `ios` and `android`
  targets. Define `pr2_mobile_ui` when Lime's `mobile` condition is active, use
  the device's full resolution, force landscape orientation, and keep the
  existing desktop/HTML5 presentation unchanged.
- Replace the current fixed `550 x 400`, `NO_SCALE` behavior on mobile with a
  root viewport that:
  - lays out inside the iOS/Android safe area;
  - preserves a centered `550 x 400` logical game area without cropping;
  - uses the extra landscape width as control gutters where possible; and
  - falls back to translucent controls over the course on narrower displays.
- Add resize/orientation/lifecycle handling. Recompute the viewport when the
  usable bounds change and clear all held input when the app is deactivated,
  interrupted, backgrounded, or covered by a modal screen.
- Build an offline native mobile smoke-test route first. It must load a course,
  render all assets and HUD elements, play audio, and complete a race on real
  iOS and Android devices before native login/lobby work is considered stable.
- Validate the pinned hxcpp `v4.3.146` upgrade on physical Android devices,
  including an affected older device/architecture that would expose the hxcpp
  4.3.2 `__atomic_compare_exchange_4` startup failure. Pin and document the
  remaining known-working JDK, Android SDK, and NDK versions.
- Add target-specific app metadata and packaging: icons, launch screens, bundle
  identifiers, supported orientations, permissions, Android signing, iOS
  provisioning, and release build instructions.
- Audit native behavior for HTTP GET/POST requests, cookies and sessions,
  `SharedObject` persistence, saved accounts, dynamic audio loading, embedded
  fonts, soft-keyboard text entry, external links, and fatal-error reporting.

##### Native Multiplayer Transport

- Extract `LobbySocket`'s JS WebSocket implementation behind a shared transport
  interface so login, frame buffering, pinging, command dispatch, disconnects,
  and reconnection policy do not depend on a specific socket implementation.
- Implement the native transport with a direct TCP socket unless device testing
  reveals a material platform or TLS disadvantage. The multiplayer server
  supports direct socket connections as well as WebSockets, so prefer the direct
  connection to avoid adding a native WebSocket dependency.
- Run socket I/O away from the render thread, marshal received frames back to
  the OpenFL thread, preserve the protocol's `\x04` frame delimiter across
  partial reads, and make writes safe when lifecycle callbacks race a close.
- Verify native login, lobby reuse of the login connection, ping timing,
  clean/unclean disconnects, background/resume behavior, and reconnect failure
  states against a live server on both iOS and Android.
- Decide and document whether native release connections require encryption or
  another transport security layer. Do not silently send credentials over an
  untrusted plaintext TCP connection merely because direct sockets are easier.

##### Mobile Gameplay Controls

- Introduce a shared player-input aggregator instead of synthesizing keyboard
  events. Keyboard and touch sources should independently contribute to the
  existing `LocalPlayerInput` actions without changing character physics,
  item behavior, or network emission.
- Add a mobile-only six-button race overlay:
  - left side: move left, jump, and item;
  - right side: move right, jump, and item; and
  - duplicate jump/item buttons should support either hand and simultaneous
    presses without one button's release cancelling the other button's hold.
- Handle touch input explicitly with `TOUCH_BEGIN`, `TOUCH_MOVE`, `TOUCH_END`,
  and stable `touchPointID` ownership. Support sliding between controls and
  release touches that end outside their original button.
- Give controls large adjustable hit areas, clear pressed feedback, safe-area
  padding, and configurable size, opacity, handedness, and position. Ensure the
  overlay sits above the course/HUD but below modal and finished-race screens.
- Add deterministic tests for multi-finger input aggregation, duplicated
  jump/item holds, touch cancellation, focus loss, reversed controls, item
  press/release semantics, and course rotation.
- Add device tests for common play combinations, including run+jump, run+item,
  changing direction while jumping, and holding jetpack/item input.

##### Proper Mobile Lobby

- Run the completed mobile lobby through native login, soft-keyboard, safe-area,
  popup, race-return, and rotation tests on representative physical iOS and
  Android phones/tablets before release. Browser coverage is available with
  `?screen=lobby&mobile=1` (and `offlineLists=1` for deterministic level data).
