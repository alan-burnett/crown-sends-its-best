class_name ResourceKind
extends RefCounted

## One of the colony's resources (SPEC §10.1).
##
## **`resource`, never "good"** — SPEC §4 is locked, and tax rates are
## per-resource. The class is `ResourceKind` only because Godot has already taken
## `Resource`; every field, id and comment keeps the spec's word.
##
## Everything about a resource is **data**. Nothing in code may ask "is this
## sugar" — it asks whether the resource is a luxury, whether the colony can
## produce it, and what it converts from.

var id: StringName = &""
var display_name: String = ""

## Consumed to raise quality of life. **Taxed differently, and provokes far less
## rebel sentiment**, because a town can go without it (SPEC §10.2).
##
## A flag on the resource, never a list in code: SPEC §10.2's different treatment
## has to read this, or adding a luxury later means hunting through branches.
var luxury: bool = false

## Whether the colony can make it at all.
##
## **Tea is the only resource that cannot be produced** (SPEC §10.1). It must be
## bought from the Crown, which is exactly what makes it a natural first trade
## protest in M3 — by its mechanics, not by a hardcoded priority.
var producible: bool = true

## What it is made from. **Any one input will do**: clothing comes from furs
## *or* cotton, not both.
var converts_from: PackedStringArray = PackedStringArray()

## Trades like a resource and carries the livestock tax rate, but is population
## rather than stockpile (SPEC §12.2). The population side is M4.
var livestock: bool = false

## What one unit trades for with the Crown, before tax (SPEC §10.2). Tuning.
var price: float = 1.0

## Whether a town needs a building before it can make this at all (#150).
##
## **Declared here and enforced by absence.** Nothing reads this to refuse a
## conversion — the refusal is that no town hall defines terms for it, so a town
## without the building has nothing saying how it might be made. This says that
## the omission is deliberate, so the content validator can tell a gate apart
## from a line somebody dropped.
var requires_building: bool = false

## What it is worth to a colonial town in itself (#135, #136).
##
## **Its own authored figure, not a multiple of `price`.** Derive it and the gap
## between town and Crown becomes a function of shortfall alone — every surplus
## sells and every shortage buys, whatever the resource, and lumber behaves
## exactly like furs. §1's table, where lumber trades in neither direction
## because both sides value it alike, cannot fall out of a derived number.
var town_base: float = 1.0

## What a tribe would give for it, as a multiple of `price` (#136).
##
## **The value is in the making, not the material.** Zero for iron, which they
## cannot work; high for tools and guns, which they cannot make at all. Authored
## in the resource data per `town-economy.md` §1 and inert until M5.
var native_worth: float = 0.0

## Food one head eats each month, when it is not on pasture (#48).
var feed: float = 0.0

## Food one head yields when a hungry town kills it (SPEC §12.2).
var slaughter_yield: float = 0.0

## How much raw resource one unit of this takes to make (#64).
var input_per_unit: float = 1.0

## How much of this one worker makes in a month, in the town rather than the
## fields. **Every conversion costs a worked tile** (SPEC §11.3 step 1).
var per_worker: float = 0.0


func is_processed() -> bool:
	return not converts_from.is_empty()


func is_raw() -> bool:
	return converts_from.is_empty()


## Whether this resource can be made from `input`.
func converts_from_resource(input: StringName) -> bool:
	return converts_from.has(String(input))


static func from_data(record: Dictionary) -> ResourceKind:
	var kind := ResourceKind.new()
	kind.id = StringName(record.get("id", ""))
	kind.display_name = String(record.get("name", record.get("id", "")))
	kind.luxury = bool(record.get("luxury", false))
	kind.producible = bool(record.get("producible", true))
	kind.converts_from = PackedStringArray(record.get("converts_from", []))
	kind.livestock = bool(record.get("livestock", false))
	kind.price = float(record.get("price", 1.0))
	kind.native_worth = float(record.get("native_worth", 0.0))
	kind.town_base = float(record.get("town_base", kind.price))
	kind.requires_building = bool(record.get("requires_building", false))
	kind.feed = float(record.get("feed", 0.0))
	kind.slaughter_yield = float(record.get("slaughter_yield", 0.0))
	kind.input_per_unit = float(record.get("input_per_unit", 1.0))
	kind.per_worker = float(record.get("per_worker", 0.0))
	return kind


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"luxury": luxury,
		"producible": producible,
		"converts_from": converts_from.duplicate(),
		"livestock": livestock,
		"price": price,
		"feed": feed,
		"slaughter_yield": slaughter_yield,
		"input_per_unit": input_per_unit,
		"per_worker": per_worker,
	}


func _to_string() -> String:
	return "ResourceKind(%s)" % id
