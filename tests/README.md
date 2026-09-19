# tests/

Tests are a safety net, not a tax. Written **only** where the value is stable
and silent breakage is expensive:

- **Determinism** — same seed and decisions produce an identical state hash.
- **Save/load round-trip** — ironman means a corrupt save is a lost run.
- **Content validation.**
- **Invariants the spec marks with a lock**, such as colony-month phase ordering
  and Orders never writing state.

**Do not write** tests asserting balance numbers, tests on UI, or tests against
anything expected to iterate. A test written against a moving value will be
rejected.

## Running

```bash
./tools/godot.sh --script res://tools/run_tests.gd
```

A file named `tests/test_*.gd` extending `TestCase` is picked up automatically;
every method named `test_*` runs. `fixtures/` holds deliberately broken JSON for
the loader tests and is not part of `data/`.

**A test method that records no assertion fails.** A GDScript runtime error
aborts a method without raising anything a runner can catch, so a test that blew
up would otherwise look exactly like a test that passed. Requiring an assertion
is the only way this runner can go red on an error rather than green.

`assert_eq` compares through `Canonical.encode`, so `1` and `1.0` are **not**
equal and dictionary insertion order does not matter. Use `assert_same` for
object identity.
