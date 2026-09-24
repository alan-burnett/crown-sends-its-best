extends TestCase

## The one intent aimed at the PC (#128, SPEC §8.5, §12.3;
## `docs/mechanics/contacts.md` §4).
##
## 🔒 **At the bottom of the loyalty scale an order does not merely fail — it can
## become the reason for what happens next.** A man insulted past bearing does
## not only decline; the thing he now intends may be to turn his town against the
## Crown.
##
## It does not replace §12.3's threshold. A town still rebels when its sentiment
## crosses. What this adds is a resident contact with heavy influence
## **deliberately driving that sentiment up** — the governor accelerates, the
## sentiment crosses, the town declares. That is a better story than a number
## quietly passing a line, and it gives the player something he can see before it
## happens.

const SEED: int = 9204

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


func _governor(loyalty: float) -> Contact:
	var contact := Contact.new(&"gov_ashmere")
	contact.relationship = Relationship.new(&"gov_ashmere", loyalty)
	for id in IntentConsiderations.ALL:
		contact.set_weight(StringName(id), 1.0)
	return contact


func _town() -> Town:
	var town := Town.new(&"ashmere", "Ashmere", Vector2i(0, 0))
	town.workers = 20
	town.governor_id = &"gov_ashmere"
	town.quality_of_life = 0.6
	return town


func _permitted(governor: Contact) -> bool:
	var filter := IntentConsiderations.OnlyIfHeLoathesYou.new()
	var context := DeliberationContext.new(DecisionKind.GOVERNOR_INTENT, WorldValues.initial_state(), EventLog.new())
	return filter.permits(governor, Candidate.new(GovernorIntent.SEDITION, {}), context)


# --- 🔒 Only a man who loathes the PC can reach it ---------------------------

func test_a_devoted_governor_cannot_reach_it() -> void:
	assert_false(_permitted(_governor(90.0)),
		"a devoted governor was free to start preparing a rebellion")


func test_a_merely_disaffected_governor_cannot_reach_it_either() -> void:
	# The line is low on purpose. A sullen man is not a seditious one, and the
	# intent should be startling when it arrives.
	assert_false(_permitted(_governor(IntentConsiderations.SEDITION_AT + 10.0)),
		"a governor who is merely fed up started preparing a rebellion")


func test_a_governor_insulted_past_bearing_can() -> void:
	assert_true(_permitted(_governor(IntentConsiderations.SEDITION_AT - 1.0)),
		"a man who loathes the Crown had no way to act on it")


func test_it_is_a_filter_rather_than_a_weight() -> void:
	# **A weight can lose a close vote and then win one** (`deliberation.md` §5).
	# A well-disposed governor with every consideration pushing him towards it
	# must still not be able to choose it.
	var devoted := _governor(100.0)
	for id in IntentConsiderations.ALL:
		devoted.set_weight(StringName(id), Contact.WEIGHT_MAX)
	assert_false(_permitted(devoted),
		"enough enthusiasm let a loyal man decide to rebel")


func test_winning_him_back_takes_it_away_again() -> void:
	# `contacts.md` §8: there is no permanent break. A governor who has been won
	# back stops preparing for a rebellion he no longer wants, and the candidate
	# simply ceases to exist for him.
	var governor := _governor(IntentConsiderations.SEDITION_AT - 5.0)
	assert_true(_permitted(governor))
	governor.relationship.loyalty = 60.0
	assert_false(_permitted(governor), "a man won back was still preparing to leave")


# --- 🔒 The PC cannot ask for it --------------------------------------------

func test_no_letter_lets_the_crown_ask_a_man_to_turn_against_it() -> void:
	# **The interesting exception.** Every other intent is something the PC can
	# argue for. This one a governor reaches entirely on his own, which is what
	# makes it a consequence of how he has been treated rather than another thing
	# the PC decides.
	for id in content.ids("letters"):
		var record: Dictionary = content.collection("letters")[id]
		assert_false(JSON.stringify(record).contains(String(GovernorIntent.SEDITION)),
			"%s lets the PC reach for a rebellion" % id)


# --- 🔒 It serves the rebellion, not the town -------------------------------

func test_its_objectives_turn_away_from_the_crown() -> void:
	# A town being made ready to stand alone: walls and powder, grain it will not
	# have to buy, and **the one profile that wants the colony's trade to fall**,
	# because every shilling of it is a thread back to London.
	assert_true(GovernorIntent.value_of(GovernorIntent.SEDITION, "trade") < 0.0,
		"a town preparing to leave still wanted the Crown's commerce")
	assert_true(GovernorIntent.value_of(GovernorIntent.SEDITION, "defence") > 0.0,
		"a town preparing to leave wanted no walls")
	assert_true(GovernorIntent.value_of(GovernorIntent.SEDITION, "food") > 0.0,
		"a town preparing to leave made no provision for a siege")


func test_it_lays_in_what_standing_alone_needs() -> void:
	var stocks := Objective.intent_stocks(GovernorIntent.SEDITION)
	assert_not_empty(stocks, "a town preparing to leave laid in nothing at all")
	assert_true(float(stocks.get("guns", 0.0)) > 0.0, "it prepared without powder")


# --- 🔒 He is an accelerant, not a passenger --------------------------------

func test_a_seditious_governor_drives_his_towns_sentiment_up() -> void:
	var sullen := _town()
	var seditious := _town()
	seditious.intent = GovernorIntent.SEDITION

	var contacts := {"gov_ashmere": _governor(5.0)}
	assert_true(_sentiment(seditious, contacts) > _sentiment(sullen, contacts),
		"a governor who had decided counted for no more than one who was merely sullen")


func test_a_loyal_town_is_not_charged_for_an_intent_it_does_not_hold() -> void:
	var quiet := _town()
	quiet.intent = GovernorIntent.GET_RICH
	var contacts := {"gov_ashmere": _governor(80.0)}
	assert_true(_sentiment(quiet, contacts) < RebelSentiment.SEDITIOUS_GOVERNOR,
		"a town with a contented governor carried a seditious one's weight")


func _sentiment(town: Town, contacts: Dictionary) -> float:
	var colony := Colony.new()
	colony.add(town)
	var context := ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null
	)
	context.colony = colony
	return float(RebelSentiment.of(town, context, null, contacts)["contacts"])


# --- 🔒 The player can see it coming ----------------------------------------

func test_he_writes_about_the_walls_without_saying_why() -> void:
	# **A rebellion the player never saw coming is a trapdoor.** §12.3 wants a
	# spiral he can watch and intervene in, so the man preparing for one reports
	# the walls, the powder and the grain — and says nothing about why. The
	# player has everything he needs to work it out, and nobody tells him.
	var town := _town()
	town.intent = GovernorIntent.SEDITION
	var context := LetterContext.new(WorldValues.initial_state(), _governor(5.0), &"dutiful")
	context.town = town
	assert_true(ColonyConditions.town_is_preparing_to_leave({}, context),
		"a town being readied to leave the Crown had nothing to report about it")

	town.intent = GovernorIntent.GET_RICH
	assert_false(ColonyConditions.town_is_preparing_to_leave({}, context),
		"a town minding its business was reported as preparing to leave")
