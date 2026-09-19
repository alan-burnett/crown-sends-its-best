class_name RunState
extends RefCounted

## Everything one run is, in one serialisable object.
##
## **A full state snapshot, not seed-and-replay** (SPEC §16.2). Ironman means
## there is one save per run and no loading of earlier states, so the save has to
## be able to say what the world *is* rather than how to rebuild it — a replay
## that diverged by one draw would silently produce a different colony.
##
## It spans both layers on purpose: the world is the sim's, the contacts and the
## post are the correspondence layer's, and a run is both at once.

## Bumped whenever the shape of a save changes. **During development a save from
## an older version is refused rather than migrated** (`CLAUDE.md`), so this
## going up invalidates saves, deliberately.
const SAVE_VERSION: int = 1

## What the Crown hands over. How the initial grant is split between people, gold
## and resources is a starting decision in M3 (SPEC §6.1); these are the numbers
## until the player gets to choose.
const FIRST_TOWN_ID: StringName = &"ashmere"
const FIRST_TOWN_NAME: String = "Ashmere"
const STARTING_WORKERS: int = 12
const STARTING_FOOD: float = 90.0
const STARTING_WOOD: float = 30.0
const STARTING_TOOLS: float = 8.0
const STARTING_GOLD: float = 250.0

var version: int = SAVE_VERSION
var run_seed: int = 0

# --- The world -------------------------------------------------------------

var world: WorldState = null
var log: EventLog = null
var intents: IntentBook = null
var streams: RngStreams = null

## The diff across the month just resolved. The correspondence layer reads it
## alongside state, because people react to change as much as to conditions.
var last_diff: WorldDiff = null

## The New World. Generated from the run seed, and carried by the save rather
## than regenerated — a map rebuilt from a seed is a map that changes the day
## generation is tuned.
var map: WorldMap = null

## Where the colony began. Site selection among several regions is Run Setup in
## M3; M2 places one town.
var starting_site: Vector2i = Vector2i(-1, -1)

## Everything the PC administers (SPEC §4).
var colony: Colony = null

## **What the colony knows**, which is all the map view may read (SPEC §11.2).
var knowledge: MapKnowledge = null

## **What the Crown makes of the PC's accounts** (SPEC §10.3, #67).
##
## Never shown as a number; the four bands are the whole interface, and
## `tools/lint.gd` keeps `presentation/` away from it entirely.
var standing: CrownStanding = null

## **Whether the Crown is still honouring the PC's word** (SPEC §10.3, #68).
##
## Separate from standing on purpose: the arithmetic may collapse in a month,
## the political process may not.
var refusal: CrownRefusal = null

# --- The correspondence ----------------------------------------------------

## Contact id -> Contact, each carrying its own Relationship.
var contacts: Dictionary = {}

## Everything the PC has committed to. Honoured automatically while he can keep
## them; a broken one costs loyalty (SPEC §9.5).
var promises: PromiseBook = null

## Letter id -> the world month it last arrived.
##
## What stops the same three letters landing every month for a year. The
## director reads it; a save carries it, or a resumed run would forget and start
## repeating itself.
var letters_sent: Dictionary = {}

## This turn's desk.
var inbox: Array[InboundLetter] = []
var post: Post = null

# --- The turn --------------------------------------------------------------

## Turns elapsed. **A turn is the player's clock and a world month is the
## simulation's, and they are not the same index**
## (`docs/mechanics/world-month.md` §3). The desk sits between the month just
## reported and the month about to run.
var turn: int = 0

## Where in SPEC §7's sequence the turn is, so quitting mid-turn and resuming
## puts the player back where he was.
var phase: StringName = &"date_card"


static func new_run(seed_value: int) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_value
	run.streams = RngStreams.new(seed_value)
	run.world = WorldValues.initial_state()
	run.log = EventLog.new()
	run.intents = IntentBook.new()
	run.post = Post.new()
	run.promises = PromiseBook.new()
	run.last_diff = WorldDiff.new()
	run.map = MapGenerator.generate(run.streams.stream("mapgen"))
	run.starting_site = MapGenerator.choose_starting_site(run.map)
	run.colony = Colony.new()
	run.knowledge = MapKnowledge.new()
	run.standing = CrownStanding.new()
	run.refusal = CrownRefusal.new()
	run.found_first_town()

	# **A town knows the ground it was built on.** Territory is recomputed in
	# phase 3 of every world month, but the first of those does not run until the
	# first post is sent — so without this the player opens the map on turn one,
	# having just founded a town, and is shown an empty sea.
	run.knowledge.observe(
		run.map,
		Territory.compute(run.map, run.colony.in_order()),
		run.world.month,
		run.colony.in_order(),
	)
	return run


