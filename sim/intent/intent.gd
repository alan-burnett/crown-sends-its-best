class_name Intent
extends RefCounted

## What an actor has committed to doing, executed by the simulation over months.
##
## Seam C (`CLAUDE.md`, `docs/mechanics/deliberation.md` §7). Neither a player
## letter nor an NPC's decision changes the world directly:
##
## ```
## player letter -> Order -> compliance --+
##                                        +--> Intent -> executed over months -> events
## NPC deliberation -> will --------------+
## ```
##
## "The contact complied with your order" and "the contact acted on his own and
## informed the PC afterward" (SPEC §8.5) are therefore the same code path with
## different origins, rather than two systems that resemble each other.
##
## **The model is fixed in M1. Later milestones add executors, not a new model.**

# --- Resolutions -----------------------------------------------------------

const IN_PROGRESS: StringName = &"in_progress"
const COMPLETED: StringName = &"completed"
const STALLED: StringName = &"stalled"
const ABANDONED: StringName = &"abandoned"
const OVERTAKEN_BY_EVENTS: StringName = &"overtaken_by_events"

const RESOLUTIONS: Array[StringName] = [COMPLETED, STALLED, ABANDONED, OVERTAKEN_BY_EVENTS]

## Where an Intent came from. The two origins Seam C unifies.
const ORIGIN_ORDER: StringName = &"order"
const ORIGIN_WILL: StringName = &"will"

var id: StringName = &""

## What is being done. Executors select on this.
var kind: StringName = &""

## Who committed to it, and what it is aimed at.
var source: StringName = &""
var target: StringName = &""

## `ORIGIN_ORDER` when it came from a player letter through compliance,
## `ORIGIN_WILL` when the actor decided for himself. The executor treats them
## identically; only the letters care which it was.
var origin: StringName = ORIGIN_WILL

## The world month this was committed in.
##
## **The timing rule lives here.** An Intent committed in month N executes in
## phase 2 of month N+1 (`docs/mechanics/world-month.md` §3), so an executor
## must refuse to advance an Intent in the month it was committed. Stated on the
## player's clock: an order written on turn T is acknowledged in turn T+1's
## letters, and its physical consequence happens during turn T+1's resolution,
## which the player watches in turn T+2's map playback.
var committed_month: int = 0

## Months of work done, and months needed.
##
## **Make consequential actions multi-month, so they can be interrupted**
## (`docs/mechanics/world-month.md` §3). A single-month action cannot be
## countermanded, which is where arriving too late is supposed to sting; if
## everything were single-month the player would be a spectator.
var progress: int = 0
var months_required: int = 1

var resolution: StringName = IN_PROGRESS

## The month it resolved, or -1 while live.
var resolved_month: int = -1

## Whatever the executor needs: an amount, a resource, a destination.
var data: Dictionary = {}


func _init(
	p_id: StringName = &"",
	p_kind: StringName = &"",
	p_source: StringName = &"",
	p_target: StringName = &"",
	p_months_required: int = 1,
	p_data: Dictionary = {},
) -> void:
	id = p_id
	kind = p_kind
	source = p_source
	target = p_target
	months_required = maxi(1, p_months_required)
	data = p_data.duplicate(true)


func is_live() -> bool:
	return resolution == IN_PROGRESS


## Two Intents contend when they come from the same actor and are aimed at the
## same thing. Committing the second resolves the first as `overtaken_by_events`
## — a later letter contradicting an earlier one, which SPEC §8.5 expects.
func contends_with(other: Intent) -> bool:
	return source == other.source and target == other.target


## Whether this may advance during `month`.
##
## False in the month it was committed. That one month of separation is the
## whole announce-then-act property: the actor writes back saying what he will
## do, and does it the month after.
func may_advance_in(month: int) -> bool:
	return is_live() and month > committed_month


func remaining() -> int:
	return maxi(0, months_required - progress)


## Advance one month of work. Returns true when that completed it.
func advance() -> bool:
	progress += 1
	return progress >= months_required


func resolve(p_resolution: StringName, month: int) -> void:
	if not RESOLUTIONS.has(p_resolution):
		push_error("Unknown Intent resolution '%s'." % p_resolution)
		return
	resolution = p_resolution
	resolved_month = month


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"kind": String(kind),
		"source": String(source),
		"target": String(target),
		"origin": String(origin),
		"committed_month": committed_month,
		"progress": progress,
		"months_required": months_required,
		"resolution": String(resolution),
		"resolved_month": resolved_month,
		"data": data.duplicate(true),
	}


static func from_dict(source_data: Dictionary) -> Intent:
	var intent := Intent.new(
		StringName(source_data.get("id", "")),
		StringName(source_data.get("kind", "")),
		StringName(source_data.get("source", "")),
		StringName(source_data.get("target", "")),
		int(source_data.get("months_required", 1)),
		source_data.get("data", {}),
	)
	intent.origin = StringName(source_data.get("origin", ORIGIN_WILL))
	intent.committed_month = int(source_data.get("committed_month", 0))
	intent.progress = int(source_data.get("progress", 0))
	intent.resolution = StringName(source_data.get("resolution", IN_PROGRESS))
	intent.resolved_month = int(source_data.get("resolved_month", -1))
	return intent


func _to_string() -> String:
	return "Intent(%s %s %s->%s %d/%d %s)" % [id, kind, source, target, progress, months_required, resolution]
