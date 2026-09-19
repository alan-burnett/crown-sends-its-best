# data/crown

Tuning for what the Crown asks of the PC.

`demands.json` holds **the bar and what moves it**, per
`docs/mechanics/crown-demands.md`. `steady` is years one to three, which do not
grow at all — the early squeeze is a level set above a young colony's output,
not a curve. `growth` is what one draw on each axis does from year four.

Every magnitude here is a placeholder awaiting the harness sweep in §8 of that
doc. The target is **equal expected pressure across the reference players**,
which is a measurement: the spendthrift never feels `desperation`, the miser
feels almost nothing else, and the steady hand feels all four.

Sweep it with:

```bash
./tools/godot.sh --script res://tools/balance.gd -- 25 12 steady
```
