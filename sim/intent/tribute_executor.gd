class_name TributeExecutor
extends IntentExecutor

## The PC pays a rival to leave him alone (#69, `crown-demands.md` §4,
## SPEC §8.4, §14.1).
##
## ## 🔒 The fourth currency, and that is the whole point of him
##
## The Steward, the Marshal and the Provost all bill the PC in things the Crown
## keeps books on. A rival bills him in **reputation**, so a PC can be solvent,
## meeting every Crown demand on time, and **still despised at court for having
## paid a foreigner to go away.**
##
## That is why the optic is charged on **accepting**. `prestige.md` §4 prices
## `tribute_paid` at the moment the PC agrees, and `OpticsRegister` — not this
## file — decides what the court makes of it. A mechanic emits; it never prices.
##
## ## 🔒 It defers the risk. It never buys peace
##
## SPEC §8.4: they bully the PC into giving them resources, and accepting puts
## the attack off without ever settling anything. So paying writes a date on the
## world and nothing else; the rival comes back, and comes back asking for more.
##
## **Nothing reads that date yet** — rivals are M5 and their attacks M6. Writing
## it here means the milestone that brings them reads a world value rather than
## reopening this, the same seam shape as `crown.emigration` for #171.
##
## ## The goods move as any other shipment does
##
## 🔒 **The PC cannot move a town's stockpile** (SPEC §11.3). Tribute is goods in
## somebody's warehouse exactly as the Marshal's requisition is, so it takes the
## same second letter to a governor who may refuse — and a governor who refuses
## to be bullied is a man the player may find he agrees with.

## The world value being written — **not the optic**.
##
## 🔒 These were the same string until #210, so every payment emitted
## `tribute_paid` twice and `OpticsRegister` charged the court a thousand gold
## for a five-hundred-gold embarrassment. A state change and a thing the court
## hears about are two different events and must never share a name.
const EVENT_DEFERRED: StringName = &"tribute_quiet_bought"

const KIND: StringName = &"pay_tribute"

## Where the deferred risk lives, per rival. Nothing drives it yet (M6).
const DEFERRED_PREFIX: String = "rival.quiet_until."

## How long a payment buys. Tuning, and deliberately short: **it defers, it does
## not settle**, so he must be back inside a year.
const MONTHS_OF_QUIET: int = 9


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var to := String(intent.data.get("to", ""))
	var months := maxi(1, int(intent.data.get("months", MONTHS_OF_QUIET)))
	var quiet_until := state.month + months

	# **Through `apply`, like any other world value** (Seam A). M6 reads this and
	# decides whether he comes; nothing here knows what an attack is.
	state.apply(log, EVENT_DEFERRED, StringName(to), {
		DEFERRED_PREFIX + to: float(quiet_until),
	}, WorldPhase.MOVEMENT)

	# 🔒 **The optic, at the moment of agreeing** (`prestige.md` §4). The register
	# prices it; this only says it happened, and says it with no figure on the
	# payload — SPEC §14.1 keeps prestige off the player's screens.
	log.emit(OpticsRegister.EVENT_TRIBUTE_PAID, StringName(to), state.month, {
		"to": to,
		"resource": String(intent.data.get("resource", "")),
		"amount": int(intent.data.get("amount", 0)),
		"quiet_until": quiet_until,
		# **Not peace.** He will be back, and the payload says so rather than
		# leaving a reader to assume the matter is closed.
		"bought_peace": false,
	}, WorldPhase.MOVEMENT)
	return Intent.COMPLETED
