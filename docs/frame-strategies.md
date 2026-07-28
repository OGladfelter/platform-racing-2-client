# HTML5 Frame Strategies

The HTML5 client accepts a frame strategy through the current page URL:

```text
?frame_strategy=30smooth
?frame_strategy=30fixed
?frame_strategy=60smooth
?frame_strategy=60fixed
```

The value is not saved. Invalid or missing values select `30smooth`.

| Strategy | Lime stage request | Simulation policy | Intermediate world pose |
| --- | ---: | --- | --- |
| `30smooth` | 30 FPS | One physics tick per accepted frame | No |
| `30fixed` | 60 FPS | Elapsed-time 30 Hz; zero or multiple ticks per accepted frame | No |
| `60smooth` | 60 FPS | Strictly alternate physics and visual frames | Yes |
| `60fixed` | 60 FPS | Elapsed-time 30 Hz; zero or multiple ticks per accepted frame | Yes |

Lime 8.3.2 treats a stage rate of 60 as unlimited and consumes every browser
`requestAnimationFrame` callback. For every strategy that requests 60, the
client also installs an elapsed-time 60 Hz limiter in Lime's HTML5 backend.
Thus a 120 or 144 Hz display cannot accelerate `60smooth` physics.

`60smooth` deliberately has no low-frame-rate protection. If the browser only
delivers 50 accepted frames per second, strict alternation produces about 25
physics ticks per second. The fixed strategies instead preserve 30 physics
ticks per active wall-clock second by skipping intermediate visual work or
running multiple complete physics passes before the next render.

Focus loss and page deactivation reset the fixed-time origin. Time spent in a
background or inactive page is not replayed as catch-up physics.

## Legacy flag

`smooth60=1` remains supported and is an alias for
`frame_strategy=60smooth`. A valid `frame_strategy` takes precedence when both
parameters are present.

## Diagnostics

HTML5 publishes the resolved configuration and measured rates through body
attributes:

- `data-pr2-frame-strategy`
- `data-pr2-presentation-fps-target`
- `data-pr2-presentation-fps`
- `data-pr2-simulation-fps`

The existing `data-pr2-smooth60` attribute remains available for compatibility.
