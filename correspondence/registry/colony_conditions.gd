class_name ColonyConditions
extends RefCounted

## When a governor has something to write home about (#54).
##
## M1's conditions ask about the world's scalars, which is all the stub had. A
## governor writes about **a place**: what it is short of, what he has set the
## men to, whether the church is finished. These are those questions.
##
## Every one of them returns false when there is no town, so a Crown officer's
## trigger cannot accidentally borrow one and fire on a colony-wide reading of a
## town-shaped question.
##
## **Named static functions, not lambdas.** A lambda held in a static registry
## crashes Godot 4.7 on shutdown (CLAUDE.md), and named functions show up in a
## stack trace.
##
## Every one only ever **reads**. A condition that changed anything would be
## logic in what is supposed to be a declarative layer.

static func register_all() -> void:
	ContentRegistry.register_condition(
		"town_short_of", {"resource": "string"}, ColonyConditions.town_short_of
	)
	ContentRegistry.register_condition(
		"town_is_building", {}, ColonyConditions.town_is_building
	)
	ContentRegistry.register_condition(
		"town_holds_a_posture", {}, ColonyConditions.town_holds_a_posture
	)
	ContentRegistry.register_condition(
		"town_objective_is_new", {}, ColonyConditions.town_objective_is_new
	)
	ContentRegistry.register_condition(
		"town_finished_something", {}, ColonyConditions.town_finished_something
	)
	ContentRegistry.register_condition(
		"town_intent_is", {"intent": "string"}, ColonyConditions.town_intent_is
	)
	ContentRegistry.register_condition(
		"town_disagrees_with_the_crown", {}, ColonyConditions.town_disagrees_with_the_crown
	)
	ContentRegistry.register_condition(
		"town_measure_below", {"measure": "string", "value": "number"},
		ColonyConditions.town_measure_below,
	)
	ContentRegistry.register_condition(
		"town_measure_above", {"measure": "string", "value": "number"},
		ColonyConditions.town_measure_above,
	)


## Whether the town could not cover a need out of its own stores this month.
##
## Reads Reckon's own shortfall rather than a fresh comparison, so the letter
## and the simulation cannot disagree about what "short" means (SPEC §9.1).
static func town_short_of(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	var resource := StringName(args.get("resource", ""))
	var monthly := maxf(1.0, float(context.town.population())) * ColonyNeeds.per_head(resource)
	if monthly <= 0.0:
		return false
	return context.town.held(resource) < monthly


## Whether there is a project underway — something with a finish.
static func town_is_building(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and Objective.completes(context.town.objective)


## Whether the town is under a standing order instead.
static func town_holds_a_posture(_args: Dictionary, context: LetterContext) -> bool:
	return context.town != null and Objective.is_posture(context.town.objective)


## Whether the objective was settled on this month and nothing has been done
## about it yet.
##
## **This is the announcement window.** The governor says what he means to do in
## phase 9; the work starts in next month's Build. A letter fired on this
## condition is the player's chance to object before a plank is cut, which is
## what makes the loop feel responsive rather than reportorial.
static func town_objective_is_new(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.objective).is_empty():
		return false
	return town.objective_since == context.month and town.objective_progress == 0


## Whether something was finished this month.
##
## Read from what the town remembers rather than from the objective, which Build
## has already cleared by the time anybody writes about it.
static func town_finished_something(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.last_completed).is_empty():
		return false
	return town.last_completed_month == context.month


static func town_intent_is(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return String(context.town.intent) == String(args.get("intent", ""))


## Whether the governor is going his own way after being written to.
##
## **He was asked and he has not come round**, which is a letter he owes the PC
## and the one place compliance becomes visible as character rather than as an
## outcome code.
static func town_disagrees_with_the_crown(_args: Dictionary, context: LetterContext) -> bool:
	var town := context.town
	if town == null or String(town.urged_intent).is_empty():
		return false
	return town.urged_intent != town.intent


static func town_measure_below(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return context.measure(String(args.get("measure", "")), 1.0) < float(args.get("value", 0.0))


static func town_measure_above(args: Dictionary, context: LetterContext) -> bool:
	if context.town == null:
		return false
	return context.measure(String(args.get("measure", "")), 0.0) > float(args.get("value", 0.0))
