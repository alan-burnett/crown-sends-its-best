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

## What one worker makes in a month, and what that consumes, **at the base terms
## every town hall defines** (#152).
##
## A recipe exists because the catalogue says the output converts from the input.
## What the exchange actually costs is the town's business, because it is a fact
## about the building doing the work — so these two are the town hall's figures
## and `made_by`/`consumes_for` are what anything with a town in hand should ask.
var made: float = 0.0

## How much of the input that consumes.
var consumed: float = 0.0


func _init(p_output: StringName = &"", p_input: StringName = &"") -> void:
	output = p_output
	input = p_input
	var base := Building.find(Building.BASE)
	var terms: Dictionary = {} if base == null else base.conversion_terms(id())
	consumed = float(terms.get("throughput", 0.0))
	made = consumed / maxf(0.0001, float(terms.get("ratio", 1.0)))


func id() -> StringName:
	return StringName("%s<-%s" % [output, input])


## The best rate this town can turn anything into `output` at (#152).
##
## **One answer, because there used to be two.** The catalogue carries an
## `input_per_unit` and the buildings now carry a ratio, and anything that asked
## the catalogue was working from a different exchange rate than the town
## actually gets — so Reckon would reserve furs for a bolt of cloth the loom
## could not weave from them.
##
## Cloth comes from furs or cotton, so "best" is over the recipes for this
## output: the town lays in raw for whichever it would actually use.
static func best_ratio(town: Town, output: StringName) -> float:
	var best := 0.0
	for input in ResourceCatalogue.inputs_for(output):
		var recipe := Conversion.new(output, StringName(input))
		var made := recipe.made_by(town)
		if made <= 0.0:
			continue
		var ratio := recipe.consumes_for(town) / made
		if best <= 0.0 or ratio < best:
			best = ratio
	return best if best > 0.0 else ResourceCatalogue.input_per_unit_of(output)


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


## What this town puts through this recipe in a worker-month (#152).
func consumes_for(town: Town) -> float:
	var terms := Building.terms_for(town, id())
	return consumed if terms.is_empty() else float(terms["throughput"])


## And what it gets out of that.
##
## **Experts raise the yield of their resource including processed resources**
## (SPEC §12.2), and that is still a multiplier because it is a fact about the
## people rather than about the terms.
##
## A building is not. It **defines** the exchange rather than improving on one,
## so `yield_bonus` no longer touches a conversion — it would be raising output
## while the input stayed fixed, which is the single dial #152 exists to split in
## two.
func made_by(town: Town) -> float:
	var terms := Building.terms_for(town, id())
	var out := made if terms.is_empty() \
		else float(terms["throughput"]) / float(terms["ratio"])
	return out * WorkPhase.expert_multiplier(town, output)
