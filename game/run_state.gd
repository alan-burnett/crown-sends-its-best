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

# --- The correspondence ----------------------------------------------------

## Contact id -> Contact, each carrying its own Relationship.
var contacts: Dictionary = {}

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
	run.world = StubWorld.initial_state()
	run.log = EventLog.new()
	run.intents = IntentBook.new()
	run.post = Post.new()
	run.last_diff = WorldDiff.new()
	return run


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
		"streams": streams.to_dict(),
		"last_diff": last_diff.to_dict(),
		"contacts": contact_entries,
		"inbox": inbox_entries,
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
	run.streams = RngStreams.from_dict(data.get("streams", {}))
	run.last_diff = WorldDiff.from_dict(data.get("last_diff", {}))
	run.post = Post.from_dict(data.get("post", {}))

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
