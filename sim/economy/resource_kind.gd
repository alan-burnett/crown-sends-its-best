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
	return kind


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"luxury": luxury,
		"producible": producible,
		"converts_from": converts_from.duplicate(),
		"livestock": livestock,
	}


func _to_string() -> String:
	return "ResourceKind(%s)" % id
