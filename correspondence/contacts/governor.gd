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


## How much of the launcher's regard a daughter town's governor starts with.
##
## 🔒 **This is what makes disloyalty propagate geographically** (#178,
## `founding-towns.md` §4). A sour governor seeds a sour daughter town, which
## will in turn seed another — so a colony with one bad town can be growing its
## second **before the PC has done anything wrong at all**. It runs the other way
## too: a patron the PC has treated well hands him a man already inclined to
## listen.
##
## Not all of it, because he is his own man and was elected by the people setting
## out rather than appointed by his old master. Tuning.
const INHERITED_SHARE: float = 0.65


## Make the governor an expedition elected as it set out (#178, §4).
##
## **Generated the month the expedition launches**, not the month it arrives —
## the same month the town commits and consumes the cargo — so that he can write
## to the PC immediately and the PC can hear what he sounds like while there is
## still a journey in which to answer.
##
## 🔒 **The PC has no say whatever in who he is.** He is elected by the people
## setting out, and there is no argument here that the PC could reach.
##
## His id is the party's rather than a town's, because the town does not exist
## yet — #179 founds it around him.
static func generate_for(
	party: ExpeditionParty,
	launched_by: Contact,
	streams: RngStreams,
) -> Contact:
	var id := StringName("governor_%s" % party.id)
	var contact := _draw(id, streams, "Governor-elect")

	# 🔒 **Inherited, not neutral.** A man's regard for the Crown starts where the
	# man who sent him stood, pulled part of the way back toward whatever he would
	# have been on his own.
	if launched_by != null and launched_by.relationship != null:
		var his_own := contact.relationship.loyalty
		contact.relationship.loyalty = clampf(
			launched_by.loyalty() * INHERITED_SHARE + his_own * (1.0 - INHERITED_SHARE),
			Relationship.MIN_LOYALTY, Relationship.MAX_LOYALTY)
	return contact


## Make the governor of a town.
##
## Everything is drawn from **his own** stream, so adding a second governor in M4
## changes nothing about the first.
static func generate(town: Town, streams: RngStreams) -> Contact:
	var id := StringName("governor_%s" % town.id)
	var contact := _draw(id, streams, "Governor of %s" % town.display_name)
	contact.town = town.display_name
	town.governor_id = id
	return contact


## Draw a man from his own stream.
##
## 🔒 **Everything comes from `hash(run_seed, contact_id)`**, so the same seed
## yields the same man regardless of what happened elsewhere — and adding a
## second governor changes nothing about the first.
static func _draw(id: StringName, streams: RngStreams, title: String) -> Contact:
	var rng := streams.contact_stream(String(id))

	var contact := Contact.new(id, {})
	contact.role = ROLE
	contact.display_name = "%s %s" % [
		FORENAMES[rng.randi_range(0, FORENAMES.size() - 1)],
		SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)],
	]
	contact.title = title
	contact.portrait_asset = "portrait.governor"

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
	return contact
