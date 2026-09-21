class_name Epitaph
extends RefCounted

## What became of the PC afterwards (#78, SPEC §6.3, §14.2, §9.7).
##
## ## 🔒 He always goes to a comfortable retirement
##
## SPEC §5 locks that **nothing in the game can harm the PC**, and that every
## ending — including the worst of them — sends him into comfort. That is not a
## consolation prize; it is the joke, and it is the whole reason the score and
## the epitaph are shown on the same screen.
##
## So there is no ruined-and-destitute epitaph and there never will be. A ruinous
## run buys him a smaller house in a duller county. **The summary states it
## plainly and does not comment**, because the gap between what happened to the
## colony and what happened to the man is the point and pointing at it would
## spoil it.
##
## ## 🔒 SPEC §3.2: the satire targets the empire, never the colonized
##
## A colony that failed through the PC's misrule is **not a joke at the
## colonists' expense**. Every line here is at the expense of the man, the court,
## or the Crown, and a line that would read as amusement at the colony's
## suffering does not belong in the data however well it scans.
##
## ## Chosen from data, by outcome and band
##
## `data/epitaphs_en/` — the folder carries the language, as the letters do, so a
## second language is a copied folder where only `text` changes. **Nothing is
## authored about which one fires**: a record declares the outcome and the band
## it answers for, and the selection is a lookup.
##
## A record with no `band` answers for **every** band of that outcome, which is
## how an outcome gets a floor without five near-identical files.

const COLLECTION: String = "epitaphs"


## The epitaph for a finished run, as prose.
##
## Exact rather than approximate: a record naming both the outcome and the band
## wins over one naming only the outcome, so the general case can be written once
## and sharpened where it is worth sharpening.
static func for_ending(ending: RunEnding, content: ContentDatabase) -> Dictionary:
	if ending == null or content == null:
		return {}
	return for_outcome(ending.reason, Prestige.band_of(ending.score), content)


static func for_outcome(
	outcome: StringName,
	band: StringName,
	content: ContentDatabase,
) -> Dictionary:
	var exact: Dictionary = {}
	var general: Dictionary = {}
	# Sorted, because two records answering for the same pair must not resolve by
	# whichever the directory happened to list first.
	for id in content.ids(COLLECTION):
		var record := content.record(COLLECTION, id)
		if String(record.get("outcome", "")) != String(outcome):
			continue
		var its_band := String(record.get("band", ""))
		if its_band == String(band) and exact.is_empty():
			exact = record
		elif its_band.is_empty() and general.is_empty():
			general = record
	return exact if not exact.is_empty() else general


## Every outcome an epitaph may answer for.
##
## **The reasons a run can stop, and nothing else.** A record naming an outcome
## that is not one of these could never fire, and the validator says so.
static func outcomes() -> PackedStringArray:
	return PackedStringArray([
		String(RunEnding.RETIRED),
		String(RunEnding.TERM_EXPIRED),
		String(RunEnding.FAILED),
	])
