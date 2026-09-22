class_name PatronDriver
extends RefCounted

## Brings the patrons in, and carries what they say (#282,
## `docs/mechanics/patrons.md` §6, §7).
##
## ## Phase 1, because arriving is what phase 1 is
##
## 🔒 **No clock of its own** (§7). `Patron.how_many_arrived` reads the Squeeze's
## fourth dimension and nothing else, so this driver has nothing to decide: it
## compares how many the Squeeze has produced with how many are on the roster and
## makes up the difference.
##
## **Asked every month rather than reacting to a growth event.** The same shape
## `ContactRoster.house_the_residents` takes, and for the same reason — a run
## loaded from a save is correct without replaying its history.
##
## ## Phase 7, after the drift, because gossip is about a fall
##
## `DriftDriver` has just moved every man with the month, and the deeds of the
## month before are already in. So what the court hears is everything that has
## happened to a patron since the last time it heard, which is what
## `PatronBook.fall_of` means.
##
## **Before compliance**, like the drift, so a Steward writing this month writes
## in the mood the gossip has already put him in.

var run: RunState = null


func _init(p_run: RunState = null) -> void:
	run = p_run


func on_phase(phase: StringName, state: WorldState, log: EventLog, _streams: RngStreams) -> void:
	if run == null:
		return
	match phase:
		WorldPhase.ARRIVALS:
			_arrive(state, log)
		WorldPhase.RECKONING:
			PatronGossip.spread(run, log, state.month)


## Make up the difference between the men the Squeeze has produced and the men
## on the roster.
func _arrive(state: WorldState, log: EventLog) -> void:
	if run.patrons == null or run.streams == null:
		return
	var wanted := Patron.how_many_arrived(run.demands)
	var here := Patron.all_in(run).size()
	while here < wanted:
		var patron := Patron.generate(run.patrons.next_id(), run.streams, state.month)
		run.add_contact(patron)
		here += 1
		# Seam A. What he is, said once, so the letters and the map read the same
		# man — and so the harness can count the vices a run actually produced.
		log.emit(Patron.EVENT_ARRIVED, patron.id, state.month, {
			"patron": String(patron.id),
			"name": patron.display_name,
			"specialty": patron.specialty,
			"need": patron.need,
			"vice": String(patron.vice),
		}, WorldPhase.ARRIVALS)
