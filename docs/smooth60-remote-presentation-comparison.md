# Smooth 60 Remote Presentation Strategy

The experiment uses guarded extrapolation for remote characters.

Delayed previous/current interpolation is stable, but it must render the
previous pose on each simulation frame and the midpoint on the extra frame.
That adds one 30 Hz tick (about 33 ms) of remote visual latency. If it instead
renders the current pose on the simulation frame, its midpoint moves backward
on the following presentation frame.

For constant movement `0 → 10 → 20`, the extra-frame candidates after `10` are:

| Strategy | Extra-frame position | Correction to next authoritative `20` |
| --- | ---: | ---: |
| Delayed midpoint | 5 | 15 |
| Guarded extrapolation | 15 | 5 |

Guarded extrapolation therefore preserves the newest queued/catch-up result and
reduces the next correction for ordinary motion. Discontinuities snap to the
current authoritative pose. This policy is remote-only; the local player keeps
its zero-added-latency authoritative simulation frames and disposable half-step
presentation frames.
