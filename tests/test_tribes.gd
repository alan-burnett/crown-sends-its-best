extends TestCase

## The three peoples already here (#203, SPEC §12.5;
## `docs/mechanics/natives.md` §1, §2).
##
## 🔒 **No tribe ever writes to the PC.** There is no native contact, no chief,
## no letter, no negotiation — they have not heard of him. A dev who adds a
## native to the contact roster has broken the premise the whole doc rests on.
##
## 🔒 **Standing is held per faction**, and trust is standing-toward-the-colony
## rather than a second field.
##
## 🔒 **The point of no return is a latch, not a threshold.** Once a tribe
## concludes a faction means it destroyed, that conclusion never reverses — and
## it is reached by a pattern rather than raised by one event.

const SEED: int = 7042

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
	content.free()


func _context() -> ColonyContext:
	return ColonyContext.new(
		WorldValues.initial_state(), EventLog.new(), RngStreams.new(SEED), null)


func _tribe(toward_colony: float = 50.0) -> Tribe:
	var tribe := Tribe.new()
	tribe.id = &"tribe_test"
	tribe.display_name = "Test"
	tribe.standing = {String(Tribe.COLONY): toward_colony}
	return tribe


# --- 🔒 Three of them, from the map's own stream ----------------------------

func test_three_tribes_exist_from_the_first_month() -> void:
	var run := RunState.new_run(SEED)
	assert_true(run.tribes != null, "the New World came with nobody in it")
	# **Three, written out.** Comparing against `HOW_MANY` would assert that the
	# constant equals itself, which is true however wrong the constant is.
	assert_eq(run.tribes.in_order().size(), 3,
		"SPEC 12.5 says three and there are not three")


func test_each_of_them_is_a_different_people() -> void:
	var seen: Dictionary = {}
	for tribe in RunState.new_run(SEED).tribes.in_order():
		assert_false(seen.has(tribe.display_name),
			"two of the three are called '%s', and a player could not learn either"
				% tribe.display_name)
		seen[tribe.display_name] = true


func test_the_same_seed_gives_the_same_three_peoples() -> void:
	var once := RunState.new_run(SEED).tribes.in_order()
	var twice := RunState.new_run(SEED).tribes.in_order()
	for index in once.size():
		assert_eq(once[index].display_name, twice[index].display_name,
			"the same seed made a different New World")
		assert_almost_eq(once[index].trust(), twice[index].trust(), 0.0001,
			"and gave them a different opinion of the colony")


func test_a_different_seed_can_give_different_peoples() -> void:
	var here := RunState.new_run(SEED).tribes.in_order()
	var elsewhere := RunState.new_run(SEED + 9_871).tribes.in_order()
	var same := true
	for index in here.size():
		same = same and here[index].display_name == elsewhere[index].display_name \
			and is_equal_approx(here[index].trust(), elsewhere[index].trust())
	assert_false(same, "every chart in the game is the same three peoples")


# --- 🔒 No tribe is a contact -----------------------------------------------

func test_no_tribe_is_in_the_contact_roster() -> void:
	# 🔒 §1. **They have not heard of him.** What the PC knows arrives through his
	# own people, and a tribe in the roster is a tribe that could write.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	for tribe in run.tribes.in_order():
		assert_false(run.contacts.has(String(tribe.id)),
			"'%s' is a contact, which means a chief can write to London" % tribe.id)


func test_no_letter_has_a_tribe_as_its_sender() -> void:
	# The same lock from the content side, so adding the letter fails before
	# anybody gets as far as adding the contact.
	var senders: Dictionary = {}
	for id in content.ids("letters"):
		senders[String(content.record("letters", id).get("sender", ""))] = id
	for tribe in RunState.new_run(SEED).tribes.in_order():
		assert_false(senders.has(String(tribe.id)),
			"'%s' writes a letter, and no tribe has heard of the PC" % tribe.id)
	for sender in senders:
		assert_false(String(sender).begins_with("tribe"),
			"'%s' writes to the PC and its name says it should not" % sender)


