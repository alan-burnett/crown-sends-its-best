class_name M1Registrations
extends RefCounted

## The effects and conditions M1 needs, and the measures its letters judge.
##
## Registering is the whole of it. **Every one of these is a declaration**, not a
## handler with a body: an effect says what Order it makes, and the registry
## builds it. That is what makes "no effect handler writes sim state" (Seam B)
## true by construction rather than by review.
##
## A later milestone adds entries here, or registers its own from its own system.
## Neither the letter schema nor the renderer changes when it does.

# --- Order kinds -----------------------------------------------------------

const ORDER_PROMISE_GOLD: StringName = &"promise_gold"
const ORDER_PROMISE_RESOURCE: StringName = &"promise_resource"
const ORDER_PROMISE_REVENUE: StringName = &"promise_revenue"
const ORDER_DECLINE_DEMAND: StringName = &"decline_demand"
const ORDER_SHIP_RESOURCE: StringName = &"ship_resource"
const ORDER_PROMISE_SHIPMENT: StringName = &"promise_shipment"
const ORDER_EMBARGO: StringName = &"embargo"
const ORDER_ENACT_POLICY: StringName = &"enact_policy"
const ORDER_FUND_POLICY: StringName = &"fund_policy"
const ORDER_END_POLICY: StringName = &"end_policy"
const ORDER_REFUSE: StringName = &"refuse"
const ORDER_GRANT_FAVOR: StringName = &"grant_favor"
const ORDER_SET_POLICY: StringName = &"set_policy"

## **Paying a foreigner to leave you alone** (#69, `crown-demands.md` §4).
##
## The fourth asker's currency, and the reason he is in the table at all: a PC
## can be solvent, meeting every Crown demand, and still despised at court for
## having done this.
const ORDER_PAY_TRIBUTE: StringName = &"pay_tribute"

## **The third door** (#284, `patrons.md` §5). Sending the duke to collect from
## the patron's house instead: it costs no gold, no loyalty and no optic, and it
## is worth two demands — the one deflected and the one skipped.
const ORDER_DEFLECT_TRIBUTE: StringName = &"deflect_tribute"

## **A preference about where a town goes** (#177, SPEC §11.4).
##
## 🔒 The PC approves, refuses, or states a preference. **He never chooses a
## tile**, and the effect's params are where that is enforced: there is nowhere
## in them to put a coordinate.
const ORDER_PREFER_SITE: StringName = &"prefer_site"

## **The Crown sends a town** (#180, `founding-towns.md` §3), and the PC argues
## about it. Two kinds, because agreeing and objecting are not the same act: the
## first settles what the town is equipped with, the second is a letter the
## contact may simply not take.
const ORDER_FUND_FOUNDING: StringName = &"fund_founding"
const ORDER_DISSUADE_FOUNDING: StringName = &"dissuade_founding"
const ORDER_REQUEST_TROOPS: StringName = &"request_troops"
const ORDER_ADJUST_LOYALTY: StringName = &"adjust_loyalty"
const ORDER_SET_TAX_RATE: StringName = &"set_tax_rate"

## **Send the Diplomat to a town** (#393, `the-diplomat.md` §3, §7).
##
## Addressed to him and decided by him: agreeing to the move he asked for and
## sending him toward trouble are the same Order, and he may refuse either.
const ORDER_MOVE_DIPLOMAT: StringName = &"move_diplomat"

## **A duty set aside for a stated number of months** (#278,
## `institutional-contacts.md` §3).
##
## Not a rate change. A rate change is standing and this one reverts on its own,
## so `TaxWaiver` counts it down in the Crown's month — but it reaches the world
## the same way any rate does, through `WorldValueExecutor`, because it is a
## named world value being set.
const ORDER_WAIVE_DUTY: StringName = &"waive_duty"

## **The only order that reaches a town** (SPEC §8.5, #53). It argues for a goal
## and names no project, no tile and no month. The letters that use it are #54.
const ORDER_URGE_INTENT: StringName = &"urge_intent"


