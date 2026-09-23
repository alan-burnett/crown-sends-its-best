class_name DemandBook
extends RefCounted

## What the Crown is asking of the PC right now, and when it last asked
## (SPEC §10.2; `docs/mechanics/crown-demands.md` §4).
##
## ## A revenue target, not a bill
##
## SPEC §10.2 locks that the PC's gold is **not a wallet**, so the Steward is not
## asking him to hand over coins he does not have. He is stating what the colony
## is expected to return through taxed trade over the coming months.
##
## Accepting makes it a **promise** (SPEC §9.5), and whether it is kept depends
## on whether the colony's trade actually reaches the figure. **Saying yes is a
## bet on your own colony**: fall short and the promise *breaks*, costing loyalty
## on top of the standing. Refuse outright and it costs standing and the
## Steward's regard, but nothing breaks and nobody is surprised.
##
## That asymmetry is the decision, and the player has to judge his own colony to
## know which he is making.
##
## ## Issued by the sim, answered by the post
##
## The Crown decides in phase 5 that it wants something; the letter that carries
## it goes out in phase 9. Deciding it here rather than in a trigger condition
## keeps the schedule where the schedule belongs — a condition cannot record
## that it fired, so a demand scheduled from the letter side would either repeat
## every month or need a cooldown that could not grow with `frequency`.

const KIND_GOLD: StringName = &"gold"
const KIND_RESOURCE: StringName = &"resource"

const EVENT_DEMANDED: StringName = &"crown_demanded"
const EVENT_LAPSED: StringName = &"crown_demand_lapsed"

## Months before the Crown asks for anything at all.
##
## Not zero: a demand in the founding month arrives before the player has seen
## what he is governing, and the first decision of a run should not be a bet
## made blind.
const FIRST_DEMAND_MONTH: int = 3


## The month the Crown last asked for something, so the next one is `frequency`
## months after it rather than a fixed cooldown the growth could not reach.
var last_issued_month: int = -1

## The demand made this month, if any. Read by the letter that carries it.
var issued_month: int = -1
var asker: StringName = &""
var kind: StringName = KIND_GOLD
var amount: float = 0.0
var term_months: int = 0

## What the Marshal wants, when it is goods rather than gold.
var resource: StringName = &""

## The month after which a demand for goods is taken as a refusal.
##
## **Gold is answered by return of post; goods are not.** A careful player writes
## to the governor first and learns whether they can be had — it costs him a
## month, and the demand may not wait, but it turns a blind bet into an informed
## one (`crown-demands.md` §5). A demand answered by return of post makes that
## play impossible and reduces the decision to a coin toss.
var expires_month: int = -1


## Whether a letter carrying this demand is owed.
##
## A gold demand is owed the month it is made and no longer. A demand for goods
## stands until it is answered or it lapses, because the PC is meant to be able
## to go away and ask.
func is_pending(month: int) -> bool:
	if issued_month < 0:
		return false
	if kind == KIND_RESOURCE:
		return month <= expires_month
	return issued_month == month


## How many more posts the PC has to answer with.
func turns_left(month: int) -> int:
	return 0 if expires_month < 0 else maxi(0, expires_month - month)


## The PC answered. Whatever he said, the Crown is no longer waiting.
func answer() -> void:
	expires_month = -1
	issued_month = -1


## Nothing came back before the deadline.
##
## **Silence is not neutral.** SPEC §9.3 lets the post pile up, and the price of
## letting it pile up here is the price of a refusal — the Marshal was not asking
## whether the PC had noticed him.
func lapse(month: int, log: EventLog) -> bool:
	if kind != KIND_RESOURCE or expires_month < 0 or month <= expires_month:
		return false
	if log != null:
		log.emit(EVENT_LAPSED, asker, month, {
			"asker": String(asker),
			"kind": String(kind),
			"resource": String(resource),
			"amount": amount,
		}, WorldPhase.CROWNS_MONTH)
	answer()
	return true


