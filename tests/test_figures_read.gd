extends TestCase

## How large figures read, by who is writing (#437,
## `docs/mechanics/population.md` §7, the Author's ruling on #425).
##
## 🔒 **Rounding is formatting, not perception.** A town's own governor and the
## Steward count heads to the nearest ten; everybody else estimates in words; a
## painting says it in words; the run summary prints it exact; and anything
## under a hundred is exact from everyone.

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


func test_counted_heads_round_to_the_nearest_ten() -> void:
	assert_eq(Figures.counted(3_933), "3,930")
	assert_eq(Figures.counted(12_345), "12,350")


func test_an_estimate_is_in_words_and_hedged_by_which_side_it_fell() -> void:
	assert_eq(Figures.estimated(3_933), "nearly four thousand")
	assert_eq(Figures.estimated(45_200), "some forty-five thousand")
	assert_eq(Figures.estimated(4_000), "some four thousand")
	assert_eq(Figures.estimated(10_000), "some ten thousand")
	assert_eq(Figures.estimated(123_456), "some one hundred and twenty thousand")


func test_a_figure_under_a_hundred_is_exact_from_everyone() -> void:
	assert_eq(Figures.counted(57), "57")
	assert_eq(Figures.estimated(57), "57")


## One line of prose printing a head count about a town.
func _render(sender: Contact, town: String, people: int) -> String:
	var letter := Letter.from_record({
		"id": "test.head_count", "type": "news",
		"params": {"people": "people", "town": "town"},
		"body": [{"text": "{param:town} holds {param:people} souls."}],
	})
	var context := LetterContext.new(WorldValues.initial_state(), sender)
	context.params = {"people": people, "town": town}
	return LetterRenderer.new().render_body(letter, context)


func _contact(id: StringName, role: StringName, town: String = "") -> Contact:
	var contact := Contact.new(id)
	contact.role = role
	contact.town = town
	return contact


func test_the_towns_own_governor_counts_heads_and_a_duke_writes_words() -> void:
	var governor := _contact(&"governor_ashmere", Contact.ROLE_GOVERNOR, "Ashmere")
	var duke := _contact(&"rival_duke_montargis", Contact.ROLE_RIVAL)
	assert_true(_render(governor, "Ashmere", 3_933).contains("3,930"), _render(governor, "Ashmere", 3_933))
	assert_true(_render(duke, "Ashmere", 3_933).contains("nearly four thousand"), _render(duke, "Ashmere", 3_933))


func test_a_governor_about_another_town_writes_words_and_the_steward_counts() -> void:
	var governor := _contact(&"governor_ashmere", Contact.ROLE_GOVERNOR, "Ashmere")
	assert_true(_render(governor, "Bellhaven", 3_933).contains("nearly four thousand"),
		"a governor counted heads in another man's town")
	var steward := _contact(&"steward", Contact.ROLE_CROWN_OFFICER)
	assert_true(_render(steward, "Bellhaven", 3_933).contains("3,930"), "the Steward estimated")


func test_how_he_counts_is_a_whitelisted_sender_field() -> void:
	assert_true(LetterSchema.SENDER_FIELDS.has(&"counts"))
	var context := LetterContext.new(WorldValues.initial_state(), _contact(&"rival_duke_montargis", Contact.ROLE_RIVAL))
	assert_eq(context.sender_field(&"counts"), String(Contact.COUNTS_IN_WORDS))


func test_a_painting_says_it_in_words_and_the_summary_exact() -> void:
	assert_eq(CutsceneParams.written(3_933, "people", null), "nearly four thousand")
	assert_eq(Figures.people(3_933), "3,933")
