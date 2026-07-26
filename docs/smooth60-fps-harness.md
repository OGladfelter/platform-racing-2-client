# Smooth60 Independent FPS Harness

The application publishes paired one-second diagnostic samples:

- `data-pr2-presentation-frame-samples`
- `data-pr2-simulation-tick-samples`

`tools/openfl_driver.py ... fps` waits for application readiness, discards the
partial preload window, and validates the two streams independently. In
`smooth60=1` mode it also requires every paired sample to contain at least as
many presented frames as simulation ticks. At a steady 60 FPS the normal
cadence remains 2:1. The clock averages presentation cadence over five seconds
and targets half that rate, clamped to 27-30 physics ticks per second.
Visual-only callbacks are converted into simulation frames only when the
natural half-rate cadence would fall below 27 Hz. Without smooth mode, the two
counts must be identical.

Example:

```text
python3 tools/openfl_driver.py \
  --fps-duration 5 \
  --fps-target 60 \
  --fps-tolerance 8 \
  --simulation-fps-target 30 \
  --simulation-fps-tolerance 1 \
  --query "screen=intro&smooth60=1" \
  fps
```

Add `--uncapped-browser-refresh` to the command to disable Chromium's frame
limiter and vsync. This supplies callbacks faster than 60 Hz and verifies that
the application still emits approximately 60 presentation frames and 30
simulation ticks per second. It reproduces the high-refresh-display failure
mode without requiring a 120 Hz monitor.

The production HTML5 build produced presentation samples of
`60,60,60,61,61` and simulation samples of `30,30,30,30,31`; both independent
rate checks and every exact 2:1 cadence check passed. A separate longer run
encountered a one-second headless-browser stall (`48/24`) and correctly failed
both rate thresholds while preserving the exact cadence, demonstrating that a
reported 60 FPS can no longer conceal a slow simulation rate.
