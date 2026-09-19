# data/improvements/

What can be built on a tile and what it does to the yield (SPEC §11.1).

**"Best on plains" is a number in a file.** `terrain_factor` scales what the
improvement contributes, so a farm on plains is worth more than a farm on
scrubland without any code knowing which is which.

| Field | Meaning |
| :--- | :--- |
| `scale` | Multiplies the tile's existing yields. `"*"` is everything |
| `keeps` | Resources exempt from `scale` — a farm lowers every yield but food |
| `adds` | Yields the improvement contributes, by level, scaled by `terrain_factor` |
| `terrain_factor` | How well suited the terrain is. `"*"` is the fallback |
| `allowed_on` | Terrains it may be built on at all |
| `livestock_capacity` | Livestock supported without eating (§11.1). The population side is M4 |
| `natural` | Built at no cost by trade rather than chosen. Roads only |

A tile holds **one** improvement. Building a farm where a mine stood replaces it,
which is what the yields already say: each improvement computes from the
terrain, not from whatever was there before.

**Fort** is here so the type exists; it does nothing to yields, and what it does
to combat is M6.
