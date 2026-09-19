# CI

One job, on pull requests against `main`. It runs **only** the content validator
and the narrow mandatory tests — per the testing policy in `CLAUDE.md`, it does
not run UI tests and does not gate on balance.

| Step | What a failure means |
| :--- | :--- |
| Import the project | Godot could not scan the project at all |
| Content validator | A letter or trigger is wrong. The message names the file, the path and the token |
| Architecture lint | A node in `sim/`, a global RNG draw, a built-in `hash()`, or a write to sim state from above `sim/` |
| Tests | Determinism or the save round trip broke, or a locked invariant did |
| Determinism across processes | The same seed and decisions produced two different runs |

**Non-blocking to begin with.** Nothing here is a required check, so a red run is
a signal to the dev rather than a gate. Making it required later is a
branch-protection setting and no change to the workflow.

**If CI ever becomes the reason to write a test the policy would reject, that is
a bug in this job**, not a reason to relax the policy.

## Why the import step exists

Godot registers `class_name` globals during a project scan. On a fresh checkout
there is no `.godot/`, so until one runs every type is missing and everything
fails with `Could not find type "X" in the current scope`. It is the same step
`./tools/godot.sh --editor --quit` performs locally.
