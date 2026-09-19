class_name Contact
extends DeliberationActor

## Somebody the PC writes to.
##
## Every contact has a name, portrait, role, personality and loyalty (SPEC §8).
## Personality affects both the **tone** of their letters and their
## **behaviour** — how they read vague orders, what they choose when left to
## decide, and whether they act on their own.
##
## Personality is inherited from `DeliberationActor`: it is a **weight vector
## over considerations**, not a tag with special-cased behaviour. No contact has
## bespoke behavioural code, which is what SPEC §8 requires when it says
## personality drives behaviour and not merely prose.
##
## Contacts come from two places. Crown Officers are **fixed in every run and
## never randomised** (SPEC §8.1), so they load from data. Colony contacts and
## patrons are **generated semi-randomly** per run (SPEC §8.2, §8.3) from that
## contact's own RNG stream, so the same seed yields the same person however
## late in the run he appears.

## Roles. A contact's role decides which purposes the player may write to him
## about (SPEC §9.4).
const ROLE_CROWN_OFFICER: StringName = &"crown_officer"
const ROLE_GOVERNOR: StringName = &"governor"
const ROLE_COMMANDER: StringName = &"commander"
const ROLE_PATRON: StringName = &"patron"
const ROLE_RIVAL: StringName = &"rival"
const ROLE_INSTITUTIONAL: StringName = &"institutional"

## Personality weights are drawn from this range. A weight of 1.0 is average
## interest in a consideration. Tuning: `docs/mechanics/deliberation.md` §9 flags
## how far weights should be allowed to spread before a contact reads as broken
## rather than characterful.
const WEIGHT_MIN: float = 0.5
const WEIGHT_MAX: float = 1.6

var display_name: String = ""
var title: String = ""
var role: StringName = &""

## An id into the asset registry, never a path (SPEC §16.3).
var portrait_asset: String = ""

## Where this contact lives, for the `{sender:town}` slot (#9). Empty for the
## Crown officers, who are an ocean away.
var town: String = ""

## Signed bias per topic, in `[-1, +1]`, applied in normalised space by the
## perception resolver (#10). The machinery is
## `docs/mechanics/perception.md`; this is only where a contact's values live.
var leans: Dictionary = {}

## Measure ids this contact cares about.
##
## "Whether the things they care about are going well" is **read from world
## state and the diff when it is needed**, not cached here, so it can never go
## stale against the sim. This holds the "what they care about" half; the
## "going well" half belongs to the measure registry (#10).
var cares_about: PackedStringArray = PackedStringArray()

var relationship: Relationship = null


func _init(p_id: StringName = &"", p_weights: Dictionary = {}) -> void:
	super(p_id, p_weights)
	relationship = Relationship.new(p_id)


func loyalty() -> float:
	return relationship.loyalty


func lean_for(topic: String) -> float:
	return clampf(float(leans.get(topic, 0.0)), -1.0, 1.0)


# --- Construction ----------------------------------------------------------

## A fixed contact, from a data file. Crown Officers take this path, so adding
## the Provost and the Diplomat later is a new data file and no new code.
static func from_data(record: Dictionary) -> Contact:
	var contact := Contact.new(StringName(record.get("id", "")), record.get("weights", {}))
	contact.display_name = String(record.get("name", ""))
	contact.title = String(record.get("title", ""))
	contact.role = StringName(record.get("role", ""))
	contact.portrait_asset = String(record.get("portrait", ""))
	contact.town = String(record.get("town", ""))
	contact.leans = record.get("leans", {}).duplicate()
	contact.cares_about = PackedStringArray(record.get("cares_about", []))
	contact.relationship = Relationship.new(
		contact.id,
		float(record.get("loyalty", Relationship.NEUTRAL_LOYALTY)),
	)
	return contact


## A semi-random contact, from its own stream.
##
## Drawn from `streams.contact_stream(id)` rather than a shared stream, so the
## same seed produces the same person regardless of how many contacts were
## created before him or in what order.
static func generate(
	id: StringName,
	role: StringName,
	streams: RngStreams,
	consideration_ids: PackedStringArray,
	starting_loyalty: float = Relationship.NEUTRAL_LOYALTY,
) -> Contact:
	var rng := streams.contact_stream(String(id))
	var weights: Dictionary = {}
	# Sorted, so the draws are consumed in a fixed order and the same seed gives
	# the same personality however the caller assembled the list.
	var sorted_ids := consideration_ids.duplicate()
	sorted_ids.sort()
	for consideration_id in sorted_ids:
		weights[consideration_id] = rng.randf_range(WEIGHT_MIN, WEIGHT_MAX)

	var contact := Contact.new(id, weights)
	contact.role = role
	contact.relationship = Relationship.new(id, starting_loyalty)
	return contact


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"weights": weights.duplicate(),
		"name": display_name,
		"title": title,
		"role": String(role),
		"portrait": portrait_asset,
		"town": town,
		"leans": leans.duplicate(),
		"cares_about": cares_about.duplicate(),
		"relationship": relationship.to_dict(),
	}


static func from_dict(data: Dictionary) -> Contact:
	var contact := Contact.from_data(data)
	contact.relationship = Relationship.from_dict(data.get("relationship", {}))
	return contact
