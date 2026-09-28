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
## ## 🔒 Regard is the whole of what it buys (#458, `rival-pressure.md` §4)
##
## SPEC §8.4's *may defer the risk of an attack* is the bands at work: paying
## raises his regard, and a duke kept at High or Medium does not attack. **There
## is no period of quiet after a payment.** He comes back, and comes back asking
## for more. This used to write a quiet date on the world that nothing ever read.
##
## ## 🔒 The gold comes from the Crown, and no governor is asked
##
## **Only the Crown trades with these colonies** (SPEC §10.1). A duke paid in
## goods would mean his ships docking at a Crown wharf to collect them, which is
## not a thing the world allows — so tribute is gold out of the Crown's purse,
## and it is an ordinary gold promise (`PromiseBook.from_order`).
##
## **That is the difference between a duke and the Marshal.** The Crown may ask
## for *resources*, and that takes a second letter to a governor who can refuse
## to part with them. A duke asks for money the PC never had in his hands, so
## there is nobody in the colony to ask and nothing for a governor to decline.
##
## It also means paying reaches `net_position`, lowering Crown Standing *and*
## prestige together (`rival-pressure.md` §4) — and a Crown that has closed its
## purse (§10.3) breaks the promise, so a PC in financial trouble cannot buy a
## duke off at all. The machinery for every part of that already existed.

const KIND: StringName = &"pay_tribute"


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var to := String(intent.data.get("to", ""))

	# 🔒 **The optic, at the moment of agreeing** (`prestige.md` §4). The register
	# prices it; this only says it happened, and says it with no figure on the
	# payload — SPEC §14.1 keeps prestige off the player's screens.
	log.emit(OpticsRegister.EVENT_TRIBUTE_PAID, StringName(to), state.month, {
		"to": to,
		# **Gold, and no resource** (SPEC §8.4, v3.0). The figure is here for the
		# log and the letters; `OpticsRegister` prices the optic and does not read
		# it, because the court minds that he paid rather than how much.
		"gold": float(intent.data.get("amount", 0.0)),
		# **Not peace.** He will be back, and the payload says so rather than
		# leaving a reader to assume the matter is closed.
		"bought_peace": false,
	}, WorldPhase.MOVEMENT)
	return Intent.COMPLETED
