# Smooth 60 Race-World Motion Inventory

This inventory assigns a presentation policy to every moving world-space
display owner mounted by `Course`, `LevelRenderer`, character/effect classes,
and their race-only helpers. HUD and lobby timelines are excluded because they
are screen-space and already remain on 30 Hz simulation ticks.

Policies:

- **Extrapolate**: render `current + 0.5 × (current - previous)` on the extra
  frame, with lifecycle/contact/discontinuity guards.
- **Interpolate**: evaluate an already continuous authored tween between its two
  30 Hz values without advancing its authoritative frame or lifetime.
- **Intentional snap/hold**: retain the latest authoritative value. Discrete
  state changes, visibility, layer changes, and authored animation frames do
  not synthesize intermediate states.

## Camera, World, And Characters

| Visible owner | Source owner | Policy | Boundary / rationale | Status |
| --- | --- | --- | --- | --- |
| Local character feet position and orientation | `Course`, `LocalCharacter`, `PresentationPose` | Extrapolate | Inner `CharacterView` only; x/y predicts from the authoritative post-step position and velocity through contacts and teleports. Rotation retains pose-delta lifecycle guards. | Implemented |
| Local character body/hat/item animation pose | `CharacterView` | Intentional snap/hold | Authored timeline remains exactly 30 Hz; transform the latest pose only. | Implemented |
| Remote character position and orientation | `RemoteCharacter` | Extrapolate | Guarded extrapolation preserves queue/catch-up semantics; target/layer/exact-position discontinuities snap. | Implemented |
| Remote character body/hat/item animation pose | `CharacterView` through `RemoteCharacter` | Intentional snap/hold | Never consume an additional queued update or animation frame. | Implemented |
| Follow/spectate camera | `CameraFollow`, `CameraPresentationPose`, `Course` | Extrapolate | Disposable transform follows the same phase and snap boundaries as its target. | Implemented |
| Base world, character, effect, and art-plane camera translation | `LevelRenderer` | Extrapolate | Fractional matrix update only; authoritative integer culling remains at 30 Hz. | Implemented |
| In-progress rotate-block world angle | `LocalPlayerController`, `LevelRenderer` | Extrapolate | Tween angle is disposable; collision axes and 90-degree commit remain authoritative. | Implemented |
| Front/back character layer membership | `Course.moveCharacterToLayer` | Intentional snap/hold | Local and remote water-layer changes are discrete, invalidate the pose, and reparent one existing character instance rather than duplicating it. | Implemented and focused-tested |
| Player and remote minimap dots | `MiniMapDot`, `Course`, `RemoteCharacter` | Intentional snap/hold | Keep informational dots on exact 30 Hz authoritative coordinates; no predicted collision/player location. The minimap rotates only on committed course rotations, including while spectating. | Decision implemented and focused-tested |

## Gameplay-Owned Moving Objects

| Visible owner | Source owner | Policy | Boundary / rationale | Status |
| --- | --- | --- | --- | --- |
| Snake moving controller/head anchor and placed trail segments | `SnakeManager` | Extrapolate moving anchor; hold placed tiles | Predict the local continuous controller by a half-step without changing its authoritative camera target. Trail blocks are discrete occupied tiles, so they hold; turns, spawn, removal, and network tile steps snap. | Implemented and focused-tested |
| Egg projectiles and attack visuals | `EggRound`, `EggView` | Extrapolate | Predict position/rotation only; spawn, landing, reversal, wrap, hit, pickup, and removal stay discrete. | Implemented and focused-tested |
| Loose hats | `HatEffect`, `Course.stepLooseHats` | Extrapolate | Predict falling/bouncing position; landing, wall contact, pickup, return-to-start, equip, and removal snap. | Implemented and focused-tested |
| Moving-block display positions | `CourseBlockVisualController.syncMoveBlockDisplays` | Extrapolate | Predict continuous block offset only; authoritative block grid and collisions stay at 30 Hz. | Pending |
| Block bounce displacement | `LevelRenderer.onBlockBounceFrame` | Interpolate | It is an existing continuous visual tween; block state/collision never follows the presented displacement. | Pending |
| Water ripple displacement/scale | `LevelRenderer.onWaterRippleFrame` | Interpolate | Evaluate between authored 30 Hz ripple keys without advancing the ripple lifecycle. | Pending |
| Animated arrow-block artwork | `ArrowBlockView`, dynamic arrow completion handlers | Intentional snap/hold | Authored frames and completion callbacks remain at 30 Hz. | Implemented (30 Hz hold) |
| Block disappearance, pickup, activation, tint, ice, and visibility | `CourseBlockVisualController`, `LevelRenderer` | Intentional snap/hold | Instant gameplay state must never be predicted. | Implemented (30 Hz discrete) |

