class_name ContactRoster
extends RefCounted

## Loads the contacts a run starts with.
##
## **Crown Officers are the same in every run and are not randomised**
## (SPEC §8.1), so they come from `data/contacts/`. Adding the Provost and the
## Diplomat later is a new data file and no new code — which is the test of
## whether this is actually data-driven.
##
## Colony contacts and patrons are generated per run from their own streams
## (SPEC §8.2, §8.3) and arrive in later milestones.

const COLLECTION: String = "contacts"


## Every contact defined in data, in id order.
static func load_into(run: RunState, content: ContentDatabase) -> Array[Contact]:
	var loaded: Array[Contact] = []
	for id in content.ids(COLLECTION):
		var contact := Contact.from_data(content.collection(COLLECTION)[id])
		run.add_contact(contact)
		loaded.append(contact)
	house_the_diplomat(run)
	return loaded


## Put the Diplomat somewhere (#81, `the-diplomat.md` §2).
##
## **Data cannot know which town**, because the towns are made per run. He starts
## in the first the colony has, which is the capital and the one the PC will most
## want watched — and from there it is his own business and the PC's where he
## ends up.
##
## 🔒 **Housed in one town and aware of all of them.** A Diplomat with no town at
## all would report the colony's business and never the sharp half, which is the
## half that makes where he lives a decision.
static func house_the_diplomat(run: RunState) -> void:
	if run == null or run.colony == null:
		return
	var towns := run.colony.in_order()
	if towns.is_empty():
		return
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role == Contact.ROLE_DIPLOMAT and contact.town.is_empty():
			contact.town = towns[0].display_name


# --- Residents a building brings (#276) --------------------------------------

## 🔒 **A building brings a man, and there is no machinery for him** (#276,
## `institutional-contacts.md` §1).
##
## Every question one of these raises is answered somewhere `contacts.md` already
## has: what his loyalty does is §2, how he gets it is `cares_about`, what he asks
## for is his letters, and his bias is a perception lean. **A change made for one
## of them must not silently move the others**, which is what building him out of
## the base contact guarantees and a bespoke type would not.
##
## They are not patrons either. `patrons.md` is deliberately simple, and binding
## the two models together would handcuff each to the other's future.
##
## So this lives beside the Diplomat's housing rather than in a file of its own,
## because it is the same job: **putting a contact in a town.**
static func residents_of(town: Town, run: RunState) -> Array[Contact]:
	var out: Array[Contact] = []
	if town == null or run == null:
		return out
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role == Contact.ROLE_INSTITUTIONAL and contact.town == town.display_name:
			out.append(contact)
	return out


## The id a building's man goes by in this town.
##
## **One per kind per town**, which is what makes an extension widen rather than
## duplicate: the cathedral asks for the same id the church did and finds him
## already there.
static func resident_id(town: Town, kind: String) -> StringName:
	return StringName("%s_%s" % [kind, town.id])


## Grant whatever the buildings this town holds should have brought.
##
## 🔒 **Idempotent, and that is the whole of the extension rule** (§1). An
## extension building names the contact it widens rather than granting one, so
## the cathedral finds the clergyman the church brought and the town never has
## two. Asking every month rather than reacting to the completion event means a
## town loaded from a save is correct without replaying its history.
static func house_the_residents(run: RunState) -> void:
	if run == null or run.colony == null:
		return
	for town in run.colony.in_order():
		for id in town.buildings:
			var building := Building.find(StringName(id))
			if building == null or building.grants_contact.is_empty():
				continue
			_bring(town, building.grants_contact, run)


## And take back the ones whose building or town has gone.
##
## 🔒 **No successor** (`contacts.md` §8). A town that falls takes its clergyman
## with it, and the church rebuilt brings a new man who remembers nothing — which
## falls out of him being a fresh contact at a fresh id rather than needing a rule.
static func unhouse_the_lost(run: RunState) -> void:
	if run == null or run.colony == null:
		return
	var standing: Dictionary = {}
	for town in run.colony.in_order():
		for id in town.buildings:
			var building := Building.find(StringName(id))
			if building != null and not building.grants_contact.is_empty():
				standing[String(resident_id(town, building.grants_contact))] = true

	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role != Contact.ROLE_INSTITUTIONAL:
			continue
		if not standing.has(String(id)):
			run.contacts.erase(String(id))


static func _bring(town: Town, kind: String, run: RunState) -> void:
	var id := resident_id(town, kind)
	if run.contacts.has(String(id)):
		return
	var contact := Contact.generate(
		id, Contact.ROLE_INSTITUTIONAL, run.streams, IntentConsiderations.ALL)
	# **He lives here, which is most of what he is** (§2). Residency is what gives
	# him prominence, and prominence is what makes a slighted clergyman a
	# mechanical problem rather than a flavour one.
	contact.town = town.display_name
	contact.title = kind.capitalize()
	# §2's table: *Journalist Aldous Crane of Kettleburn*. The word is his kind,
	# because four kinds share the institutional role the way four offices share
	# the Crown officer's.
	contact.role_word = kind.capitalize()
	contact.portrait_asset = "portrait.%s" % kind
	run.add_contact(contact)


## The Crown Officers, in id order. M1 has three of the five.
static func crown_officers(run: RunState) -> Array[Contact]:
	var out: Array[Contact] = []
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role == Contact.ROLE_CROWN_OFFICER:
			out.append(contact)
	return out