## Decide whether the Crown asks for something this month, and what.
##
## Returns whether it did. **Idempotent within a month**, since the driver runs
## once a month but nothing should depend on that being true.
func advance(month: int, growth: DemandGrowth, streams: RngStreams, log: EventLog) -> bool:
	if lapse(month, log):
		# One lapses and the next is not due the same month. The Crown is not so
		# eager as to send a fresh demand in the same post as the reproach.
		return false
	if month < FIRST_DEMAND_MONTH or issued_month == month:
		return false
	if is_pending(month):
		return false  # He is still holding one; the Crown waits for its answer.
	if last_issued_month >= 0:
		if float(month - last_issued_month) < DemandSchedule.months_between(growth):
			return false

	issued_month = month
	last_issued_month = month
	amount = DemandSchedule.gold_target(growth)
	term_months = DemandSchedule.term_months()
	resource = &""
	expires_month = -1

	if _wants_goods(growth, streams):
		asker = &"marshal"
		kind = KIND_RESOURCE
		resource = _wanted(streams)
		# Priced in the same gold as the Steward's figure, so the two askers weigh
		# roughly the same on the colony and the `size` axis reaches both.
		amount = maxf(1.0, roundf(amount / maxf(0.5, ResourceCatalogue.price_of(resource))))
		expires_month = month + DemandSchedule.deadline_turns() - 1
	else:
		asker = &"steward"
		kind = KIND_GOLD

	if log != null:
		log.emit(EVENT_DEMANDED, asker, month, {
			"asker": String(asker),
			"kind": String(kind),
			"resource": String(resource),
			"amount": amount,
			"term_months": term_months,
			"expires_month": expires_month,
		}, WorldPhase.CROWNS_MONTH)
	return true


## Whether this demand is for goods rather than gold.
##
## ## The Marshal is not asking yet
##
## **Two things gate it.** The first is `reach`: at the opening of a run only the
## Steward has a hand out, and `crown-demands.md` §6 reads the fourth dimension
## as *more sources of demand* — naming "the Marshal wanting supplies as well as
## gold" among them. So a requisition is something the run grows into rather than
## something it starts with, and the axis moves a thing the player can feel
## rather than a number nobody consults.
##
## He still writes early about his wars (`marshal.request_supplies`). That is the
## Marshal asking because a campaign is going badly, which is not the same as the
## Crown setting a requisition against the colony on a schedule.
##
## The second is that **gold is the routine**. A resource demand costs two
## letters, a payment decision and a governor's compliance; at every demand the
## desk becomes a logistics exercise and SPEC §9.6's promise that it will not
## become a chore is broken (§5).
func _wants_goods(growth: DemandGrowth, streams: RngStreams) -> bool:
	# 🔒 **When the Squeeze has put out a Crown officer's hand** (#339, §6) —
	# *the Marshal wanting supplies as well as gold*. It used to wait for a second
	# hand of any kind, which is a ladder no doc asked for.
	if streams == null or growth == null \
			or growth.sources_of(DemandGrowth.SOURCE_CROWN) < 1:
		return false
	return streams.stream(DemandGrowth.STREAM).randf() < DemandSchedule.resource_share()


## What the Marshal's wars need. Iron, guns and the like — never a comfort.
##
## Drawn from the catalogue rather than listed here, so a resource added to the
## data is one the Crown can want without a code change.
func _wanted(streams: RngStreams) -> StringName:
	var wantable: PackedStringArray = PackedStringArray()
	for id in ResourceCatalogue.ids():
		var candidate := StringName(id)
		if ResourceCatalogue.is_luxury(candidate) or ResourceCatalogue.is_livestock(candidate):
			continue
		if ColonyNeeds.per_head(candidate) > 0.0:
			continue  # He does not take the bread out of a colony's mouth by post.
		wantable.append(String(id))
	wantable.sort()
	if wantable.is_empty():
		return &"iron"
	return StringName(wantable[streams.stream(DemandGrowth.STREAM).randi_range(
		0, wantable.size() - 1)])


func to_dict() -> Dictionary:
	return {
		"last_issued_month": last_issued_month,
		"issued_month": issued_month,
		"asker": String(asker),
		"kind": String(kind),
		"amount": amount,
		"term_months": term_months,
		"resource": String(resource),
		"expires_month": expires_month,
	}


static func from_dict(data: Dictionary) -> DemandBook:
	var restored := DemandBook.new()
	restored.last_issued_month = int(data.get("last_issued_month", -1))
	restored.issued_month = int(data.get("issued_month", -1))
	restored.asker = StringName(data.get("asker", ""))
	restored.kind = StringName(data.get("kind", KIND_GOLD))
	restored.amount = float(data.get("amount", 0.0))
	restored.term_months = int(data.get("term_months", 0))
	restored.resource = StringName(data.get("resource", ""))
	restored.expires_month = int(data.get("expires_month", -1))
	return restored
