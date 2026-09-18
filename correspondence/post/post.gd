class_name Post
extends RefCounted

## The letters the player has written and queued during a turn (SPEC §4).
##
## **🔒 Changes of mind are allowed only within a turn.** Until the post is sent,
## any outgoing letter can be reopened, rewritten, or discarded. Once sent, it is
## final — and `sealed` is how that becomes true rather than remembered.

var _letters: Array[OutgoingLetter] = []
var _next_ordinal: int = 0

## Set when the post is sent. A sealed post refuses every edit.
var sealed: bool = false


func add(letter: OutgoingLetter) -> OutgoingLetter:
	if sealed:
		push_error("The post has been sent. Nothing in it can be altered.")
		return null
	if letter.id.is_empty():
		letter.id = StringName("outgoing_%d" % _next_ordinal)
	_next_ordinal += 1
	_letters.append(letter)
	return letter


## Discard an outgoing letter entirely.
func discard(id: StringName) -> bool:
	if sealed:
		push_error("The post has been sent. Nothing in it can be altered.")
		return false
	for index in _letters.size():
		if _letters[index].id == id:
			_letters.remove_at(index)
			return true
	return false


## The letter to reopen and rewrite, or null.
func letter(id: StringName) -> OutgoingLetter:
	for entry in _letters:
		if entry.id == id:
			return entry
	return null


## The reply already queued to an inbound letter, or null. Answering the same
## letter twice replaces rather than duplicates.
func reply_to(inbound_id: StringName) -> OutgoingLetter:
	for entry in _letters:
		if entry.in_reply_to == inbound_id:
			return entry
	return null


func all() -> Array[OutgoingLetter]:
	return _letters.duplicate()


func size() -> int:
	return _letters.size()


func is_empty() -> bool:
	return _letters.is_empty()


## Seal the post. Sending commits every decision in it, and there is no going
## back (SPEC §7).
func seal() -> void:
	sealed = true


func to_dict() -> Dictionary:
	var entries: Array = []
	for entry in _letters:
		entries.append(entry.to_dict())
	return {"letters": entries, "next_ordinal": _next_ordinal, "sealed": sealed}


static func from_dict(data: Dictionary) -> Post:
	var post := Post.new()
	for entry in data.get("letters", []):
		post._letters.append(OutgoingLetter.from_dict(entry))
	post._next_ordinal = int(data.get("next_ordinal", post._letters.size()))
	post.sealed = bool(data.get("sealed", false))
	return post
