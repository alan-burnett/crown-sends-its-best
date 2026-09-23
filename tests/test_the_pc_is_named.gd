extends TestCase

## The PC's title and name, and the salutation that can withhold it (#358,
## `docs/mechanics/names.md` §1, §2; SPEC §5).
##
## SPEC §5 has both as *flavor only and has no effect*, which is exactly why they
## are worth a test: nothing else in the game will notice if they stop working.
##
## 🔒 **The old default title was a trap.** §2 makes the first word of a
## letterhead the role, so a PC styled *Governor* read exactly like one of his own
## colonial governors. *Lord* is not a preference — it removes a collision.

const SEED: int = 5501

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


func _pc(title: String = "Lord", name: String = "Frank Zappa") -> RunSetup:
	var setup := RunSetup.new()
	setup.pc_title = title
	setup.pc_name = name
	return setup


# --- 🔒 Both arrive filled in, and the style does not collide ---------------

func test_the_style_defaults_to_lord() -> void:
	assert_eq(RunSetup.new().pc_title, "Lord",
		"a fresh commission is not styled as the doc says")


func test_the_style_is_not_a_word_a_letterhead_uses() -> void:
	# 🔒 The reason the default changed. §2's first word is the **role**, and a PC
	# styled *Governor* was indistinguishable from the men who work for him.
	var styled := RunSetup.new().pc_title
	for role in Letterhead.ROLE_WORD:
		assert_ne(Letterhead.role_word(StringName(role)), styled,
			"the PC is styled '%s', which is also what a %s is called" % [styled, role])


func test_the_name_is_guessed_from_the_aristocrats_bag() -> void:
	# 🔒 **The same pool his patrons come from**, which is right for a minor
	# royal — he is one of them, sent out.
	var suggested := RunSetup.suggest_a_name(SEED)
	assert_false(suggested.is_empty(), "the commission arrived with no name on it")

	var given: Array = NameBags.entries(NameBags.ARISTOCRATS, "given")
	var family: Array = NameBags.entries(NameBags.ARISTOCRATS, "family")
	var parts := suggested.split(" ")
	assert_eq(parts.size(), 2, "a name is a given name and a family name")
	assert_true(given.has(parts[0]), "'%s' is not a name the aristocrats use" % parts[0])
	assert_true(family.has(parts[1]), "'%s' is not a name the aristocrats use" % parts[1])


func test_the_same_chart_suggests_the_same_man() -> void:
	assert_eq(RunSetup.suggest_a_name(SEED), RunSetup.suggest_a_name(SEED),
		"two players on one chart were offered different names")
	assert_ne(RunSetup.suggest_a_name(SEED), RunSetup.suggest_a_name(SEED + 1),
		"every chart in the game offers the same man")


func test_a_name_he_typed_is_not_overwritten_by_another_chart() -> void:
	var setup := _pc("Lord", "Frank Zappa")
	setup.seed_value = SEED
	assert_eq(setup.suggested_name(), "Frank Zappa",
		"rerolling the chart took the name he had chosen")


# --- 🔒 A name he keeps is struck from the bag ------------------------------

func test_a_kept_name_is_struck_for_the_run() -> void:
	var setup := _pc("Lord", "Frank Zappa")
	assert_false(NameBags.is_struck("Frank Zappa"), "it was struck before he took it")
	setup.settle_the_name(SEED)
	assert_true(NameBags.is_struck("Frank Zappa"), "the name he sails under is still going spare")


func test_no_patron_can_share_the_name_he_sails_under() -> void:
	# 🔒 §5, *no two live things share a name*, applied to the one thing in the
	# game that is not generated. A patron who happened to share it would read as
	# a mistake even though nothing was wrong.
	var streams := RngStreams.new(SEED)
	var taken := NameBags.person(
		NameBags.ARISTOCRATS, streams.contact_stream("patron_x"))
	assert_false(taken.is_empty(), "no patron was named at all, so this proves nothing")

	NameBags.strike(taken)
	var drawn := NameBags.person(
		NameBags.ARISTOCRATS, RngStreams.new(SEED).contact_stream("patron_x"))
	assert_ne(drawn, taken, "a patron was given the name the PC sails under")
	assert_false(drawn.is_empty(), "striking one name left the man with none")


func test_striking_a_name_does_not_shift_anybody_elses_rolls() -> void:
	# 🔒 **Two draws either way**, which is why `person` walks forward from the
	# family name it drew rather than drawing again. A PC who retyped his own name
	# would otherwise have got different patrons — and a decision that is *flavor
	# only and has no effect* would have had one.
	var plain := RngStreams.new(SEED).contact_stream("patron_x")
	var _unused := NameBags.person(NameBags.ARISTOCRATS, plain)
	var after_plain := plain.randi()

	NameBags.strike(NameBags.person(
		NameBags.ARISTOCRATS, RngStreams.new(SEED).contact_stream("patron_x")))
	var struck := RngStreams.new(SEED).contact_stream("patron_x")
	var _also_unused := NameBags.person(NameBags.ARISTOCRATS, struck)

	assert_eq(struck.randi(), after_plain,
		"striking a name consumed a different number of rolls")


