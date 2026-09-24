class_name StandingOrder
extends RefCounted

## What a company was raised to do (#220, #434, `docs/mechanics/commanders.md`
## §3; `battles.md` §4).
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
## ## The four orders (§3, the Author's ruling on #423)
##
## | Order | What the company does each month |
## | :--- | :--- |
## | **Defend the town** | stays in its town and fights whatever attacks it |
## | **Explore** | moves toward the nearest unexplored tile, revealing the land it passes |
## | **Guard the border** | holds the tile of its town's influence facing the nearest threat |
## | **March on a foe** | moves on its foe and attacks it |
##
## `OrderRule` chooses one when the company is raised.
##
## ## 🔒 The order no longer decides who leads it
##
## The rule that anything which leaves the town needs a commander is **retired**
## (#434). Leadership comes from the company's size (#432, `Company.led_by`), so
## a militia may explore — and a militia that explores still has nobody deciding
## for it: it follows its order, and a commander deliberates.

## Stays at home, and the only order that does.
const DEFEND_THE_TOWN: StringName = &"defend_the_town"

## The nearest unexplored tile, a move a month, revealing what it passes.
const EXPLORE: StringName = &"explore"

## The edge of its town's influence, facing the nearest threat.
const GUARD_THE_BORDER: StringName = &"guard_the_border"

## Its foe (`OrderRule.foe_of`), and fight it.
const MARCH_ON_A_FOE: StringName = &"march_on_a_foe"

## 🔒 **Orders that never leave the town.** Everything else goes somewhere.
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


## Whether a company under this order ever moves off its tile.
static func leaves_the_town(order: StringName) -> bool:
	return not is_defensive(order)