## Populate the resource catalogue and the terrain table from loaded content.
##
## Separate from `register_all()` because it needs the content database, and the
## registries deliberately do not.
static func load_resources(content: ContentDatabase) -> void:
	var records: Array = []
	for id in content.ids("resources"):
		records.append(content.collection("resources")[id])
	ResourceCatalogue.load_from(records)

	var terrains: Array = []
	var levels: Dictionary = {}
	for id in content.ids("terrain"):
		var record: Dictionary = content.collection("terrain")[id]
		if record.has("levels"):
			levels = record["levels"]
		else:
			terrains.append(record)
	Terrain.load_from(terrains, levels)

	var improvements: Array = []
	for id in content.ids("improvements"):
		improvements.append(content.collection("improvements")[id])
	Improvement.load_from(improvements)

	var buildings: Array = []
	for id in content.ids("buildings"):
		buildings.append(content.collection("buildings")[id])
	Building.load_from(buildings)

	if content.has_record("colony", "needs"):
		ColonyNeeds.load_from(content.record("colony", "needs"))
	if content.has_record("colony", "spending"):
		Spending.load_from(content.record("colony", "spending"))

	if content.has_record("colony", "objectives"):
		Objective.load_from(content.record("colony", "objectives"))
	# The six intents, their stockpiles and the considerations table (#428).
	if content.has_record("colony", "agendas"):
		Objective.load_intents(content.record("colony", "agendas"))
		IntentConsiderations.load_table(content.record("colony", "agendas"))
		AgendaMenu.load_from(content.record("colony", "agendas"))

	if content.has_record("crown", "demands"):
		DemandSchedule.load_from(content.record("crown", "demands"))
	# What a man has to mind before he writes (#255). Per role, in data, because
	# *enough to write about* is a harness sweep rather than a judgement.
	if content.has_record(Threshold.COLLECTION, Threshold.RECORD):
		Threshold.load_from(content.record(Threshold.COLLECTION, Threshold.RECORD))
	# And whether he still bothers to ask (#259). Loyalty gates the kind of
	# letter, never the number, so this is a filter on questions and offers and
	# leaves every request alone.
	if content.has_record(Consultation.COLLECTION, Consultation.RECORD):
		Consultation.load_from(content.record(Consultation.COLLECTION, Consultation.RECORD))
	# The one sentence a harsh letter adds (#263). Prose, so it lives in the
	# language-suffixed folder with everything else the player reads.
	if content.has_record(HarshClause.COLLECTION, HarshClause.RECORD):
		HarshClause.load_from(content.record(HarshClause.COLLECTION, HarshClause.RECORD))
	# How a letter addresses the PC (#358). The other end of `names.md` §2 from
	# the letterhead, and prose for the same reason.
	if content.has_record(Salutation.COLLECTION, Salutation.RECORD):
		Salutation.load_from(content.record(Salutation.COLLECTION, Salutation.RECORD))
	if content.has_record(IndependenceClause.COLLECTION, IndependenceClause.RECORD):
		IndependenceClause.load_from(
			content.record(IndependenceClause.COLLECTION, IndependenceClause.RECORD))
	# Where a generated name comes from (#304). No language suffix: a bag carries
	# no prose and is not translated.
	NameBags.load_from(content)
	# What a generated resident starts from (#277). A template rather than a
	# contact, in the same collection as every other contact record.
	ContactRoster.load_from(content)
	# Who a patron can be (#282). No language suffix either: the catalogue is a
	# list of ids and a vice is a list of knobs, and neither carries a word the
	# player reads.
	# What a company wants and what a month without rations costs it (#211).
	if content.has_record(Company.COLLECTION, Company.RECORD):
		Company.load_from(content.record(Company.COLLECTION, Company.RECORD))
		Raising.load_from(content.record(Company.COLLECTION, Company.RECORD))
	# And what each of §5's six factors is worth (#214).
	if content.has_record(Force.COLLECTION, Force.RECORD):
		Force.load_from(content.record(Force.COLLECTION, Force.RECORD))
	# And how hard a battle hits (#216).
	if content.has_record(Battle.COLLECTION, Battle.RECORD):
		Battle.load_from(content.record(Battle.COLLECTION, Battle.RECORD))
	# And what a commander learns in the field (#223).
	if content.has_record(CommanderExperience.COLLECTION, CommanderExperience.RECORD):
		CommanderExperience.load_from(
			content.record(CommanderExperience.COLLECTION, CommanderExperience.RECORD))
	if content.has_record(Patron.COLLECTION, Patron.CATALOGUE_RECORD):
		Patron.load_from(content.record(Patron.COLLECTION, Patron.CATALOGUE_RECORD))
	if content.has_record(PatronVices.COLLECTION, PatronVices.RECORD):
		PatronVices.load_from(content.record(PatronVices.COLLECTION, PatronVices.RECORD))