func test_a_tribe_has_no_loyalty_and_no_relationship() -> void:
	# The shape is the lock: there is nowhere on a `Tribe` to put the things a
	# contact has, so the roster could not hold one even if somebody tried.
	var tribe := _tribe()
	assert_false(tribe.has_method("loyalty"),
		"a tribe has a loyalty, which is what a man the PC writes to has")
	assert_false(tribe.get("relationship") != null,
		"a tribe has a relationship with a man it has never met")


# --- 🔒 Standing per faction, and trust is one of them ----------------------

func test_it_can_hold_two_opinions_at_once() -> void:
	# **Hostile to the colony and civil with a rival** — and then deal with that
	# rival about the colony.
	var tribe := _tribe(10.0)
	var context := _context()
	tribe.move(&"rival_duke", 30.0, "traded fairly", context)

	assert_true(tribe.standing_toward(&"rival_duke") > tribe.trust(),
		"what it thinks of the colony and of a rival are the same opinion")


func test_trust_is_standing_toward_the_colony_and_not_a_second_field() -> void:
	# 🔒 Two numbers would eventually disagree, and the one the letters read
	# would be the wrong one.
	var tribe := _tribe(70.0)
	assert_almost_eq(tribe.trust(), tribe.standing_toward(Tribe.COLONY), 0.0001)
	tribe.move(Tribe.COLONY, -25.0, "a town on their ground", _context())
	assert_almost_eq(tribe.trust(), tribe.standing_toward(Tribe.COLONY), 0.0001,
		"trust and standing-toward-the-colony have come apart")


func test_the_crown_s_troops_are_their_own_faction() -> void:
	# 🔒 §2: they distinguish the Crown's troops **from the colonists those troops
	# are supposedly protecting**, which is why M6's garrison is a thing a tribe
	# can hate on its own account.
	var tribe := _tribe(60.0)
	tribe.move(Tribe.CROWN_TROOPS, -40.0, "a column through the valley", _context())
	assert_true(tribe.standing_toward(Tribe.CROWN_TROOPS) < tribe.trust(),
		"soldiers marching through soured them on the farmers as well")


func test_a_faction_it_has_never_met_is_neutral_rather_than_hated() -> void:
	assert_almost_eq(_tribe().standing_toward(&"nobody_in_particular"), Tribe.NEUTRAL, 0.0001,
		"a people it has never heard of already means it destroyed")


# --- 🔒 The latch -----------------------------------------------------------

func test_standing_moves_both_ways_across_almost_all_of_it() -> void:
	# **Insults are forgiven, intrusions are lived with, a badly-used tribe can
	# be won back.** The latch is what makes that worth saying.
	var tribe := _tribe(80.0)
	var context := _context()
	tribe.move(Tribe.COLONY, -50.0, "a town on their ground", context)
	assert_true(tribe.trust() < 40.0, "an intrusion cost them nothing")
	tribe.move(Tribe.COLONY, 40.0, "years of fair dealing", context)
	assert_true(tribe.trust() > 60.0, "a tribe that had been badly used could not be won back")


func test_past_the_point_it_concludes_and_never_unconcludes() -> void:
	# 🔒 §2. **Not with gifts, not with concessions, not with a change of
	# governor.** Once entered it is held for the run regardless of what standing
	# later does.
	var tribe := _tribe(Tribe.IRRECONCILABLE_BELOW + 2.0)
	var context := _context()
	tribe.move(Tribe.COLONY, -5.0, "the last of it", context)
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY),
		"it went past the point and concluded nothing")

	for gift in 20:
		tribe.move(Tribe.COLONY, 20.0, "a wagon of gifts", context)
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY),
		"four hundred points of gifts talked them out of it")

	# 🔒 **A latch and not a threshold.** Put the standing back up by force — as
	# some future mechanic might, or a save edited by hand — and the conclusion
	# is still held. A threshold recomputed on read would let them out here.
	tribe.standing[String(Tribe.COLONY)] = Tribe.MAXIMUM
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY),
		"the conclusion is read off the standing, so it is a threshold and reverses")


