class_name SilenceDriver
extends RefCounted

## Resolves the letters the PC did not answer, in **phase 7, Reckoning**.
##
## The same phase the post is read in, because silence is a kind of reply: the
## contact learns in the same month that nothing came, and reacts then.

var run: RunState = null
var content: ContentDatabase = null

## Letters set aside when the post went, waiting to be read as silence.
var pending: Array[InboundLetter] = []

var results: Array[Dictionary] = []


func on_phase(phase: StringName, _state: WorldState, _log: EventLog, _streams: RngStreams) -> void:
	if phase != WorldPhase.RECKONING or run == null or content == null:
		return

	results.clear()
	for inbound in pending:
		if not content.has_record("letters", inbound.letter_id):
			continue
		var letter := Letter.from_record(content.record("letters", inbound.letter_id))
		var contact := run.contact(inbound.sender)
		if contact == null:
			continue
		results.append(Silence.resolve_one(contact, letter, inbound, run))
	pending.clear()
