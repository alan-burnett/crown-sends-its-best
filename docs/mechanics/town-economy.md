# Mechanics — The Town Economy

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §10.1 (resources), §10.2 (taxes and gold), §11.3 (the Colony
> Month), and the Squeeze pillar in §2.
>
> **Does not cover:** production and conversion in full. See §10.

---

## 1. Three dictionaries, not one price

**Every faction values a resource differently, and trade happens on the gap.**

A single price table was wrong. No ship comes from the Crown carrying lumber,
because a developed country and a forested colony value timber about the same and
there is no gap to pay for the voyage. No food goes back the other way, because
the home country grows it on a scale the colony cannot touch.

### All three are dynamic. They differ in what moves them, and how fast

| Dictionary | Moves with | Pace |
| :--- | :--- | :--- |
| **Town** | Desired stock against what it holds | **Monthly.** A town of forty revalues timber when it raises a church. |
| **Natives** | Their circumstances — war, trust, what they hold | Seasonal |
| **Crown** | Events at home — a failed harvest, a livestock die-off, a war | **Slow**, and from the colony it reads almost fixed |

**Nothing is locked static.** A valuation is a function; a constant is a function
with no inputs. Starting the Crown's as effectively fixed and adding drivers
later costs nothing, whereas declaring it immovable would have to be undone.

**When the Crown's prices do move, it is news.** A failed harvest at home means
the Crown will suddenly pay handsomely for colonial grain — reversing a trade
that never made sense before, and giving the Steward something worth writing
about. That is content the model gets for free and a fixed table could never
produce.

What does **not** change is that the PC has no purview over any of it. SPEC §10.2
locks that his gold is not a wallet, and §8.1 gives him no lever on terms of
trade. Prices move because the world moves, never because he asked.

### The mercantile pattern falls out of the numbers

| | Town values | Crown values | Result |
| :--- | --: | --: | :--- |
| Furs | low — it has plenty | high — scarce and fashionable at home | colony **sells** |
| Tools | high — it needs them and can make few | low — it manufactures them | colony **buys** |
| Lumber | low | low | **no trade** |
| Food | moderate | low — grown at home at scale | **no trade** |

The colony exports raw goods and imports manufactures because the valuations say
so. That is the age of colonialism emerging from a price table.

### What the natives value: the craft they do not have

They are not short of land or its fruits. **A thing is valuable to them when
making it requires a craft they cannot do**, and worthless when it does not.

| Native valuation | Resources | Why |
| :--- | :--- | :--- |
| **Very high** | Horses, tools, guns | Immense power, and no way whatever to make them |
| **Moderate** | Rum, beer, clothing | They have no stills, no needles, no spinning — these are genuinely new |
| **Low** | Food, wood, stone, furs, cotton, sugar, tobacco, **tea, cigars**, cows, sheep | The fruits of the land. **A rolled leaf and a dried leaf are still leaves.** |
| **None** | **Iron** | They cannot work it |

That last distinction is the rule doing its job. Cigars and rum are both made
from something the land gives, but **rum needs a still and a cigar needs a pair
of hands.** Only one of those is a craft they lack.

Iron at nothing and tools at everything says the same thing from the other end:
**the value is in the making, not the material.**

**And it moves with their circumstances.** A tribe at war wants guns and horses
far more than a tribe at peace, and §12.5 gives tribes their own diplomacy to be
at war over. The native dictionary is not a fixed table with a hostility gate on
top; the valuations themselves move.

Two consequences worth seeing now, because they shape M5 rather than decorate it:

- **Native trade runs opposite to Crown trade.** The colony sells the Crown its
  raw produce and buys manufactures; it sells the natives manufactures and buys
  their produce. SPEC §11.3 puts natives **first** in Exchange and §10.1 makes
  that trade untaxed, so a tribe that trusts the colony is its **one escape from
  the Crown's monopoly**.
- **The price of that escape is arming them.** The things natives want most are
  guns, tools and horses. SPEC §10.1 already calls guns and tools "especially
  coveted," and this is why.

