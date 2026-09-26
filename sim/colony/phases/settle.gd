class_name SettlePhase
extends ColonyPhase

## **Settle.** The month is totted up: how the town lived, whether it grew, and
## what it does next (SPEC §11.3, #50, #53).
##
## Four things happen, in this order, and the order is the reason it is one
## phase rather than four:
##
## 1. **Quality of life** is computed from the month that has just happened
##    (`QualityOfLife`, from `docs/mechanics/quality-of-life.md`).
## 2. **The population grows** from births, at a rate that reads the quality of
##    life just computed (SPEC §12.1).
## 3. **Each town reconsiders its objective**
##    (`docs/mechanics/governor-objectives.md` §7).
## 4. **The colony's condition** is settled: revenue is the duty the Crown
##    actually took (#47) and food security is what is left after eating (#48).
##
## ## 🔒 Quality of life is stored, and moved only here
##
## A reader that recomputed it would get a different answer halfway through a
## month and two readers would disagree. So it is written once, in Settle, and
## everything else in the game reads the field.
##
## ## 🔒 Rebel sentiment is not touched
##
## M3 owns it. QoL feeds sentiment, so sentiment must not feed back within a
## month (`quality-of-life.md` §7) — and the surest way to keep that true is that
## nothing here writes it at all.
##
## ## What is still a placeholder
##
## **Supply is a random walk.** Nothing derives it: it is the convoy, the Crown's
## shipping, the state of the road, and none of those are modelled. It moves so
## the letters do not go static, which is the failure #20 warns of, and it is not
## a model of anything.

const EVENT_SETTLED: StringName = &"colony_settled"
const EVENT_CONVOY_LOST: StringName = &"convoy_lost"
const EVENT_LIVED: StringName = &"town_lived"
const EVENT_BORN: StringName = &"town_grew"
const EVENT_CALVED: StringName = &"livestock_bred"

# --- Population (SPEC §12.1) ------------------------------------------------

## Births a month per head, in a town living well.
##
## **Natural growth starts slowly and snowballs**: it is a share of the
## population, so a town of twelve gains a person every year or so and a town of
## two hundred gains several a month. Immigration, which §12.1 calls the main
## source of early growth, is M4.
const BIRTH_RATE: float = 0.006

## Below this quality of life nobody is having children.
const BARREN_BELOW: float = 0.25

## What share of a grazing herd is added a month. Faster than people, because a
## town that buys two cows should see a herd inside a run rather than a dynasty.
const LIVESTOCK_RATE: float = 0.02

# --- The drift, which nothing yet replaces ---------------------------------

const SUPPLY_RECOVERY: float = 6.0
const SUPPLY_NOISE: float = 2.5
const WAR_DRAIN: float = 0.09
const CONVOY_LOSS_CHANCE: float = 0.15
const CONVOY_LOSS: float = 18.0

## How many months of food the colony holds to count as fully secure. Matches
## the perception range in `docs/mechanics/perception.md` §4.
const SECURE_MONTHS: float = 3.0

## Changes smaller than this are not worth a letter noticing.
const NOTICEABLE: float = 0.02


func run(town: Town, _before: ColonySnapshot, context: ColonyContext) -> void:
	_live(town, context)
	# **After quality of life and before anything reads it.** Sentiment is read
	# through how the town lived (`rebel-sentiment.md` §4), so it cannot be
	# worked out until this month's living is settled.
	_take_the_temperature(town, context)
	# **After sentiment and never before it** (#75). Sentiment is the largest
	# input to a protest and a protest is no input at all to sentiment, so the
	# order is what keeps that one-way (`trade-protests.md` §7). A protest
	# declared this month is a refusal from next month's Exchange, which is the
	# same announce-then-act shape rebellion has.
	TradeProtest.resolve(town, context)
	_grow(town, context)
	_reconsider(town, context)

	# The colony's condition is the colony's, not any one town's.
	if claim_month(context):
		_settle_the_colony(context)


