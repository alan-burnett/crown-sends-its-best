class_name IndependenceClause
extends RefCounted

## How the Chancellor names each of Independence's four conditions (#268,
## `docs/mechanics/endings.md` §3).
##
## 🔒 **Prose, and therefore data** (`CLAUDE.md`). The folder carries the
## language and a second language is a copied folder where only these strings
## change — which is the whole reason this is not four `match` arms in a param
## source, however much shorter that would be.
##
## Two forms for each: what he says when it is **true**, and what he says when it
## still stands between the PC and the end. §3 wants a letter that names *which
## are true and what still stands*, and a condition he can only describe one way
## would make the second half of that impossible.
##
## The warmth is his and the content is not. He is delighted throughout.

const COLLECTION: String = "clauses"
const RECORD: String = "independence"

static var _true: Dictionary = {}
static var _false: Dictionary = {}
static var _joiner: String = ", and "


static func load_from(record: Dictionary) -> void:
	_true = record.get("true", {}).duplicate()
	_false = record.get("false", {}).duplicate()
	_joiner = String(record.get("joiner", ", and "))


static func reset() -> void:
	_true = {}
	_false = {}
	_joiner = ", and "


## Whether every condition `LastChance` knows about has been written down here.
##
## Asked by the content validator, so a condition added to the sim without a
## phrase fails the build rather than rendering an id at the player.
static func missing() -> PackedStringArray:
	var out := PackedStringArray()
	for name in LastChance.CONDITIONS:
		if String(_true.get(name, "")).strip_edges().is_empty():
			out.append("true.%s" % name)
		if String(_false.get(name, "")).strip_edges().is_empty():
			out.append("false.%s" % name)
	return out


## How he puts it, given what is true.
##
## **In `LastChance.CONDITIONS` order**, which is sorted, so the same four facts
## always read in the same sequence and the letter does not shuffle itself
## between months.
static func phrase_for(flags: Dictionary, wanted: bool) -> String:
	var parts := PackedStringArray()
	for name in LastChance.CONDITIONS:
		if bool(flags.get(name, false)) != wanted:
			continue
		var said := String((_true if wanted else _false).get(name, ""))
		if not said.is_empty():
			parts.append(said)
	return _joiner.join(parts)
