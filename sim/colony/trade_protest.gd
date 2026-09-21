class_name TradeProtest
extends RefCounted

## When a town refuses to deal in one resource (#75, SPEC §10.2;
## `docs/mechanics/trade-protests.md`).
##
## ## 🔒 It is the people's decision
##
## **A calculation, not a deliberation.** No actor chooses it: a score per town
## per resource is recomputed every month and a protest begins when it crosses a
## threshold, the same shape as rebellion — which is a protest's larger sibling.
##
## The governor is an *input*, because his regard for the Crown colours his
## town's, but the refusal is not his. A governor who wants to hurt the Crown has
## his own route and it is intent, not this. Nothing here goes through
## `Deliberation`, and #131 removed the decision kind on purpose.
##
## ## 🔒 A town trends toward one protest at a time. A resource does not.
##
## Each protest running in a town raises **that town's** threshold for starting
## another — not the colony's. A town on the brink over both beer and tea, whose
## beer protest fires, has room before tea follows: it has made its point, and
## the colony keeps trading with an unruly town rather than watching every
## resource shut at once.
##
## But rates are per resource and colony-wide, so raising the duty on furs raises
## the score on furs in every town in the same month. One is a town's patience;
## the other is the PC's own decision arriving everywhere he rules at once, and
## that second one is agency — he did that, on purpose, with one letter.
##
## ## 🔒 A rise provokes; a level is merely resented
##
## The duty is two terms rather than one. A town living with a punishing rate for
## two years is angrier than one just raised to half of it, and **less likely to
## act.** Both fall out of one number: the rate the town is *used to*, which
## creeps toward the real one. A rise opens a gap that erodes as the town gets
## used to it, and a cut opens it the other way — which is why §6's rate cut
## lifts a protest more readily than a merely low rate sustains one.
##
## ## 🔒 Sentiment feeds protests; protests do not feed sentiment
##
## There is no term in either direction beyond that, and everything that looks
## like a link runs through the world instead. A clothing protest leaves people
## cold, quality of life falls, and sentiment rises because quality of life is
## one of its contributors. A protest stops the duty being paid at all, and the
## tax term falls because the town is no longer paying it — that one needs no
## code, since `RebelSentiment._tax` reads the duty actually collected.
##
## Neither is a protest term. Both keep `rebel-sentiment.md`'s acyclicity intact.

const EVENT_DECLARED: StringName = &"trade_protest_declared"
const EVENT_LIFTED: StringName = &"trade_protest_lifted"
const EVENT_FAMILIARITY: StringName = &"duty_familiarity"

## Movement in the familiar rate smaller than this is not worth an event.
const SETTLED: float = 0.0005

## Where a protest begins and where it ends. The gap is hysteresis, for the same
## reason rebellion has it: a town that flickers month to month is noise rather
## than drama. Tuning.
const DECLARES_AT: float = 60.0
const LIFTS_AT: float = 40.0

## What each protest already running here adds to the bar for the next. Tuning.
const RUNWAY_PER_PROTEST: float = 22.0

## What the rate a town is used to lives under, per resource. In `WorldState`, so
## it serialises with the save and shows up in the world diff like any rate.
const FAMILIAR_PREFIX: String = "protest.familiar."

## How much of the way the familiar rate moves toward the real one each month.
##
## **This is the whole of §2's asymmetry.** At a fifth a year, a rise is most of
## a grievance for half a year and spent within two. Tuning.
const GETTING_USED_TO_IT: float = 0.05

# --- What the six inputs are worth, all tuning (§10) -------------------------
#
# **The duty outweighs the ambient on purpose.** Three of the six inputs —
# sentiment, quality of life, the governor — are properties of the *town*, so
# they say the same thing about every resource and can only decide how ready it
# is. Only the duty distinguishes one resource from another, and the duty is what
# a protest is about. When the ambient dominated, a wretched town always refused
# whichever luxury was cheapest to refuse and §4's food protest was unreachable
# at any rate whatsoever — a weighting that made the reversal decorative.

