class_name Companies
extends RefCounted

## Every body of armed men in the world, and the order they act in (#211,
## `docs/mechanics/battles.md` §7).
##
## ## 🔒 Order is fixed and never incidental
##
## Several companies may attack one in a month and each is a separate battle
## resolved in sequence, **so the defender weakens as they come** — a Crown
## company surrounded by rebels can be destroyed in a single month, and that is
## the design. Which means the order decides outcomes:
##
## 1. **Factions in a set sequence** — colonial, Crown, rebel, rival, native.
## 2. **Within a faction, earliest-created first**, by the sequential id assigned
##    at instantiation.
##
## The same rule that orders towns. It needs **no tie-break and no seeded roll**,
## because creation order is already deterministic from the seed — and a dev who
## reached for a shuffle here would be spending randomness on a question that has
## already been answered.
##
## ## 🔒 The ordinal is the identity, not the index
##
## Companies leave the list when they are wiped out, so a position in an array is
## not stable and must never be the tie-break. The ordinal is handed out once,
## never reused, and outlives whatever else happens to the array.

const EVENT_RAISED: StringName = Company.EVENT_RAISED

var list: Array = []

## How many have ever been raised. **Counts raisings, not seats** — the same
## reason `PatronBook.arrived` does, so a company destroyed in year three cannot
## have its number handed to one raised in year four.
var raised: int = 0

## And how many commanders have ever been made for them (#220).
##
## **Here rather than on a book of its own**, because it is the same kind of fact
## and because a commander only ever comes into being at a raising. Counts men
## made, not men alive: a commander killed with his company must not have his
## number handed to the next one.
var commanders_raised: int = 0


## Bring a company into the world (Seam A).
##
## 🔒 **The only place a company is created**, so the ordinal cannot be handed
## out by two routes and the arms cannot be set anywhere else. §2's rule that a
## company never resupplies is only true if there is exactly one door.
func raise_company(
	allegiance: StringName,
	size: int,
	arms: Dictionary,
	support: StringName,
	at: Vector2i,
	context: ColonyContext,
	order: StringName = StandingOrder.DEFEND_THE_TOWN,
	led_by: StringName = &"",
) -> Company:
	raised += 1
	var company := Company.new(StringName("company_%d" % raised), raised)
	company.allegiance = allegiance
	company.size = maxi(0, size)
	company.support = support
	company.at = at
	company.order = StandingOrder.of(order)
	company.led_by = led_by
	company.raised_month = context.state.month
	# **Copied, not referenced.** A town that handed its stockpile dictionary
	# over would find the company spending it.
	for resource in Company.armed_resources():
		var amount := float(arms.get(String(resource), 0.0))
		if amount > 0.0:
			company.arms[String(resource)] = amount
	list.append(company)

	context.log.emit(Company.EVENT_RAISED, company.id, context.state.month, {
		"company": String(company.id),
		"allegiance": String(allegiance),
		"size": company.size,
		"support": String(support),
		"order": String(company.order),
		# 🔒 **Whether anybody will be deciding for it** (#220, `commanders.md`
		# §2). Said at the raising, because that is the moment the choice was
		# made and the moment it can still be argued with.
		"needs_a_commander": company.wants_a_commander(),
		"arms": company.arms.duplicate(),
		"cavalry": company.is_cavalry(),
		"at": [at.x, at.y],
		# 🔒 **What it is worth, said the day it was raised** (#214, §5). Arming a
		# company is an allocation the PC pays for a month in advance, and a
		# letter that could only report how many men went out could not tell him
		# whether the guns he sent made any difference.
		"force": Force.breakdown(company, context.map),
	}, WorldPhase.COLONY_MONTH)
	return company


func find(id: StringName) -> Company:
	for entry in list:
		if (entry as Company).id == id:
			return entry
	return null


## 🔒 **Factions in sequence, then earliest-created first** (§7).
func in_resolution_order() -> Array:
	var out: Array = []
	for faction in Company.FACTIONS:
		var of_this_faction: Array = []
		for entry in list:
			if (entry as Company).allegiance == faction:
				of_this_faction.append(entry)
		of_this_faction.sort_custom(func(a: Company, b: Company) -> bool:
			return a.ordinal < b.ordinal)
		out.append_array(of_this_faction)
	# **An allegiance nobody listed still acts.** A company left out of the order
	# would be one that never moved and never fought, which is worse than one
	# acting last — and it goes after everything named, so adding a faction to
	# `FACTIONS` cannot reorder the ones already there.
	for entry in list:
		if not Company.FACTIONS.has((entry as Company).allegiance):
			out.append(entry)
	return out


## The companies a town victuals, in resolution order.
##
## 🔒 **Crown companies are never in it**, whatever they are standing next to.
## `the-marshal.md` §3 locks that Crown troops are victualled by the Crown and
## there is no state in which they depend on the colony — so the filter is on
## `support` and not on where the company happens to be.
func supported_by(town: StringName) -> Array:
	var out: Array = []
	if String(town).is_empty():
		return out
	for entry in in_resolution_order():
		var company: Company = entry
		if not company.is_the_crowns_burden() and company.support == town:
			out.append(company)
	return out


## Whoever is commanding this company, or null.
func commander_of(company: Company, contacts: Dictionary) -> Contact:
	if company == null or company.is_headless():
		return null
	return contacts.get(String(company.commander), null)


## Whether this man has a company in the field.
##
## 🔒 **The commander persists, not the company** (`commanders.md` §7). A veteran
## between commands is an ordinary contact who happens to have nothing to lead —
## which is what lets experience survive across companies without any of the
## machinery reinforcing them would demand.
func is_commanding(commander: StringName) -> bool:
	for entry in list:
		var company: Company = entry
		if not company.is_empty() and company.commander == commander:
			return true
	return false


## Drop the ones with nobody left in them.
##
## Called after losses rather than inside them, so a company that was wiped out
## has already emitted what happened to it before it leaves the list.
func bury_the_dead() -> void:
	var living: Array = []
	for entry in list:
		if not (entry as Company).is_empty():
			living.append(entry)
	list = living


func to_dict() -> Dictionary:
	var out: Array = []
	# **In resolution order**, so the save reads the way the month does.
	for entry in in_resolution_order():
		out.append((entry as Company).to_dict())
	return {"raised": raised, "commanders_raised": commanders_raised, "list": out}


static func from_dict(data: Dictionary) -> Companies:
	var book := Companies.new()
	book.raised = int(data.get("raised", 0))
	book.commanders_raised = int(data.get("commanders_raised", 0))
	for entry in data.get("list", []):
		book.list.append(Company.from_dict(entry))
	return book
