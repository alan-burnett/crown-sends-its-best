class_name PolicyBook
extends RefCounted

## Every standing instruction the PC has bought, and the monthly bill for them
## (#80, `docs/mechanics/policy.md`).
##
## ## Billed in phase 5, with the Crown's other money
##
## A policy's charge is the Crown's spending, exactly as an honoured promise is,
## so it lands on the same books and `CrownAccounts` reduces both. **A recurring
## charge the Ledger could not show would be the one commitment the player could
## never see**, and §10 flags that as the clearest picture he is likely to get of
## what he has taken on.
##
## ## Your policies survive in proportion to how well you have treated people
##
## When Crown Standing reaches `REFUSING` the PC's gold stops, and every policy
## he was funding drops to paying nothing. That is not a collapse — it is a
## renegotiation with every enactor at once, and each decides for himself whether
## to carry it.
##
## A PC who has been generous for years finds half his apparatus carried by men
## willing to cover for him. A PC who has squeezed everyone finds it all unwinds
## in a season, at the exact moment he can least afford it.

const EVENT_ENACTED: StringName = &"policy_enacted"
const EVENT_BILLED: StringName = &"policy_billed"
const EVENT_ENDED: StringName = &"policy_ended"
const EVENT_RENEGOTIATING: StringName = &"policy_renegotiating"
const EVENT_WARNED: StringName = &"policy_warned"

## How long a man carries what the PC is not paying before he says something.
##
## Long enough that an occasional lean month is not a crisis, short enough that
## a PC who is simply not paying finds out inside a year. Tuning (§9).
const PATIENCE: int = 7

## And how long he gives the PC once he has said it.
##
## 🔒 **The warning always comes before the ending**, and the grace is what makes
## it a decision rather than a notification.
const GRACE: int = 3

## What ending one costs the enactor, over and above the month's drain.
##
## **He put his name to the thing.** Men are appointed and dismissed over these,
## and calling it off makes him look like a fool in front of people whose opinion
## he minds a great deal more than he minds the PC's (§6).
const CANCELLED_COST: float = 9.0

var _policies: Array[Policy] = []
var _next_ordinal: int = 0


func enact(policy: Policy, log: EventLog, month: int) -> Policy:
	if policy.id.is_empty():
		policy.id = StringName("policy_%d" % _next_ordinal)
	_next_ordinal += 1
	policy.enacted_month = month
	_policies.append(policy)

	if log != null:
		log.emit(EVENT_ENACTED, policy.enactor, month, policy.to_dict(), WorldPhase.DISPATCH)
	return policy


func active() -> Array[Policy]:
	return _policies.duplicate()


func by_id(id: StringName) -> Policy:
	for policy in _policies:
		if policy.id == id:
			return policy
	return null


func held_by(enactor: StringName) -> Array[Policy]:
	var out: Array[Policy] = []
	for policy in _policies:
		if policy.enactor == enactor:
			out.append(policy)
	return out


## Charge the month, and drain whoever is carrying the rest.
##
## Returns what the Crown paid altogether, so the caller need not add it up
## twice.
func bill(contacts: Dictionary, log: EventLog, month: int) -> float:
	var paid := 0.0
	for policy in _policies:
		var crown := policy.crown_pays()
		paid += crown

		var contact: Contact = contacts.get(String(policy.enactor))
		var drain := policy.drains()
		if drain > 0.0:
			policy.carried_months += 1
		else:
			# He is being paid. Nothing is owed and nothing is remembered.
			policy.carried_months = 0
		if contact != null and drain > 0.0:
			# **The policy works at full strength either way.** What the PC did
			# not pay is carried by a man, in regard, every month — and he
			# remembers it (`policy.md` §10, `contacts.md` §6).
			contact.relationship.drift(-drain)

		if log != null:
			log.emit(EVENT_BILLED, policy.enactor, month, {
				"policy": String(policy.id),
				"effect": String(policy.effect),
				"split": String(policy.split),
				# **The gold, which the Ledger shows, and never the regard**,
				# which is nobody's business but the enactor's.
				"crown_paid": crown,
			}, WorldPhase.CROWNS_MONTH)
	return paid


