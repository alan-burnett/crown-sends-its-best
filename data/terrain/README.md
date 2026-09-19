# data/terrain/

The tile types of SPEC §11.1 and what they yield.

**High, medium and low are tuning values in `yield_levels.json`**, not constants
in code. A terrain says a tile is *high* in wood; what "high" is worth is one
number in one place, and balancing every forest in the game is editing it.

A yield a terrain does not mention is zero. Sea yields high food and nothing
else; ocean yields low food and nothing else.

`land` separates what a town can work from what it cannot. `navigable` is for
the water, and will matter when ships do.
