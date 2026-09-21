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


## The Crown Officers, in id order. M1 has three of the five.
static func crown_officers(run: RunState) -> Array[Contact]:
	var out: Array[Contact] = []
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact.role == Contact.ROLE_CROWN_OFFICER:
			out.append(contact)
	return out