## Rebel sentiment, scaled off its own rebellion threshold so the two models
## speak the same language: a town at the point of revolt contributes all of it.
const SENTIMENT_WEIGHT: float = 30.0

## The duty being paid at all, at its steepest.
const LEVEL_WEIGHT: float = 70.0

## And the duty having just gone up, which provokes where a level only galls.
const RISE_WEIGHT: float = 220.0

## Wretchedness, which makes a town less willing to be taken from.
const QUALITY_WEIGHT: float = 18.0

## The governor's regard, through the same prominence rule sentiment uses.
const GOVERNOR_WEIGHT: float = 14.0

## How the resource's place in the town's life scales the whole grievance.
##
## 🔒 **Weighted opposite, not excluded** (§4). A town can do without rum, which
## makes refusing it the cheapest way to tell the Crown no. Food and clothing are
## the least likely and **still reachable** — things can get bad enough that a
## town would rather starve than pay, and when that happens it is one of the
## loudest things the simulation can say.
## The bands are spread rather than steep, because §4's reachability is a real
## requirement: at 0.18 a food protest needed the duty to leap from nothing to
## everything in one month, which is not "rare" — it is decorative.
const LUXURY_APPETITE: float = 1.0
const ORDINARY_APPETITE: float = 0.68
const NEED_APPETITE: float = 0.50

## What a town keeps back when refusing would cost it its livelihood (§5).
##
## **A town that buys a resource goes without it; a town that sells it loses the
## income**, and that bites far harder than giving up rum. A fur town refusing
## furs is refusing its own wages.
##
## This is also the whole of why **tea sits where it does by mechanics rather
## than by priority** (§4). Tea is the one resource in the data nobody can
## produce, so no town ever holds this back on it, while the luxuries a town
## brews or rolls for itself are dear to refuse. Nothing here knows what tea is.
const SELLS_IT_DISCOUNT: float = 0.4


## Which resources a town is refusing to deal in, sorted.
static func running_in(town: Town) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(town.protests)
	out.sort()
	return out


static func is_protesting(town: Town, resource: StringName) -> bool:
	return town.protests.has(String(resource))


## What this town feels about the duty on this resource, this month.
##
## Returns the parts as well as the total, so the Steward can name which term
## dominated without re-deriving it — and so a test can ask about one input
## without inferring it from the sum.
static func score(town: Town, resource: StringName, context: ColonyContext) -> Dictionary:
	var rate := context.tax_rate(resource)
	var used_to := familiar_rate(context.state, resource)

	var parts: Dictionary = {}
	# **Scaled against the point of revolt**, so the two models are commensurate:
	# a town at 65 brings the whole of this term and a contented one brings none.
	parts["sentiment"] = SENTIMENT_WEIGHT \
		* clampf(town.rebel_sentiment / Rebellion.DECLARES_AT, 0.0, 1.0)
	parts["level"] = LEVEL_WEIGHT * clampf(rate, 0.0, 1.0)
	# 🔒 **A rise only.** A cut makes this negative on purpose, which is what lets
	# lowering the duty lift a protest faster than a low rate would have kept one
	# from starting (§6).
	parts["rise"] = RISE_WEIGHT * (rate - used_to)
	parts["quality"] = QUALITY_WEIGHT * clampf(1.0 - town.quality_of_life, 0.0, 1.0)
	parts["governor"] = _governor(town, context)

	var grievance := 0.0
	for key in parts:
		grievance += float(parts[key])

	# **Appetite scales the whole thing rather than adding to it.** A town does
	# not resent a duty on rum *and separately* find rum easy to give up — the
	# ease of giving it up is what makes the resentment worth acting on.
	var appetite := appetite_for(resource, town, context)
	parts["appetite"] = appetite
	parts["total"] = maxf(0.0, grievance) * appetite
	return parts


