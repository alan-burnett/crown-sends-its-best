class_name Tribe
extends DeliberationActor

## A people already living here (#203, SPEC §12.5;
## `docs/mechanics/natives.md` §1, §2).
##
## ## 🔒 They do not know the PC
##
## **No tribe writes to him. No tribe has heard of him.** There is no native
## contact, no letter from a chief, no negotiation across the ocean — and a dev
## who adds a tribe to the contact roster has broken the premise the whole doc
## rests on.
##
## They deal with **towns** and the people in them. What they think of the colony
## is earned and lost by what colonists *do*: where they settle, what they take,
## whether they shoot. So the PC has no direct instrument at all — he can argue
## with a governor's intent and set policy, and that is the whole of his reach.
## **A man who has never met them, arguing with a man who has, about people he
## will never see.**
##
## ## 🔒 Standing is held per faction, and they can tell everyone apart
##
## The colony, each rival, each other tribe, and the **Crown's troops** — which
## they distinguish from the colonists those troops are supposedly protecting.
##
## **Trust is its standing toward the colony** (§12.5). The same quantity under a
## named relationship, and **not a second field**: two numbers would eventually
## disagree, and the one the letters read would be the wrong one.
##
## Held per faction means a tribe can be hostile to the colony and civil with a
## rival — **and then deal with that rival about the colony.**
##
## ## 🔒 A people has a temperament, like anybody else who chooses
##
## `Tribe` is a `DeliberationActor`, so what one of them offers the colony in
## trade comes out of a **weight vector over considerations** and not out of a
## branch — the same mechanism as a governor's intent and a contact's compliance
## (`deliberation.md` §4). One people trade what they can spare; another will not
## sell a gun to anybody whatever it is worth.
##
## That is what SPEC §12.5's "full actors in the simulation" has to mean in code.
##
## ## 🔒 The point of no return is a latch, not a threshold
##
## Standing moves both ways across almost its whole range. Insults are forgiven,
## intrusions are lived with, a badly-used tribe can be won back.
##
## **Except at the bottom.** Past a point a tribe concludes a faction *means them
## destroyed*, and that conclusion never reverses — not with gifts, not with
## concessions, not with a change of governor. Once entered it is **held for the
## run** regardless of what standing later does.
##
## And it is **not a trigger**. §12.5 says trust can be permanently broken by
## aggression; the refinement is that it is not one massacre, it is **a pattern
## that finally convinces them**. A tribe reaches a conclusion about what the
## colony is for, and once it has there is nothing left to discuss.

const EVENT_STANDING_MOVED: StringName = &"tribe_standing_moved"
const EVENT_IRRECONCILABLE: StringName = &"tribe_irreconcilable"

## The faction every tribe can tell apart, whatever else exists.
##
## **The Crown's troops are their own faction**, distinguished from the
## colonists they are supposedly protecting — which is the whole reason M6's
## garrison is a thing a tribe can hate on its own account.
const COLONY: StringName = &"colony"
const CROWN_TROOPS: StringName = &"crown_troops"

const MINIMUM: float = 0.0
const NEUTRAL: float = 50.0
const MAXIMUM: float = 100.0

## Below this, a tribe concludes the faction means it destroyed. Tuning.
##
## 🔒 **Above the floor on purpose.** A latch at zero would be a floor with a
## different name; the point is that there is a stretch of very bad standing a
## tribe can still be talked out of, and a point past it where it cannot.
const IRRECONCILABLE_BELOW: float = 12.0

var display_name: String = ""

## Standing toward every faction it can name. Faction id -> nought to a hundred.
var standing: Dictionary = {}

## Factions it has concluded mean it destroyed. **A latch**: ids go in and never
## come out.
var irreconcilable: Dictionary = {}

## The month the colony first had a town beside this people, or -1 while it has
## not (#299). **Latched**: a people is met once, and forgetting it on a reload
## would meet it again.
var met_month: int = -1


## What it thinks of a faction it may never have met.
##
## **Neutral by default rather than absent**, because a tribe that has not yet
## formed an opinion of the Crown's troops has an opinion about them the first
## time it sees one, and a missing key would read as hatred.
func standing_toward(faction: StringName) -> float:
	return float(standing.get(String(faction), NEUTRAL))


## 🔒 **Trust is standing toward the colony**, not a second field.
func trust() -> float:
	return standing_toward(COLONY)


## Whether this tribe has concluded that a faction means it destroyed.
func is_irreconcilable_with(faction: StringName) -> bool:
	return bool(irreconcilable.get(String(faction), false))


## Move a tribe's standing toward one faction (Seam A).
##
## Returns what it moved to. 🔒 **A tribe that has concluded a faction means it
## destroyed does not move** — not up and not down, because there is nothing left
## to discuss and a figure that kept sliding would imply there was.
##
## 🔒 **`can_conclude` is the whole of the asymmetry** (#204, `natives.md` §3).
## Aggression by a colonist is the *only* thing that reaches the point of no
## return. Intrusion, exploitation and a governor set against them grind a people
## down to the edge of that conclusion and stop there, however long they run —
## which is why they clamp rather than skipping the latch. A tribe sitting at
## three with no conclusion behind it would be a people who had decided nothing
## while every system treated them as though they had.
func move(
	faction: StringName,
	by: float,
	why: String,
	context: ColonyContext,
	can_conclude: bool = true,
) -> float:
	var key := String(faction)
	if is_irreconcilable_with(faction):
		return standing_toward(faction)

	var before := standing_toward(faction)
	var after := clampf(before + by, MINIMUM, MAXIMUM)
	if not can_conclude and before >= IRRECONCILABLE_BELOW:
		# Down to the edge of the conclusion and not one step past it. Guarded on
		# `before` so this can only ever hold a people up, never lift one who is
		# already under the line back over it.
		after = maxf(after, IRRECONCILABLE_BELOW)
	standing[key] = after

	if not is_equal_approx(after, before):
		context.log.emit(EVENT_STANDING_MOVED, id, context.state.month, {
			"tribe": String(id),
			"toward": key,
			"why": why,
			# **The direction, never the figure.** Nothing about a tribe reaches
			# the player except through his own people (`natives.md` §1), and a
			# payload carrying the number is a payload a letter could render.
			"worsening": after < before,
		}, WorldPhase.COLONY_MONTH)

	# 🔒 **The latch.** Entered by a pattern reaching a point, never by one event
	# saying so — which is why this is checked after a move rather than raised by
	# whatever caused it.
	if after < IRRECONCILABLE_BELOW and not is_irreconcilable_with(faction):
		irreconcilable[key] = true
		context.log.emit(EVENT_IRRECONCILABLE, id, context.state.month, {
			"tribe": String(id),
			"toward": key,
			"why": why,
		}, WorldPhase.COLONY_MONTH)
	return after


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"weights": weights.duplicate(),
		"standing": standing.duplicate(),
		"irreconcilable": irreconcilable.duplicate(),
		"met_month": met_month,
	}


static func from_dict(data: Dictionary) -> Tribe:
	var tribe := Tribe.new()
	tribe.id = StringName(data.get("id", ""))
	tribe.display_name = String(data.get("name", ""))
	tribe.weights = data.get("weights", {}).duplicate()
	tribe.standing = data.get("standing", {}).duplicate()
	tribe.irreconcilable = data.get("irreconcilable", {}).duplicate()
	tribe.met_month = int(data.get("met_month", -1))
	return tribe
