class_name Conversion
extends RefCounted

## Turning a raw resource into a processed one (SPEC §10.1, §11.3 step 1, #64).
##
## ## Why this exists at all
##
## SPEC §10.1 names six conversions and the Colony Month had no phase where any
## of them happened, so **seven of the nineteen resources could not come into
## existence**. Towns bought their clothing from the Crown with gold, which works
## until a town has no gold — and clothing is a *need*.
##
## It also broke the luxury design. `docs/mechanics/town-economy.md` makes tea the
## point where taxation breaks, because it is the cheap luxury that **can never
## be produced** while beer and rum can. Without conversion every luxury is a
## purchase and tea is not special.
##
## ## 🔒 A worker is in the fields or in the town, never both
##
## SPEC §11.3 step 1: *"A worker is in the fields or in the town, never both, so
## every conversion costs a worked tile."* That is the whole of the labour model
## here, and it is why a recipe is scored in the same units as a tile — so the
## two can be put in one list and the best taken.
##
## ## 🔒 Conversion draws on the start-of-month stockpile
##
## Also the spec's wording. **Ore bought from the Crown this month is smelted
## next month**, never the same month, so a town cannot buy and process in one
## turn and the Exchange phase cannot be used as a same-month forge.
##
## ## What this is not
##
## Not the production mechanic. That takes in improvements, building bonuses,
## experts and the full labour model, and is deferred by the Author
## (`town-economy.md` §7). **This is the minimum M2 needs** so that a town with
## furs and spare hands can clothe itself.

## What one worker makes, from what, in one month.
##
## `id` is stable and names both ends, so a trace reads `clothing<-furs` rather
## than a number.
var output: StringName = &""
var input: StringName = &""

## How much of the output one worker produces in a month, before experts and
## buildings.
var made: float = 0.0

## How much of the input that consumes.
var consumed: float = 0.0


func _init(p_output: StringName = &"", p_input: StringName = &"") -> void:
	output = p_output
	input = p_input
	made = ResourceCatalogue.per_worker_of(output)
	consumed = made * ResourceCatalogue.input_per_unit_of(output)


func id() -> StringName:
	return StringName("%s<-%s" % [output, input])


## Every conversion the catalogue knows about, sorted by output then input.
##
## **Clothing comes from furs or cotton**, so it appears twice — one recipe per
## input, and a town picks whichever it actually has. Nothing in code names a
## resource; add a `converts_from` to the data and the recipe exists.
static func all() -> Array:
	var out: Array = []
	for id in ResourceCatalogue.processed():
		for source in ResourceCatalogue.inputs_for(StringName(id)):
			var recipe := Conversion.new(StringName(id), StringName(source))
			if recipe.made > 0.0 and recipe.consumed > 0.0:
				out.append(recipe)
	out.sort_custom(func(a: Conversion, b: Conversion) -> bool:
		if a.output != b.output:
			return String(a.output) < String(b.output)
		return String(a.input) < String(b.input))
	return out


## What this town would actually get from one worker on this recipe.
##
## **Experts raise the yield of their resource including processed resources**
## (SPEC §12.2), and so do the buildings that exist to make the thing — a smithy
## smelts better iron. Both read the same way they do for tile work, so a town
## does not have two different ideas of what an expert is worth.
func made_by(town: Town) -> float:
	return made * WorkPhase.expert_multiplier(town, output) * (1.0 + Building.yield_bonus_for(town, output))