func test_a_tribe_that_has_concluded_does_not_move_at_all() -> void:
	# Not up and not down. A figure that kept sliding would imply there was still
	# something to discuss.
	var tribe := _tribe(Tribe.IRRECONCILABLE_BELOW - 1.0)
	var context := _context()
	tribe.move(Tribe.COLONY, -1.0, "the last of it", context)
	var settled := tribe.trust()

	# **One move each way, checked separately.** A gift and a killing in the same
	# test cancel out, and the figure comes back to where it started whether the
	# moves were refused or merely balanced.
	tribe.move(Tribe.COLONY, 30.0, "gifts", context)
	assert_almost_eq(tribe.trust(), settled, 0.0001,
		"a tribe with nothing left to discuss accepted a gift")

	tribe.move(Tribe.COLONY, -30.0, "more killing", context)
	assert_almost_eq(tribe.trust(), settled, 0.0001,
		"a tribe that had already concluded went on getting angrier")


func test_the_latch_is_per_faction() -> void:
	# It may believe the colony means its destruction while still dealing civilly
	# with a rival — and then deal with that rival **about** the colony.
	var tribe := _tribe(5.0)
	var context := _context()
	tribe.move(Tribe.COLONY, -1.0, "the last of it", context)
	assert_true(tribe.is_irreconcilable_with(Tribe.COLONY))
	assert_false(tribe.is_irreconcilable_with(&"rival_duke"),
		"deciding about the colony decided about everybody")


func test_the_latch_sits_above_the_floor() -> void:
	# 🔒 A latch at zero would be a floor with a different name. The point is
	# that there is a stretch of very bad standing a tribe can still be talked
	# out of, and a point past it where it cannot.
	assert_true(Tribe.IRRECONCILABLE_BELOW > Tribe.MINIMUM + 0.001,
		"the point of no return is the bottom of the scale, so there is no stretch before it")

	var tribe := _tribe(Tribe.IRRECONCILABLE_BELOW + 6.0)
	assert_false(tribe.is_irreconcilable_with(Tribe.COLONY),
		"a tribe that despises the colony has already given up on it")


func test_concluding_is_on_the_record_and_carries_no_figure() -> void:
	# 🔒 Nothing about a tribe reaches the player except through his own people
	# (§1), so a payload carrying the number is a payload a letter could render.
	var tribe := _tribe(Tribe.IRRECONCILABLE_BELOW + 1.0)
	var context := _context()
	tribe.move(Tribe.COLONY, -3.0, "the last of it", context)

	var concluded: Array = context.log.of_type(Tribe.EVENT_IRRECONCILABLE)
	assert_eq(concluded.size(), 1, "a people decided the colony meant them destroyed, in silence")
	assert_false(concluded[0].payload.has("standing"), "the payload carries the figure")
	assert_eq(String(concluded[0].payload["toward"]), String(Tribe.COLONY))

	for moved in context.log.of_type(Tribe.EVENT_STANDING_MOVED):
		assert_false(moved.payload.has("standing"), "a movement carries the figure")


# --- The save ----------------------------------------------------------------

func test_the_tribes_survive_a_save() -> void:
	var run := RunState.new_run(SEED)
	var tribe: Tribe = run.tribes.in_order()[0]
	tribe.move(Tribe.COLONY, -3.0, "a town on their ground", _context())
	tribe.irreconcilable[String(Tribe.CROWN_TROOPS)] = true

	var restored := RunState.from_dict(run.to_dict())
	var same: Tribe = restored.tribes.find(tribe.id)
	assert_true(same != null, "a people vanished in the save")
	assert_almost_eq(same.trust(), tribe.trust(), 0.0001,
		"a reload gave them a fresh opinion of the colony")
	assert_true(same.is_irreconcilable_with(Tribe.CROWN_TROOPS),
		"a reload talked them out of a conclusion that never reverses")
