# data/buildings/

The building tree (SPEC §11.3). A town sets its objective toward a building;
buildings unlock others and have static costs and effects.

**Adding a building is adding a file.** Prerequisites, costs and effects are all
data, and nothing in code names a building.

| Field | Meaning |
| :--- | :--- |
| `requires` | Buildings that must already stand. All of them, not any |
| `cost` | Resources consumed, by the Build phase (#49). **This is also the schedule** — see below |
| `effects` | What it does once it stands — see below |
| `grants_contact` | **Uncommon.** A church brings a clergyman, an armoury a quartermaster (SPEC §8.2). Declared here; nothing consumes it until M7 |

## Effects

| Effect | Meaning |
| :--- | :--- |
| `yield_bonus` | Raises the town's production of a resource, as a share |
| `quality_of_life` | Added to the town's standing quality of life |
| `reserve_months` | Extra months of a **named resource** the town holds back — see below |
| `build_speed` | Shortens later builds, as a share |
| `defence` | M6 |
| `converts` | Conversions the town can now perform |
| `upkeep` | **Gold a month to keep it running** (#151), and it may be zero |
| `amusement` | Pleasure that arrives without a ship (#153) — see below |
| `conversions` | **The terms of a conversion** — see below |

## Upkeep, and what happens when a town cannot pay

A town that cannot pay **keeps the building and loses the effect**. It is not
lost, not damaged, not demolished — it stands idle and switches back on the
moment the town can afford it again, with no repair cost and no rebuilding. An
idle improvement reverts its tile to the bare terrain.

Upkeep settles **before the month's phases begin**, because buildings reach Work
through yields, Reckon through reserves and Build through speed. What goes dark
first is what the governor values least.

## Amusement

```json
"effects": { "amusement": 0.5 }
```

The share of the population a building entertains. It feeds **the same
`luxury` and `luxury_kinds` pair a cellar of drink produces**, not a separate
quality-of-life term, so it masks a shortfall the way rum does and counts towards
the variety bonus.

**A theatre cannot be embargoed.** Beer and rum arrive through Exchange and can
be cut off by a trade protest, a blockade, a rebellion or simply no gold, so
amusement is strategically distinct: expensive up front, carrying upkeep, and
immune to everything that interrupts commerce. The counterweight is that upkeep
*does* touch it — a town too poor to pay watches its amusements go dark in the
same month its larder empties.

## There is no `months`

**A building authors its cost and not its duration** (#148). A town has a *build
capacity* — resources a month it can put into construction, from its population,
multiplied by `build_speed` — and the time falls out:

> A granary costing 40 wood and 20 stone is 60 resources. A town with a capacity
> of 30 builds it in exactly two months.

One authored number instead of two, and they can no longer disagree. A large
town builds fast, a small one takes an age over the same structure, and nothing
has to be re-tuned when a cost changes. The validator rejects an authored
`months`.

It also collapses two gates into one: materials are consumed into the work at
the capacity rate, so **the materials are the time**, and stalling is a single
condition — the town cannot get the resources.

## Reserves name their resources

```json
"effects": { "reserve_months": { "cotton": 2 } }
```

**Per-resource only. No wildcard**, and the validator rejects both a blanket
figure and a `"*"` key. A blanket reserve made a granary hold guns and rum back
as readily as grain, which only made the town sell less of everything — not an
effect anybody would choose. Targeted, it changes behaviour: a weavers' loom
gives a town a real reason to stockpile cotton instead of selling it.

A month is measured in what the town actually gets through — what its people eat,
or what its buildings put through the recipe that consumes it — so a month means
something for a resource nobody eats.

## Conversions: two dials, not one

A building does not multiply a conversion's output. It **defines that
conversion's terms**, and the best building the town has for a recipe is the one
that governs (#152).

```json
"conversions": {
  "iron<-ore": { "ratio": 6.0, "throughput": 12.0 }
}
```

| Dial | Meaning |
| :--- | :--- |
| `ratio` | Input per unit of output. **Lower is better** |
| `throughput` | How much input one worker puts through in a month |

They are independent on purpose. *Once you build a tool factory you are shipping
it a great deal more iron than you were shipping to individual blacksmiths:
consumption goes up and the ratio improves.* A single `yield_bonus` could only
move both together, so it no longer applies to conversions at all — it is for
tile yields.

**Better means a lower ratio**; a tie goes to the one that puts more through, and
then to the name, so the choice never depends on iteration order.

## The town hall

**Every town has one from the moment it is founded.** It is not built, not
chosen and not optional, and it is what defines the eight base ratios. That is
why the base case is not a special case in code: the rule is uniform, and an
upgrade is simply a building that defines better terms.

## Gated conversions

**Nothing is gated, except guns** (#150). A town with no smithy still forges
tools, because the town hall says on what terms.

The gate is not a check on an id anywhere. It is that **no building defines
terms for `guns<-iron` except a gunsmith**, so a town without one has nothing
saying how a musket might be made. Gating another conversion is deleting its
line from the town hall; ungating one is putting it back.

The resource carries `"requires_building": true` so that the omission reads as
deliberate rather than as a line somebody dropped, and so the tests can tell
those apart.

## The fork

`storehouse` opens everything. From there a town chooses:

- **`sawmill` → `carpenters_hall`** — more wood, and everything after is quicker.
- **`quarry_works` → `smithy` → `armoury`** — stone and iron, and guns at the end.

They cost differently, they pay off at different speeds, and a town cannot do
both early. `granary` and `church` sit beside the fork for a town that would
rather be comfortable than productive.