## The colony the PC is handed: one town, on the site the map chose, with a
## governor of its own.
##
## Site selection among several regions is Run Setup in M3, and founding further
## towns is M4 (SPEC §11.4). This is the one the run begins with.
func found_first_town() -> Town:
	if map == null or not map.in_bounds(starting_site.x, starting_site.y):
		return null

	var town := Town.new(FIRST_TOWN_ID, FIRST_TOWN_NAME, starting_site)
	town.workers = STARTING_WORKERS
	town.store(&"food", STARTING_FOOD)
	town.store(&"wood", STARTING_WOOD)
	town.store(&"tools", STARTING_TOOLS)
	town.receive_gold(STARTING_GOLD)
	# **He starts on the Crown's Mandate** (SPEC §6.1). Nothing here sets the
	# town's objective: the first Settle picks one to serve this, which is the
	# only way an objective is ever chosen (#53).
	town.intent = StringName(world.get_value(WorldValues.MANDATE, GovernorIntent.ECONOMY))
	# **A town founded last month has not lived a month yet**, and Settle has not
	# run. Without a starting value its governor opens the run reporting his
	# people as wretched, which is not true of anybody and is the first thing the
	# player reads.
	town.quality_of_life = float(world.get_value(WorldValues.QUALITY_OF_LIFE, 0.5))
	colony.add(town)

	add_contact(Governor.generate(town, streams))
	return town


func contact(id: StringName) -> Contact:
	return contacts.get(String(id))


func add_contact(entry: Contact) -> Contact:
	contacts[String(entry.id)] = entry
	return entry


## Contact ids, sorted. Never iterate `contacts` where order matters.
func contact_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(contacts.keys())
	ids.sort()
	return ids


# --- The desk --------------------------------------------------------------

func unread() -> Array[InboundLetter]:
	var out: Array[InboundLetter] = []
	for letter in inbox:
		if not letter.is_handled():
			out.append(letter)
	return out


## **The post cannot be sent while any incoming letter is unhandled** (#18, #23).
## Setting one aside counts as handling it; ignoring it does not.
func everything_handled() -> bool:
	return unread().is_empty()


func inbound(id: StringName) -> InboundLetter:
	for letter in inbox:
		if letter.id == id:
			return letter
	return null


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	var contact_entries: Dictionary = {}
	for id in contact_ids():
		contact_entries[id] = contacts[id].to_dict()

	var inbox_entries: Array = []
	for letter in inbox:
		inbox_entries.append(letter.to_dict())

	return {
		"version": version,
		"run_seed": run_seed,
		"turn": turn,
		"phase": String(phase),
		"world": world.to_dict(),
		"log": log.to_dict(),
		"intents": intents.to_dict(),
		"promises": promises.to_dict(),
		"streams": streams.to_dict(),
		"last_diff": last_diff.to_dict(),
		"map": map.to_dict() if map != null else {},
		"starting_site": [starting_site.x, starting_site.y],
		"colony": colony.to_dict() if colony != null else {},
		"knowledge": knowledge.to_dict() if knowledge != null else {},
		"standing": standing.to_dict() if standing != null else {},
		"refusal": refusal.to_dict() if refusal != null else {},
		"contacts": contact_entries,
		"inbox": inbox_entries,
		"letters_sent": letters_sent.duplicate(),
		"post": post.to_dict(),
	}


static func from_dict(data: Dictionary) -> RunState:
	var run := RunState.new()
	run.version = int(data.get("version", 0))
	run.run_seed = int(data.get("run_seed", 0))
	run.turn = int(data.get("turn", 0))
	run.phase = StringName(data.get("phase", "date_card"))
	run.world = WorldState.from_dict(data.get("world", {}))
	run.log = EventLog.from_dict(data.get("log", {}))
	run.intents = IntentBook.from_dict(data.get("intents", {}))
	run.promises = PromiseBook.from_dict(data.get("promises", {}))
	run.streams = RngStreams.from_dict(data.get("streams", {}))
	run.last_diff = WorldDiff.from_dict(data.get("last_diff", {}))
	run.map = WorldMap.from_dict(data.get("map", {}))
	var site: Array = data.get("starting_site", [-1, -1])
	run.starting_site = Vector2i(int(site[0]), int(site[1]))
	run.colony = Colony.from_dict(data.get("colony", {}))
	run.knowledge = MapKnowledge.from_dict(data.get("knowledge", {}))
	run.standing = CrownStanding.from_dict(data.get("standing", {}))
	run.refusal = CrownRefusal.from_dict(data.get("refusal", {}))
	run.post = Post.from_dict(data.get("post", {}))
	run.letters_sent = data.get("letters_sent", {}).duplicate()

	var saved_contacts: Dictionary = data.get("contacts", {})
	var ids: Array = saved_contacts.keys()
	ids.sort()
	for id in ids:
		run.contacts[id] = Contact.from_dict(saved_contacts[id])

	for entry in data.get("inbox", []):
		run.inbox.append(InboundLetter.from_dict(entry))

	return run


## Identical runs hash identically, in any process and on any platform.
func state_hash() -> String:
	return Canonical.hash_of(to_dict())
