# Smooth60 Side-by-Side Replay Set

Run the browser capture with:

```text
python3 tools/openfl_driver.py smooth60-replays
```

The command boots the production HTML5 course harness once, waits for each
local race to finish loading and reach the racing phase, then captures matched
30 FPS and `smooth60=1` scenes. It writes individual frames, labeled
side-by-side composites, and `manifest.json` under
`test/output/smooth60-replays/`.

The replay set covers:

- running
- jumping
- falling
- landing
- wall contact
- teleport effects
- an in-progress course rotation
- spectating a remote character
- a queued multiplayer position correction
- a 72-particle stress scene

Both columns retain the authoritative 30 Hz simulation. The right column only
changes presentation to 60 FPS.
