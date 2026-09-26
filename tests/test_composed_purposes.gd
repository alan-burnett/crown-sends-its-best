extends TestCase

## Letters the PC can write unprompted (#454, SPEC §9.4).
##
## 🔒 Three letters existed that nobody could send: demanding a town's stores,
## pressing for a quota, and telling a governor on the march what ground to look
## for. 🔒 And a governor's intent could be urged only in answer to him, never
## by a letter the PC began — though §9.4's *ordering construction* is, by §8.5,
## exactly an urging of intent.

const SEED: int = 454

var content: ContentDatabase = null
var run: RunState = null
var composer: Composer = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	composer = Composer.new(content)


func after_each() -> void:
	reset_world()
	content.free()


func _town() -> Town:
	return run.colony.in_order()[0]


## Who the composer offers `letter_id` to, or null if it is not offered at all.
func _recipients(letter_id: String) -> Variant:
	for purpose in composer.purposes(run):
		if String(purpose["letter_id"]) == letter_id:
			return purpose["recipients"]
	return null


## A party from the first town on the march, led by a governor it elected.
func _a_party_on_the_march() -> ExpeditionParty:
	var party := ExpeditionParty.new()
	party.id = &"party_1"
	party.parent = _town().id
	party.people = 400
	var elected := Contact.new(&"governor_on_the_march")
	elected.role = Contact.ROLE_GOVERNOR
	run.add_contact(elected)
	party.governor = elected.id
	run.parties.append(party)
	return party


func test_the_stores_and_the_quota_can_be_demanded_of_a_governor() -> void:
	for letter_id in ["pc.demand_the_stores", "pc.order_the_quota"]:
		var recipients: Variant = _recipients(letter_id)
		assert_true(recipients != null and (recipients as Array).has(_town().governor_id),
			"%s cannot be written to the governor of a town" % letter_id)


func test_a_governor_can_be_urged_by_a_letter_the_pc_began() -> void:
	var recipients: Variant = _recipients("pc.urge_a_course")
	assert_true(recipients != null and (recipients as Array).has(_town().governor_id),
		"no letter the PC can begin urges a governor's course")
	var record: Dictionary = content.record("letters", "pc.urge_a_course")
	var context := LetterContext.new(run.world, null, Tone.DUTIFUL)
	context.params = {"to": String(_town().governor_id)}
	var urged: Array = []
	for step in record["reply"]["steps"]:
		for option in step["options"]:
			var effect: Dictionary = option["effect"]
			var order := ContentRegistry.run_effect("urge_intent", effect["urge_intent"], context)
			assert_eq(String(order.kind), String(M1Registrations.ORDER_URGE_INTENT))
			assert_eq(String(order.addressed_to), String(_town().governor_id))
			urged.append(String(order.get_param("intent", "")))
	urged.sort()
	assert_eq(urged, ["get_rich", "go_tall", "go_wide", "military"])

	# A governor still on the march has no town for a course to direct.
	var party := _a_party_on_the_march()
	assert_false((_recipients("pc.urge_a_course") as Array).has(party.governor),
		"a governor with no town was urged to direct one")


func test_a_preference_is_offered_only_to_the_governor_on_the_march() -> void:
	assert_true(_recipients("pc.state_a_preference") == null,
		"a preference about a site was offered with nobody on the march")
	var party := _a_party_on_the_march()
	assert_eq(_recipients("pc.state_a_preference"), [party.governor],
		"the preference is not offered to the man leading the party, and only to him")

	party.turning_back = true
	assert_true(_recipients("pc.state_a_preference") == null,
		"a preference was offered to a party already turning back")


func test_the_preference_reaches_the_party_he_leads() -> void:
	var party := _a_party_on_the_march()
	var executor := PreferenceExecutor.new()
	executor.parties = run.parties
	var intent := Intent.new(&"", PreferenceExecutor.KIND, party.governor, party.governor, 1,
		{"preference": String(SitePreference.THE_COAST)})
	assert_eq(String(executor.execute(intent, run.world, run.log)), String(Intent.COMPLETED),
		"a preference addressed to the man leading the party arrived too late")
	assert_eq(String(party.preference), String(SitePreference.THE_COAST))