## Whether the town would be better off without the Crown in its life (#71).
##
## **Computed fresh, with no carry-over term** (`rebel-sentiment.md` §3). The
## figure on the town is this month's answer rather than a running total, which
## is what makes attribution work: the same wretchedness counts one way under the
## Crown and the other way in rebellion, and a value that accumulated could not
## change its mind.
##
## **The payload carries the parts and never the figure.** §6 is explicit that
## sentiment is never a number the player sees — it surfaces through the
## Diplomat's ladders, the governor's tone, and his loyalty slipping. The parts
## are here so the Diplomat can say *what* is driving a trend, and `tools/lint.gd`
## keeps `presentation/` away from the lot of it.
func _take_the_temperature(town: Town, context: ColonyContext) -> void:
	var before := town.rebel_sentiment
	var parts := RebelSentiment.of(town, context, context.grievances, context.contacts)
	town.rebel_sentiment = float(parts["total"])

	var change := town.rebel_sentiment - before
	var direction := "steady"
	if change > NOTICEABLE:
		direction = "rising"
	elif change < -NOTICEABLE:
		direction = "settling"

	context.log.emit(RebelSentiment.EVENT_MEASURED, town.id, context.state.month, {
		"town": String(town.id),
		"direction": direction,
		# **What is driving it, never how much of it there is.** A payload
		# carrying the figure is a payload a letter could render.
		"largest": _loudest(parts),
		"rebelling": town.rebelling,
	}, WorldPhase.COLONY_MONTH)

	# **After the measuring and never before it** (#72). The state the next month
	# reads is the state this month earned, which is what lets attribution flip:
	# a town that declares in March is judged as a rebel from April.
	if Rebellion.resolve(town, context) == Rebellion.EVENT_DECLARED:
		town.rebelling_since = context.state.month
		# 🔒 **Rebellion kills the Diplomat outright** (#81, `the-diplomat.md`
		# §6). No roll. It is what gives his rehoming letter teeth: the letter is
		# the warning, and ignoring it is how the man is lost. Nobody takes his
		# place, and the run goes on blind.
		for id in _sorted(context.contacts):
			var contact: Contact = context.contacts[id]
			if contact != null and contact.role == Contact.ROLE_DIPLOMAT:
				Diplomat.rebellion_took_him(contact, town, context)

	# **An embargo runs down whether anybody remembers it or not.** A punishment
	# with no end is a punishment the PC cannot take back, and SPEC §12.3's
	# reward-and-punish pair only works if both are things he can stop doing.
	if town.embargo_months > 0:
		town.embargo_months -= 1
		if town.embargo_months == 0:
			context.log.emit(EmbargoExecutor.EVENT_LIFTED, town.id, context.state.month, {
				"town": String(town.id),
				"months": 0,
				"rebelling": town.rebelling,
			}, WorldPhase.COLONY_MONTH)


## Contact ids in a fixed order, since who is asked first must not depend on the
## order a dictionary happens to hold them in.
func _sorted(contacts: Dictionary) -> Array:
	var ids: Array = contacts.keys()
	ids.sort()
	return ids


## Which contributor is doing the most to a town's sentiment right now.
##
## What the Diplomat names when he reports. Ties break on the name so the answer
## is the colony's rather than the dictionary's.
func _loudest(parts: Dictionary) -> String:
	var loudest := ""
	var most := 0.0
	var names: Array = parts.keys()
	names.sort()
	for name in names:
		if String(name) == "total":
			continue
		var size := absf(float(parts[name]))
		if size > most + 0.000001:
			most = size
			loudest = String(name)
	return loudest


## How the town lived this month.
func _live(town: Town, context: ColonyContext) -> void:
	var parts := QualityOfLife.of(town, context)
	var before := town.quality_of_life
	town.quality_of_life = float(parts["quality_of_life"])
	# **Alongside it, from the same reckoning** (#81). Safety is one of the five
	# parts, and the Diplomat asks to be moved on it — so it is written where
	# quality of life is rather than measured again wherever it is wanted.
	town.safety = clampf(float(parts["safety"]), 0.0, 1.0)

	# **And how the poorest of them lived** (#277), out of the same five parts.
	# The clergyman's regard answers to this and his letters report it, so the
	# figure he writes about has to be the one the town lived by.
	town.poorest_quality_of_life = QualityOfLife.from_below(parts)

	# **Alongside quality of life, and for the same reason** (#168): a reader
	# that recomputed it mid-month would get a different answer from the one the
	# growth roll used.
	Education.settle(town, context)

	# **The direction and rough magnitude**, so a governor's letter can say that
	# things are looking up without the letter doing arithmetic — and so it
	# cannot say so when they are not (SPEC §9.1).
	var change := town.quality_of_life - before
	var direction := "steady"
	if change > NOTICEABLE:
		direction = "better"
	elif change < -NOTICEABLE:
		direction = "worse"

	context.log.emit(EVENT_LIVED, town.id, context.state.month, {
		"town": String(town.id),
		"quality_of_life": town.quality_of_life,
		"was": before,
		"change": change,
		"direction": direction,
		"health": float(parts["health"]),
		"safety": float(parts["safety"]),
		"means": float(parts["means"]),
		"hope": float(parts["hope"]),
		"pleasure": float(parts["pleasure"]),
	}, WorldPhase.COLONY_MONTH)