## Who has had enough, and who has run out of patience altogether.
##
## Returns `{warned, ended}`. **The warning always comes first**, so a policy
## cannot lapse in the same month the player first hears about it — which is the
## whole difference between a decision and a notification.
func take_stock(log: EventLog, month: int) -> Dictionary:
	var warned: Array[Policy] = []
	var ended: Array[Policy] = []

	for policy in _policies.duplicate():
		if policy.is_warning():
			if month >= policy.ends_month:
				ended.append(policy)
			continue
		if policy.carried_months < PATIENCE:
			continue

		policy.warned_month = month
		policy.ends_month = month + GRACE
		warned.append(policy)
		if log != null:
			log.emit(EVENT_WARNED, policy.enactor, month, {
				"policy": String(policy.id),
				"effect": String(policy.effect),
				"months": GRACE,
			}, WorldPhase.CROWNS_MONTH)

	for policy in ended:
		lapse(policy.id, log, month)
	return {"warned": warned, "ended": ended}


## The Crown's drafts have started bouncing (§5).
##
## Returns the policies now in renegotiation, so their enactors can be written
## to. **Either way he writes**, and either way the PC learns his cheque bounced.
## Loyalty at which a man will cover the PC's bounced draft rather than start
## counting the months until he stops.
##
## Everything above it is somebody willing to carry the PC for a while; below it
## is somebody who sets a date. Tuning (§9).
const WILL_COVER_FOR_YOU: float = 55.0


func crown_stopped_paying(
	log: EventLog,
	month: int,
	contacts: Dictionary = {},
) -> Array[Policy]:
	var shaken: Array[Policy] = []
	for policy in _policies:
		if not policy.crown_stopped_paying():
			continue
		shaken.append(policy)

		# **Each decides for himself**, and this is the line §5 calls one of the
		# best things loyalty does:
		#
		# > Your policies survive in proportion to how well you have treated
		# > people.
		#
		# A man who thinks well of the PC covers it from here, and the ordinary
		# patience of §4 then runs from today. A man who does not names the month
		# it ends — with time to act, because the warning still comes first.
		var contact: Contact = contacts.get(String(policy.enactor))
		var covering := contact == null or contact.loyalty() >= WILL_COVER_FOR_YOU
		if covering:
			policy.carried_months = 0
		else:
			policy.warned_month = month
			policy.ends_month = month + GRACE

		if log != null:
			log.emit(EVENT_RENEGOTIATING, policy.enactor, month, {
				"policy": String(policy.id),
				"effect": String(policy.effect),
				"covering": covering,
				"months": 0 if covering else GRACE,
			}, WorldPhase.CROWNS_MONTH)
	return shaken


## The PC calls one off. **It costs loyalty** (§6).
func cancel(id: StringName, contacts: Dictionary, log: EventLog, month: int) -> bool:
	var policy := by_id(id)
	if policy == null:
		return false
	_policies.erase(policy)

	var contact: Contact = contacts.get(String(policy.enactor))
	if contact != null:
		contact.relationship.record_deed(Relationship.REFUSED, CANCELLED_COST / 5.0)
		contact.relationship.remember(
			Relationship.REFUSED, month, policy.cost, String(policy.effect)
		)

	if log != null:
		log.emit(EVENT_ENDED, policy.enactor, month, {
			"policy": String(policy.id),
			"effect": String(policy.effect),
			"reason": "cancelled",
		}, WorldPhase.DISPATCH)
	return true


## An enactor will carry it no further.
func lapse(id: StringName, log: EventLog, month: int) -> bool:
	var policy := by_id(id)
	if policy == null:
		return false
	_policies.erase(policy)
	if log != null:
		log.emit(EVENT_ENDED, policy.enactor, month, {
			"policy": String(policy.id),
			"effect": String(policy.effect),
			"reason": "lapsed",
		}, WorldPhase.CROWNS_MONTH)
	return true


func to_dict() -> Dictionary:
	var entries: Array = []
	for policy in _policies:
		entries.append(policy.to_dict())
	return {"policies": entries, "next_ordinal": _next_ordinal}


static func from_dict(data: Dictionary) -> PolicyBook:
	var restored := PolicyBook.new()
	for entry in data.get("policies", []):
		restored._policies.append(Policy.from_dict(entry))
	restored._next_ordinal = int(data.get("next_ordinal", 0))
	return restored
