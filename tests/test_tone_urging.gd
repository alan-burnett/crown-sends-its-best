extends TestCase

## Tone moves loyalty and the urging, and intensity is the axis (#262,
## `docs/mechanics/tone.md` §4, §8).
##
## 🔒 **Pleased and annoyed both lower the urging; desperate and hateful both
## raise it.** That is not accidental symmetry. A governor who reads a letter as
## *the Crown is truly angry we have not built the second town* still remembers
## it next spring; one that was flowery, or merely peevish, is easy to roll one's
## eyes at and get on with one's own life.
##
## **Mild feeling reads as fussiness. Extreme feeling reads as meaning it.**

const SEED: int = 5507

var content: ContentDatabase = null


func before_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)


func after_each() -> void:
	ResourceCatalogue.reset()
	Terrain.reset()
	Improvement.reset()
	Building.reset()
	Objective.reset()
	ContentRegistry.reset()
	MeasureRegistry.reset()
	Deliberation.reset()
	Threshold.reset()
	Consultation.reset()
	content.free()


## What the Crown's urging is still worth, months after a letter in this manner.
func _pull_after(tone: StringName, months: int) -> float:
	var context := DeliberationContext.new(
		DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	context.data = {
		"urged": String(GovernorIntent.ECONOMY),
		"urged_month": 0,
		"urged_tone": String(tone),
	}
	context.month = months
	return IntentConsiderations.CrownUrging.new().score(
		null, Candidate.new(GovernorIntent.ECONOMY), context)


# --- 🔒 Loyalty ------------------------------------------------------------

func test_dutiful_moves_loyalty_by_nothing_at_all() -> void:
	# 🔒 Its identity is *costs nothing, buys nothing* — the safe choice a player
	# who never thinks about tone can take and lose very little by. A gain makes
	# it quietly the best letter to send about anything.
	assert_eq(float(Relationship.TONE_WEIGHT[Tone.DUTIFUL]), 0.0,
		"the plain register buys loyalty, which makes it the answer to everything")

	var relationship := Relationship.new(&"him", 50.0)
	var before := relationship.loyalty
	relationship.record_tone(Tone.DUTIFUL)
	assert_eq(relationship.loyalty, before,
		"a dutiful letter moved his regard")


func test_pleading_still_diminishes_you() -> void:
	# 🔒 A man who begs is a man who has lost his grip, and he is writing it down.
	# It is half of what stops desperation being the answer to everything.
	assert_true(float(Relationship.TONE_WEIGHT[Tone.DESPERATE]) < 0.0,
		"desperation costs nothing, so its only price is prestige")
	assert_true(
		absf(float(Relationship.TONE_WEIGHT[Tone.DESPERATE]))
			< absf(float(Relationship.TONE_WEIGHT[Tone.HATEFUL])),
		"pleading cost as much regard as contempt")


func test_tone_stays_minor_against_the_deed() -> void:
	# 🔒 SPEC §8.5, locked. What the letter grants or promises dominates.
	for deed in Relationship.DEEDS:
		for tone in Tone.ALL:
			assert_true(
				absf(float(Relationship.DEED_WEIGHT[deed]))
					> absf(float(Relationship.TONE_WEIGHT[tone])),
				"%s does not outweigh being written to %s" % [deed, tone])


# --- 🔒 Intensity is the axis ----------------------------------------------

func test_the_two_mild_tones_lower_it_and_the_two_extreme_ones_raise_it() -> void:
	var plain := IntentConsiderations.intensity_of(Tone.DUTIFUL)
	assert_eq(plain, 1.0, "the plain register is not the middle of this")

	for mild in [Tone.PLEASED, Tone.ANNOYED]:
		assert_true(IntentConsiderations.intensity_of(mild) < plain,
			"%s pulled as hard as the plain register: fussiness read as meaning it"
				% mild)
	for extreme in [Tone.DESPERATE, Tone.HATEFUL]:
		assert_true(IntentConsiderations.intensity_of(extreme) > plain,
			"%s pulled no harder than the plain register" % extreme)


func test_it_is_not_warmth_that_decides() -> void:
	# 🔒 The whole point. A warmth axis would put pleased and hateful at opposite
	# ends; this puts them on opposite sides of *mild* and *meant*.
	assert_true(
		IntentConsiderations.intensity_of(Tone.PLEASED)
			< IntentConsiderations.intensity_of(Tone.HATEFUL),
		"the fondest letter pulled harder than the most hateful one")
	assert_true(
		IntentConsiderations.intensity_of(Tone.ANNOYED)
			< IntentConsiderations.intensity_of(Tone.DESPERATE),
		"peevishness pulled harder than pleading")


func test_desperate_pulls_harder_and_longer_than_any_other() -> void:
	# §6: *it pulls harder for longer than any other tone.* That is what the
	# loyalty cost and the permanent prestige mark are buying.
	for tone in Tone.ALL:
		if tone == Tone.DESPERATE:
			continue
		assert_true(
			IntentConsiderations.intensity_of(Tone.DESPERATE)
				> IntentConsiderations.intensity_of(tone),
			"%s pulled at least as hard as desperation" % tone)


func test_a_desperate_urging_outlasts_a_pleasant_one() -> void:
	# The acceptance, measured rather than asserted: two letters, two years, and
	# what is left of each.
	var held: Dictionary = {}
	for tone in [Tone.PLEASED, Tone.DUTIFUL, Tone.DESPERATE]:
		held[String(tone)] = _pull_after(tone, 24)

	assert_true(float(held[String(Tone.DESPERATE)]) > float(held[String(Tone.DUTIFUL)]),
		"a desperate letter had faded to the plain register in two years: %s" % held)
	assert_true(float(held[String(Tone.DUTIFUL)]) > float(held[String(Tone.PLEASED)]),
		"a flowery letter held as well as a plain one: %s" % held)

	# 🔒 **The month the letter lands, every urging is at full strength.** A
	# consideration scores in `[-1, +1]`, so there is no room above the ceiling
	# for a louder one — what the manner buys is the months afterwards.
	for tone in Tone.ALL:
		assert_almost_eq(_pull_after(StringName(tone), 0), 1.0, 0.0001,
			"a letter written %s did not arrive at full strength" % tone)

	# And it is genuinely longer: the month each falls below a quarter.
	var fades: Dictionary = {}
	for tone in [Tone.PLEASED, Tone.DUTIFUL, Tone.DESPERATE]:
		for month in range(0, 241):
			if _pull_after(StringName(tone), month) < 0.25:
				fades[String(tone)] = month
				break
	assert_true(int(fades[String(Tone.DESPERATE)]) > int(fades[String(Tone.DUTIFUL)]),
		"a desperate urging faded no more slowly than a plain one: %s" % fades)
	assert_true(int(fades[String(Tone.DUTIFUL)]) > int(fades[String(Tone.PLEASED)]),
		"a flowery urging lasted as long as a plain one: %s" % fades)


func test_a_hateful_letter_he_took_pulls_harder_than_a_dutiful_one() -> void:
	# 🔒 Not a contradiction with §4's push toward refusal. Urging is consulted
	# **only if he complied**, so the two touch different moments: he is less
	# likely to take the order, and harder-driven when he does.
	assert_true(_pull_after(Tone.HATEFUL, 6) > _pull_after(Tone.DUTIFUL, 6),
		"contempt he acted on drove him no harder than the plain register")


func test_an_urging_from_nowhere_pulls_exactly_as_it_always_did() -> void:
	# A saved run from before the field existed, or an urging with no letter
	# behind it. It must read as the plain register rather than as nothing.
	assert_eq(IntentConsiderations.intensity_of(&""), 1.0)
	assert_eq(IntentConsiderations.intensity_of(&"not_a_tone"), 1.0)
	assert_almost_eq(_pull_after(&"", 9), _pull_after(Tone.DUTIFUL, 9), 0.0001,
		"an urging with no manner behind it did not read as the plain register")


# --- 🔒 The manner survives the journey -------------------------------------

func test_the_letter_carries_its_manner_to_the_town() -> void:
	# The urging is consulted for months after the letter was read, so the tone
	# has to survive from the desk to the deliberation. Read off the letter, not
	# off the man: it is the letter that was emphatic, not the reader.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var town := run.colony.in_order()[0]

	var order := Order.new(M1Registrations.ORDER_URGE_INTENT, town.governor_id, {
		"intent": String(GovernorIntent.DEFENCE),
	}, 0)
	order.id = &"order_urge"
	order.tone = Tone.DESPERATE

	var executor := UrgeIntentExecutor.new()
	executor.colony = run.colony
	var intent := Intent.new(&"i", M1Registrations.ORDER_URGE_INTENT,
		town.governor_id, town.governor_id, 1,
		{"intent": String(GovernorIntent.DEFENCE), Compliance.URGED_TONE: String(Tone.DESPERATE)})
	assert_eq(executor.execute(intent, run.world, run.log), Intent.COMPLETED)
	assert_eq(town.urged_tone, Tone.DESPERATE,
		"the town did not learn how hard the letter had been written")


func test_a_man_acting_alone_wrote_nobody_a_letter() -> void:
	# 🔒 There is no manner to carry when it was not the PC who wrote, so the
	# entry is absent rather than defaulted — and the urging reads as the plain
	# register, which is what an intent nobody urged should do.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var order := Order.new(M1Registrations.ORDER_URGE_INTENT, &"marshal", {
		"intent": String(GovernorIntent.ECONOMY),
	}, 0)
	order.tone = Tone.HATEFUL

	var compliance := Compliance.new()
	var alone: Intent = compliance.callv("_intent_for",
		[order, Compliance.ACT_ALONE, run.contact(&"marshal")])
	assert_false(alone.data.has(Compliance.URGED_TONE),
		"a contact acting on his own carried the PC's manner into his own decision")

	var told: Intent = compliance.callv("_intent_for",
		[order, Compliance.COMPLY, run.contact(&"marshal")])
	assert_eq(String(told.data.get(Compliance.URGED_TONE, "")), String(Tone.HATEFUL),
		"a letter he took did not carry the manner it was written in")


func test_the_town_remembers_it_across_a_save() -> void:
	# Ironman means one save per run (SPEC §16.2). An urging that forgot how hard
	# it had been written would quietly weaken every standing instruction the
	# moment the player closed the game.
	var run := RunState.new_run(SEED)
	var town := run.colony.in_order()[0]
	town.urged_intent = GovernorIntent.DEFENCE
	town.urged_month = 4
	town.urged_tone = Tone.DESPERATE

	var restored := Town.from_dict(town.to_dict())
	assert_eq(restored.urged_tone, Tone.DESPERATE,
		"the manner of the urging did not survive the save")
