class_name Urging
extends RefCounted

## Somebody has argued what a town is for, or what a company should do (#405,
## `docs/mechanics/governor-objectives.md` §4).
##
## 🔒 **An urging has an author, and several may stand at once.** A new one from
## the same author replaces that author's last, as a new letter from the PC
## replaces his previous one; different authors coexist, each decaying on its own
## — so the Provost's pull toward learning does not erase the PC's toward
## defence, and neither erases the other's month.
##
## 🔒 **It pulls on an intent or an order, never an objective** (SPEC §8.5). The
## town's objective is its governor's to choose; this is what he is argued at.

## The PC. Every other author is a contact id.
const PC: StringName = &"pc"

var author: StringName = PC

## The intent (a town's) or the order (a company's) it pulls toward.
var target: StringName = &""

## When it landed.
var month: int = 0

## **How hard, and therefore how long** — a factor on the half-life (#262,
## `tone.md` §4). **Carried, not derived at read time**: for the PC it is his
## letter's tone, read once as it lands; for anyone else, whatever the act that
## made it says.
var strength: float = 1.0

## The manner it was written in, where it came in a letter. Kept so a letter or
## an event can say so; the strength is what decides.
var tone: StringName = &""


static func make(
	p_author: StringName,
	p_target: StringName,
	p_month: int,
	p_strength: float = 1.0,
	p_tone: StringName = &"",
) -> Urging:
	var urging := Urging.new()
	urging.author = p_author
	urging.target = p_target
	urging.month = p_month
	urging.strength = maxf(0.0, p_strength)
	urging.tone = p_tone
	return urging


## The PC's, from the manner of his letter — exactly as the single slot read it.
static func from_pc(p_target: StringName, p_month: int, p_tone: StringName = &"") -> Urging:
	return make(PC, p_target, p_month, IntentConsiderations.intensity_of(p_tone), p_tone)


## How hard it pulls now, on a half-life of `half_life` months at strength one.
func pull(now: int, half_life: float) -> float:
	return IntentConsiderations.decayed(float(now - month), half_life * strength)


# --- A standing list, keyed by author ----------------------------------------

## Put `urging` among `urgings`, **replacing its author's last**. Kept sorted by
## author, so nothing that reads them depends on the order they arrived in.
static func stand(urgings: Array[Urging], urging: Urging) -> void:
	for index in urgings.size():
		if urgings[index].author == urging.author:
			urgings[index] = urging
			return
	urgings.append(urging)
	urgings.sort_custom(_by_author)


static func _by_author(a: Urging, b: Urging) -> bool:
	return String(a.author) < String(b.author)


## This author's standing urging, or null.
static func by(urgings: Array[Urging], p_author: StringName) -> Urging:
	for urging in urgings:
		if urging.author == p_author:
			return urging
	return null


# --- The save -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"author": String(author),
		"target": String(target),
		"month": month,
		"strength": strength,
		"tone": String(tone),
	}


static func from_dict(data: Dictionary) -> Urging:
	return make(
		StringName(data.get("author", String(PC))),
		StringName(data.get("target", "")),
		int(data.get("month", 0)),
		float(data.get("strength", 1.0)),
		StringName(data.get("tone", "")),
	)


static func list_to_dicts(urgings: Array[Urging]) -> Array:
	var out: Array = []
	for urging in urgings:
		out.append(urging.to_dict())
	return out


static func list_from_dicts(data: Variant) -> Array[Urging]:
	var out: Array[Urging] = []
	if typeof(data) != TYPE_ARRAY:
		return out
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY:
			Urging.stand(out, Urging.from_dict(entry))
	return out
