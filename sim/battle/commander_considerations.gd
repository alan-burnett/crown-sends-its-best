class_name CommanderConsiderations
extends RefCounted

## What a commander weighs before he moves (#221, `docs/mechanics/commanders.md`
## §5, SPEC §8.5, §12.6).
##
## ## 🔒 There is no "will he obey" check anywhere
##
## A commander **scores every option open to him** — attack, hold, march,
## withdraw to the town and disband — and takes the best. *Refusing to attack* is
## simply **attack scoring below retreat**, and it needs no code of its own, no
## branch and no special outcome.
##
## So the answer to *can a commander refuse to attack* is yes, and the answer to
## *how* is: the same way everybody in this game refuses anything. Compliance
## with the PC's letters runs the identical path (§8.5) — **the letter moves the
## weights, it does not move the company.**
##
## ## 🔒 Keeping his army alive is a consideration, not a rule
##
## Weighted by personality. **A cautious man weights it heavily and will not
## spend his men on a fort; a glory-seeker weights it low and will. Both are
## reading the same board**, and neither has a branch of his own.
##
## That is also how §12.6's *Crown troops may refuse orders against Crown
## interests* falls out: an officer whose men are the Crown's asset weighs losing
## them, and a losing assault scores below standing still without anybody writing
## down what a Crown interest is.
##
## ## And the trace is the letter
##
## `choose()` emits its scoring, so when a commander writes to say he will not
## assault the fort, **the reason in his prose is the reason in his trace**
## (SPEC §9.1). He can name what he weighed because the kernel recorded it.
##
## Each scores in `[-1, +1]`, like every other consideration, so no system
## dominates by choosing a larger scale.

const KINDS: Array[StringName] = [DecisionKind.COMMANDER_ORDERS]

## The ids, for the roll that gives a commander his personality. **A commander
## with no weight on these would weigh them exactly as every other commander
## does**, and two men reading the same board would always agree.
## A literal rather than a `PackedStringArray(...)` call: Godot will not take a
## constructor as a constant expression (`CLAUDE.md`).
const ALL: PackedStringArray = [
	"keeping_my_army_alive",
	"the_prize_in_front_of_me",
	"the_orders_i_was_given",
	"the_crowns_urging",
	"standing_about",
]

## 🔒 **What his regard for the PC does to an order** (SPEC §8.5).
##
## **An order is a request, and a request from a man you despise is barely an
## argument at all.** Both order terms below are scaled by this, so:
##
## - a commander who thinks well of the PC weighs the order at full strength,
##   and for most boards that is what decides it
## - a commander who does not is **barely moved even by a desperate letter** —
##   the tone raises how hard the letter pulls, and his regard crushes the
##   product
##
## That is the difference between this and the governor's urging, which relies
## on compliance to gate whether the letter lands at all. A commander in the
## field is not answering a letter when he decides; he is deciding, with a letter
## in his pocket. So the regard has to reach the weighing itself, or a man who
## loathed the PC would follow his last instruction exactly as faithfully as a
## man who admired him.
##
## 🔒 **It never reaches nought.** A company under orders is still under orders,
## and a commander who ignored them completely would have stopped being the
## Crown's — which is a rebellion and belongs to a different mechanism.
const LEAST_REGARD: float = 0.1

## The size of enemy a commander would call a famous victory. Tuning.
##
## **An absolute, deliberately.** Beating a hundred men is the same feat whether
## you brought fifty or five hundred, which is what makes this a different
## question from the odds rather than the same one inverted.
const GLORY_AT: float = 80.0

## How long the PC's last word to a commander keeps half its pull.
##
## **Shorter than a governor's year** (`intent_considerations.md`'s twelve
## months), because a campaign is a season and a town is a lifetime: a letter
## about a march that is over is a letter about nothing. Tuning.
const URGING_HALF_LIFE: float = 6.0


## How much this man's orders count with him, nought to one.
##
## Linear in loyalty, because there is no band here worth naming — the point is a
## gradient, so that the PC can feel a commander slipping rather than discover it
## at a threshold.
static func regard_of(actor: DeliberationActor) -> float:
	var contact := actor as Contact
	if contact == null:
		return 1.0
	return lerpf(
		LEAST_REGARD, 1.0,
		clampf(contact.loyalty() / Relationship.MAX_LOYALTY, 0.0, 1.0))


static func register_all() -> void:
	Deliberation.register_consideration(
		StayingAliveConsideration.new(&"keeping_my_army_alive"), KINDS)
	Deliberation.register_consideration(
		PrizeConsideration.new(&"the_prize_in_front_of_me"), KINDS)
	Deliberation.register_consideration(
		OrdersConsideration.new(&"the_orders_i_was_given"), KINDS)
	Deliberation.register_consideration(
		UrgingConsideration.new(&"the_crowns_urging"), KINDS)
	Deliberation.register_consideration(
		IdlenessConsideration.new(&"standing_about"), KINDS)


