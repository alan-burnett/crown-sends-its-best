class_name DiplomatReport
extends RefCounted

## What the Diplomat has to say this month (#81, `the-diplomat.md` §2).
##
## ## 🔒 Locally correct, globally naive
##
## He names **one town** and proposes the obvious remedy for **its** problem,
## taking no account of the Crown's demands, the other towns, or what a tax cut
## does to standing. Shipping a town rum really would raise its quality of life;
## it is simply not a responsible way to run a colony, and he has no view from
## which to know that.
##
## ## 🔒 He never suggests something mechanically false
##
## He will not propose raising taxes to quell rebellion. That would be confusing
## rather than characterful, and it would teach the player to stop reading him —
## which is fatal for the one contact whose whole job is to be read.
##
## So the suggestions live **here, next to the trouble they answer**, rather than
## in the prose: a remedy that stopped working would be a line in a letter file
## nobody thought to check.

## The four things he watches, colony-wide (§2).
const SENTIMENT: String = "sentiment"
const SAFETY: String = "safety"
const HUNGER: String = "hunger"
const QUALITY: String = "quality"

## Where each becomes worth writing about. Tuning.
const SENTIMENT_WORTH_SAYING: float = 30.0
const SAFETY_WORTH_SAYING: float = 0.55
const QUALITY_WORTH_SAYING: float = 0.55

## Months of going without that he would call a crisis rather than a bad season.
const MONTHS_HUNGRY_IS_A_CRISIS: float = 6.0


## Every trouble he reports on, in the order he would raise them.
##
## **Sentiment first.** A town about to leave the Crown matters more than a town
## that is merely cold, and he knows the difference even when his advice about it
## is naive.
static func troubles() -> PackedStringArray:
	return PackedStringArray([SENTIMENT, SAFETY, HUNGER, QUALITY])


## The one thing he would put before the PC this month, or empty.
##
## 🔒 **One letter, not four.** He watches four things across every town, but a
## resident writing home picks the worst of them and says *that* — and a Diplomat
## who filed four separate reports a month would crowd the Crown's own business
## out of the post, which is the post's most limited resource.
##
## The four are on different scales, so each is expressed as a share of the point
## at which it stops being a grumble and starts being a crisis. Ties break in
## §2's order, which puts sentiment first: a town about to leave the Crown
## matters more than a town that is merely cold.
static func most_pressing(context: LetterContext) -> Dictionary:
	var worst: Dictionary = {}
	var most := 0.0
	for trouble in troubles():
		var town := worst_for(trouble, context)
		if town == null:
			continue
		var severity := _severity(trouble, town)
		if severity > most + 0.0001:
			most = severity
			worst = {"trouble": trouble, "town": town}
	return worst


## How near a crisis this trouble is in this town, as a share of one.
static func _severity(trouble: String, town: Town) -> float:
	match trouble:
		SENTIMENT:
			return clampf(
				(town.rebel_sentiment - SENTIMENT_WORTH_SAYING)
					/ maxf(1.0, Rebellion.DECLARES_AT - SENTIMENT_WORTH_SAYING), 0.0, 1.0)
		SAFETY:
			return clampf(
				(SAFETY_WORTH_SAYING - Diplomat.safety_of(town)) / SAFETY_WORTH_SAYING, 0.0, 1.0)
		HUNGER:
			return clampf(float(town.months_hungry) / MONTHS_HUNGRY_IS_A_CRISIS, 0.0, 1.0)
		QUALITY:
			return clampf(
				(QUALITY_WORTH_SAYING - town.quality_of_life) / QUALITY_WORTH_SAYING, 0.0, 1.0)
		_:
			return 0.0


## The town in the worst state of one trouble, or null if none is worth a letter.
##
## Ties break toward the larger town and then on the name, so which one he writes
## about is the colony's business rather than the iteration order's.
static func worst_for(trouble: String, context: LetterContext) -> Town:
	if context == null or context.colony == null:
		return null
	var worst: Town = null
	var most := 0.0
	for town in context.colony.in_order():
		if not has_lived(town, context):
			continue
		var badness := _badness(trouble, town)
		if badness <= 0.0:
			continue
		if worst == null or badness > most + 0.0001:
			worst = town
			most = badness
		elif absf(badness - most) <= 0.0001 \
				and (town.population() > worst.population()
					or (town.population() == worst.population()
						and String(town.id) < String(worst.id))):
			worst = town
			most = badness
	return worst


## 🔒 **He reports what he has seen, not what has not happened yet.**
##
## A town's quality of life and safety are written in Settle and are nothing
## before the first one — so a colony in its first month reads as wretched on
## every measure, and he was writing home about a famine in a place nobody had
## yet spent a night in. Asked of the log rather than of a month number, because
## a town founded in year four has its own first month too.
static func has_lived(town: Town, context: LetterContext) -> bool:
	if town == null or context == null or context.log == null:
		return false
	for event in context.log.of_type(SettlePhase.EVENT_LIVED):
		if event.subject == town.id:
			return true
	return false


## How bad this trouble is in this town, as a positive figure, or zero when it is
## not worth mentioning.
static func _badness(trouble: String, town: Town) -> float:
	match trouble:
		SENTIMENT:
			return maxf(0.0, town.rebel_sentiment - SENTIMENT_WORTH_SAYING)
		SAFETY:
			return maxf(0.0, SAFETY_WORTH_SAYING - Diplomat.safety_of(town))
		HUNGER:
			# **What he can see**, which is a town that has been going without —
			# not a figure off the reckoning. Months hungry is the plainest form
			# of it and it is the one a resident would actually notice.
			return float(town.months_hungry)
		QUALITY:
			return maxf(0.0, QUALITY_WORTH_SAYING - town.quality_of_life)
		_:
			return 0.0


## The remedy he would propose for a trouble.
##
## 🔒 **True, and narrow.** Each of these would genuinely work for the town it
## names — and none of them is a thing that would not work, which is the rule
## that keeps him worth reading.
static func suggestion_for(trouble: String) -> String:
	match trouble:
		SENTIMENT:
			return "lighten the duties on what they drink, and tell their governor to leave them be"
		SAFETY:
			return "tell their governor to see to the walls before anything else"
		HUNGER:
			return "tell their governor that nothing matters there but the harvest"
		QUALITY:
			return "send them something to drink, and do not ask what it costs"
		_:
			return "write to their governor"
