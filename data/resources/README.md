# data/resources/

The resources of SPEC §10.1. **Everything in the colony economy is denominated
in these**, so nothing that produces or consumes may hardcode one.

**`resource`, never "good"** — SPEC §4 is locked, and tax rates are
per-resource.

| Field | Meaning |
| :--- | :--- |
| `luxury` | Consumed to raise quality of life. **Taxed differently** and provokes far less rebel sentiment (§10.2). A flag, never a list in code. |
| `producible` | Whether the colony can make it at all. **Tea is the only one that cannot** — it must be bought from the Crown, which is what makes it a natural first trade protest. |
| `converts_from` | Inputs it is made from. Any one of them will do: clothing comes from furs **or** cotton. |
| `price` | What one unit trades for with the Crown, before tax. Tuning |
| `input_per_unit` | How much raw resource one unit of this takes to make |
| `per_worker` | How much of this one worker makes in a month |
| `feed` | Food one head eats each month off pasture. Livestock only |
| `slaughter_yield` | Food one head yields when a hungry town kills it |
| `livestock` | Trades like a resource and carries the livestock tax rate, but is population rather than stockpile (§12.2). The population side is M4. |

Adding a resource is adding a file. Nothing in code needs to be told.