# --- What a commander may do -----------------------------------------------

## The five options §5 names, and no sixth.
##
## 🔒 **Withdrawing and disbanding are ordinary candidates**, scored alongside
## attacking rather than reached by a branch when things go badly. That is the
## whole of the section: a commander who pulls back did so because pulling back
## scored highest, and the trace says so.
const ATTACK: StringName = &"attack"
const HOLD: StringName = &"hold"
const MARCH: StringName = &"march"
const WITHDRAW: StringName = &"withdraw"
const DISBAND: StringName = &"disband"

const OPTIONS: Array[StringName] = [ATTACK, HOLD, MARCH, WITHDRAW, DISBAND]


## Everything this commander could do this month.
##
## **Attack is offered only when there is somebody to attack**, because an option
## that could never be taken is noise in every trace — and `applies_to` already
## distinguishes *no opinion* from *scored nothing*.
##
## `data` carries what the considerations read: the company, and the enemy in
## front of it when there is one.
static func options_for(
	company: Company, enemy: Company, has_somewhere_to_go: bool
) -> Array:
	var out: Array = []
	var board := {"company": company, "enemy": enemy}
	if enemy != null:
		out.append(Candidate.new(ATTACK, board))
	out.append(Candidate.new(HOLD, board))
	# 🔒 **Marching is not how you leave a fight** (§6: there is no rout). A
	# company in contact cannot stroll onward past the men in front of it — the
	# ways out of contact are withdrawing, which is a decision and goes home, and
	# dying. Offering both would let a commander with orders to press on walk
	# around every enemy he met, which is neither a refusal nor a battle.
	if has_somewhere_to_go and enemy == null:
		out.append(Candidate.new(MARCH, board))
	out.append(Candidate.new(WITHDRAW, board))
	out.append(Candidate.new(DISBAND, board))
	return out


static func _company_of(candidate: Candidate) -> Company:
	return candidate.get_value("company", null) as Company


static func _enemy_of(candidate: Candidate) -> Company:
	return candidate.get_value("enemy", null) as Company


## How the two forces stand, as the attacker's share of the pair.
##
## Nought to one, where a half is an even fight. **Read through `Force` and
## nowhere else** (#214), so terrain and the wall reach this the only way they
## ever reach anything.
static func _odds(candidate: Candidate, context: DeliberationContext) -> float:
	var mine := _company_of(candidate)
	var theirs := _enemy_of(candidate)
	if mine == null or theirs == null:
		return 0.5
	var map: WorldMap = context.data.get("map", null)
	var my_force := Force.of(mine, map, false)
	var their_force := Force.of(theirs, map, true, mine)
	var both := my_force + their_force
	return 0.5 if both <= 0.0 else clampf(my_force / both, 0.0, 1.0)


# --- The considerations -----------------------------------------------------

