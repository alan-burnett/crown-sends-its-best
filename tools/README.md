# tools/ — command-line entry points

All of these run headless and exit non-zero on failure, so CI (#26) can gate on
them.

```bash
./tools/godot.sh --script res://tools/run_tests.gd    # tests
./tools/godot.sh --script res://tools/lint.gd         # architecture lint
./tools/godot.sh --editor --quit                      # reimport (see below)
```

`godot.sh` finds Godot, runs it headless against this project, and streams its
output. Set `GODOT_BIN` to override the executable.

**On Windows, Godot needs that wrapper.** The standard build is a GUI-subsystem
binary with no console wrapper, so it prints nothing at all to a terminal unless
its output is redirected to a file.

## Reimport after adding a `class_name`

Godot registers `class_name` globals during a project scan. A script added
outside the editor is invisible until one runs, and the failure looks like
`Could not find type "X" in the current scope`. Run the reimport line above.
**CI has to do this before running anything**, on a fresh checkout where
`.godot/` does not exist yet.

| Script | What it does |
| :--- | :--- |
| `run_tests.gd` | Runs every `tests/test_*.gd`. A test file that fails to parse is a failure, not a hang. |
| `lint.gd` | `sim/` references no node type; nothing uses the global RNG or the engine's `hash()`. |