## How readily this town would give the resource up.
##
## The band it falls in, and then what refusing would actually cost *this* town.
static func appetite_for(
	resource: StringName,
	town: Town = null,
	context: ColonyContext = null,
) -> float:
	var band := ORDINARY_APPETITE
	if ResourceCatalogue.is_luxury(resource):
		band = LUXURY_APPETITE * _softest(resource)
	# **Asked of the needs table rather than named here.** Nothing in this file
	# knows what food is; a third survival resource in the data would be weighted
	# with the other two without anybody remembering to come back.
	elif ColonyNeeds.per_head(resource) > 0.0:
		band = NEED_APPETITE

	if town != null and _makes_it(town, resource, context):
		band *= SELLS_IT_DISCOUNT
	return band


## Where a duty lands **softest**, among the pleasures (§4).
##
## 🔒 **Tea sits where it does by mechanics and not by priority.** The doc is
## explicit that if tea does not come out early the prices or the weights are
## wrong, not the rule — so price is in the model, and this is where. **The
## cheapest pleasure is the one least is lost by giving up**, and a duty on it
## therefore lands on a comfortable town exactly where it is least defended.
##
## Measured against the cheapest luxury in the data rather than an authored
## figure, so adding a pleasure to the catalogue re-ranks the lot of them without
## anything here being edited. Nothing in this file knows what tea is; what makes
## tea come first is that it is the cheapest of them **that no town can make**,
## and the second half of that is `_makes_it`.
##
## Applied to pleasures only. §4 gives needs one rule — weighted opposite — and
## says nothing about ranking them against each other, so they keep the flat
## band rather than acquiring a price mechanism the doc has not asked for.
static func _softest(resource: StringName) -> float:
	var cheapest := 0.0
	for id in ResourceCatalogue.ids():
		var other := StringName(id)
		if not ResourceCatalogue.is_luxury(other):
			continue
		var price := ResourceCatalogue.price_of(other)
		if price > 0.0 and (cheapest <= 0.0 or price < cheapest):
			cheapest = price
	var mine := ResourceCatalogue.price_of(resource)
	if cheapest <= 0.0 or mine <= 0.0:
		return 1.0
	return clampf(cheapest / mine, 0.0, 1.0)


## Whether this town's own living comes partly out of this resource.
##
## Its ground or its loom, asked the same way a scholar's specialism is (#169) —
## so a town is reluctant to refuse the thing it sells without anything here
## being told which towns those are.
static func _makes_it(town: Town, resource: StringName, context: ColonyContext) -> bool:
	if context == null:
		return false
	if context.map != null:
		for at in context.tiles_of(town):
			if context.map.yield_at(at.x, at.y, resource) > 0.0:
				return true
	for entry in Conversion.all():
		var recipe: Conversion = entry
		if recipe.output != resource:
			continue
		var takes := recipe.consumes_for(town)
		if recipe.made_by(town) > 0.0 and takes > 0.0 and town.held(recipe.input) >= takes:
			return true
	return false


## The bar this town must clear to start *another* protest (§3).
static func threshold_for(town: Town) -> float:
	return DECLARES_AT + RUNWAY_PER_PROTEST * float(town.protests.size())


## The rate this town has got used to paying on a resource.
static func familiar_rate(state: WorldState, resource: StringName) -> float:
	if state == null:
		return 0.0
	var key := FAMILIAR_PREFIX + String(resource)
	if not state.has_value(key):
		return TaxRates.rate_for(state, resource)
	return float(state.get_value(key, 0.0))


