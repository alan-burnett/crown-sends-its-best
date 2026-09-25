class_name ColonyParamSources
extends RefCounted

## Where a governor's letter gets the facts about his town (#54).
##
## **`{param:}` slots are exact and truthful** (SPEC §9.7). The bias lives in
## `{perception:}` and nowhere else, so everything here is the plain number or
## the plain name. A governor may be gloomy about how much grain there is; he
## does not misreport which building he is putting up.
##
## Named static functions, not lambdas — a lambda in a static registry crashes
## Godot 4.7 on shutdown (CLAUDE.md).

static func register_all() -> void:
	# --- The last chance (#268, `endings.md` §2, §3) ------------------------
	ContentRegistry.register_param_source(
		"independence_conditions", {"which": "string"},
		ColonyParamSources.independence_conditions,
	)
	ContentRegistry.register_param_source(
		"colony_people", {}, ColonyParamSources.colony_people
	)

	ContentRegistry.register_param_source(
		"warning_turns", {}, ColonyParamSources.warning_turns
	)
	# What the Treasury has actually paid on the PC's word this year (#364).
	ContentRegistry.register_param_source(
		"treasury_honoured_this_year", {}, ColonyParamSources.treasury_honoured_this_year
	)
	# What the reported event carried, as a name or a number (#398).
	ContentRegistry.register_param_source(
		"what_happened",
		{"event": "string", "within": "integer", "concerning": "string", "field": "string"},
		ReportableEvents.what_happened,
	)
	ContentRegistry.register_param_source("sender_id", {}, ColonyParamSources.sender_id)
	# What a commander's letter says of his company (#394).
	ContentRegistry.register_param_source("my_company_men", {}, ColonyParamSources.my_company_men)
	ContentRegistry.register_param_source("my_company_near", {}, ColonyParamSources.my_company_near)
	ContentRegistry.register_param_source(
		"enemies_near_my_company", {}, ColonyParamSources.enemies_near_my_company
	)
	# The tribe whose letter a governor passes on (#436).
	ContentRegistry.register_param_source(
		"the_tribe_that_wrote_to_me", {}, ColonyParamSources.the_tribe_that_wrote_to_me
	)
	# The duke a patron offers to trouble, as an id or by name (#395).
	ContentRegistry.register_param_source(
		"the_duke_to_trouble", {"field": "string"}, ColonyParamSources.the_duke_to_trouble
	)
	# The one kind a patron's specialty names (#396, `patrons.md` §3).
	ContentRegistry.register_param_source(
		"his_specialty_kind", {}, ColonyParamSources.his_specialty_kind
	)
	ContentRegistry.register_param_source(
		"patron_who_spoke", {"fallback": "string"}, ColonyParamSources.patron_who_spoke
	)
	ContentRegistry.register_param_source(
		"patron_ask", {}, ColonyParamSources.patron_ask
	)
	# The letter a companion travels with, read by name (#404).
	ContentRegistry.register_param_source("lead", {"param": "string"}, ColonyParamSources.lead)
	# What a patron wants shipped to him: its kind, how much, how soon (#441).
	ContentRegistry.register_param_source(
		"his_need", {"field": "string"}, ColonyParamSources.his_need
	)
	# What the priest asks a festival for (#278). The resource that sold the
	# most gold this month, which is the Author's first ruling.
	ContentRegistry.register_param_source(
		"best_selling_resource", {"fallback": "string"},
		ColonyParamSources.best_selling_resource,
	)
	ContentRegistry.register_param_source(
		"patron_leaves_in", {}, ColonyParamSources.patron_leaves_in
	)
	ContentRegistry.register_param_source("town_name", {}, ColonyParamSources.town_name)
	ContentRegistry.register_param_source(
		"idle_building", {"field": "building"}, ColonyParamSources.idle_building
	)
	ContentRegistry.register_param_source(
		"objective_name", {"fallback": "string"}, ColonyParamSources.objective_name
	)
	ContentRegistry.register_param_source(
		"finished_name", {"fallback": "string"}, ColonyParamSources.finished_name
	)
	ContentRegistry.register_param_source("intent_name", {}, ColonyParamSources.intent_name)
	ContentRegistry.register_param_source(
		"intent_pursuing", {}, ColonyParamSources.intent_pursuing
	)
	ContentRegistry.register_param_source(
		"town_lacks", {"fallback": "string"}, ColonyParamSources.town_lacks
	)
	ContentRegistry.register_param_source(
		"town_stock", {"resource": "string"}, ColonyParamSources.town_stock
	)
	ContentRegistry.register_param_source(
		"town_lacking_stock", {}, ColonyParamSources.town_lacking_stock
	)
	ContentRegistry.register_param_source("town_trade", {}, ColonyParamSources.town_trade)
	ContentRegistry.register_param_source(
		"town_population", {}, ColonyParamSources.town_population
	)
	ContentRegistry.register_param_source("years_served", {}, ColonyParamSources.years_served)
	ContentRegistry.register_param_source(
		"crown_demand", {"field": "string"}, ColonyParamSources.crown_demand
	)
	ContentRegistry.register_param_source(
		"town_surplus", {"fallback": "string"}, ColonyParamSources.town_surplus
	)
	ContentRegistry.register_param_source(
		"town_surplus_amount", {}, ColonyParamSources.town_surplus_amount
	)
	ContentRegistry.register_param_source(
		"town_months_out", {}, ColonyParamSources.town_months_out
	)
	ContentRegistry.register_param_source(
		"neighbour_tribe", {"fallback": "string"}, ColonyParamSources.neighbour_tribe
	)
	ContentRegistry.register_param_source(
		"neighbour_fields", {}, ColonyParamSources.neighbour_fields
	)
	ContentRegistry.register_param_source(
		"bargain", {"field": "string", "fallback": "string"},
		ColonyParamSources.bargain,
	)
	ContentRegistry.register_param_source(
		"denied_fields", {}, ColonyParamSources.denied_fields
	)
	ContentRegistry.register_param_source(
		"divergence", {"field": "string", "fallback": "string"},
		ColonyParamSources.divergence,
	)
	ContentRegistry.register_param_source(
		"tribute_amount", {}, ColonyParamSources.tribute_amount
	)
	ContentRegistry.register_param_source(
		"protest", {"field": "string", "within": "integer"}, ColonyParamSources.protest
	)
	# The Diplomat (#81). Every one of these is a fact about a town he can see.
	ContentRegistry.register_param_source(
		"worst_town", {"field": "string"}, ColonyParamSources.worst_town
	)
	ContentRegistry.register_param_source(
		"his_town", {"field": "string"}, ColonyParamSources.his_town
	)
	ContentRegistry.register_param_source(
		"what_he_carries", {}, ColonyParamSources.what_he_carries
	)
	ContentRegistry.register_param_source(
		"recalled", {"reach": "string", "field": "string"}, ColonyParamSources.recalled
	)
	ContentRegistry.register_param_source(
		"pc", {"field": "string"}, ColonyParamSources.pc
	)
	ContentRegistry.register_param_source(
		"policy", {"field": "string"}, ColonyParamSources.policy
	)


