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

## The fork

`storehouse` opens everything. From there a town chooses:

- **`sawmill` → `carpenters_hall`** — more wood, and everything after is quicker.
- **`quarry_works` → `smithy` → `armoury`** — stone and iron, and guns at the end.

They cost differently, they pay off at different speeds, and a town cannot do
both early. `granary` and `church` sit beside the fork for a town that would
rather be comfortable than productive.
