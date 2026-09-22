class_name RunModifiers
extends RefCounted

## What a perk or a quirk actually turns (#286,
## `docs/mechanics/perks-and-quirks.md` §1, §2).
##
## ## 🔒 A perk names a knob. It never adds a number
##
## *Righteous* is not `+5 clergy loyalty`. It is **a drift term on one class of
## contact** — a knob that already exists, turned.
##
## That is what keeps perks out of the engine (SPEC §16.1's lock that content is
## data-driven), what lets the Author add one without a code change, and what
## **stops forty of them becoming forty special cases**.
##
## **Where a perk wants a knob that does not exist, the knob is the work** — not
## the perk. Two of §3's will need one: *Read between the lines* modifies
## perception leans, and *Distant colony* changes the post's transit time.
##
## ## 🔒 Perks are about you, quirks are about the world
##
## | | Is | Therefore |
## | :--- | :--- | :--- |
## | **A perk** | a fact about the PC | **pure benefit**, one per run |
## | **A quirk** | a fact about the world he was given | **benefit and drawback**, any number |
##
## A fact about you is yours; a fact about the world cuts both ways. That is the
## whole of SPEC §5's asymmetry, and it needs no second rule — **nothing here
## enforces it**, because a quirk with only benefits is a content mistake the
## Author makes and not a state the code can be in.
##
## ## The registry
##
## Ids into a code-side table with typed params, **exactly as effects and
## conditions are** (`CLAUDE.md`). A modifier id nobody has registered is a
## content error the validator catches, not a silent no-op.
##
## Named static functions rather than lambdas: a `Callable` living in a static
## registry segfaults Godot 4.7 on shutdown (`CLAUDE.md`).

const PERKS: String = "run"
const PERKS_RECORD: String = "perks"
const QUIRKS_RECORD: String = "quirks"

## Modifier id -> the name of the static function that applies it.
##
## **A table of names, not of callables.** Looked up by name at the moment of
## use, so nothing holds a `Callable` at shutdown.
const APPLIES: Dictionary = {
	"crown_grace": "_crown_grace",
}


static func is_modifier(id: String) -> bool:
	return APPLIES.has(id)


static func ids() -> PackedStringArray:
	var out := PackedStringArray(APPLIES.keys())
	out.sort()
	return out


## Turn every knob this run's perk and quirks name.
##
## 🔒 **One perk and any number of quirks** (§1), and the perk goes first so that
## a quirk which happened to turn the same knob is the later word. Applied at run
## setup, once, because a modifier is a fact about the run rather than a thing
## that happens in it.
static func apply_all(run: RunState, content: ContentDatabase) -> void:
	if run == null or run.setup == null or content == null:
		return
	_apply_one(run, content, PERKS_RECORD, String(run.setup.perk))
	var quirks := run.setup.quirks.duplicate()
	quirks.sort()
	for quirk in quirks:
		_apply_one(run, content, QUIRKS_RECORD, String(quirk))


## Everything a run may be offered, in id order.
##
## 🔒 **Adding an entry to the file adds it to the list**, which is the whole
## point: the code knows how to apply the ids it finds, and nothing else.
static func offered(content: ContentDatabase, record: String) -> PackedStringArray:
	var out := PackedStringArray()
	if content == null:
		return out
	for entry in entries_in(content, record):
		if bool((entry as Dictionary).get("offered", true)):
			out.append(String((entry as Dictionary).get("id", "")))
	out.sort()
	return out


## The raw entries a file holds, offered or not.
static func entries_in(content: ContentDatabase, record: String) -> Array:
	if content == null or not content.has_record(PERKS, record):
		return []
	return content.record(PERKS, record).get("entries", [])


static func _apply_one(
	run: RunState, content: ContentDatabase, record: String, id: String
) -> void:
	if id.is_empty():
		return
	var _turning := RunModifiers.new()
	for entry in entries_in(content, record):
		if String((entry as Dictionary).get("id", "")) != id:
			continue
		for modifier in (entry as Dictionary).get("modifiers", []):
			for modifier_id in modifier:
				if not APPLIES.has(String(modifier_id)):
					push_error(
						"'%s' names the modifier '%s', which nothing registers."
						% [id, modifier_id])
					continue
				# **Dispatched by name through an instance**, which is the only way
				# GDScript will `call` into this script — and it is the shape that
				# matters anyway: the instance is made here and dropped here, so
				# nothing holds a `Callable` at shutdown (`CLAUDE.md`).
				_turning.call(
					String(APPLIES[String(modifier_id)]), run, modifier[modifier_id])
		return


# --- The knobs -------------------------------------------------------------

## **It's my first day**: an extra Chancellor warning before the Crown first
## refuses payment.
##
## The grace `CrownRefusal` has carried since #68 with nothing able to switch it
## on — which is exactly the shape §2 asks for. The perk names it; it does not
## invent a number.
static func _crown_grace(run: RunState, _args: Dictionary) -> void:
	if run.refusal != null:
		run.refusal.has_grace = true