## How many letters the Treasury will still honour.
##
## **The deadline, in something the player can count** (#68). A window he cannot
## see is a trap rather than an opportunity, and this is how the Chancellor says
## it without anybody seeing a standing figure.
static func warning_turns(_args: Dictionary, _context: LetterContext) -> Variant:
	return CrownRefusal.WARNING_TURNS


## 🔒 **What the Treasury has honoured on the PC's word this year** (#364,
## SPEC §9.1).
##
## `chancellor.warning_standing` used to take this figure from colony revenue,
## doubled and floored at 100 — so on the first turn of every run, with nothing
## promised and nothing paid, the Chancellor reported a payout of 100 that never
## happened. A `{param:}` is exact and truthful, and this is the figure the
## Ledger shows.
static func treasury_honoured_this_year(_args: Dictionary, context: LetterContext) -> Variant:
	if context == null:
		return 0
	return int(roundf(CrownAccounts.of(context.log).paid_in_year_of(context.month)))


## How many years the PC has held the post.
##
## Exact and truthful, so it belongs in a `{param:}` rather than a
## `{perception:}` — the Chancellor may be unpleasant about the length of a
## man's tenure but he is not wrong about the number.
static func years_served(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.state == null else context.state.year_index() - 1


## What the Crown asked for, exactly as it asked for it (#69).
##
## **Exact and truthful**, so it is a `{param:}`. The Steward's opinion of the
## figure is his own and belongs in a `{perception:}`; the figure itself is the
## thing the promise will be settled against, and a letter that rounded it would
## be settling the player against a number he was never shown.
static func crown_demand(args: Dictionary, context: LetterContext) -> Variant:
	var book := context.demand_book
	if book == null:
		return 0
	match String(args.get("field", "")):
		"amount":
			return int(roundf(book.amount)) if book.kind == DemandBook.KIND_RESOURCE \
				else book.amount
		"months":
			return book.term_months
		"resource":
			return String(book.resource)
		"turns_left":
			return book.turns_left(context.month)
	return 0


## Who the letter came from, so a reply can be addressed back without the file
## hard-coding a contact id.
##
## **This is what makes a governor letter set reusable.** M4 brings a second
## governor and a second town; without it, every letter file would name Ashmere
## and the set would have to be copied per town, which is a content-scaling
## problem the folder-per-language rule was designed to avoid (SPEC §9.7).
## The patron the court has just heard from, by name (#282).
##
## **The first of them, in the order the gossip was carried**, which is id order
## — so a month in which two men talked names the same one every time the same
## seed is played.
##
## 🔒 **The name is looked up, not carried in the payload.** SPEC §10.3's rule
## about what an event may say holds here: the log records that a man spoke, and
## the roster is where his name lives.
static func patron_who_spoke(args: Dictionary, context: LetterContext) -> Variant:
	var fallback := String(args.get("fallback", ""))
	if context.log == null:
		return fallback
	var events := context.log.of_type(PatronGossip.EVENT_SPREAD)
	for index in range(events.size() - 1, -1, -1):
		for id in events[index].payload.get("patrons", []):
			var patron: Contact = context.contacts.get(String(id), null)
			if patron != null and not patron.display_name.is_empty():
				return patron.display_name
	return fallback


static func sender_id(_args: Dictionary, context: LetterContext) -> Variant:
	return String(context.sender.id) if context.sender != null else ""


## How many men his company has (#394). Nought for a man with no command.
static func my_company_men(_args: Dictionary, context: LetterContext) -> Variant:
	var company := UrgeCompanyExecutor.commanded_by(context.companies, context.sender.id) \
		if context.sender != null else null
	return company.size if company != null else 0


## The town his company stands nearest, by name (#394): where a letter says he
## is. Ties go to the first town in id order.
static func my_company_near(_args: Dictionary, context: LetterContext) -> Variant:
	var company := UrgeCompanyExecutor.commanded_by(context.companies, context.sender.id) \
		if context.sender != null else null
	if company == null or context.colony == null or company.at == Company.NOWHERE:
		return "the colony"
	var nearest: Town = null
	var closest := 0
	for town in context.colony.in_order():
		var away := maxi(absi(town.at.x - company.at.x), absi(town.at.y - company.at.y))
		if nearest == null or away < closest:
			nearest = town
			closest = away
	return nearest.display_name if nearest != null else "the colony"


## How many companies that may fight his stand within reach of it (#394).
static func enemies_near_my_company(_args: Dictionary, context: LetterContext) -> Variant:
	var company := UrgeCompanyExecutor.commanded_by(context.companies, context.sender.id) \
		if context.sender != null else null
	return enemies_near(company, context)


## Companies `Battle.may_fight` lets fight this one, within `OrderRule.THREAT_WITHIN`.
static func enemies_near(company: Company, context: LetterContext) -> int:
	if company == null or context.companies == null or company.at == Company.NOWHERE:
		return 0
	var count := 0
	for entry in context.companies.in_resolution_order():
		var other: Company = entry
		if other.is_empty() or other.at == Company.NOWHERE or not Battle.may_fight(company, other):
			continue
		var away := maxi(absi(other.at.x - company.at.x), absi(other.at.y - company.at.y))
		if away <= OrderRule.THREAT_WITHIN:
			count += 1
	return count


## The people whose latest letter to this governor he is passing on (#436), by
## name.
static func the_tribe_that_wrote_to_me(_args: Dictionary, context: LetterContext) -> Variant:
	if context.sender == null or context.natives == null:
		return "the natives"
	var latest := context.natives.grievances.latest_to(context.sender.id)
	var tribe: Tribe = context.natives.find(latest.tribe) if latest != null else null
	return tribe.display_name if tribe != null else "the natives"


## The duke a patron offers to trouble (#395): `field` `id` for the effect,
## `name` for the prose.
static func the_duke_to_trouble(args: Dictionary, context: LetterContext) -> Variant:
	var duke := ColonyConditions.the_duke_to_trouble(context)
	if duke == null:
		return ""
	return String(duke.id) if String(args.get("field", "name")) == "id" else duke.display_name


## The one kind his specialty names (#396): *horses*, *sugar*. Empty for a
## category that comes in no kinds.
static func his_specialty_kind(_args: Dictionary, context: LetterContext) -> Variant:
	return context.sender.specialty_kind if context.sender != null else ""


## What a town has had to shut, by name (#151).
##
## **Never an id.** A letter saying "we have shut sawmill" is a bug report, not a
## governor. The first in build order, so a town with two dark buildings names
## the one it has had longest rather than whichever the dictionary yielded first.
static func idle_building(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null or context.town.dark_buildings.is_empty():
		return args.get("fallback", "the works")
	for id in context.town.buildings:
		if not context.town.dark_buildings.has(String(id)):
			continue
		var building := Building.find(StringName(id))
		if building != null:
			return building.display_name
	return args.get("fallback", "the works")


static func town_name(_args: Dictionary, context: LetterContext) -> Variant:
	return context.town.display_name if context.town != null else "the colony"


## What the town is working on, by name. Never its id, and never a tile.
static func objective_name(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return args.get("fallback", "the work")
	var name := Objective.display_name(context.town.objective)
	return name if not name.is_empty() else args.get("fallback", "the work")


## What the town last finished, by name.
static func finished_name(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return args.get("fallback", "the work")
	var name := Objective.display_name(context.town.last_completed)
	return name if not name.is_empty() else args.get("fallback", "the work")


## What the governor is *for*, as a noun phrase.
static func intent_name(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return "the colony"
	return Objective.intent_name(context.town.intent)


## What he says he is doing, as a clause.
static func intent_pursuing(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return "doing what I can"
	return Objective.intent_pursuing(context.town.intent)


## The need the town is furthest from covering, named.
##
## **The worst one**, on the same worst-first rule Relief serves need by, so the
## letter and the simulation agree about which shortage matters.
static func town_lacks(args: Dictionary, context: LetterContext) -> Variant:
	var town := context.town
	if town == null:
		return args.get("fallback", "supplies")

	var worst := ""
	var deepest := INF
	for resource in ColonyNeeds.needed_resources():
		var monthly := town.mouths() * ColonyNeeds.per_head(StringName(resource))
		if monthly <= 0.0:
			continue
		var months := town.held(StringName(resource)) / monthly
		if months < deepest:
			deepest = months
			worst = resource
	return worst if not worst.is_empty() else args.get("fallback", "supplies")


## How much of something is in the store, as a whole number. A letter that
## declares an integer must never render "48.0" at the player.
static func town_stock(args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	return int(roundf(context.town.held(StringName(args.get("resource", "")))))


## How much of the thing it is short of the town actually has.
##
## Paired with `town_lacks`, so the letter names one resource and counts the
## same one. Naming the shortage and then counting the grain is the sort of
## mismatch a player notices and a validator cannot.
static func town_lacking_stock(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	var worst := String(town_lacks({"fallback": ""}, context))
	return 0 if worst.is_empty() else int(roundf(context.town.held(StringName(worst))))


## What this town has most of, over what it needs to keep.
##
## **The default the Crown would ask for**, so a composed shipment letter opens
## on something the town could plausibly send rather than on whatever is first in
## the catalogue. Comforts are excluded: the Marshal's wars do not run on rum,
## and asking a town for its beer reads as a joke rather than a requisition.
##
## Ordered by name on a tie, so the same town always suggests the same thing.
static func town_surplus(args: Dictionary, context: LetterContext) -> Variant:
	var fallback := String(args.get("fallback", "iron"))
	if context.town == null:
		return fallback
	var mouths := context.town.mouths()

	var best := ""
	var most := 0.0
	for id in ResourceCatalogue.ids():
		var resource := StringName(id)
		if ResourceCatalogue.is_luxury(resource) or ResourceCatalogue.is_livestock(resource):
			continue
		var keep := mouths * ColonyNeeds.per_head(resource) \
			* (1.0 + ColonyNeeds.reserve_months(resource))
		var spare := context.town.held(resource) - keep
		if spare > most + 0.001 or (absf(spare - most) <= 0.001 and best != "" and String(id) < best):
			most = spare
			best = String(id)
	return fallback if best.is_empty() or most <= 0.0 else best


## How much of that surplus there is, rounded to something a letter can say.
##
## Half of it rather than all: the Crown asking a town for every last bar of its
## spare iron is a demand no governor would treat as anything but confiscation,
## and the default a composed letter opens on should be one the PC might
## plausibly send unedited.
static func town_surplus_amount(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null:
		return 0
	var resource := StringName(town_surplus({"fallback": "iron"}, context))
	var mouths := context.town.mouths()
	var keep := mouths * ColonyNeeds.per_head(resource) \
		* (1.0 + ColonyNeeds.reserve_months(resource))
	return maxi(1, int(roundf(maxf(0.0, context.town.held(resource) - keep) * 0.5)))


## How long the town was outside the Crown, in months (#74).
##
## Read off the return event rather than off the town, which has already
## forgotten: `rebelling_since` is cleared the moment it comes home, because a
## town that is back is not a town that is out.
static func town_months_out(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null or context.log == null:
		return 0
	for event in context.log.of_type(Rebellion.EVENT_RETURNED):
		if event.subject == context.town.id:
			return int(event.payload.get("months_out", 0))
	return 0


## Something the sender actually remembers the PC doing (#127).
##
## > *Your Grace was good enough to send two hundred measures of iron in the
## > spring, when we had none.*
##
## **Always true**, because it names a real event on the record, which is what
## SPEC §9.1 requires of a letter. The bias is in `reach` — which memory this
## contact goes to — and that is framing, which §9.1 allows: a warm man leads
## with the last kindness, a sour one with the last slight, and neither is lying.
##
## `field` is `amount`, `resource` or `months_ago`. A letter asks for the pieces
## it needs and builds its own sentence, because **a stored sentence is a
## sentence no translation could reach**.
static func recalled(args: Dictionary, context: LetterContext) -> Variant:
	var field := String(args.get("field", "amount"))
	if context.sender == null or context.sender.relationship == null:
		return 0 if field != "resource" else ""

	var memory: Recollection = null
	match String(args.get("reach", "kindness")):
		"kindness":
			memory = context.sender.relationship.most_generous()
		"slight":
			memory = context.sender.relationship.most_recent_slight()
		"broken_word":
			memory = context.sender.relationship.last_broken_word()
		"in_character":
			memory = context.sender.relationship.recalled(sourness_of(context.sender))
		"his_kindness":
			# 🔒 **What he did for the PC** (#397): the most valuable, as it
			# weighs now.
			memory = context.sender.relationship.most_valuable_favour(context.month)

	if memory == null:
		return 0 if field != "resource" else ""
	match field:
		"amount":
			return int(roundf(memory.magnitude))
		"resource":
			return memory.subject
		"months_ago":
			return maxi(0, context.month - memory.month)
		"ask":
			# **What he asks back** (#397): a share of what the favour is worth
			# now. A placeholder.
			return int(maxf(1.0, roundf(Relationship.worth_now(memory, context.month) * FAVOUR_ASK_SHARE)))
	return 0


## What share of a remembered favour's worth he asks back (#397). Tuning.
const FAVOUR_ASK_SHARE: float = 0.25


## How sourly this contact remembers things.
##
## **Free characterisation from a weight he already has.** A man who leans hard
## on being let down reaches for the slight; a man who does not reaches for the
## kindness. Same log, same queries, different men.
static func sourness_of(contact: Contact) -> float:
	return clampf(1.0 - contact.loyalty() / Relationship.MAX_LOYALTY, 0.0, 1.0)


## What to call the man (#79).
##
## **The only thing SPEC §5's flavour is for.** A letter addresses him by name
## and title and nothing else in the game may read either — no condition, no
## effect, no consideration. A `{param:}` rather than a new slot kind, because
## the four in CLAUDE.md are a contract and this needed no fifth.
static func pc(args: Dictionary, context: LetterContext) -> Variant:
	if context.pc == null:
		return ""
	match String(args.get("field", "name")):
		"name":
			return context.pc.pc_name
		"title":
			return context.pc.pc_title
	return ""


## What the policy this contact is warning about costs, and how long he will
## give (#80, §4).
##
## **The charge and the deadline, never the drain.** He can say what it costs him
## in gold because he knows; what it has cost him in regard is his own business
## and no letter reads it.
static func policy(args: Dictionary, context: LetterContext) -> Variant:
	if context.sender == null or context.policies == null:
		return 0
	for held in context.policies.held_by(context.sender.id):
		if not held.is_warning() and String(args.get("field", "cost")) != "any_cost":
			continue
		match String(args.get("field", "cost")):
			"cost", "any_cost":
				return int(roundf(held.cost))
			"months":
				return maxi(0, held.ends_month - context.month)
	return 0


## The town in the worst state of one trouble, and what he would do about it.
##
## 🔒 **The suggestion comes from the registry, not from the prose** (#81, §2).
## A remedy written into a letter file is a remedy nobody would think to check
## when the mechanic behind it changed, and the one rule his advice must keep is
## that it is never mechanically false.
static func worst_town(args: Dictionary, context: LetterContext) -> Variant:
	var pressing := DiplomatReport.most_pressing(context)
	var field := String(args.get("field", "name"))
	if pressing.is_empty():
		return 0 if field == "months" else ""
	var town: Town = pressing["town"]
	match field:
		"suggestion":
			return DiplomatReport.suggestion_for(String(pressing["trouble"]))
		"months":
			return town.months_hungry
		_:
			return town.display_name


## What the Provost is paying for out of his own pocket (#174, §7).
##
## 🔒 **The cost is always in the advice.** "When he advises, he also advises
## that the PC pay for it" — an advice letter with no figure in it would be him
## asking a favour rather than presenting a bill. And the figure is what he is
## **already carrying**, never a larger one, because he does not escalate.
static func what_he_carries(_args: Dictionary, context: LetterContext) -> Variant:
	if context == null or context.policies == null:
		return 0
	var asking := Provost.advises(context.policies)
	return 0 if asking.is_empty() else int(roundf(float(asking["monthly"])))


## A fact about the town he lives in (#81, §2).
##
## The **sharp** half of his reporting, and the half his regard takes away first.
## `governor` is the man he dines with; `refused` is how many of the PC's orders
## that man has turned down, which nobody else in the game will tell the PC at
## all.
static func his_town(args: Dictionary, context: LetterContext) -> Variant:
	var field := String(args.get("field", "name"))
	var him: Contact = context.sender if context != null else null
	var town: Town = null
	if him != null and context.colony != null:
		town = Diplomat.home_of(him, context.colony)
	if town == null:
		return 0 if field == "refused" else ""

	match field:
		"governor":
			var governor: Contact = context.contacts.get(String(town.governor_id))
			return governor.display_name if governor != null else "their governor"
		"intent":
			return Objective.intent_name(town.intent)
		"loyalty":
			# **A judgement, never a figure.** SPEC §8.5 keeps loyalty off the
			# player's screens; what the Diplomat gives is a resident's read of a
			# man, which is what a resident would actually write.
			return _regard_for(context.contacts.get(String(town.governor_id)))
		"refused":
			return _refusals_in(town, context)
		"destination":
			# **Where he would ask to go**: least trouble, ties to the largest.
			var to := Diplomat.destination_for(town, context.colony)
			# A one-town colony has nowhere to send him, which is a real state of
			# the game and not an error — he asks to come home instead.
			return to.display_name if to != null else "England"
		_:
			return town.display_name


## How many of the PC's orders have been refused in his town (#81, §2).
##
## Counted off the log, so it is the record rather than anybody's memory of it —
## and it is the one thing in the game only the Diplomat will tell the PC, since
## the man who refused is not going to write and say so.
static func _refusals_in(town: Town, context: LetterContext) -> int:
	if context == null or context.log == null:
		return 0
	var refused := 0
	var theirs: Dictionary = {}
	for id in context.contacts:
		var contact: Contact = context.contacts[id]
		if contact != null and RebelSentiment.lives_in(contact, town):
			theirs[String(id)] = true
	for event in context.log.of_type(StringName(Compliance.OUTCOME_EVENTS[Compliance.REFUSE])):
		if theirs.has(String(event.subject)):
			refused += 1
	return refused


## How a resident would describe a man's regard for the Crown.
static func _regard_for(contact: Contact) -> String:
	if contact == null:
		return "hard to read"
	var loyalty := contact.loyalty()
	if loyalty >= 75.0:
		return "warmly, and says so in company"
	if loyalty >= 55.0:
		return "correctly, and no more than that"
	if loyalty >= 35.0:
		return "coolly, though he is careful about it"
	if loyalty >= 15.0:
		return "badly, and has stopped troubling to hide it"
	return "as an enemy, and the table knows it"


## What the Steward knows about the latest refusal (#75, SPEC §8.1).
##
## **The fact, not the figure.** Which town and which resource, and the duty that
## is on it — never the score, which SPEC §12.3 keeps off the player's screens
## for the same reason sentiment is kept off them.
static func protest(args: Dictionary, context: LetterContext) -> Variant:
	var within := maxi(1, int(args.get("within", 2)))
	var payload := ColonyConditions._latest_protest(context, within)
	var field := String(args.get("field", "resource"))
	if payload.is_empty():
		return 0 if field == "rate" else ""
	match field:
		"town":
			return String(payload.get("town", ""))
		"rate":
			return int(roundf(float(payload.get("rate", 0.0)) * 100.0))
		_:
			return String(payload.get("resource", ""))


static func town_trade(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.town == null else int(roundf(context.town.traded_value))


static func town_population(_args: Dictionary, context: LetterContext) -> Variant:
	return 0 if context.town == null else context.town.population()


## The name of the people this man borders (#208).
##
## 🔒 **A name and nothing else.** It is the one fact about a tribe that reaches
## the page exactly: which people these are. What they think of the colony goes
## through a `{perception:}` ladder or nowhere, and there is deliberately no
## param source here that could carry it.
static func neighbour_tribe(args: Dictionary, context: LetterContext) -> Variant:
	if context.natives == null:
		return args.get("fallback", "the natives")

	var tribe: Tribe = null
	if context.town != null:
		var nearest: Dictionary = Intrusion.at(context.town.at, context.natives)
		if float(nearest["depth"]) > 0.0:
			tribe = context.natives.find(StringName(nearest["tribe"]))
	if tribe == null and context.sender != null \
			and context.sender.role == Contact.ROLE_DIPLOMAT:
		# §8.1: he reports more widely, so the people he names are whichever of
		# them the colony has most to worry about.
		tribe = context.natives.the_angriest()
	if tribe == null:
		return args.get("fallback", "the natives")
	return tribe.display_name


## How many of this town's own fields they work.
##
## **A count he could make himself**, walking out to the edge of his ground.
static func neighbour_fields(_args: Dictionary, context: LetterContext) -> Variant:
	if context.town == null or context.natives == null:
		return 0
	var reach := Territory.reach_of(context.town)
	var held := 0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if not String(context.natives.holder_of(
					context.town.at + Vector2i(dx, dy))).is_empty():
				held += 1
	return held


## One side of the bargain a governor has struck with a village (#206).
##
## 🔒 **What was traded, never what it did to their regard.** The axis is a plain
## fact the PC is entitled to: his governor gave away so much of one thing for so
## much of another, and he is reading about it a month late because that is when
## the post is.
static func bargain(args: Dictionary, context: LetterContext) -> Variant:
	var field := String(args.get("field", "they_give"))
	var value := ColonyConditions.bargain_field(context, field)
	return value if not value.is_empty() else args.get("fallback", "goods")


## How much this duke is asking for (#210, `rival-pressure.md` §3).
##
## 🔒 **Scaled by his band**, which is read off his loyalty like everything else
## he does: reasonable while he is being paid, dearer once he is not. Priced
## against the Crown's own demand so the two weigh comparably on a colony, and
## so the `size` dimension reaches both without a second table.
## 🔒 **Gold, never goods** (SPEC §8.4, v3.0). A duke's ships do not dock at a
## colonial town — only the Crown trades with these colonies — so there is no
## resource to name and no conversion at the end of this. The figure was always
## gold; it used to be divided by a price on the way out.
static func tribute_amount(_args: Dictionary, context: LetterContext) -> Variant:
	var band := RivalDuke.band_of(context.loyalty())
	return maxf(1.0, DemandSchedule.gold_target(context.demands)
		* RivalDuke.tribute_multiple(band))


## 🔒 **What a patron asks for when a matter at home has gone against him**
## (#388, `patrons.md` §10).
##
## A share of the Crown's own monthly ask, so it grows with the colony exactly as
## every other figure the PC is asked for does — a fixed sum would be ruinous in
## year one and beneath notice in year eight.
##
## 🔒 **Below what a duke demands, and that is the difference between them.**
## A duke is describing a difficulty he has and letting the PC draw the
## conclusion; a patron is asking a favour of somebody he likes, and a favour
## that beggared the colony would not be one. The share is tuning and M8 owns it.
const PATRON_ASK_SHARE: float = 0.55


## 🔒 **The resource that sold the most gold this month** (#278,
## `institutional-contacts.md` §3, the Author's first ruling).
##
## **Not most duty collected, and not averaged over a season.** The liveliest of
## the three readings, chosen deliberately: the priest asks about whatever had a
## good harvest, so the ask **swings with the colony's fortunes** rather than
## settling on one staple for the whole run.
##
## Gross rather than net, because what he is celebrating is the trade itself and
## not the Crown's share of it — and because the duty is the thing he is about to
## ask to have set aside, so pricing his question by it would be circular.
##
## Summed across every town, since §10.2 has no per-town rates and the festival
## he is asking for is colony-wide.
static func best_selling_resource(args: Dictionary, context: LetterContext) -> Variant:
	var fallback := String(args.get("fallback", ""))
	if context == null or context.log == null:
		return fallback
	var sold: Dictionary = {}
	for event in context.log.of_type(Trade.EVENT_SOLD):
		if event.month != context.month:
			continue
		var id := String(event.payload.get("resource", ""))
		if id.is_empty():
			continue
		sold[id] = float(sold.get(id, 0.0)) + float(event.payload.get("gross", 0.0))

	# **Sorted, and ties go to the earlier id.** Two trades that earned the same
	# gold must not depend on which town's sale the log happened to hold first.
	var best := ""
	var most := 0.0
	var names: Array = sold.keys()
	names.sort()
	for id in names:
		if float(sold[id]) > most:
			most = float(sold[id])
			best = String(id)
	return best if not best.is_empty() else fallback


static func patron_ask(_args: Dictionary, context: LetterContext) -> Variant:
	return maxf(1.0, DemandSchedule.gold_target(context.demands) * PATRON_ASK_SHARE)


## 🔒 **What the letter this one travels with said** (#404): one of its params,
## by name. Only a companion has a lead; anywhere else this is empty, and the
## validator refuses it outside a `companion_of` trigger.
static func lead(args: Dictionary, context: LetterContext) -> Variant:
	if context == null:
		return ""
	return context.lead.get(String(args.get("param", "")), "")


## 🔒 **What a patron wants shipped to him** (#441, `patrons.md` §4): his need's
## kind (`resource`), how much of it (`amount`), and inside how many months
## (`months`).
##
## **As heavy as his gold ask, in goods**: the gold `patron_ask` would name, at
## the Crown's price for the kind — the Marshal's requisition is sized the same
## way. A placeholder, since §11 lists the size of a need's shipment as tuning;
## the term is the requisition's.
static func his_need(args: Dictionary, context: LetterContext) -> Variant:
	var him := context.sender if context != null else null
	match String(args.get("field", "resource")):
		"amount":
			if him == null or him.need_kind.is_empty():
				return 0
			var price := maxf(0.5, ResourceCatalogue.price_of(StringName(him.need_kind)))
			return int(maxf(1.0, roundf(float(patron_ask({}, context)) / price)))
		"months":
			return DemandSchedule.term_months()
		_:
			return him.need_kind if him != null else ""


## How many months until this patron goes (#388, `patrons.md` §8).
##
## 🔒 **Every letter from here names the date**, and the reason is that his
## final loyalty banks permanently when he leaves: the six months are the last
## chance to move it and the PC is supposed to know it to the month.
static func patron_leaves_in(_args: Dictionary, context: LetterContext) -> Variant:
	if context == null or context.sender == null:
		return 0
	return PatronTerm.months_left(context.sender, context.month)


## How many of this town's fields somebody's men are standing on (#188).
##
## **A count a governor could make by walking out to them**, which is the whole
## of what he can report: there is no casualty to name and no damage to describe,
## only less country than there was last month.
static func denied_fields(_args: Dictionary, context: LetterContext) -> Variant:
	return ColonyConditions.denied_count(context)


## One field of the gap between what the PC wrote and what a town did (#258).
##
## 🔒 **He can name the man's reason truthfully** because `choose()` emitted its
## trace (SPEC §9.1). The Diplomat is not guessing and he is not inventing; he is
## reading the same record the sim wrote, which is exactly what makes him worth
## keeping and what his death costs.
static func divergence(args: Dictionary, context: LetterContext) -> Variant:
	var found := ColonyConditions.diverged({"within": 6}, context)
	var field := String(args.get("field", "governor"))
	if found.is_empty() or not found.has(field):
		return args.get("fallback", "the work")

	var value := String(found[field])
	# An intent is named as a letter would name it, not by its id.
	if field == "asked" or field == "did":
		var name := Objective.intent_name(StringName(value))
		return name if not name.is_empty() else value
	if field == "town" and context.colony != null:
		var town := context.colony.by_id(StringName(value))
		if town != null:
			return town.display_name
	return value


# --- The last chance (#268, `docs/mechanics/endings.md` §2, §3) -------------


## How the Chancellor names Independence's conditions — `which` being `"true"`
## for the ones that have flipped and `"false"` for what still stands.
##
## 🔒 **Read off the same look `RunEndCheck` was given**, never recomputed. A
## letter that asked the world again could name a condition the check did not
## believe in, which is the one thing a formal warning must never do.
##
## 🔒 **And the prose is in `data/`** (`IndependenceClause`). The ids stop here.
static func independence_conditions(
	args: Dictionary, context: LetterContext
) -> Variant:
	if context == null or context.log == null:
		return ""
	var flags := LastChance.latest(context.log, context.month)
	if flags.is_empty():
		return ""
	return IndependenceClause.phrase_for(
		flags, String(args.get("which", "true")) == "true")


## Everyone the colony still has, in its towns and on the road.
##
## Exact and truthful, so a `{param:}` rather than a `{perception:}` — the
## Chancellor is unpleasant about the figure and he is not wrong about it.
static func colony_people(_args: Dictionary, context: LetterContext) -> Variant:
	if context == null or context.log == null:
		return 0
	return int(LastChance.latest(context.log, context.month).get("people", 0))
