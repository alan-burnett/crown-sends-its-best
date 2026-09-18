class_name Tone
extends RefCounted

## The five tones, shared by incoming and outgoing letters.
##
## **🔒 They are not ordered.** There is no "annoyed or worse" anywhere, and no
## range logic: prose comes from a default or from a named tone, never from an
## inferred range (`CLAUDE.md`, Content pipeline). Anything keyed on tone is a
## lookup per tone, which is why loyalty's response to tone is a table rather
## than a scale.
##
## The same five in both directions: a sender's tone compresses loyalty,
## personality, circumstance and urgency into one id (SPEC §9.1), and the
## player's reply picks one from the same set (SPEC §9.2).

const PLEASED: StringName = &"pleased"
const DUTIFUL: StringName = &"dutiful"
const ANNOYED: StringName = &"annoyed"
const DESPERATE: StringName = &"desperate"
const HATEFUL: StringName = &"hateful"

const ALL: Array[StringName] = [PLEASED, DUTIFUL, ANNOYED, DESPERATE, HATEFUL]


static func is_tone(name: StringName) -> bool:
	return ALL.has(name)


## Sorted tone ids, for anywhere a stable order is needed for output. This is a
## presentation convenience and carries no meaning — sorting alphabetically is
## not a ranking.
static func sorted_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for tone in ALL:
		ids.append(String(tone))
	ids.sort()
	return ids
