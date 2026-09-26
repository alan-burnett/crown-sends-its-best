extends TestCase

## What a new run may choose from (#465, SPEC §5, §6.1, §14.3).
##
## 🔒 *"One Perk and any number of Quirks are selected"*, from what is unlocked:
## *"only unlocked perk from the start… no unlocked quirks."* Every perk and quirk
## is marked offered, so a selector wired to *offered* would hand a new player
## all fifteen at once. 🔒 The PC's likeness and colours are his to choose, and
## are asset ids the registry can resolve (§16.3).

var content: ContentDatabase = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")


func after_each() -> void:
	reset_world()
	content.free()


func test_a_new_player_is_offered_the_first_day_and_no_quirks() -> void:
	var none := PackedStringArray()
	assert_eq(RunModifiers.unlocked(content, RunModifiers.PERKS_RECORD, none),
		PackedStringArray([String(RunSetup.PERK_FIRST_DAY)]),
		"a new player was offered a perk he has not unlocked")
	assert_eq(RunModifiers.unlocked(content, RunModifiers.QUIRKS_RECORD, none), PackedStringArray(),
		"a new player was offered a quirk")


func test_what_a_past_run_unlocked_is_offered() -> void:
	var some := PackedStringArray(["righteous", "boom_town"])
	var perks := RunModifiers.unlocked(content, RunModifiers.PERKS_RECORD, some)
	assert_true(perks.has("righteous") and perks.has(String(RunSetup.PERK_FIRST_DAY)))
	assert_eq(perks.size(), 2, "an unlock let in a perk it did not name")
	assert_eq(RunModifiers.unlocked(content, RunModifiers.QUIRKS_RECORD, some),
		PackedStringArray(["boom_town"]))


func test_nothing_is_unlocked_until_a_run_unlocks_it() -> void:
	Records.reset()
	assert_eq(Records.unlocks("user://test_what_a_run_may_choose_absent.cfg"), PackedStringArray())


func test_every_likeness_on_offer_is_an_asset() -> void:
	var text := FileAccess.get_file_as_string("res://data/assets/portraits.json")
	var ids: Array = []
	for entry in JSON.parse_string(text):
		ids.append(String(entry.get("id", "")))
	for portrait in RunSetup.PORTRAITS:
		assert_true(ids.has(portrait), "the setup offers a likeness '%s' with no art behind it" % portrait)
	assert_true(RunSetup.PORTRAITS.has(RunSetup.new().portrait), "the default likeness is not one on offer")


func test_the_likeness_and_colours_are_kept_with_the_run() -> void:
	var setup := RunSetup.new()
	setup.portrait = RunSetup.PORTRAITS[2]
	setup.colour = RunSetup.COLOURS[3]
	var restored := RunSetup.from_dict(setup.to_dict())
	assert_eq(restored.portrait, RunSetup.PORTRAITS[2])
	assert_true(restored.colour.is_equal_approx(RunSetup.COLOURS[3]))
