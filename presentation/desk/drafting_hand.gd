class_name DraftingHand
extends RefCounted

## The hand that writes the reply while the player chooses it (#295,
## `docs/mechanics/beats.md` §5).
##
## **Two things run at once and at different speeds.** The wizard is the
## player's pace; the hand is the letter's. A player who knows what he wants
## clicks through every step and leaves the hand several sentences behind,
## writing dutifully; one reading each option never sees a queue at all.
##
## Each choice pushes **one beat**: the letter as it now stands, which is the
## sentence that choice added on the end of what was there. The hand reveals text
## `ReplyWizard.draft()` already returns — **it never composes** — so the letter
## that is sent is the same whether the hand was watched or skipped.
##
## ## 🔒 The hand only ever appends
##
## Tone is step one and resolves every line, and the steps are asked in the order
## they are written, so each draft is the last one with a sentence on the end.
## A draft that is not would mean the hand rewriting what it already drew; this
## refuses it and starts the sheet again rather than showing the player his own
## letter changing behind the pen. **Rewriting is a reopen, not an edit.**
##
## ## Sign and post
##
## The last act is not a sentence. `sign` settles everything still queued at once
## — §3's fast-forward, one resolution sound and not one scratch per sentence —
## so the full letter is on the page before it folds.
##
## Headless like `ReplyWizard`: this holds the queue and the view plays it.

const KIND: StringName = &"write_a_line"

## The method on the view that puts a draft on the sheet.
const SETTLES: String = "write_draft"

## How long the hand takes over one character, and the least and most it spends
## on one sentence. Tuning (`beats.md` §9).
const SECONDS_PER_CHARACTER: float = 0.025
const SHORTEST: float = 0.35
const LONGEST: float = 3.0

## The sound of the pen, and the hand that holds it. Asset ids, never paths.
const SOUND: String = "sound.pen"
const SPRITE: String = "sprite.hand"

var queue: BeatQueue = null

## The draft as far as the hand has been given it.
var written: String = ""


func _init(stage: Object = null) -> void:
	register_kind()
	queue = BeatQueue.new(stage)


static func register_kind() -> void:
	BeatKinds.register(KIND, SETTLES, SHORTEST, SOUND, SPRITE)


## The player chose something and the letter now reads `draft`. Returns the beat
## the hand will write, or null when nothing new was added.
func wrote(draft: String) -> Beat:
	if draft == written:
		return null
	if not draft.begins_with(written):
		# 🔒 Never rewrite what is drawn: start the sheet again instead.
		restart()
	var beat := Beat.new(KIND, &"", {"text": draft}, 1.0)
	beat.hold = clampf(float(draft.length() - written.length()) * SECONDS_PER_CHARACTER,
		SHORTEST, LONGEST)
	written = draft
	queue.push(beat)
	return beat


## Sign it: settle everything still queued, at once. Returns how many sentences
## the signature caught up with — one resolution sound covers them all.
func sign() -> int:
	return queue.skip()


## A clean sheet, for a letter being written again.
func restart() -> void:
	queue.clear()
	written = ""
