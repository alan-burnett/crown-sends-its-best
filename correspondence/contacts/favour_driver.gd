class_name FavourDriver
extends RefCounted

## Remembers what a contact did for the PC once it has actually happened (#397,
## `docs/mechanics/contacts.md` §6, §7; the Author's ruling is on the ticket).
##
## ## The two kinds of favour that are only real when they land
##
## Complying with a costly order is remembered by `Compliance` the month he
## agrees. These two are not, because agreeing is not doing them:
##
## - **Goods he shipped**, remembered when the shipment ends, however it ended,
##   for what actually left his town — worth what the goods were worth to the
##   Crown. A governor who agreed and then shipped nothing did the PC no favour.
## - **A patron's expert, gold or men**, remembered when they arrive.
##
## ## Phase 7, after the month has happened
##
## Shipments move and gifts land in phase 2, and a patron's men come ashore in
## phase 1, so by Reckoning the month's events all exist. Reading this month's
## log rather than keeping a list means nothing can be remembered twice.

## What an expert is worth, as a favour, in gold. A placeholder: nothing else in
## the game puts a price on a man.
const EXPERT_WORTH: float = 400.0

## A patron's men are worth this many months of what they cost. A placeholder.
const TROOPS_WORTH_MONTHS: float = 12.0

## The Intent resolutions a shipment can end in.
const ENDINGS: Array[StringName] = [
	&"intent_completed", &"intent_stalled", &"intent_abandoned", &"intent_overtaken",
]

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or run == null or log == null:
		return
	for event in log.for_month(state.month):
		match event.type:
			ExpertGiftExecutor.EVENT_ARRIVED:
				_remember(String(event.payload.get("from", "")), Relationship.FAVOUR_GAVE, state.month,
					1.0, String(event.payload.get("resource", "")), EXPERT_WORTH)
			GoldGiftExecutor.EVENT_GIVEN:
				var amount := float(event.payload.get("amount", 0.0))
				_remember(String(event.payload.get("from", "")), Relationship.FAVOUR_GAVE, state.month,
					amount, "", amount)
			CrownTroops.EVENT_LANDED:
				_his_men_landed(event, state.month)
			_:
				if ENDINGS.has(event.type):
					_shipment_ended(event, state.month)


## A shipment the PC ordered has ended, and this much of it left his town.
func _shipment_ended(event: SimEvent, month: int) -> void:
	if String(event.payload.get("kind", "")) != String(Shipment.KIND):
		return
	if String(event.payload.get("origin", "")) != String(Intent.ORIGIN_ORDER):
		return
	var data: Dictionary = event.payload.get("data", {})
	var shipped := float(data.get("shipped", 0.0))
	var resource := String(data.get("resource", ""))
	if shipped <= 0.0 or resource.is_empty():
		return
	_remember(String(event.payload.get("source", "")), Relationship.FAVOUR_SHIPPED, month,
		shipped, resource, shipped * ResourceCatalogue.price_of(StringName(resource)))


## A patron's men came ashore. The Marshal's are not a favour of his: the
## policy that put them there is priced at compliance like any other.
func _his_men_landed(event: SimEvent, month: int) -> void:
	var enactor := String(event.subject)
	var patron: Contact = run.contacts.get(enactor)
	if not Patron.is_patron(patron) or run.policies == null:
		return
	var policy := run.policies.by_id(StringName(event.payload.get("policy", "")))
	var worth := 0.0 if policy == null else policy.cost * TROOPS_WORTH_MONTHS
	_remember(enactor, Relationship.FAVOUR_GAVE, month,
		float(event.payload.get("men", 0)), "troops", worth)


func _remember(
	who: String, kind: StringName, month: int, magnitude: float, subject: String, worth: float
) -> void:
	var contact: Contact = run.contacts.get(who)
	if contact == null or contact.relationship == null or worth <= 0.0:
		return
	contact.relationship.remember_favour(kind, month, magnitude, subject, worth)