# --- 🔒 Free text, bounded, measured after trimming -------------------------

func test_a_style_and_a_name_have_room_to_be_typed() -> void:
	assert_true(RunSetup.is_a_title("Lord"))
	assert_true(RunSetup.is_a_name("Frank Zappa"))
	assert_true(RunSetup.is_a_name("A".repeat(RunSetup.NAME_MAX)),
		"a name at the stated limit was refused")
	assert_true(RunSetup.is_a_title("A".repeat(RunSetup.TITLE_MAX)),
		"a style at the stated limit was refused")


func test_nothing_at_all_is_refused() -> void:
	# 🔒 **The minimum of one is what removes the empty case**, so nothing
	# downstream needs a fallback for a nameless PC — there is no such PC.
	assert_false(RunSetup.is_a_name(""), "a nameless PC was let through")
	assert_false(RunSetup.is_a_title(""), "a PC with no style at all was let through")
	assert_false(RunSetup.what_is_wrong_with("Lord", "").is_empty(),
		"the screen would have had nothing to say about it")


func test_a_single_space_is_nothing_at_all() -> void:
	# 🔒 **Measured after trimming.** A naive length check counts the space, and
	# the empty case is straight back.
	assert_false(RunSetup.is_a_name("   "), "a name of three spaces was accepted")
	assert_false(RunSetup.is_a_title(" "), "a style of one space was accepted")


func test_too_long_is_refused_at_both_ends() -> void:
	assert_false(RunSetup.is_a_name("A".repeat(RunSetup.NAME_MAX + 1)))
	assert_false(RunSetup.is_a_title("A".repeat(RunSetup.TITLE_MAX + 1)))
	assert_false(RunSetup.what_is_wrong_with(
		"A".repeat(RunSetup.TITLE_MAX + 1), "Frank Zappa").is_empty())


func test_trailing_space_does_not_buy_a_longer_name() -> void:
	# The other half of *after trimming*: it cuts both ways, so a name that fits
	# once trimmed is a name that fits.
	assert_true(RunSetup.is_a_name("  %s  " % "A".repeat(RunSetup.NAME_MAX)),
		"trimming made a legal name illegal")
	assert_false(RunSetup.is_a_name(" %s " % "A".repeat(RunSetup.NAME_MAX + 1)),
		"padding a too-long name with spaces got it past the check")


func test_what_he_sails_under_is_what_he_typed_without_the_spaces() -> void:
	var setup := _pc("  Lord  ", "  Frank Zappa  ")
	setup.settle_the_name(SEED)
	assert_eq(setup.pc_name, "Frank Zappa", "he sailed under a name with spaces round it")
	assert_eq(setup.pc_title, "Lord")


# --- 🔒 The whole salutation is tone-keyed ----------------------------------

func _addressed(tone: StringName, title: String = "Lord", name: String = "Frank Zappa") -> String:
	return Salutation.for_pc(tone, _pc(title, name))


func test_a_polite_letter_and_a_hateful_one_address_him_differently() -> void:
	# The acceptance line.
	assert_ne(_addressed(Tone.PLEASED), _addressed(Tone.HATEFUL),
		"a man who loathes the PC greets him exactly as a man who does not")


func test_the_hateful_form_withholds_the_title() -> void:
	# 🔒 **Not an adjective in front of a fixed name.** A contact refusing the PC
	# his style is doing something, and the prose has to be able to say it — which
	# is why the whole line is tone-keyed rather than a table of adjectives.
	assert_true(_addressed(Tone.PLEASED).contains("Lord"),
		"a pleased man would not even give him his style")
	assert_false(_addressed(Tone.HATEFUL).contains("Lord"),
		"a man who despises the PC still styled him Lord")
	assert_true(_addressed(Tone.HATEFUL).contains("Frank Zappa"),
		"he withheld the name as well, and then the letter is addressed to nobody")


func test_withholding_the_title_leaves_no_hole_where_it_was() -> void:
	# A form that drops `{title}` leaves the space in front of the name behind it,
	# and the reader sees it.
	var hateful := _addressed(Tone.HATEFUL)
	assert_false(hateful.contains("  "), "'%s' has a gap where the style was" % hateful)
	assert_false(hateful.contains(" ,"), "'%s' has a comma adrift in it" % hateful)


func test_every_tone_addresses_him_somehow() -> void:
	for tone in Tone.ALL:
		var line := _addressed(tone)
		assert_false(line.is_empty(), "a %s letter opens with nothing" % tone)
		assert_true(line.contains("Frank Zappa"),
			"a %s letter is addressed to somebody else: '%s'" % [tone, line])