## Recompute every town's protests for the month (Seam A).
##
## Called from Settle with the sentiment just measured, so a protest declared in
## March is a refusal from April — the same announce-then-act shape as rebellion,
## and the reason the PC has a month to answer the Steward's letter.
static func resolve(town: Town, context: ColonyContext) -> void:
	# **A rebelling town already refuses the Crown entirely** (§11.3), so a
	# protest there is moot and subsumed. Its running protests stand; they simply
	# change nothing while it is out.
	if town.rebelling:
		return

	var scores: Dictionary = {}
	for id in ResourceCatalogue.ids():
		scores[id] = float(score(town, StringName(id), context)["total"])

	# **Lifting first**, so a month that ends one protest is a month with room
	# for another — and so the bar the next declaration must clear is the bar
	# after this month's news rather than before it.
	for id in running_in(town):
		if float(scores[id]) > LIFTS_AT:
			continue
		town.protests.erase(id)
		context.log.emit(EVENT_LIFTED, town.id, context.state.month, {
			"town": String(town.id),
			"resource": id,
			"running": running_in(town),
		}, WorldPhase.COLONY_MONTH)

	# 🔒 **One a month, and it is the one felt most** (§3). A town over the line
	# on everything at once makes its point *once*, and the bar it must clear
	# next month is higher for having done so — so a second follows only under
	# continued pressure. Taking the loudest rather than the first is what keeps
	# the choice the town's: picking in catalogue order would have "beer" beat
	# "tea" because of the alphabet.
	var worst := &""
	var most := 0.0
	var bar := threshold_for(town)
	for id in ResourceCatalogue.ids():
		if is_protesting(town, StringName(id)):
			continue
		var total := float(scores[id])
		if total < bar or total <= most + 0.0001:
			continue
		worst = StringName(id)
		most = total
	if String(worst).is_empty():
		return

	town.protests.append(String(worst))
	town.protests.sort()
	context.log.emit(EVENT_DECLARED, town.id, context.state.month, {
		"town": String(town.id),
		"resource": String(worst),
		"luxury": ResourceCatalogue.is_luxury(worst),
		"rate": context.tax_rate(worst),
		"loudest": _loudest(score(town, worst, context)),
		"running": running_in(town),
		# 🔒 **Prestige is one-off, at declaration** (§8). Nothing charges it yet
		# — #76 is the ticket — and carrying it here means that ticket is a
		# reader of this event rather than a change to this file. There is
		# deliberately no ongoing drain: a protest already costs the duty on that
		# resource, and charging twice would make protests dominate the score for
		# the wrong reason.
		"prestige": true,
	}, WorldPhase.COLONY_MONTH)


## Let the colony get a little more used to what it is paying.
##
## **Once a month for the colony, not once per town**, because the rate is the
## colony's — settled before the month's first phase so every town then judges a
## rise against the same figure, exactly as upkeep is settled there.
static func settle_familiarity(context: ColonyContext) -> void:
	if context == null or context.state == null:
		return
	var changes: Dictionary = {}
	for id in ResourceCatalogue.ids():
		var key := FAMILIAR_PREFIX + id
		var rate := TaxRates.rate_for(context.state, StringName(id))
		if not context.state.has_value(key):
			# **A town starts used to what it is already paying.** Without this
			# first write the fallback would keep returning the live rate, and a
			# rise would be measured against itself — no rise, ever.
			changes[key] = rate
			continue
		var used_to := float(context.state.get_value(key, 0.0))
		var moved := used_to + (rate - used_to) * GETTING_USED_TO_IT
		if absf(moved - used_to) > SETTLED:
			changes[key] = moved

	# **Through `apply`, like any other world value** (Seam A), and only when
	# something actually moved — in steady state a colony is used to its duties
	# and this writes nothing at all.
	if changes.is_empty():
		return
	context.state.apply(
		context.log, EVENT_FAMILIARITY, &"colony", changes, WorldPhase.COLONY_MONTH)


## What the governor's regard is worth here.
##
## **The same prominence rule sentiment uses**, so a governor whose role field
## was never filled in is not a silent zero in a term he should dominate.
static func _governor(town: Town, context: ColonyContext) -> float:
	if context == null:
		return 0.0
	var contact: Contact = context.contacts.get(String(town.governor_id))
	if contact == null:
		return 0.0
	return GOVERNOR_WEIGHT \
		* (RebelSentiment.LOYALTY_NEUTRAL - contact.loyalty()) / RebelSentiment.LOYALTY_NEUTRAL


## Which term drove this, for the Steward to name. Ties break on the name.
static func _loudest(parts: Dictionary) -> String:
	var loudest := ""
	var most := 0.0
	var names: Array = parts.keys()
	names.sort()
	for name in names:
		if String(name) == "total" or String(name) == "appetite":
			continue
		var size := absf(float(parts[name]))
		if size > most + 0.000001:
			most = size
			loudest = String(name)
	return loudest
