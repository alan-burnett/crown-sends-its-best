class_name CrownRelief
extends RefCounted

## The Squeeze's five reliefs (#399, `crown-demands.md` §10 *Stated
## interactions: the five reliefs*).
##
## **Five hooks a letter can pull**, each loosening the Squeeze its own way. None
## is the draw easing off on its own: each is a contact's ability or a favour
## earned, which is what §10 says relief must be. Every figure is a placeholder.
##
## **What pulls them is content** — which contact, when, at what cost — written
## in #368 with the effect ids and the first letters that use them. Until then
## these are the machinery, callable and tested, and nothing in play calls them.
##
## | | Relief | Where its state lives |
## | :--- | :--- | :--- |
## | 1 | A targeted break | the contact's regard, and his next ask (`DemandBook.skipping`, `Contact.skips_next_ask`) |
## | 2 | Crown war relief | `DemandGrowth.war_relief_until` |
## | 3 | Pulling back a hand | `DemandGrowth.sources` |
## | 4 | Goodwill | `CrownStanding.goodwill` |
## | 5 | Tax forgiveness | a world value per resource (`TaxRates.forgiven`) |

## What a targeted break lifts his regard by.
const BREAK_REGARD: float = 20.0
## How long war relief runs.
const WAR_RELIEF_MONTHS: int = 12
## What one favour banks.
const GOODWILL: float = 5.0

## The Crown officers whose asks are demands in the `DemandBook`.
const DEMANDERS: Array[StringName] = [&"steward", &"marshal"]

const EVENT_BREAK: StringName = &"targeted_break"
const EVENT_GOODWILL: StringName = &"goodwill_banked"


## 🔒 **1. A targeted break.** One contact who asks the PC for things gets a
## single large lift in regard, and his next ask is skipped: a Crown officer's
## next demand, or a patron's next need or gold ask. Returns whether he exists.
static func targeted_break(run: RunState, contact_id: StringName, month: int) -> bool:
	var contact := run.contact(contact_id)
	if contact == null:
		return false
	contact.relationship.loyalty = clampf(
		contact.relationship.loyalty + BREAK_REGARD, Relationship.MIN_LOYALTY, Relationship.MAX_LOYALTY)
	if DEMANDERS.has(contact.id):
		if run.demand_book != null and not run.demand_book.skipping.has(String(contact.id)):
			run.demand_book.skipping.append(String(contact.id))
	else:
		contact.skips_next_ask = true
	run.log.emit(EVENT_BREAK, contact.id, month, {"regard": BREAK_REGARD}, WorldPhase.CROWNS_MONTH)
	return true


## 🔒 **2. Crown war relief.** Desperation reads a level lower for a year. The
## war itself is never touched.
static func war_relief(run: RunState, month: int) -> void:
	if run.demands != null:
		run.demands.relieve_the_war(month, WAR_RELIEF_MONTHS, run.log)


## 🔒 **3. Pulling back a hand.** A Crown officer the Squeeze turned needy stops
## asking. Returns whether one was.
static func pull_back_a_hand(run: RunState, month: int) -> bool:
	return run.demands != null and run.demands.pull_back_a_hand(month, run.log)


## 🔒 **4. Goodwill.** Standing that never decays and is never gold.
static func goodwill(run: RunState, month: int, amount: float = GOODWILL) -> void:
	if run.standing == null:
		return
	run.standing.bank_goodwill(amount)
	run.log.emit(EVENT_GOODWILL, &"crown", month, {"amount": amount}, WorldPhase.CROWNS_MONTH)


## 🔒 **5. Tax forgiveness.** Part of the duty on one resource, for ever.
static func forgive(run: RunState, resource: StringName) -> float:
	return TaxRates.forgive(run.world, run.log, resource)