static func register_all() -> void:
	register_effects()
	register_conditions()
	register_measures()
	register_considerations()
	M1ParamSources.register_all()
	# **A milestone that adds a system ships that system's content hooks with
	# it.** The colony's conditions and param sources arrive with the colony.
	ColonyConditions.register_all()
	ColonyParamSources.register_all()


## **A milestone that adds a system ships that system's considerations with it.**
static func register_considerations() -> void:
	ComplianceConsiderations.register_all()
	UnansweredConsiderations.register_all()
	IntentConsiderations.register_all()
	# **A milestone that adds a system ships that system's considerations with
	# it** (#221). A commander scores every option open to him, and refusal is
	# attack scoring below retreat rather than a branch.
	CommanderConsiderations.register_all()
	CoordinationConsiderations.register_all()
	# 🔒 **`faction_posture` finally has something registered against it** (#206).
	# It has been a decision kind with no considerations since the kernel was
	# built, which is a decision nobody could make.
	TradeConsiderations.register_all()


# --- Effects ---------------------------------------------------------------

static func register_effects() -> void:
	# Commits the Crown to paying. Whether it *can* pay is crown standing, which
	# is M3 (#17); for M1 the Crown always pays and the seam is left open.
	ContentRegistry.register_effect(
		"promise_gold", {"to": "contact", "amount": "gold"}, ORDER_PROMISE_GOLD
	)
	# 🔒 **A promise of gold that names a town** (#400, `town-economy.md` §4).
	# The same Order as any promise of gold, so it is paid, broken and counted on
	# the Crown's books exactly as one is; the only difference is that when the
	# Crown pays, the town's purse receives it.
	ContentRegistry.register_effect(
		"promise_gold_to_town", {"to": "contact", "town": "town", "amount": "gold"},
		ORDER_PROMISE_GOLD,
	)
	ContentRegistry.register_effect(
		"promise_resource",
		{"to": "contact", "resource": "resource", "amount": "integer"},
		ORDER_PROMISE_RESOURCE,
	)
	# **A bet on your own colony** (#69). The PC is not pledging coins; he is
	# agreeing to a figure his colony's trade is expected to return, and the
	# promise is kept or broken by whether it does. Falling short costs loyalty on
	# top of the standing an honest refusal would have cost — which is the whole
	# decision the Steward's letter puts in front of him.
	ContentRegistry.register_effect(
		"promise_revenue",
		{"to": "contact", "amount": "gold", "months": "integer"},
		ORDER_PROMISE_REVENUE,
	)
	# A refusal is still an Order. The contact learns of it and reacts, which is
	# not the same as the PC saying nothing at all (SPEC §9.3).
	ContentRegistry.register_effect("refuse", {"to": "contact"}, ORDER_REFUSE)
	# **Declining a demand is not the same as refusing a request** (#69). It costs
	# Crown standing, where an ordinary refusal costs only the contact's regard —
	# so the Crown has to be able to tell the two apart, and a shared `refuse`
	# would have made every "no" to the Steward a matter for the Treasury.
	ContentRegistry.register_effect("decline_demand", {"to": "contact"}, ORDER_DECLINE_DEMAND)
	# **The Crown's thumb on the scale** (#80). A standing instruction with a
	# monthly charge, and who bears that charge is the whole of the mechanic —
	# which is why the split is a param the letter sets rather than a constant.
	ContentRegistry.register_effect(
		"enact_policy",
		{"to": "contact", "effect": "string", "cost": "gold", "split": "string"},
		ORDER_ENACT_POLICY,
		M1Registrations.build_policy_order,
	)
	# 🔒 **A policy aimed at a resource** (#396, `policy.md` §8). Its own effect
	# rather than `enact_policy` with an optional field, for the reason the
	# Provost's knobs are: effect params are all required, and a different shape
	# is a different effect. It produces the same Order kind, because it is the
	# same act — the charge, the split and the renegotiation are all `policy.md`'s.
	# The target is a resource or a kind of livestock: both have a Crown price.
	ContentRegistry.register_effect(
		"enact_policy_on",
		{
			"to": "contact", "effect": "string", "cost": "gold", "split": "string",
			"resource": "resource",
		},
		ORDER_ENACT_POLICY,
		M1Registrations.build_policy_order,
	)
	# **The Provost's knobs are a different shape** (#173, `the-provost.md` §2),
	# so they are a different effect rather than `enact_policy` with an optional
	# field. His five run nothing / a little / a lot / a great deal: the letter
	# names a **setting** and `PolicyEffects` decides what that setting is worth,
	# which is the same declare-and-supply split the content pipeline uses
	# everywhere else.
	#
	# It produces the same Order kind, because turning a knob **is** enacting a
	# policy — the recurring cost, the split, the 3x asymmetry on non-payment and
	# the renegotiation when the Crown stops paying are all `policy.md`'s and none
	# of them is reimplemented here.
	# 🔒 **A name, never a coordinate** (#177, SPEC §11.4). `preference` is one of
	# `SitePreference.ALL`; a `tile` param here would be the locked invariant
	# broken, and `test_no_letter_can_name_a_tile_for_a_town` says so out loud.
	# 🔒 **The correspondence determines what it starts with** (#180, §3). What
	# the PC promises is what it is equipped with, so the letter names how
	# handsomely and `CrownFounding.EQUIPPED` says what that buys — declare and
	# supply, as everywhere else.
	ContentRegistry.register_effect(
		"fund_founding",
		{
			"to": "contact", "equipped": "string", "expert": "resource",
			"building": "building", "intent": "string",
		},
		ORDER_FUND_FOUNDING,
	)
	# 🔒 **He may dissuade; he does not decide.** SPEC §11.4 presses these on the
	# colony, so this is an ordinary Order resolved by ordinary compliance — a
	# determined patron founds his town over it.
	ContentRegistry.register_effect(
		"dissuade_founding", {"to": "contact"}, ORDER_DISSUADE_FOUNDING
	)
	ContentRegistry.register_effect(
		"prefer_site",
		{"to": "contact", "preference": "string"},
		ORDER_PREFER_SITE,
	)
	ContentRegistry.register_effect(
		"set_knob",
		{
			"to": "contact", "effect": "string", "cost": "gold",
			"split": "string", "level": "string",
		},
		ORDER_ENACT_POLICY,
	)
	# **The PC's only power over goods he has already promised** (#69). He cannot
	# move a town's stockpile — SPEC §11.3 locks that towns run themselves — so he
	# writes to the governor and the governor decides what priority to give it.
	# The payment is the lever: pay nothing and the governor bears the whole cost,
	# pay double and his town is richer for it.
	# **Undertaking goods the PC does not control** (#69). Accepting the Marshal's
	# demand is a promise; making it good takes a second letter to a governor who
	# may refuse. Both steps can fail, and the second failing breaks the first.
	ContentRegistry.register_effect(
		"promise_shipment",
		{"to": "contact", "resource": "resource", "amount": "integer", "months": "integer"},
		ORDER_PROMISE_SHIPMENT,
	)
	# **The Crown's one punishment before it has troops** (SPEC §12.3, #73/#74).
	# Its neighbours stop relieving it, which raises the punished town's own
	# sentiment and lowers the argument its rebellion makes to everybody else.
	ContentRegistry.register_effect(
		"embargo", {"to": "contact", "months": "integer"}, ORDER_EMBARGO
	)
	# **The answer to a man who says he will not carry it further** (#80, §4).
	# `bonus` is the lump sum on top — everybody loves a bribe, and a letter that
	# offers one reads very differently from a letter that merely concedes a
	# point.
	ContentRegistry.register_effect(
		"fund_policy", {"to": "contact", "split": "string", "bonus": "gold"},
		ORDER_FUND_POLICY,
	)
	ContentRegistry.register_effect("end_policy", {"to": "contact"}, ORDER_END_POLICY)
	ContentRegistry.register_effect(
		"ship_resource",
		{"to": "contact", "resource": "resource", "amount": "integer", "payment": "gold"},
		ORDER_SHIP_RESOURCE,
	)
	ContentRegistry.register_effect(
		"grant_favor", {"to": "contact", "favor": "string"}, ORDER_GRANT_FAVOR
	)
	# **The fourth currency** (#69, `crown-demands.md` §4). A rival bullies the PC
	# into handing over goods, and **accepting defers the risk of an attack
	# without ever buying peace**. It costs **prestige** rather than standing —
	# the Crown's books are untouched and the court hears about it anyway — which
	# is the whole reason the rival is in the table of askers: a fourth pocket the
	# player's existing defences do not reach.
	# 🔒 **Gold, and only ever gold** (SPEC §8.4, v3.0). A duke's ships do not dock
	# at a colonial town: **only the Crown trades with these colonies**, so tribute
	# in goods would put a foreign hold at a Crown wharf. It comes out of the
	# Crown's purse, which is why this makes an ordinary gold promise.
	ContentRegistry.register_effect(
		"pay_tribute",
		{"to": "contact", "amount": "gold", "months": "integer"},
		ORDER_PAY_TRIBUTE,
	)
	# 🔒 **No params but the man**, because there is nothing to decide: the
	# patron arranges it, and a figure here would be a price on a door whose
	# whole identity is costing nothing.
	ContentRegistry.register_effect(
		"deflect_tribute", {"to": "contact"}, ORDER_DEFLECT_TRIBUTE
	)
	ContentRegistry.register_effect(
		"set_policy", {"policy": "string", "value": "string"}, ORDER_SET_POLICY
	)
	# The payment level is chosen in the letter. It drives the loyalty cost and
	# then the refusal probability (SPEC §8.5, §12.6, #16).
	# 🔒 **Troops are a standing policy** (#420, `the-marshal.md` §2): strength and
	# posture are its two knobs, and it is the same Order kind as any policy, so
	# the charge, the split, the drain and the renegotiation are `policy.md`'s.
	# The placeholder `request_troops` it replaces fed the soldiers from the
	# colony's stores, which §3 locks they never are.
	ContentRegistry.register_effect(
		"station_troops",
		{"to": "contact", "strength": "string", "posture": "string", "cost": "gold", "split": "string"},
		ORDER_ENACT_POLICY,
		M1Registrations.build_troops_order,
	)
	ContentRegistry.register_effect(
		"adjust_loyalty", {"to": "contact", "amount": "number"}, ORDER_ADJUST_LOYALTY
	)
	# **🔒 The PC argues for a goal and nothing else** (SPEC §8.5). There is no
	# effect that names a project, a tile or a month, and `tools/lint.gd` fails
	# if one appears. `intent` is one of `GovernorIntent`; the town is the one the
	# governor addressed speaks for.
	ContentRegistry.register_effect(
		"urge_intent", {"to": "contact", "intent": "string"}, ORDER_URGE_INTENT
	)
	# **The player never sets a rate directly** (SPEC §10.2). It is always a
	# letter to the Steward, resolved through compliance like any other Order —
	# which is why he can delay it.
	#
	# `resource` empty means the base rate, which applies to everything without an
	# override of its own. A builder rather than a plain declaration because the
	# world key and the size of the step are worked out here, once, instead of in
	# every letter that asks for a change.
	ContentRegistry.register_effect(
		"set_tax_rate",
		{"to": "contact", "resource": "string", "steps": "number"},
		ORDER_SET_TAX_RATE,
		M1Registrations.build_tax_order,
	)
	# **Where the Diplomat lives** (#393). It was a gold promise and nothing else,
	# so the PC paid for a move that never happened; this is the move.
	ContentRegistry.register_effect(
		"move_diplomat", {"to": "contact", "town": "town"}, ORDER_MOVE_DIPLOMAT
	)
	# **The clergy's two asks, which are one effect** (#278). `resource` empty is
	# a holy day — every duty, for the month — and a named resource is a festival
	# in that trade. A builder for the same reason the rate above has one: the
	# world key and the number of months are worked out here, once.
	#
	# 🔒 **The PC never sets this directly either.** It is a reply to a letter
	# the priest wrote, resolved through compliance like any other Order.
	ContentRegistry.register_effect(
		"waive_duty",
		{"to": "contact", "resource": "string", "months": "integer"},
		ORDER_WAIVE_DUTY,
		M1Registrations.build_waiver_order,
	)


