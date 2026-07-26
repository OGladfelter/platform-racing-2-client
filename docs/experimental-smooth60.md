# Experimental 60 FPS Presentation

The HTML5 client has an opt-in presentation experiment that draws an additional
visual frame between the game's authoritative 30 Hz simulation ticks.

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

The experiment remains default-off. Removing `smooth60=1` restores the existing
30 FPS behavior and Flash timing.

## What changes

With the experiment active, HTML5 requests a 60 FPS presentation rate while the
simulation stays at 30 Hz. On the extra frame, disposable presentation poses
predict half of the most recent authoritative movement delta. This covers the
local character, guarded remote-character motion, camera/course transforms,
course rotation, and supported moving effects.

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

## Deliberate snaps

Prediction is intentionally suppressed when recent motion is not a safe estimate
of the next half-step. A frame may therefore snap to the authoritative pose for:

- spawn, respawn, finish, removal, or course teardown;
- teleports, warps, level loads, and unusually large position corrections;
- landing, wall or ceiling contact, velocity reversal, or stopped motion;
- character layer/water transitions and visibility changes;
- spectate-target changes, committed course rotations, and editor scrolling;
- discrete block changes, pickups, and other instantaneous state transitions.

These snaps favor correct placement over carrying stale motion across a
discontinuity. Minimap dots intentionally remain on authoritative 30 Hz
positions.

## Performance fallback status

Automatic performance fallback is currently disabled so `smooth60=1` is a
definitive testing control. Once enabled, it requests a 60 FPS presentation
target for the entire page session even when the browser cannot sustain that
rate. Physics and networking remain at 30 Hz.

The fallback policy and diagnostics remain available for a later re-enable.
While it is disabled, HTML5 diagnostics remain:

- `data-pr2-smooth60="1"` — the experiment was requested;
- `data-pr2-smooth60-fallback="0"` — no automatic downgrade occurred;
- `data-pr2-presentation-fps-target="60"` — the effective target remains 60.

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
