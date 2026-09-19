class_name TaxRates
extends RefCounted

## The colony's tax rates (SPEC §10.2).
##
## - **One base rate** applies to all resources across the whole colony.
## - **Per-resource rates** override the base for specific resources, also
##   colony-wide.
## - **🔒 There are no per-town rates.** Ever.
##
## That last one is not a rule this class remembers — it is a rule its shape
## makes true. A rate is keyed by resource and nothing else, so there is nowhere
## to put a town even if somebody wanted to.
##
## Rates live in `WorldState.values` under these keys rather than in a structure
## of their own, which means they serialise with the save, appear in the world
## diff when they change, and can be moved by an Intent through the ordinary
## executor — a tax change is an Order like any other.

const BASE_KEY: String = "tax.base"
const PREFIX: String = "tax."

## Rates are shares of the trade, so 0.0 to 1.0. A rate of 1.0 would take the
## whole transaction, which is a thing the Steward would dearly love to try.
const MIN_RATE: float = 0.0
const MAX_RATE: float = 1.0

## Where a run starts. Tuning.
const DEFAULT_BASE: float = 0.1

## How far one instruction moves a rate. Tuning.
const STEP: float = 0.05


## The key a resource's override lives under.
static func key_for(resource: StringName) -> String:
	return PREFIX + String(resource)


static func base_rate(state: WorldState) -> float:
	return clampf(float(state.get_value(BASE_KEY, DEFAULT_BASE)), MIN_RATE, MAX_RATE)


## **The override wins.** A resource with no override of its own pays the base.
static func rate_for(state: WorldState, resource: StringName) -> float:
	var key := key_for(resource)
	if state.has_value(key):
		return clampf(float(state.get_value(key, DEFAULT_BASE)), MIN_RATE, MAX_RATE)
	return base_rate(state)


static func has_override(state: WorldState, resource: StringName) -> bool:
	return state.has_value(key_for(resource))


## Resources carrying an override of their own, sorted.
static func overridden(state: WorldState) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key in state.value_keys():
		if key == BASE_KEY or not key.begins_with(PREFIX):
			continue
		out.append(key.substr(PREFIX.length()))
	out.sort()
	return out


## The rates a run begins with.
static func initial_values() -> Dictionary:
	return {BASE_KEY: DEFAULT_BASE}


## Where a rate would land if moved by `steps`, clamped.
##
## Exposed so a letter can say what an instruction will actually do before the
## player commits to it — **every choice's mechanical effect is understandable
## from its wording** (SPEC §9.2).
static func moved(state: WorldState, resource: StringName, steps: float) -> float:
	var from := base_rate(state) if String(resource).is_empty() else rate_for(state, resource)
	return clampf(from + steps * STEP, MIN_RATE, MAX_RATE)


## How heavily the colony is taxed overall, as `0.0` to `1.0`.
##
## The measure the Steward writes about, and the one his lean shades. Averaged
## across what the colony actually trades rather than over the base alone, so an
## override on a single resource still shows.
static func burden(state: WorldState) -> float:
	var ids := ResourceCatalogue.ids()
	if ids.is_empty():
		return base_rate(state)
	var total: float = 0.0
	for id in ids:
		total += rate_for(state, StringName(id))
	return clampf(total / float(ids.size()), MIN_RATE, MAX_RATE)
