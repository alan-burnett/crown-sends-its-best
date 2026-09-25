class_name DecisionKind
extends RefCounted

## The decision points the spec asks an actor to weigh.
##
## `docs/mechanics/deliberation.md` §1 lists them. They are one mechanism, so that
## a system added in a later milestone extends every decision point at once
## instead of each one growing an `if` branch.
##
## A consideration registers against the kinds it affects. Adding a kind here
## does not touch the kernel.

## A governor commits to what his town is for (SPEC §11.3, §8.5).
##
## **Not the objective.** `docs/mechanics/governor-objectives.md` §9 marks
## objective selection, stall detection and tile choice as decisions personality
## must *not* touch — the governor has wise advisors and a town that builds badly
## reads as a bug rather than as character. Those are `ObjectiveSelector` and
## `Reconsideration`, and they are deliberately not decision kinds: a kind here
## is an invitation to register a weight against it.
const GOVERNOR_INTENT: StringName = &"governor_intent"

## A contact complies, partly complies, delays, reinterprets, refuses, or acts
## alone (SPEC §8.5).
const ORDER_COMPLIANCE: StringName = &"order_compliance"

## A contact decides for himself when the PC does not reply (SPEC §9.3).
const UNANSWERED: StringName = &"unanswered"

## The director decides who writes to the PC and about what (SPEC §9.6).
const DIRECTOR_URGENCY: StringName = &"director_urgency"

## **A trade protest is not here, and must not be added** (#131).
##
## It is a calculation rather than a deliberation: no actor chooses it. A score
## per town per resource is recomputed each month and crosses a threshold — the
## same shape as rebellion in SPEC §12.3, which is a protest's larger sibling.
##
## **It is the people's decision, not the governor's.** He is an input to it, his
## loyalty and temperament colouring his town's mood, but the refusal is the
## town's. A kind here is an invitation to register a weight against it, and a
## governor's personality weighing whether his town protests would put the
## decision in the wrong hands.
##
## A governor who wants to hurt the Crown has his own route, and it is **intent**
## (#128) — *prepare the town for rebellion*, reachable at very low loyalty. That
## is his version of the impulse and it belongs to him. The protest does not.

## A tribe decides its diplomacy; a rival decides to demand or attack
## (SPEC §12.5, §8.4).
const FACTION_POSTURE: StringName = &"faction_posture"

## 🔒 **A commander decides what his company does this month** (#221,
## `commanders.md` §5, SPEC §8.5, §12.6).
##
## The seventh point, and it is here rather than as a branch for the reason §5
## gives: **there is no "will he obey" check anywhere.** He scores attack, hold,
## march, withdraw and disband and takes the best, so *refusing to attack* is
## attack scoring below retreat and needs no code of its own.
##
## Which makes §12.6's *Crown troops may refuse orders against Crown interests*
## and §8.5's *orders are requests* the same mechanism rather than two: the PC's
## letter moves the weights, it does not move the company.
const COMMANDER_ORDERS: StringName = &"commander_orders"

## 🔒 **Where a commander is taking his company** (#222, `commanders.md` §4).
##
## The eighth point, and separate from the seventh because the two run on
## different clocks. *What he does this step* is re-asked every move and every
## attack, on a board his last step changed. *Where he is going* is a standing
## purpose that survives the month, becomes an **Intent**, and is the only thing
## another commander can see.
##
## 🔒 **This is the one decision that reads other actors' plans.** Everything
## else in the game deliberates about its own situation alone. §4 is explicit
## that it needs no faction brain and no general staff to do it: coordination is
## considerations reading the `IntentBook`, so it **emerges** rather than being
## directed — which it also has to, because §12.6 locks that the PC never
## commands and the Marshal is an ocean away. **There is nobody to model.**
const COMMANDER_OBJECTIVE: StringName = &"commander_objective"

## 🔒 **A governor answers a tribe's letter** (#435, `natives.md` §11): yield,
## gift, refuse or threaten. A decision point, so it goes through the kernel and
## emits its trace like every other.
const TRIBE_GRIEVANCE: StringName = &"tribe_grievance"

const ALL: Array[StringName] = [
	GOVERNOR_INTENT,
	ORDER_COMPLIANCE,
	UNANSWERED,
	DIRECTOR_URGENCY,
	FACTION_POSTURE,
	COMMANDER_ORDERS,
	COMMANDER_OBJECTIVE,
	TRIBE_GRIEVANCE,
]


static func is_kind(name: StringName) -> bool:
	return ALL.has(name)
