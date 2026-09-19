class_name RngStreams
extends RefCounted

## Named RNG streams, one per system, plus lazily derived per-contact streams.
##
## `CLAUDE.md` Determinism: never one global RNG. Each system draws from its own
## stream, so adding a die roll in one system cannot perturb another's sequence.
##
## Per-contact streams derive lazily from the run seed and the contact id, so a
## contact created in month 40 still reproduces exactly: the same seed yields
## the same Marshal, with the same temperament, whatever happened elsewhere.
##
## Streams serialise with the save (SPEC §16.2). A `RandomNumberGenerator`
## carries both `seed` and `state`; restoring `state` resumes the sequence at
## precisely the draw it was on, which is what resume has to mean.

## The system streams. Asking for anything else is a programming error.
##
## `crown` is the Crown's own dice: which axis its demands grow along each year
## (#69). Separate from `sim` so that the shape of a run's squeeze does not
## change because the colony sim threw one more die somewhere.
const SYSTEM_STREAMS: PackedStringArray = ["mapgen", "letters", "sim", "contacts", "crown"]

const CONTACT_PREFIX: String = "contact:"

var _run_seed: int = 0
var _streams: Dictionary = {}  # String -> RandomNumberGenerator


func _init(run_seed: int = 0) -> void:
	_run_seed = run_seed


func run_seed() -> int:
	return _run_seed


## A system stream. The name must be one of SYSTEM_STREAMS.
func stream(name: String) -> RandomNumberGenerator:
	assert(SYSTEM_STREAMS.has(name), "Unknown system stream '%s'. Add it to RngStreams.SYSTEM_STREAMS." % name)
	return _get_or_derive(name)


## A contact's own stream, derived on first use.
func contact_stream(contact_id: String) -> RandomNumberGenerator:
	assert(not contact_id.is_empty(), "contact_stream() requires a contact id")
	return _get_or_derive(CONTACT_PREFIX + contact_id)


## Stream keys that currently exist, sorted, so callers never iterate an
## unordered collection where the result depends on order.
func active_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray(_streams.keys())
	keys.sort()
	return keys


func _get_or_derive(key: String) -> RandomNumberGenerator:
	if _streams.has(key):
		return _streams[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = StableHash.stream_seed(_run_seed, key)
	_streams[key] = rng
	return rng


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	var streams: Dictionary = {}
	for key in active_keys():
		var rng: RandomNumberGenerator = _streams[key]
		streams[key] = {"seed": rng.seed, "state": rng.state}
	return {"run_seed": _run_seed, "streams": streams}


static func from_dict(data: Dictionary) -> RngStreams:
	var streams := RngStreams.new(int(data.get("run_seed", 0)))
	var saved: Dictionary = data.get("streams", {})
	var keys: Array = saved.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = saved[key]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(entry.get("seed", 0))
		rng.state = int(entry.get("state", 0))
		streams._streams[key] = rng
	return streams
