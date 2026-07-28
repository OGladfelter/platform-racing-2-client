# Legacy Smooth60 Alias

The HTML5 client now exposes four selectable frame strategies. See
[frame-strategies.md](frame-strategies.md) for their current behavior.
`smooth60=1` remains as a compatibility alias for
`frame_strategy=60smooth`.

## Enable it

Add the exact query parameter `smooth60=1` to the client URL:

```text
https://example.invalid/?smooth60=1
```

If the URL already has a query string, append `&smooth60=1`. Missing, empty,
`0`, `true`, and other values leave the feature disabled. The setting is read
from the current URL only: it is not saved, and a navigation without the
parameter returns to the default 30 FPS presentation. Native builds currently
ignore the parameter.

The alias remains default-off. Removing `smooth60=1` restores the default
`30smooth` behavior and Flash timing unless an explicit `frame_strategy` is
present.

## What changes

With the alias active, HTML5 requests a nominal 60 FPS presentation rate and
strictly alternates simulation and visual frames. Lime treats 60 as unlimited,
so the client also applies its elapsed-time 60 Hz limiter. On the extra frame,
the local character predicts half of its authoritative post-step velocity from
its current authoritative position. This lets resolved wall, ceiling, floor,
and teleport motion continue in the direction physics selected without carrying
a pre-contact or source-to-destination movement delta forward. Guarded
previous/current pose extrapolation remains in use for remote characters,
camera/course transforms, course rotation, and supported moving effects.

There is deliberately no low-frame-rate physics safeguard in this strategy. A
browser delivering fewer than 60 accepted frames per second runs fewer than 30
simulation ticks per second.

Character animation timelines still advance at 30 Hz. This experiment smooths
world-space motion; it does not synthesize blended body-art frames.

## Authoritative 30 Hz guarantee

Physics, collision detection, input consumption, animation state, timers,
items, blocks, effects, finish handling, remote-update consumption, and network
emission run only on simulation ticks. Presented coordinates and rotations are
applied to display objects as temporary offsets and are never copied back into
game state.

The deterministic twin replay compares every `LocalPlayerState` and the complete
multiplayer command stream with the experiment off and on. Both must remain
identical after every simulation tick.

## Presentation resets

Local-character x/y prediction is not suppressed for collisions, landings,
velocity reversals, teleports, or large coordinate changes. Its prediction is
anchored at the current authoritative position, so a teleport continues from
the destination and resolved collision velocity points along or away from the
contact surface.

Presentation state is still reset when its owning display lifecycle changes,
including local-character replacement, course teardown, visibility/removal
changes, spectate-target changes, and editor scrolling. Character rotation also
guards committed course-rotation and layer changes because it uses pose-delta
rather than angular-velocity prediction. Minimap dots intentionally remain on
authoritative 30 Hz positions.

## Diagnostics

HTML5 diagnostics include:

- `data-pr2-smooth60="1"` — the experiment was requested;
- `data-pr2-frame-strategy="60smooth"` — the resolved strategy;
- `data-pr2-presentation-fps-target="60"` — the requested presentation target.

## Release status

The state/packet equivalence checks, visual replay set, and current performance
thresholds pass, but the feature remains opt-in. Enabling it by default is not
part of this experiment's acceptance. Any future default-on proposal must be a
separate parity and product decision, with its own target-device evidence and
rollout plan.

## Verification

- `python3 tools/openfl_driver.py smooth60-flag`
- `python3 tools/openfl_driver.py smooth60-stability`
- `python3 tools/openfl_driver.py smooth60-replays`
- `python3 tools/openfl_driver.py smooth60-benchmark`

See [smooth60-visual-replays.md](smooth60-visual-replays.md) and
[smooth60-performance-benchmark.md](smooth60-performance-benchmark.md) for the
recorded visual and performance evidence.
