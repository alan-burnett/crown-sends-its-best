class_name Commanders
extends RefCounted

## Who leads a company, and whether one is needed at all (#220,
## `docs/mechanics/commanders.md` §1, §2; `battles.md` §4).
##
## ## 🔒 A commander is an ordinary contact
##
## He has a name, a personality, leans, `cares_about` and a **relationship** with
## the PC, exactly as every other contact does. What makes him a commander is
## that a company is attached to him — and there is deliberately **no commander
## machinery**, for the same reason `institutional-contacts.md` §1 refuses it for
## the clergy: every question he raises is answered somewhere `contacts.md`
## already has.
##
## **Colonial, Crown and rebel commanders are the same object.** A rebel general
## corresponding with the Crown about terms is the mechanism working rather than
## a special case — the channel SPEC §12.3 implies when it says the PC keeps
## writing to a rebel town and never names for its soldiers. He differs from a
## colonial commander in one field, his allegiance's, and in the pool his name
## comes from.
##
## ## 🔒 The order decides whether a man is needed, and it is not a size check
##
## `battles.md` §4: a company with no commander has nobody to deliberate for it,
## so it can only hold a posture. **You do not need a general to man a palisade**
## — you need one the moment the company has to *go* somewhere, because going
## somewhere is a decision.
##
## ## The three outcomes at raising (§2)
##
## | | |
## | :--- | :--- |
## | A veteran is waiting in this town | **he takes it**, at the level he left at |
## | No veteran, and the order needs one | a new commander, at level zero |
## | The order is defensive | **nobody**, and it disbands on its timer |
##
## The first is what makes `commanders.md` §7 work without a resupply mechanic:
## a company only ever dwindles, so **the commander is the thing that persists**
## and experience survives across companies rather than across reinforcements.

const ROLE: StringName = Contact.ROLE_COMMANDER


## Every commander on the roster, in id order — commanding or waiting, alive or
## not.
static func all_in(run: RunState) -> Array:
	var out: Array = []
	if run == null:
		return out
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact != null and contact.role == ROLE:
			out.append(contact)
	return out


## The veterans idle in this town, in id order.
##
## 🔒 **A veteran is an ordinary contact who happens to have nothing to lead**
## (§7). He waits where he was dispatched from and takes the next command raised
## there — which is also why his letter is an instrument rather than flavour: a
## general without a command is a standing argument for raising another company,
## made by the man himself.
static func waiting_in(town: Town, run: RunState) -> Array:
	var out: Array = []
	if town == null or run == null or run.companies == null:
		return out
	for entry in all_in(run):
		var man: Contact = entry
		if man.is_dead or man.town != town.display_name:
			continue
		if not run.companies.is_commanding(man.id):
			out.append(man)
	return out


## Give this company a commander, if it wants one: as its raising settled it
## (#432), or else as its order asks (§2).
##
## Returns the man who took it, or null for a headless militia. **Called at the
## raising and nowhere else**, because §3's order is given once and a company
## that acquired a commander later would be one that changed what it was for.
static func take_command(
	company: Company, town: Town, run: RunState, context: ColonyContext
) -> Contact:
	if company == null or run == null:
		return null
	# 🔒 **Settled at the raising** (#432): a scouting party is a militia and a
	# big company from a sizeable town has a man. For a company nobody settled it
	# for, **the order, not the size** (§2): a hundred men behind a stockade need
	# nobody; twelve men marching on a village need someone to decide whether to
	# press on when they find it defended.
	if not company.wants_a_commander():
		return null

	var veterans := waiting_in(town, run)
	var man: Contact = veterans[0] if not veterans.is_empty() else null
	var found_one := man != null
	if not found_one:
		man = _generate(company, town, run)
		run.add_contact(man)

	company.commander = man.id
	# 🔒 **At the level he left at** (§7, #223). The veteran's tally is his and
	# survived the company that earned it, so the next command starts where the
	# last one ended — which is what makes experience persist without any of the
	# machinery reinforcing a company would demand.
	if run.commanders != null:
		company.commander_level = run.commanders.level_of(man.id)
	# **His allegiance is the company's**, and it can change under him: a town
	# commander whose town revolts becomes *of the independent nation*, the same
	# object serving somebody else (`names.md` §2).
	man.qualifier = _qualifier_for(company.allegiance)

	context.log.emit(Company.EVENT_COMMANDED, company.id, context.state.month, {
		"company": String(company.id),
		"commander": String(man.id),
		"name": man.display_name,
		"order": String(company.order),
		# Which of §2's first two outcomes this was, for the harness and for the
		# letter that tells the PC his veteran is in the field again.
		"veteran": found_one,
	}, WorldPhase.COLONY_MONTH)
	return man


## A new man, at nothing at all (§2's second outcome).
##
## 🔒 **From his own stream**, derived as `hash(run_seed, contact_id)` like every
## other generated contact — so the same seed yields the same officer however
## late in the run his town got around to raising him a company.
static func _generate(company: Company, town: Town, run: RunState) -> Contact:
	var run_of_commanders := run.companies.commanders_raised + 1
	run.companies.commanders_raised = run_of_commanders
	# 🔒 **He is rolled a weight for what a commander weighs** (#221). A man with
	# no weight on `keeping_my_army_alive` would weigh it exactly as every other
	# commander does, and two men reading the same board would always agree — so
	# the cautious man and the glory-seeker would be the same man.
	var considers := IntentConsiderations.ALL.duplicate()
	considers.append_array(CommanderConsiderations.ALL)
	var man := Contact.generate(
		StringName("commander_%d" % run_of_commanders),
		ROLE,
		run.streams,
		considers,
	)
	# 🔒 **A company is given to the same sort of man either way** (`names.md`
	# §3). The Marshal's officer comes from the pool a patron comes from; a
	# colonial company goes to one of the well-to-do colonists a governor comes
	# from, which the bag decides and nothing here does.
	var bag := NameBags.bag_for(ROLE, company.allegiance == Company.CROWN)
	if not bag.is_empty():
		var drawn := NameBags.person(bag, run.streams.contact_stream(String(man.id)))
		if not drawn.is_empty():
			man.display_name = drawn
	if town != null:
		man.town = town.display_name
	man.known_since = run.world.month if run.world != null else 0
	return man


## What follows his name, by whose company it is (`names.md` §2).
static func _qualifier_for(allegiance: StringName) -> String:
	match allegiance:
		Company.CROWN:
			return Letterhead.CROWN_COMMANDER
		Company.REBEL:
			return Letterhead.REBEL_COMMANDER
		_:
			return Letterhead.qualifier_for(ROLE)