func test_the_salutation_names_only_known_tones() -> void:
	# The content rule: every tone key is one of the five, and they are not
	# ordered, so there is no *annoyed or worse* form hiding in the file.
	var record: Dictionary = content.record(Salutation.COLLECTION, Salutation.RECORD)
	var by_tone: Dictionary = record.get("by_tone", {})
	assert_not_empty(by_tone, "the salutation file has no forms in it")
	for tone in by_tone:
		assert_true(Tone.is_tone(StringName(tone)),
			"'%s' is not one of the five tones" % tone)
	assert_false(String(record.get("default", "")).is_empty(),
		"a letter with no tone would be addressed to nobody")


# --- 🔒 It reaches the letter the player actually reads ---------------------

func _rendered(tone: StringName, pc: RunSetup) -> String:
	var letter := Letter.new()
	letter.id = "test.letter"
	letter.body = [{"text": "The colony is as you left it."}]
	var context := LetterContext.new(WorldValues.initial_state(), null, tone)
	context.pc = pc
	return LetterRenderer.new().render_body(letter, context)


func test_the_letter_on_the_desk_opens_by_addressing_him() -> void:
	# A salutation nothing prepends is a line in a data file.
	var body := _rendered(Tone.PLEASED, _pc())
	assert_true(body.begins_with("To the most noble Lord Frank Zappa"),
		"the letter opens '%s'" % body.substr(0, 60))
	assert_true(body.ends_with("The colony is as you left it."),
		"the salutation ate the letter")


func test_the_same_letter_reads_differently_from_a_man_who_hates_him() -> void:
	assert_ne(_rendered(Tone.HATEFUL, _pc()), _rendered(Tone.PLEASED, _pc()),
		"tone reached the salutation in the file and not the letter")


func test_a_letter_with_no_pc_is_simply_the_letter() -> void:
	# 🔒 The content validator renders every letter in the game with no run behind
	# it. A salutation that insisted on a PC would put a hole in all of them.
	assert_eq(_rendered(Tone.PLEASED, null), "The colony is as you left it.",
		"a letter rendered outside a run was addressed to nobody in particular")


func test_no_letter_file_writes_its_own_salutation() -> void:
	# 🔒 **One place.** Four Chancellor letters opened with a hand-rolled
	# `{param:pc_title} {param:pc_name}.` and have lost it — it is now said once,
	# and said better, because it moves. A file that grew its own back would
	# address the PC twice.
	for id in content.ids("letters"):
		var record: Dictionary = content.record("letters", String(id))
		for line in record.get("body", []):
			var text := String((line as Dictionary).get("text", ""))
			assert_false(text.contains("{param:pc_name}"),
				"%s addresses the PC itself, so he is greeted twice" % id)


# --- 🔒 And he names himself, and nobody else -------------------------------

func test_the_setup_carries_no_town_name_and_no_governor() -> void:
	# 🔒 SPEC §11.3, locked: towns run themselves, and the PC has no say in who a
	# governor is. Nothing to build — asserted so that nobody adds a control for
	# it later on the reasoning that the name field was there anyway.
	var fields := RunSetup.new().to_dict()
	for key in fields:
		var name := String(key)
		assert_false(name.contains("town"),
			"run setup carries '%s', so the player is choosing a town" % name)
		assert_false(name.contains("governor"),
			"run setup carries '%s', so the player is choosing a governor" % name)


func test_the_only_name_the_player_gives_is_his_own() -> void:
	var setup := _pc("Lord", "Frank Zappa")
	setup.seed_value = SEED
	var run := RunState.from_setup(setup)

	var first := run.colony.in_order()[0]
	assert_false(first.display_name.is_empty(), "the first town has no name")
	assert_ne(first.display_name, setup.pc_name,
		"the town took the PC's name, so he named it after himself by accident")

	var governor := run.contact(first.governor_id)
	assert_true(governor != null, "the first town has no governor")
	assert_ne(governor.display_name, setup.pc_name,
		"the man the PC writes to is named after the PC")


# --- 🔒 And the other end of §2: how a sender is shown ----------------------

func test_the_open_letter_heads_with_the_role_and_not_the_style() -> void:
	# 🔒 `contact.gd` carries the lock: **no letter reads `title` and the
	# letterhead must not**, because the first word is the role and it is there to
	# be scanned. `Letterhead.of` existed, was tested, and nothing in
	# `presentation/` called it — so the desk showed *Corvyn Thrale, Steward of
	# the Revenue*.
	var run := RunState.from_setup(_pc())
	ContactRoster.load_into(run, content)
	var steward := run.contact(&"steward")
	assert_true(steward != null, "there is no Steward to head a letter from")
	assert_false(steward.title.is_empty(),
		"the Steward has no flavour style, so this proves nothing")

	var head := Letterhead.of(steward)
	assert_true(head.begins_with(steward.role_word),
		"'%s' does not open with what he is" % head)
	assert_false(head.contains(steward.title),
		"'%s' carries the flavour style the letterhead is locked against" % head)
