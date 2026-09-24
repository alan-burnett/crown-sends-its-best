extends TestCase

## The drafting hand (#295, `docs/mechanics/beats.md` §5).
##
## 🔒 **The hand only ever appends**, and **the letter produced is identical
## whether the hand was watched or skipped.** Both asserted headless: the hand is
## a queue of drafts `ReplyWizard.draft()` already returned, and the view only
## plays it. Nothing here is about how it looks.

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	reset_world()
	content.free()


## Where the queue settles drafts: what a sheet was told, in order.
class Sheet:
	extends RefCounted
	var texts: PackedStringArray = PackedStringArray()

	func write_draft(beat: Beat) -> void:
		texts.append(String(beat.outcome.get("text", "")))


## A context that can answer every param a letter declares.
func _context(letter: Letter) -> LetterContext:
	var run := RunState.new_run(2950)
	ContactRoster.load_into(run, content)
	var params := {}
	for name in letter.params:
		params[name] = "Kettleburn"
	var context := LetterContext.new(run.world, run.contact(&"steward"), &"")
	context.params = params
	context.measures = WorldValues.measures(run.world)
	return context


## Answer a letter the way a player clicking the first of everything would, and
## hand the hand each draft as it stands. Returns the drafts, in order.
func _write(letter: Letter, hand: DraftingHand, context: LetterContext) -> PackedStringArray:
	var wizard := ReplyWizard.new(letter, OutgoingLetter.new(letter.id, &"steward"))
	var drafts := PackedStringArray()
	if wizard.has_tone_step() and not wizard.tone_options().is_empty():
		wizard.choose_tone(wizard.tone_options()[0]["tone"])
		hand.wrote(wizard.draft(context))
		drafts.append(wizard.draft(context))
	if wizard.harsh_is_pending():
		wizard.choose_harsh(false)
	for index in wizard.steps().size():
		var options := wizard.options_for(index, context)
		if options.is_empty():
			continue
		wizard.choose(String(wizard.steps()[index].get("id", "")), String(options[0]["id"]), context)
		hand.wrote(wizard.draft(context))
		drafts.append(wizard.draft(context))
	drafts.append(wizard.assemble(context))
	return drafts


# --- 🔒 The hand only ever appends ------------------------------------------------

func test_every_shipped_reply_is_written_by_appending() -> void:
	# The lock the doc says nothing enforced: tone is step one and resolves every
	# line, and the steps come in the order they are written, so each choice puts
	# a sentence on the end. **The letter sent is the last draft and its ending**,
	# so the hand finishes the letter that goes.
	var checked := 0
	for id in content.ids("letters"):
		var letter := Letter.from_record(content.record("letters", id))
		if not letter.has_reply():
			continue
		var drafts := _write(letter, DraftingHand.new(null), _context(letter))
		for at in range(1, drafts.size()):
			assert_true(drafts[at].begins_with(drafts[at - 1]),
				"'%s' rewrote what the hand had drawn:\n  %s\n  %s" % [id, drafts[at - 1], drafts[at]])
		checked += 1
	assert_true(checked > 40, "only %d letters were checked" % checked)


func test_a_draft_that_does_not_append_starts_a_clean_sheet() -> void:
	var hand := DraftingHand.new(null)
	hand.wrote("I write to you. The iron will come.")
	hand.wrote("Something else entirely.")
	assert_eq(hand.queue.size(), 1, "the hand kept drawing on top of a letter that changed")
	assert_eq(hand.written, "Something else entirely.")


# --- 🔒 Watched or skipped, the same letter ----------------------------------------

func test_the_letter_is_the_same_whether_the_hand_was_watched_or_skipped() -> void:
	var letter := Letter.from_record(content.record("letters", "marshal.request_supplies"))
	var watched_sheet := Sheet.new()
	var watched := DraftingHand.new(watched_sheet)
	var drafts := _write(letter, watched, _context(letter))
	while not watched.queue.is_done():
		watched.queue.play_next()

	for skip_at in range(0, watched.queue.size()):
		var sheet := Sheet.new()
		var hand := DraftingHand.new(sheet)
		_write(letter, hand, _context(letter))
		for _step in skip_at:
			hand.queue.play_next()
		hand.sign()
		assert_eq(sheet.texts[sheet.texts.size() - 1], watched_sheet.texts[watched_sheet.texts.size() - 1],
			"signing after %d sentences left a different letter on the sheet" % skip_at)
	assert_eq(watched_sheet.texts[watched_sheet.texts.size() - 1], drafts[drafts.size() - 2],
		"the hand finished on something other than the last draft")


func test_signing_catches_up_in_one_and_leaves_no_scratches() -> void:
	# §3: one resolution sound for the lot, not one pen-scratch per sentence.
	var letter := Letter.from_record(content.record("letters", "marshal.request_supplies"))
	var hand := DraftingHand.new(Sheet.new())
	_write(letter, hand, _context(letter))
	var queued := hand.queue.size()
	assert_true(queued >= 2, "the fixture queued fewer than two sentences, so this proves nothing")
	assert_eq(hand.sign(), queued, "signing did not catch up with every sentence")
	assert_empty(hand.queue.sounds_remaining(), "sentences still had scratches to play after signing")


func test_writing_it_again_is_a_clean_sheet() -> void:
	var hand := DraftingHand.new(Sheet.new())
	hand.wrote("I write to you.")
	hand.restart()
	assert_eq(hand.written, "")
	assert_eq(hand.queue.size(), 0)
	assert_true(hand.wrote("A different letter.") != null)


func test_a_longer_sentence_takes_the_hand_longer() -> void:
	var hand := DraftingHand.new(null)
	var short := hand.wrote("Yes.")
	var long := hand.wrote("Yes. " + "And a great deal more besides, written out at length. ".repeat(3))
	assert_true(long.seconds() > short.seconds(), "the hand wrote a paragraph as fast as a word")