## 🔒 **Keeping his army alive** (§5), and the reason refusal needs no branch.
##
## Attacking costs men in proportion to how badly the odds run against him, so a
## losing assault scores hard against this and a walkover barely registers.
## Withdrawing and disbanding are the safe options and say so; holding is
## middling, because standing still in front of an enemy is not safety.
##
## **A cautious man weights this heavily and will not spend his men on a fort; a
## glory-seeker weights it low and will.** Neither has a rule of his own.
class StayingAliveConsideration:
	extends Consideration

	func score(
		_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		match candidate.id:
			CommanderConsiderations.ATTACK:
				# An even fight is a wash; the worse the odds the worse this gets,
				# and a walkover is nearly free.
				return clampf(
					(CommanderConsiderations._odds(candidate, context) - 0.5) * 2.0,
					-1.0, 1.0)
			CommanderConsiderations.WITHDRAW, CommanderConsiderations.DISBAND:
				# 🔒 **Retreat is worth exactly the danger it avoids.**
				#
				# A flat reward for leaving made a cautious man retreat from a
				# fight he was winning, and from an enemy who was not there —
				# which reads as a coward rather than as a careful officer. So it
				# is the mirror of what attacking costs: nothing at all when the
				# odds are with him, and everything when they are not.
				return clampf(
					(0.5 - CommanderConsiderations._odds(candidate, context)) * 2.0,
					0.0, 1.0)
			CommanderConsiderations.MARCH:
				return 0.0
			_:
				# Holding in front of an enemy is not safety; holding alone is.
				return -0.3 if CommanderConsiderations._enemy_of(candidate) != null \
					else 0.2


## What is in front of him, and what beating it would be worth.
##
## 🔒 **Measured in men, not in odds** — and that is what makes it a different
## axis from the one above rather than the same number under a second name.
##
## Glory is who you beat, not how convenient the ground was: **a large enemy is a
## large prize and also a large risk**, so the two considerations pull against
## each other and a commander's weights decide which wins. A version that scored
## the odds here would be perfectly correlated with staying alive, and the
## cautious man and the glory-seeker would differ only by a scalar.
##
## Every other option scores nothing at all here rather than scoring zero — a
## withdrawal has no opinion about a prize.
class PrizeConsideration:
	extends Consideration

	func applies_to(candidate: Candidate) -> bool:
		return candidate.id == CommanderConsiderations.ATTACK

	func score(
		_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext
	) -> float:
		var theirs := CommanderConsiderations._enemy_of(candidate)
		if theirs == null:
			return 0.0
		# 🔒 **Their size, not their share of the pair.** A share is one minus the
		# odds, so it cancelled the risk exactly whenever force tracked size —
		# which is every fight in a bare field between two unarmed companies. The
		# two considerations then summed to nothing and only the weights decided,
		# which is the correlation this pair exists to avoid.
		return clampf(
			float(theirs.size) / CommanderConsiderations.GLORY_AT, 0.0, 1.0)


## 🔒 **What he was told to do** (§5, SPEC §8.5) — and this is the only place the
## PC's letter reaches the field.
##
## **It moves the weight, it never moves the company.** A commander told to press
## on scores marching and attacking higher; the same letter to a man who weighs
## his army heavily still loses to the arithmetic in front of him, which is
## exactly what §8.5 means by an order being a request.
##
## Disbanding is what the order most plainly is not, whatever the order was.
class OrdersConsideration:
	extends Consideration

	func score(
		actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext
	) -> float:
		var company := CommanderConsiderations._company_of(candidate)
		var sent := company != null and StandingOrder.leaves_the_town(company.order)
		var asked := 0.0
		match candidate.id:
			CommanderConsiderations.ATTACK:
				asked = 0.8 if sent else 0.2
			CommanderConsiderations.MARCH:
				asked = 1.0 if sent else -0.2
			CommanderConsiderations.HOLD:
				asked = -0.2 if sent else 1.0
			CommanderConsiderations.WITHDRAW:
				asked = -0.6 if sent else 0.2
			_:
				asked = -1.0
		# 🔒 **Scaled by what he thinks of the man who gave it** (SPEC §8.5). An
		# order is a request, and a request from somebody you despise is barely an
		# argument — so the same order counts for everything with a loyal officer
		# and for almost nothing with a bitter one.
		return asked * CommanderConsiderations.regard_of(actor)


## 🔒 **What the PC last argued him toward** (`commanders.md` §8, SPEC §8.5).
##
## The commander's half of the lever the whole game turns on. The PC cannot name
## a tile and cannot order an attack; he can write, and a commander who thinks
## well of him takes it to heart.
##
## Three things decide how hard it pulls, and they multiply:
##
## | | |
## | :--- | :--- |
## | **how long ago** | a letter fades — `commanders.md` §8's *argue with his intent* is not a standing order |
## | **how it was written** | desperate pulls harder and for longer than dutiful (`tone.md` §4) |
## | **what he thinks of the PC** | and this is what makes the other two matter or not |
##
## 🔒 **Which is why a disloyal commander is barely moved by even a desperate
## letter.** Tone raises the product and regard crushes it, and there is no tone
## strong enough to make a man who loathes the PC do as he is told — which is the
## whole of an order being a request rather than a command.
##
## **Only the option he was urged toward** scores here. A letter arguing for one
## thing says nothing about the other four, and scoring them negatively would
## make the PC's letter an argument against everything he did not mention.
class UrgingConsideration:
	extends Consideration

	func applies_to(candidate: Candidate) -> bool:
		var company := CommanderConsiderations._company_of(candidate)
		return company != null and not String(company.urged).is_empty() 			and candidate.id == company.urged

	func score(
		actor: DeliberationActor, candidate: Candidate, context: DeliberationContext
	) -> float:
		var company := CommanderConsiderations._company_of(candidate)
		if company == null:
			return 0.0
		# **One factor on the half-life, as the governor's urging does it**
		# (#262, `tone.md` §4): a consideration is clamped to one, so a fresh
		# letter is already at the ceiling and what a stronger tone buys is that
		# it is still pulling months later.
		var intensity := IntentConsiderations.intensity_of(company.urged_tone)
		var age := float(context.month - company.urged_month)
		return IntentConsiderations.decayed(
			age, CommanderConsiderations.URGING_HALF_LIFE * intensity
		) * CommanderConsiderations.regard_of(actor)


## A company doing nothing, in a war that is costing its town every month.
##
## Standing about is not free: `battles.md` §4 gives defence a running cost, and
## a commander who knows what his men eat has an opinion about earning it. Only
## holding scores against this, and only when there is nothing in front of him.
class IdlenessConsideration:
	extends Consideration

	func applies_to(candidate: Candidate) -> bool:
		return candidate.id == CommanderConsiderations.HOLD

	func score(
		_actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext
	) -> float:
		return 0.0 if CommanderConsiderations._enemy_of(candidate) != null else -0.5