## Turn "raise the rate on cloth" into an Order that names the world value it
## moves and how far.
static func build_tax_order(args: Dictionary, context: LetterContext) -> Order:
	var resource := String(args.get("resource", ""))
	var steps := float(args.get("steps", 0.0))
	var params := args.duplicate()
	params["key"] = TaxRates.BASE_KEY if resource.is_empty() else TaxRates.key_for(StringName(resource))
	# Where the rate is to land, worked out now so the letter and the Order agree
	# about what was asked for. A rate is put somewhere, not drifted towards.
	params["rate"] = TaxRates.moved(context.state, StringName(resource), steps)
	return Order.new(
		ORDER_SET_TAX_RATE,
		StringName(args.get("to", "")),
		params,
		context.month,
	)


## The Marshal's troops policy (#420): the policy it is, with its two knobs in
## its params. **Which strengths and postures a letter may name is the content
## validator's** (`check_troop_requests`), so a bad one is refused when the data
## loads rather than when the player sends it.
static func build_troops_order(args: Dictionary, context: LetterContext) -> Order:
	var params := args.duplicate()
	params["effect"] = String(PolicyEffects.CROWN_TROOPS)
	return Order.new(ORDER_ENACT_POLICY, StringName(args.get("to", "")), params, context.month)


## A policy, refused when it needs a market and has none (#396).
##
## 🔒 **A market policy needs its market.** `enact_policy` naming
## `favour_our_market` produced a policy that pressed on no price and charged the
## Crown every month for it; it is refused here rather than enacted and ignored.
## The other half — `enact_policy_on` naming a policy that reads no resource — is
## refused when the data loads (`ContentValidator.check_policy_targets`), where
## the letter that says it can be named.
static func build_policy_order(args: Dictionary, context: LetterContext) -> Order:
	var effect := StringName(args.get("effect", ""))
	if PolicyEffects.is_aimed_at_a_resource(effect) and not args.has("resource"):
		push_error("'%s' needs a resource; use enact_policy_on." % effect)
		return null
	return Order.new(
		ORDER_ENACT_POLICY,
		StringName(args.get("to", "")),
		args.duplicate(),
		context.month,
	)


