class_name Prestige
extends RefCounted

## The Crown's running account of the PC (#76, `docs/mechanics/prestige.md`).
##
##     prestige = net_gold + patron_credit - optics_debt
##
## ## 🔒 It is denominated in gold
##
## The court prices humiliation in money. Every term is in the same unit, which
## is the Crown's unit, because the Crown has no other — a trade protest is worth
## so many pounds of embarrassment, a patron pleased so many pounds of goodwill.
##
## **This is the satire load-bearing rather than decorative.** SPEC §14.1 locks
## that prestige measures only how the Crown benefits and that nobody at court
## cares how the colonists fared, and a gold-denominated score is the bluntest
## possible statement of it.
##
## ## 🔒 It never reads the colony's welfare
##
## It may read **what the Crown received, what it paid, and what made it look
## foolish**. It may never read quality of life, rebel sentiment, population, or
## anything else about how the colonists fared. SPEC §18 lists scoring the
## colony's own welfare as a non-goal and §14.1 locks the same thing from the
## other side.
##
## Reaching for quality of life here breaks the pillar the ending rests on: **a
## PC can leave behind a wretched, half-starved colony and retire in glory**, and
## the game must let him.
##
## ## 🔒 It is never a number the player sees
##
## Never a screen, never a bar. He reads it in the tone and content of letters
## from Crown contacts — and above all from patrons, who are M7, so for now the
## audible channel is the Steward, the Chancellor, the Provost and the Marshal.
## `tools/lint.gd` keeps `presentation/` away from it, as it does standing and
## sentiment.
##
## **Prestige is not loyalty.** Loyalty is how a contact feels about the PC
## personally; prestige is how the court regards him. A contact may like the PC
## enormously and still know he is a joke in the capital, and his letters carry
## both. Two dials into one voice.
##
## ## The same number as standing, asked a different question
##
## | | Reads | Asks | Acts on |
## | :--- | :--- | :--- | :--- |
## | **Crown Standing** | net position over monthly net | *are you on track?* — a rate | refusing payments, during the run |
## | **Prestige** | net position | *what did you net us?* — a level | letters, and the final score |
##
## A PC deep in debt but newly profitable has recovering standing and dismal
## prestige. One who banked a fortune and then stopped earning has great prestige
## and falling standing. Two verdicts from one number, and both correct.

const EVENT_MEASURED: StringName = &"prestige_measured"

## The figure as of the month it was last settled.
##
## **Stored, not recomputed on demand** (§6), as quality of life is, so that two
## readers cannot disagree about it halfway through a month.
var value: float = 0.0
var net_gold: float = 0.0
var patron_credit: float = 0.0
var optics_debt: float = 0.0

## What it was last month, so a letter can tell a rising man from a falling one
## without holding the previous state (§8).
var was: float = 0.0
var settled_month: int = -1


## Work it out from the record, without storing anything.
##
## Exposed because §14.1 requires prestige be **measurable at any point in a
## run** rather than only at the end, and because a test asking what a thing is
## worth should not have to run a month to find out.
static func of(log: EventLog) -> Dictionary:
	var gold := CrownAccounts.of(log).net_position()
	var patrons := patron_credit_in(log)
	var optics := OpticsRegister.debt_in(log)
	return {
		"net_gold": gold,
		"patron_credit": patrons,
		"optics_debt": optics,
		"total": gold + patrons - optics,
	}


## What the PC's patrons are worth to his name.
##
## **Named, and reads zero.** Patrons are M7 (SPEC §8.3). §5 has the shape ready
## for them: a favour banks the month it is granted and survives his departure, a
## present patron's regard is a live term, and on leaving his final loyalty banks
## permanently — which is what makes a patron about to go worth pleasing now.
##
## Reading it here means M7 fills this in rather than threading a third term
## through everything that touches prestige.
static func patron_credit_in(_log: EventLog) -> float:
	return 0.0


## Settle this month's figure (Seam A).
##
## **Falls as well as rises** (SPEC §13.2), because `net_position` does: the
## Crown honouring promises a failing colony cannot repay drives it down while
## optics only ever accumulate. That is the whole of §8's retirement decision —
## the reason to leave is never that waiting heals anything, it is that waiting
## accrues new damage.
func settle(log: EventLog, month: int) -> void:
	var parts := Prestige.of(log)
	was = value
	value = float(parts["total"])
	net_gold = float(parts["net_gold"])
	patron_credit = float(parts["patron_credit"])
	optics_debt = float(parts["optics_debt"])
	settled_month = month

	# **The parts and the direction, never a figure a screen could render.** Same
	# rule as rebel sentiment: what the letters need is whether the court thinks
	# better or worse of him this month and roughly what did it.
	log.emit(EVENT_MEASURED, &"crown", month, {
		"direction": direction(),
		"embarrassed_this_month": OpticsRegister.debt_for_month(log, month) > 0.0,
	}, WorldPhase.RUN_END_CHECK)


## Whether the court thinks better or worse of him than it did last month.
func direction() -> String:
	if settled_month < 0:
		return "steady"
	if value > was + 0.0001:
		return "rising"
	if value < was - 0.0001:
		return "falling"
	return "steady"


func to_dict() -> Dictionary:
	return {
		"value": value,
		"net_gold": net_gold,
		"patron_credit": patron_credit,
		"optics_debt": optics_debt,
		"was": was,
		"settled_month": settled_month,
	}


static func from_dict(data: Dictionary) -> Prestige:
	var out := Prestige.new()
	out.value = float(data.get("value", 0.0))
	out.net_gold = float(data.get("net_gold", 0.0))
	out.patron_credit = float(data.get("patron_credit", 0.0))
	out.optics_debt = float(data.get("optics_debt", 0.0))
	out.was = float(data.get("was", 0.0))
	out.settled_month = int(data.get("settled_month", -1))
	return out