## Births (#172, `immigration.md` §3 and §8). **Not immigration**, which lands in
## phase 1 and is the larger source while a town is small.
##
## 🔒 **Proportional to population**, where arrivals are flat. That one difference
## is what makes immigration dominate at twelve people and natural growth at two
## hundred, and it falls out of the two formulas rather than being balanced
## between them.
##
## It reads quality of life too — **people have children when life is good** — so
## a thriving town compounds and a wretched one merely persists.
##
## 🔒 **Population moves one at a time — in the log.** The remainder is carried
## and whole people are delivered, and each of them is **its own event**, exactly
## as a famine resolves one life at a time. `CLAUDE.md`'s rule is about keeping
## per-population consequences uniform and legible rather than about the
## arithmetic, and a cap on the arithmetic would flatly contradict §12.1's
## snowball: a town past two hundred is owed more than a person a month, and one
## that could only ever be given one would grow linearly for ever.
func _grow(town: Town, context: ColonyContext) -> void:
	if town.quality_of_life < BARREN_BELOW or town.population() <= 0:
		return

	var rate := BIRTH_RATE * (1.0 + Building.growth_bonus_for(town))
	var people := float(town.population()) * rate * town.quality_of_life

	# **Education gates natural growth, not arrivals** (`the-provost.md` §3). An
	# unlettered town turns all of its growth into hands; a learned one turns some
	# of it into expertise, and the fraction waits until it is a whole man (#169).
	var scholars := people * Experts.share_of_growth(town)
	Experts.accrue(town, scholars)
	town.growth_accrued += people - scholars

	_breed(town, context)
	Experts.materialise(town, context, Experts.RAISED, WorldPhase.COLONY_MONTH)

	# **Whole people land, the fraction carries** (#426, `population.md` §6), in
	# one event that says how many: a town of thousands has dozens of children a
	# month, and an event for each would be a log of births and nothing else.
	var born := int(floor(town.growth_accrued))
	if born <= 0:
		return
	town.growth_accrued -= float(born)
	town.workers += born
	context.log.emit(EVENT_BORN, town.id, context.state.month, {
		"town": String(town.id),
		"born": born,
		"population": town.population(),
	}, WorldPhase.COLONY_MONTH)


## The herds breed, up to what there is to graze them on.
##
## 🔒 **Pasture is the ceiling, not the rate.** A herd inside its pasture grows;
## one already over it does not, because the beasts beyond capacity are the ones
## Consume is buying grain to feed. So a town pastures first and breeds after,
## and the granary that speeds its children speeds its calves with them
## (`buildings.md` §4).
func _breed(town: Town, context: ColonyContext) -> void:
	var room := float(Building.pasture_capacity_for(town))
	if context.map != null:
		for at in context.tiles_of(town):
			room += float(context.map.livestock_capacity_at(at.x, at.y))
	if room <= 0.0:
		return

	var rate := LIVESTOCK_RATE * (1.0 + Building.growth_bonus_for(town))
	for id in ResourceCatalogue.livestock():
		var kind := StringName(id)
		var head := float(town.livestock_head(kind))
		var grazing := minf(head, room)
		room -= grazing
		if grazing < 1.0:
			continue
		# **Whole head land, the fraction carries, and nothing caps it** (#427,
		# `population.md` §6): a herd of thousands calves by the dozen.
		# 🔒 **Faster breeding of a patron's kind** (#442, `patrons.md` §4).
		var breeds := rate * (1.0 + PolicyEffects.more_of(context.state, kind))
		town.livestock_accrued[id] = float(town.livestock_accrued.get(id, 0.0)) + grazing * breeds
		var calves := int(floorf(float(town.livestock_accrued[id])))
		if calves <= 0:
			continue
		town.livestock_accrued[id] = float(town.livestock_accrued[id]) - float(calves)
		town.add_livestock(kind, calves)
		context.log.emit(EVENT_CALVED, town.id, context.state.month, {
			"town": String(town.id),
			"kind": id,
			"born": calves,
			"head": town.livestock_head(kind),
		}, WorldPhase.COLONY_MONTH)


