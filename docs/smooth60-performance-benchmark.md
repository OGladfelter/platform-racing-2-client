# Smooth60 Performance Benchmark

Run:

```text
python3 tools/openfl_driver.py smooth60-benchmark
```

The matrix uses the production HTML5 course at `smooth60=1`. Each result
contains five complete racing-phase one-second windows. The lower-powered
device proxy uses Chrome's 4× CPU throttle. Frame times come from the OpenFL
stage's `enterFrame` callback; memory records heap before the window, observed
peak, heap after forced GC, and reclaimed bytes. The complete machine-readable
report is written to `test/output/smooth60-benchmark.json`.

| Device profile | Scene | Presented FPS | Simulation Hz | Frame p95 | Frame p99 | Peak heap | GC reclaimed |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Desktop | Small | 60.2 | 30.0 | 17.3 ms | 17.6 ms | 18.9 MiB | 6.3 MiB |
| Desktop | Large | 60.0 | 30.0 | 17.4 ms | 17.6 ms | 25.7 MiB | 12.3 MiB |
| Desktop | Art-heavy | 60.2 | 30.0 | 17.6 ms | 17.8 ms | 27.3 MiB | 14.3 MiB |
| Desktop | Multiplayer | 60.4 | 30.2 | 17.7 ms | 17.9 ms | 33.1 MiB | 19.2 MiB |
| 4× CPU throttle | Small | 60.0 | 30.0 | 17.8 ms | 18.3 ms | 27.0 MiB | 14.0 MiB |
| 4× CPU throttle | Large | 60.0 | 30.0 | 17.5 ms | 18.0 ms | 36.4 MiB | 14.9 MiB |
| 4× CPU throttle | Art-heavy | 60.0 | 30.0 | 17.6 ms | 18.0 ms | 27.7 MiB | 14.6 MiB |
| 4× CPU throttle | Multiplayer | 60.4 | 30.2 | 17.6 ms | 18.0 ms | 31.8 MiB | 18.0 MiB |

Both profiles sustained the requested presentation/simulation cadence in all
four scenes. Every benchmark window is checked for a 2:1 presentation/simulation
cadence and an effective target of 60; a mode change or simulation rate above
the protected range fails the run.
