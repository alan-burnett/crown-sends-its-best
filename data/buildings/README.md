# data/buildings/

The building tree (SPEC §11.3). A town sets its objective toward a building;
buildings unlock others and have static costs and effects.

**Adding a building is adding a file.** Prerequisites, costs and effects are all
data, and nothing in code names a building.

| Field | Meaning |
| :--- | :--- |
| `requires` | Buildings that must already stand. All of them, not any |
| `months` | How long it takes once the resources are there |
| `cost` | Resources consumed, by the Build phase (#49) |
| `effects` | What it does once it stands — see below |
| `grants_contact` | **Uncommon.** A church brings a clergyman, an armoury a quartermaster (SPEC §8.2). Declared here; nothing consumes it until M7 |

## Effects

| Effect | Meaning |
| :--- | :--- |
| `yield_bonus` | Raises the town's production of a resource, as a share |
| `quality_of_life` | Added to the town's standing quality of life |
| `reserve_months` | Extra months of need the town holds back before selling |
| `build_speed` | Shortens later builds, as a share |
| `defence` | M6 |
| `converts` | Conversions the town can now perform |
| `conversions` | **The terms of a conversion** — see below |

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

## The fork

`storehouse` opens everything. From there a town chooses:

- **`sawmill` → `carpenters_hall`** — more wood, and everything after is quicker.
- **`quarry_works` → `smithy` → `armoury`** — stone and iron, and guns at the end.

They cost differently, they pay off at different speeds, and a town cannot do
both early. `granary` and `church` sit beside the fork for a town that would
rather be comfortable than productive.
