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

## **The PC's only resident eyes** (#81, SPEC §8.1). A role of his own because
## nothing else in the game is a Crown officer who lives in a town — he is
## prominent where he lives, and his regard governs what he tells rather than
## what he does.
const ROLE_DIPLOMAT: StringName = &"diplomat"

## Personality weights are drawn from this range. A weight of 1.0 is average
## interest in a consideration. Tuning: `docs/mechanics/deliberation.md` §9 flags
## how far weights should be allowed to spread before a contact reads as broken
## rather than characterful.
const WEIGHT_MIN: float = 0.5
const WEIGHT_MAX: float = 1.6

## How large each kind of man looms in the town he lives in. Tuning.
##
## The Crown's officers sit at nothing deliberately — they are an ocean away and
## live in no town at all, so they never push anybody's sentiment however the
## rest of the model changes.
const PROMINENCE: Dictionary = {
	"governor": 1.0,
	"commander": 0.5,
	"institutional": 0.3,
	# **A resident Crown man, and the town knows it.** He looms smaller than the
	# governor and larger than a merchant: he dines with the quality and writes
	# home about them, and a town can see him doing it.
	"diplomat": 0.4,
	"patron": 0.0,
	"rival": 0.0,
	"crown_officer": 0.0,
}


static func prominence_of(role: StringName) -> float:
	return float(PROMINENCE.get(String(role), 0.0))


## How large this man looms where he lives.
func prominence() -> float:
	return prominence_override if prominence_override >= 0.0 else prominence_of(role)

## How much weight this man's opinion carries where he lives
## (`rebel-sentiment.md` §4).
##
## **Prominence, not office.** A town listens to the people it has heard of, so
## what a contact does to its rebel sentiment is scaled by how large he looms
## there rather than by which box his role falls in. The governor is the town's
## leader and its voice; a clergyman is listened to on a Sunday.
##
## It cuts both ways, which is the point: **if the famous men of a town are all
## loyal to the Crown there is not much rebel sentiment in it**, and the same
## men slighted are what carries the town out.
##
## **Derived from the role unless the data overrides it**, so it cannot be
## forgotten. A contact built any other way — a test fixture, a scenario — has
## the prominence his office implies without anyone remembering to set it, which
## is the failure this shape exists to prevent.
##
## A particular clergyman may be a firebrand, so the field can still say so.
var prominence_override: float = -1.0

var display_name: String = ""
var title: String = ""
var role: StringName = &""

## An id into the asset registry, never a path (SPEC §16.3).
var portrait_asset: String = ""

## Where this contact lives, for the `{sender:town}` slot (#9). Empty for the
## Crown officers, who are an ocean away.
var town: String = ""

## **Gone, and not replaced** (#81, SPEC §8.1). Only the Diplomat can die so far,
## and nobody will take his post — so this is not a slot to be refilled, it is a
## fact the letters and the run have to live with.
var is_dead: bool = false

## The month he is writing again, if he is at sea (#81, `the-diplomat.md` §3).
##
## **A real blackout.** Agreeing to move him costs the PC two months of not
## knowing, which is the price of agreeing and the reason refusing is a genuine
## option rather than a formality.
var travelling_until: int = -1

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
	contact.prominence_override = float(record.get("prominence", -1.0))
	contact.portrait_asset = String(record.get("portrait", ""))
	contact.town = String(record.get("town", ""))
	contact.is_dead = bool(record.get("is_dead", false))
	contact.travelling_until = int(record.get("travelling_until", -1))
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
		"prominence": prominence_override,
		"portrait": portrait_asset,
		"town": town,
		"is_dead": is_dead,
		"travelling_until": travelling_until,
		"leans": leans.duplicate(),
		"cares_about": cares_about.duplicate(),
		"relationship": relationship.to_dict(),
	}


static func from_dict(data: Dictionary) -> Contact:
	var contact := Contact.from_data(data)
	contact.relationship = Relationship.from_dict(data.get("relationship", {}))
	return contact