## Particles, Projectiles, And Effects

| Visible owner | Source owner | Policy | Boundary / rationale | Status |
| --- | --- | --- | --- | --- |
| Character physics particles | `PhysicsParticle` and emitters | Extrapolate | Predict position, rotation, and scale only; spawning, lifetime, alpha, and removal remain 30 Hz. | Implemented and focused-tested |
| Block debris pieces | `BlockPiece` | Extrapolate | Predict position/rotation only; gravity/friction integration, fade, and lifetime remain authoritative. | Implemented and focused-tested |
| Colliding physics effects | `PhysicsEffect` | Extrapolate | Predict the last safe movement delta; collision/activation/removal snap. | Pending |
| Shot/projectile effects | `ShotEffect` | Extrapolate | Predict travel transform only; direction changes, collision, damage, timeline, and removal snap/remain 30 Hz. | Implemented and focused-tested |
| Follow/fade effects | `FollowFadeEffect` | Extrapolate | Consume the owner character’s exact disposable presentation offset, including its snap guards; alpha/lifetime remain 30 Hz. | Implemented and focused-tested |
| Segment pixels and glints | `SegPixel` | Extrapolate | Predict continuous positional easing; target change, glint phase, and removal snap/hold. | Pending |
| Arrow and star effect motion | `ArrowEffect`, `StarEffect` | Interpolate | Their transforms come from authored continuous keys; frame/lifetime advancement stays 30 Hz. | Pending |
| Laser impact artwork | `LaserShotView` | Intentional snap/hold | Stationary world anchor with authored 30 Hz frames. | Implemented (30 Hz hold) |
| Mine appearance/explosion artwork | `MineAppear`, `MineExplosion`, `NativeEffectAnimation` | Intentional snap/hold | Stationary world anchor; completion, damage, and authored frames remain 30 Hz. | Implemented (30 Hz hold) |
| Teleport pops | `TeleportPop` | Intentional snap/hold | Spawn at exact endpoints and hold the latest authored frame; never move a pop between endpoints. | Implemented (30 Hz hold) |
| Generic timed effect removal | `Effect` | Intentional snap/hold | Visibility/removal is a discrete 30 Hz lifecycle. | Implemented (30 Hz hold) |

## Cross-Check

The inventory was cross-checked against:

- all production race-related `ENTER_FRAME` owners in
  `docs/smooth60-frame-rate-inventory.md`;
- every world-space collection stepped by `Course.onEnterFrame`;
- every `LevelRenderer` transform/animation owner;
- local and remote character display ownership; and
- effect classes mounted into the block, character, or effect world planes.

Emission itself is discrete: particle/effect creation, damage, pickup,
visibility, parenting, and teardown always occur on simulation ticks even when
the spawned object later receives a disposable presentation transform.

## Discrete-Transition Invariant

Presentation-only frames may write only disposable transforms: character inner
offsets, effect/projectile display transforms, camera matrices, and the
in-progress course display angle. They must not collect pickups, change held
items or ammo, choose gameplay/animation states, change visibility or parenting,
activate/remove blocks, apply damage, or advance an authored block tween.

Focused clock-phase coverage verifies that a loose hat touching the player stays
visible and uncollected on the intervening presentation frame, item and character
state stay unchanged, and a water ripple holds its latest 30 Hz alpha. The next
simulation phase performs the pickup and advances the existing Flash ripple
exactly once.

## Teardown Invariant

Simulation and presentation work share one guarded frame callback per owner, so
teardown must remove that callback rather than manage two independent lifetimes.
Course removal clears local, camera, and remote pose samples and explicitly
disposes remote characters, physics particles, block pieces, shots, and
follow/fade effects before their display layers are detached. Focused teardown
coverage asserts that all of those callbacks are gone and their presentation
owners are unparented after a course is removed.

## Steady-State Allocation Invariant

Pose objects and owner arrays are created only when a course, character, or
effect is created. Presentation frames walk stable arrays or display children
by index; they do not build map iterators or temporary child lists. The renderer
also reuses dedicated block, character, effect, art-layer, and course-tween
matrices instead of constructing matrices for every extra frame.

`tools/check_presentation_allocations.py` guards the 21 steady-state
presentation methods against object construction, array comprehensions,
collection copies/concatenation, and map/iterator creation. The check runs in
every focused deterministic test invocation.

## Cache-Preservation Invariant

Presentation frames transform existing outer containers only. They do not
replace cached character-part children, reparent static level art, toggle the
renderer’s art-cache policy, or alter `cacheAsBitmap`/cache-matrix settings.
Focused coverage applies fractional camera and course transforms plus a local
character half-step and verifies that static artwork, text, and a flattened
character subtree retain the same parents, children, cache flags, scale, and
registration.
