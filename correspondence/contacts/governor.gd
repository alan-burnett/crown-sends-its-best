class_name Governor
extends RefCounted

## The colony's voice: one governor per town, and the main contact for that
## town's affairs (SPEC §8.2).
##
## ## What makes him different from the Crown officers
##
## The officers want things **from** the PC. The governor is the PC's only window
## **into** a place. His perception leans are about his own town, so the player's
## picture of the colony is filtered through one man's temperament — an anxious
## governor and a complacent one describing the same harvest is the whole effect.
##
## **🔒 Towns run themselves** under him (SPEC §11.3). The PC sets objectives and
## policies by letter; the governor has authority over what the town actually
## does. Orders to him resolve through the same compliance system as anybody
## else's, refusal and acting alone included.
##
## He is **generated semi-randomly from his own contact stream**, so the same
## seed yields the same man with the same temperament however late in a run he
## appears. Election of a governor for a *new* town is M4.

const ROLE: StringName = &"governor"

## Considerations a governor weighs. Compliance ships its own (#16) and intent
## ships the rest (#53) — **personality is a weight vector over these and
## nothing else**, so a cautious governor and a greedy one differ by seven
## numbers rather than by a line of code.
const WEIGHTED: PackedStringArray = [
	"loyalty", "cost_of_request", "payment_offered", "autonomy", "order_clarity",
	"quality_of_life", "food_security", "revenue", "native_threat",
	"room_to_grow", "mandate", "crown_urging",
]

## Topics a governor shades when he writes about his own town. **These are what
## make him a lens rather than a readout.**
const LEANED: PackedStringArray = [
	"food_security", "supply_situation", "colony_revenue", "quality_of_life",
]

## How far a governor's report may stray from the truth. The perception resolver
## caps the effect at one rung whatever this is; this decides how often it bites.
const LEAN_SPREAD: float = 0.3

## Where a governor's loyalty begins. He is the PC's man, more or less, and has
## not yet been given cause.
const START_LOYALTY_MIN: float = 45.0
const START_LOYALTY_MAX: float = 70.0

## Invented names, in the spec's register. **🔒 All factions are fictionalised**
## (SPEC §3.1), so nothing here names a real person or place.
const FORENAMES: PackedStringArray = [
	"Ambrose", "Cuthbert", "Hester", "Jerrold", "Maud", "Nathaniel",
	"Oriel", "Perrin", "Rosamund", "Selwyn", "Thomasin", "Wilfrid",
]
const SURNAMES: PackedStringArray = [
	"Ashcombe", "Breward", "Calloway", "Dunmore", "Fenwick", "Garrow",
	"Halloway", "Larkin", "Merrick", "Pell", "Quarles", "Rushworth", "Standish", "Thorne",
]


## Make the governor of a town.
##
## Everything is drawn from **his own** stream, so adding a second governor in M4
## changes nothing about the first.
static func generate(town: Town, streams: RngStreams) -> Contact:
	var id := StringName("governor_%s" % town.id)
	var rng := streams.contact_stream(String(id))

	var contact := Contact.new(id, {})
	contact.role = ROLE
	contact.display_name = "%s %s" % [
		FORENAMES[rng.randi_range(0, FORENAMES.size() - 1)],
		SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)],
	]
	contact.title = "Governor of %s" % town.display_name
	contact.portrait_asset = "portrait.governor"
	contact.town = town.display_name

	# Sorted, so the draws are consumed in a fixed order and the same seed gives
	# the same man however the lists were assembled.
	var weights := WEIGHTED.duplicate()
	weights.sort()
	for consideration in weights:
		contact.set_weight(StringName(consideration), rng.randf_range(Contact.WEIGHT_MIN, Contact.WEIGHT_MAX))

	var topics := LEANED.duplicate()
	topics.sort()
	for topic in topics:
		contact.leans[topic] = rng.randf_range(-LEAN_SPREAD, LEAN_SPREAD)

	contact.cares_about = topics
	contact.relationship = Relationship.new(id, rng.randf_range(START_LOYALTY_MIN, START_LOYALTY_MAX))

	town.governor_id = id
	return contact