## Turn "waive the duty on cloth for three months" into an Order naming the world
## value it sets and what it sets it to.
##
## 🔒 **An empty resource is a holy day**, which is `TaxWaiver.ALL` rather
## than a loop over the catalogue — so a resource added next year is covered
## without anybody remembering to cover it.
static func build_waiver_order(args: Dictionary, context: LetterContext) -> Order:
	var resource := String(args.get("resource", ""))
	var named := TaxWaiver.ALL if resource.is_empty() else StringName(resource)
	var months := int(args.get("months", TaxWaiver.HOLY_DAY_MONTHS))
	var params := args.duplicate()
	params["key"] = TaxWaiver.key_for(named)
	# **The longer of the two wins**, worked out now so the letter and the Order
	# agree: a priest granted a second festival in the same trade is not being told
	# the first one is over.
	params["months_left"] = maxi(
		TaxWaiver.months_left(context.state, named), maxi(1, months))
	return Order.new(
		ORDER_WAIVE_DUTY,
		StringName(args.get("to", "")),
		params,
		context.month,
	)


# --- Conditions ------------------------------------------------------------

static func register_conditions() -> void:
	ContentRegistry.register_condition("always", {}, M1Conditions.always)

	ContentRegistry.register_condition(
		"world_value_above", {"key": "string", "value": "number"}, M1Conditions.world_value_above
	)
	ContentRegistry.register_condition(
		"world_value_below", {"key": "string", "value": "number"}, M1Conditions.world_value_below
	)

	ContentRegistry.register_condition(
		"world_value_fell_by", {"path": "string", "amount": "number"}, M1Conditions.world_value_fell_by
	)
	ContentRegistry.register_condition(
		"world_value_rose_by", {"path": "string", "amount": "number"}, M1Conditions.world_value_rose_by
	)

	ContentRegistry.register_condition(
		"loyalty_below", {"value": "number"}, M1Conditions.loyalty_below
	)
	ContentRegistry.register_condition(
		"loyalty_above", {"value": "number"}, M1Conditions.loyalty_above
	)

	ContentRegistry.register_condition(
		"year_at_least", {"year": "integer"}, M1Conditions.year_at_least
	)
	ContentRegistry.register_condition(
		"months_silent_at_least", {"months": "integer"}, M1Conditions.months_silent_at_least
	)