## Walk the menu when the objective is done, open, or no longer his intent's.
func _reconsider(town: Town, context: ColonyContext) -> void:
	var verdict := Reconsideration.verdict(town)
	if verdict == Reconsideration.NONE:
		return

	if verdict == Reconsideration.STALLED:
		Reconsideration.stall(town, context)

	if verdict == Reconsideration.INTENT_CHANGED:
		# **The new intent may want the very same thing.** Go wide and go tall
		# both list the granary; tearing down a half-raised frame to begin the
		# same frame would forfeit the timber for nothing, so the project carries
		# on and now serves the new intent.
		var instead := ObjectiveSelector.choose(town, town.intent, context)
		if instead["id"] == town.objective and instead["target"] == town.objective_target:
			town.objective_intent = town.intent
			return
		Reconsideration.abandon(town, verdict, context)

	var chosen := ObjectiveSelector.choose(town, town.intent, context)
	if chosen["id"] == &"":
		return
	# **Still nothing worth building**: the town stays on the fallback and says
	# nothing new. A month of *no building* is not news.
	if verdict == Reconsideration.OPEN and chosen["id"] == town.objective:
		return

	town.objective = chosen["id"]
	town.objective_target = chosen["target"]
	town.objective_intent = town.intent
	town.objective_since = context.state.month
	town.objective_progress = 0
	town.objective_idle_months = 0
	town.objective_invested = {}

	context.log.emit(ObjectiveSelector.EVENT_CHOSEN, town.id, context.state.month, {
		"town": String(town.id),
		"objective": String(town.objective),
		"name": Objective.display_name(town.objective),
		"kind": String(Objective.kind_of(town.objective)),
		"target": town.objective_target,
		"intent": String(town.intent),
		"after": String(verdict),
	}, WorldPhase.COLONY_MONTH)


func _settle_the_colony(context: ColonyContext) -> void:
	var state := context.state
	var rng := context.streams.stream("sim")

	var war := float(state.get_value(WorldValues.WAR, 0.0))
	var supply := float(state.get_value(WorldValues.SUPPLY, 0.0))

	# The war pulls supply down; the colony pulls it back up. Which wins this
	# month is what the Marshal and the Steward end up arguing about.
	supply += SUPPLY_RECOVERY - war * WAR_DRAIN
	supply += rng.randf_range(-SUPPLY_NOISE, SUPPLY_NOISE)

	if rng.randf() < CONVOY_LOSS_CHANCE:
		supply -= CONVOY_LOSS
		context.log.emit(EVENT_CONVOY_LOST, &"colony", state.month, {
			"supply_lost": CONVOY_LOSS,
		}, WorldPhase.COLONY_MONTH)

	state.apply(context.log, EVENT_SETTLED, &"colony", {
		WorldValues.SUPPLY: clampf(supply, 0.0, 100.0),
		WorldValues.REVENUE: context.crown_tax,
		# What a month lately brings, so a judgement about the returns is made
		# against this colony rather than against a constant (#63).
		WorldValues.REVENUE_BASELINE: WorldValues.followed_baseline(state, context.crown_tax),
		WorldValues.FOOD: _food_security(context),
		WorldValues.QUALITY_OF_LIFE: _colony_quality_of_life(context),
		# What the Provost reports on and what his regard answers to (#174).
		WorldValues.EDUCATION: _colony_education(context),
	}, WorldPhase.COLONY_MONTH)


## What the colony has worth teaching, averaged over its towns (#174).
##
## **A mean and not a total**, so a colony does not read as learned merely by
## being large — and so the figure means the same thing in year one as in year
## eight.
func _colony_education(context: ColonyContext) -> float:
	if context.colony == null or context.colony.is_empty():
		return 0.0
	var total := 0.0
	var towns := 0
	for town in context.colony.in_order():
		total += maxf(0.0, town.education)
		towns += 1
	return 0.0 if towns == 0 else total / float(towns)


## Months of food the colony is holding, per mouth, capped.
##
## **Read after Consume, so it is what is actually left**, not what was harvested
## and then eaten. This is the number the Steward quotes and the governors write
## around, and SPEC §9.1 makes letters matching the simulation an invariant — so
## it had better be the food that is really in the storehouses.
func _food_security(context: ColonyContext) -> float:
	if context.colony == null or context.colony.is_empty():
		return 0.0

	var held := 0.0
	var mouths := 0.0
	for town in context.colony.in_order():
		held += town.held(&"food")
		mouths += float(town.population())
	if mouths <= 0.0:
		return 0.0

	var monthly := Population.of(ColonyNeeds.per_head(&"food"), mouths)
	if monthly <= 0.0:
		return 0.0
	return clampf(held / monthly, 0.0, SECURE_MONTHS)


## How the colony is living, **weighted by where people actually are**.
##
## A colony of one wretched hamlet and one thriving city is not living averagely;
## it is mostly living the way the city does, because that is where most of it
## is. Weighting by population is what makes the Crown's impression of the
## colony match the impression of the average colonist.
func _colony_quality_of_life(context: ColonyContext) -> float:
	if context.colony == null or context.colony.is_empty():
		return 0.0
	var total := 0.0
	var mouths := 0.0
	for town in context.colony.in_order():
		var here := float(town.population())
		total += town.quality_of_life * here
		mouths += here
	if mouths <= 0.0:
		return 0.0
	return clampf(total / mouths, 0.0, 1.0)
