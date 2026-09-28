class_name MakingAnExample
extends RefCounted

## A Crown commander may make an example of a rebel town (#457,
## `commanders.md` §5, `rebel-sentiment.md` §4, SPEC §12.3).
##
## ## 🔒 It is his choice, not the PC's order
##
## A commander sent to put down the rebellion has one option more beside attack,
## hold, march, withdraw and disband: **punish the rebel town**. He scores it with
## everything else and takes it when it is best. For as long as he holds it, his
## company razes the town's improvements, strikes its expeditions, and sits on
## its fields so they yield nothing, as a duke's men deny tiles
## (`rival-pressure.md` §5). It takes his month, as razing does.
##
## ## 🔒 He asks first, or he says so after
##
## Choosing it, he **writes to the PC first** and waits for the answer — an
## urging like any other, which reaches him through compliance
## (`contacts.md` §3) — or he **does it on his own** (Seam C) and writes
## afterwards to say so. Which of the two is the one rule for whether a man still
## asks (`Consultation`), drawn on his own stream: a man who thinks well of the
## PC always asks.
##
## A PC who says yes urges him toward it. **Any other answer spares the town**,
## and so does none: he does not propose it again for a year.
##
## ## 🔒 Made an example of
##
## A town he punishes counts as punished for `MONTHS` from the last month he did
## (`Town.example_months`), and its example persuades its neighbours only a
## quarter as much, as an embargoed town's does (`RebelSentiment.argument_of`).
## What the punishment does to the town itself needs no term: its fields burn
## and lie idle, its quality of life falls, and that is what brings it back.

## He wrote to the PC first, proposing it.
const EVENT_PROPOSED: StringName = &"punishment_proposed"
## He began it without asking, and will write to say so.
const EVENT_ACTED_ALONE: StringName = &"made_an_example_unasked"
## A month of it: what he burnt, whom he struck, what he sat on.
const EVENT_PUNISHED: StringName = &"town_made_an_example_of"

## How long a town counts as made an example of, from the last month it was
## punished. A placeholder (#457).
const MONTHS: int = 12

## How long he waits on the PC's answer before reading its absence as a no. His
## letter goes out the month he asks, the reply is read the month after, and the
## urging it carries lands on his company the month after that. A placeholder.
const ANSWER_MONTHS: int = 4

## How long a town the PC spared stays spared before he may propose it again. A
## placeholder.
const SPARED_MONTHS: int = 12


## The rebel town this company could punish, or null.
##
## 🔒 **Only a Crown company sent to put down the rebellion**, on a rebel town's
## ground or beside it. Nearest first, then by id.
static func town_within_reach(company: Company, colony: Colony) -> Town:
	if company == null or colony == null or company.at == Company.NOWHERE:
		return null
	if company.allegiance != Company.CROWN or company.raised_under != CrownTroops.PUT_DOWN_THE_REBELLION:
		return null
	var best: Town = null
	var nearest := 0
	for entry in colony.in_order():
		var town: Town = entry
		if not town.rebelling:
			continue
		var away := maxi(absi(town.at.x - company.at.x), absi(town.at.y - company.at.y))
		if away > Territory.reach_of(town) + 1:
			continue
		if best == null or away < nearest:
			best = town
			nearest = away
	return best


## Whether he may choose it this month: he has leave, or he has not yet asked,
## or he asked long enough ago that the PC's answer has come and gone and the
## year he spared the town is over.
static func may_punish(company: Company, town: Town, log: EventLog, month: int) -> bool:
	if has_leave(company, town, log, month):
		return true
	var asked := _asked_in(company, town, log)
	return asked < 0 or month - asked > ANSWER_MONTHS + SPARED_MONTHS


## 🔒 **Whether he has leave to go on**: he was punishing it last month, or an
## urging toward it has reached his company since he asked — the PC's yes, or his
## own decision on a question the PC left unanswered (SPEC §9.3).
static func has_leave(company: Company, town: Town, log: EventLog, month: int) -> bool:
	if log == null:
		return false
	for event in log.of_type(EVENT_PUNISHED):
		if event.month == month - 1 and String(event.payload.get("company", "")) == String(company.id) \
				and String(event.payload.get("town", "")) == String(town.id):
			return true
	var asked := _asked_in(company, town, log)
	if asked < 0:
		return false
	for entry in company.urgings:
		var urging: Urging = entry
		if urging.target == CommanderConsiderations.PUNISH and urging.month >= asked:
			return true
	return false


## The month his commander last asked to punish this town, or -1.
static func _asked_in(company: Company, town: Town, log: EventLog) -> int:
	var asked := -1
	if log == null:
		return asked
	for event in log.of_type(EVENT_PROPOSED):
		if String(event.payload.get("commander", "")) == String(company.commander) \
				and String(event.payload.get("town", "")) == String(town.id):
			asked = event.month
	return asked
