class_name DecisionKind
extends RefCounted

## The decision points the spec asks an actor to weigh.
##
## `docs/mechanics/deliberation.md` §1 lists six. They are one mechanism, so that
## a system added in a later milestone extends every decision point at once
## instead of each one growing an `if` branch.
##
## A consideration registers against the kinds it affects. Adding a kind here
## does not touch the kernel.

## A governor picks a town objective (SPEC §11.3).
const TOWN_OBJECTIVE: StringName = &"town_objective"

## A contact complies, partly complies, delays, reinterprets, refuses, or acts
## alone (SPEC §8.5).
const ORDER_COMPLIANCE: StringName = &"order_compliance"

## A contact decides for himself when the PC does not reply (SPEC §9.3).
const UNANSWERED: StringName = &"unanswered"

## The director decides who writes to the PC and about what (SPEC §9.6).
const DIRECTOR_URGENCY: StringName = &"director_urgency"

## A town decides to hold a trade protest (SPEC §10.2).
const TRADE_PROTEST: StringName = &"trade_protest"

## A tribe decides its diplomacy; a rival decides to demand or attack
## (SPEC §12.5, §8.4).
const FACTION_POSTURE: StringName = &"faction_posture"

const ALL: Array[StringName] = [
	TOWN_OBJECTIVE,
	ORDER_COMPLIANCE,
	UNANSWERED,
	DIRECTOR_URGENCY,
	TRADE_PROTEST,
	FACTION_POSTURE,
]


static func is_kind(name: StringName) -> bool:
	return ALL.has(name)
