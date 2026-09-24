class_name Cutscene
extends RefCounted

## A painting and a line of text (#297, `docs/mechanics/cutscenes.md` §1).
##
## > *Meeting the natives.* *Colony holds trade protest.*
##
## A large still image, a short caption, and **advance** as the only input
## (SPEC §15). Some cutscenes carry several panels and advance cycles them; most
## carry one.
##
## ## 🔒 Nothing in a cutscene moves
##
## The map is the animated screen. This is the painting you are shown about it,
## and that is the whole of it — **no queue, no beats, no fast-forward**, none of
## `beats.md`'s machinery. It has music, which is a bed, and a sound on each
## panel change.
##
## A deliberate narrowing: a cutscene that animated would need everything the map
## needs, for a screen with no information on it. **If this starts needing the
## beat queue, something has been misunderstood.**
##
## ## 🔒 One image per panel and one caption per panel
##
## A panel with two captions is two panels; a caption with no image is not a
## cutscene. Both are enforced here rather than left to the Author's care,
## because a panel that silently dropped half of itself would be a panel the
## player never sees the rest of.
##
## ## The image is a reference, never a path
##
## SPEC §16.3: the Author supplies final art later and swapping it in must not
## require a code change. A panel carries an **asset id** — `cutscene.arrival` —
## and `AssetRegistry` says what that currently is. A missing one renders as an
## obvious placeholder rather than an empty screen.
##
## ## What is not here
##
## The trigger registry and the three kinds (#298), and the data files and the
## validator that covers them (#299). This is the shape the screen consumes, so
## that both of those land against something that already exists.

## 🔒 **The folder carries the language suffix** (`CLAUDE.md`, SPEC §9.7). A
## caption is prose, so cutscenes live in `data/cutscenes_en/` and a second
## language is a copied folder where only `text` fields change — the collection
## name is what `ContentDatabase` strips the suffix down to.
const COLLECTION: String = "cutscenes"

## The one SPEC §6.1 says a run opens with.
##
## **Named here rather than in the screen**, so the file that supplies it (#299)
## and the boot that looks for it agree without either naming a string.
const OPENING: StringName = &"opening"

const KEY_ID: String = "id"
const KEY_PANELS: String = "panels"
## What the captions are told, declared the way a letter declares its params:
## name -> the kind of value (#299). The trigger supplies them.
const KEY_PARAMS: String = "params"
const KEY_IMAGE: String = "image"
const KEY_TEXT: String = "text"

var id: StringName = &""

## `[{image, text}]`, advanced in order. **Never empty** for a cutscene that
## reached the screen.
var panels: Array[Dictionary] = []

## The facts the captions name, declared (#299).
var params: Dictionary = {}


func _init(p_id: StringName = &"") -> void:
	id = p_id


func count() -> int:
	return panels.size()


func is_empty() -> bool:
	return panels.is_empty()


## The asset id of a panel's image, or "" past the end.
func image_at(index: int) -> String:
	if index < 0 or index >= panels.size():
		return ""
	return String(panels[index].get(KEY_IMAGE, ""))


## A panel's caption, or "" past the end.
func text_at(index: int) -> String:
	if index < 0 or index >= panels.size():
		return ""
	return String(panels[index].get(KEY_TEXT, ""))


## 🔒 **A panel's caption with its facts written in** (#299).
##
## `{param:x}` becomes what the trigger supplied, already written out; a param
## nobody supplied reads `[x]`, which a placeholder caption should show rather
## than hide.
func caption_at(index: int, values: Dictionary) -> String:
	var out := text_at(index)
	for name in params:
		var slot := "{param:%s}" % name
		if out.contains(slot):
			out = out.replace(slot, String(values.get(String(name), "[%s]" % name)))
	return out


## Whether advancing from here leaves the cutscene.
##
## 🔒 **The same question for one panel and for three** (§1's acceptance). A
## single-panel cutscene is one where the first panel is also the last, which
## needs no special case anywhere — and the screen asks this rather than
## comparing counts itself.
func is_last(index: int) -> bool:
	return index >= panels.size() - 1


## Build one from a content record.
##
## 🔒 **A panel missing either half is refused**, loudly. §1 makes both halves
## required, and a panel that rendered as a caption over a placeholder would look
## exactly like a missing art file — which is the failure the placeholder exists
## to make obvious, spent on the wrong problem.
static func from_data(record: Dictionary) -> Cutscene:
	var cutscene := Cutscene.new(StringName(record.get(KEY_ID, "")))
	var declared: Variant = record.get(KEY_PARAMS, {})
	if typeof(declared) == TYPE_DICTIONARY:
		cutscene.params = (declared as Dictionary).duplicate()
	var entries: Variant = record.get(KEY_PANELS, [])
	if typeof(entries) != TYPE_ARRAY:
		push_error("Cutscene '%s' has no panels." % cutscene.id)
		return cutscene
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Cutscene '%s' holds a panel that is not an object." % cutscene.id)
			continue
		var image := String((entry as Dictionary).get(KEY_IMAGE, ""))
		var text := String((entry as Dictionary).get(KEY_TEXT, ""))
		if image.is_empty() or text.is_empty():
			push_error(
				"Cutscene '%s' holds a panel with no %s."
				% [cutscene.id, "image" if image.is_empty() else "caption"])
			continue
		cutscene.panels.append({KEY_IMAGE: image, KEY_TEXT: text})
	return cutscene


## One panel, without a file. For a caller that has the pair in hand.
static func of(id: StringName, image: String, text: String) -> Cutscene:
	return Cutscene.from_data({
		KEY_ID: String(id),
		KEY_PANELS: [{KEY_IMAGE: image, KEY_TEXT: text}],
	})
