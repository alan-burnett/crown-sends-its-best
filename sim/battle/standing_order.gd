class_name StandingOrder
extends RefCounted

## What a company was raised to do, and whether that needs a man (#220,
## `docs/mechanics/commanders.md` §2, §3; `battles.md` §4).
##
## ## 🔒 Orders are not objectives
##
## Worth being exact, because the words carry weight elsewhere (SPEC §4).
##
## | | Has | Reconsidered |
## | :--- | :--- | :--- |
## | **A town** | an **objective** | every Settle — complete, stalled, superseded |
## | **A militia** | a **standing order** | never |
##
## An order is given **once**, by whoever raised the company, and every map move
## executes against it until the company disbands or dies. *Defend the town* is
## never complete and never stalls.
##
## **No reconsideration machinery applies to a headless company**
## (`governor-objectives.md` §7), and a dev who wires it there has misread both
## docs. A *commanded* company is the opposite: its commander deliberates afresh
## every month, and his intent can change.
##
## ## 🔒 The order decides whether a commander is needed, and it is not a size
## check
##
## `battles.md` §4 fixes the important half: a company with no commander has
## nobody to deliberate for it, so it can only hold a posture.
##
## | The standing order | Needs a commander? |
## | :--- | :--- |
## | **Defend the town** | **No.** It never leaves, never chooses, never reconsiders |
## | Anything that leaves the town | **Yes.** Somebody has to decide where, and when to stop |
##
## **You do not need a general to man a palisade.** You need one the moment the
## company has to *go* somewhere, because going somewhere is a decision. So a
## hundred men behind a stockade need nobody, and twelve men marching on a
## village need someone to decide whether to press on when they find it defended.

## The one order the docs name, and the only one that stays at home.
const DEFEND_THE_TOWN: StringName = &"defend_the_town"

## 🔒 **Orders that never leave the town.**
##
## **Adding to this list is a design decision, not a tuning one.** Every entry
## here is a company that can be raised with no commander at all, which means one
## the PC can never write to and that will never reconsider anything — so a new
## defensive order is a new way for a town to put men under arms outside the
## correspondence, and belongs in `commanders.md` §2's table before it belongs
## here.
##
## Everything not in it leaves, and therefore needs a man.
const DEFENSIVE: Array[StringName] = [DEFEND_THE_TOWN]


## The order a company actually carries.
##
## **Nothing is the posture.** A company raised with no order at all is a
## standing posture from whoever raised it and nothing else (`battles.md` §4),
## which is precisely *defend the town* — so the empty case is named rather than
## being a fourth state nobody wrote down.
static func of(order: StringName) -> StringName:
	return DEFEND_THE_TOWN if String(order).is_empty() else order


static func is_defensive(order: StringName) -> bool:
	return DEFENSIVE.has(of(order))


## 🔒 **The test, and it is not a size check** (§2).
static func needs_a_commander(order: StringName) -> bool:
	return not is_defensive(order)


## Whether a company under this order ever moves off its tile.
##
## The same question `needs_a_commander` asks, named the other way round because
## the movement driver asks it about a march and the raising asks it about a man,
## and one definition is what keeps the two from disagreeing.
static func leaves_the_town(order: StringName) -> bool:
	return not is_defensive(order)