# --- Measures --------------------------------------------------------------

## What counts as high or low, per measure. The Author never needs to know that
## `crown_war_intensity` runs 0-100 while a food ratio runs 0-3.
static func register_measures() -> void:
	# The worked example in `docs/mechanics/perception.md` §4: stockpile over
	# consumption, 0.0 at a ratio of 0 and 1.0 at a ratio of 3.0.
	MeasureRegistry.register_linear("food_security", 0.0, 3.0)
	MeasureRegistry.register_linear("crown_war_intensity", 0.0, 100.0)
	# **Not gold: a ratio** (#63, `perception.md` §4a). `WorldValues.measures()`
	# supplies this month's duty against what a month lately brings, so `1.0` is
	# a normal month and the middle of any ladder. A colony ten times the size
	# reads the same when it is doing as well as it usually does, and the
	# Steward's four rungs all stay reachable for the whole run.
	MeasureRegistry.register_linear("colony_revenue", 0.0, 2.0)
	MeasureRegistry.register_linear("supply_situation", 0.0, 100.0)
	# Quality of life is already a share (`quality-of-life.md` §1), so there is
	# no scale to apply. **The player never sees the number** — only a governor
	# who sounds comfortable or wretched.
	MeasureRegistry.register_linear("quality_of_life", 0.0, 1.0)
	# A governor's own affairs (#54). Progress and stockpile health are already
	# shares; trade is in gold and needs a scale.
	MeasureRegistry.register_linear(ColonyMeasures.OBJECTIVE_PROGRESS, 0.0, 1.0)
	MeasureRegistry.register_linear(ColonyMeasures.STOCKPILE_HEALTH, 0.0, 1.0)
	# **How the poorest live** (#277). The same range as quality of life, because
	# it is the same five parts weighted differently rather than a new quantity.
	MeasureRegistry.register_linear(ColonyMeasures.POOREST_QUALITY_OF_LIFE, 0.0, 1.0)
	# **The worst town, not the average** (#279). Same range as quality of life,
	# because it is a quality of life - the lowest one there is.
	MeasureRegistry.register_linear(ColonyMeasures.WORST_QUALITY_OF_LIFE, 0.0, 1.0)
	# **Whether anybody has been fighting** (#280), never who began it.
	MeasureRegistry.register_linear(ColonyMeasures.COLONY_AT_PEACE, 0.0, 1.0)
	# **Guns in the stores and in the companies hands** (#281), as a share of
	# what it would take to arm everybody.
	MeasureRegistry.register_linear(ColonyMeasures.COLONY_IS_ARMED, 0.0, 1.0)
	# 🔒 **The whole of the player's sight of the natives** (#208). Across the
	# full range, so the bottom rung covers a people who have concluded the
	# colony means them destroyed *and* a people who very nearly have — which is
	# why the latch is never announced: there is no word that means only the one.
	MeasureRegistry.register_linear(
		ColonyMeasures.NATIVE_REGARD, Tribe.MINIMUM, Tribe.MAXIMUM
	)
	MeasureRegistry.register_linear(ColonyMeasures.NATIVE_PRESSURE, 0.0, 0.6)
	# 🔒 **What a man across a border can see** (#209). Already a share of one by
	# construction, and it reads the same in year one and year eight because it
	# is measured against what a colony might reach rather than against a total.
	MeasureRegistry.register_linear(ColonyMeasures.COLONY_REACH, 0.0, 1.0)
	MeasureRegistry.register_linear(ColonyMeasures.COLONY_IS_NO_THREAT, 0.0, 1.0)
	# 🔒 **What a man at court reads, and nobody else** (#282). A share of the
	# money that moved rather than a pile of gold, so the ends are the arithmetic
	# and not a tuning value: every penny lost, and every penny returned several
	# times over.
	MeasureRegistry.register_linear(
		ColonyMeasures.COLONY_NET_POSITION,
		ColonyMeasures.DEEP_IN_THE_RED,
		ColonyMeasures.HANDSOMELY_IN_PROFIT,
	)
	MeasureRegistry.register_linear(ColonyMeasures.COLONY_IS_QUIET, 0.0, 1.0)
	# Likewise a ratio: a town's month against the colony's average town, so a
	# governor calling his month brisk means brisk for the place he governs.
	MeasureRegistry.register_linear(
		ColonyMeasures.TRADE_VOLUME, 0.0, ColonyMeasures.BUSY_TOWN
	)
	# How heavily the colony is taxed, which is what the Steward writes about and
	# what his lean shades.
	MeasureRegistry.register_linear("tax_burden", 0.0, TaxRates.MAX_RATE)
	# What the colony has worth teaching, which is what the Provost writes about
	# and what his lean shades (#174). Scaled to where he stops complaining, which
	# is above where any real colony gets.
	MeasureRegistry.register_linear(
		WorldValues.EDUCATION, 0.0, Provost.LEARNED_ENOUGH
	)
