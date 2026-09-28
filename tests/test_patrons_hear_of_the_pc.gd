extends TestCase

## A patron has heard what the court says of the PC (#466, `patrons.md` §7,
## `prestige.md` §7, SPEC §14.1 *especially patrons*).
##
## 🔒 He arrives warmer or colder by the PC's prestige band. 🔒 While the PC is
## ruinous he offers nothing — no specialty, no one-off — and his other letters
## carry on; offers return when the PC's name recovers.

const SEED: int = 466

## The offers, and only the offers.
const OFFERS: Array = [
	"trigger.patron.his_barony_would_buy",
	"trigger.patron.a_word_against_the_duke",
	"trigger.patron.more_of_his_kind",
	"trigger.patron.his_herds_would_thrive",
	"trigger.patron.an_expert_for_you",
	"trigger.patron.a_gift_for_the_crown",
	"trigger.patron.his_men_for_you",
]

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


## The first patron a run meets, with the PC's prestige at `score`.
func _arrival(score: float) -> Contact:
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.prestige.value = score
	run.demands.sources = PackedStringArray(["patron"])
	PatronDriver.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	var patrons := Patron.all_in(run)
	assert_eq(patrons.size(), 1, "no patron arrived to prove anything with")
	return patrons[0] if patrons.size() == 1 else null


func _gates(trigger: String) -> Array:
	var out: Array = []
	for entry in content.collection("triggers")[trigger].get("conditions", []):
		for name in entry:
			out.append(String(name))
	return out


func test_he_arrives_warmer_or_colder_by_the_band() -> void:
	var ruinous := _arrival(-5_000.0)
	var obscure := _arrival(0.0)
	var celebrated := _arrival(100_000.0)
	if ruinous == null or obscure == null or celebrated == null:
		return
	assert_eq(String(ruinous.id), String(celebrated.id), "not the same man twice")
	assert_almost_eq(celebrated.loyalty() - ruinous.loyalty(), 40.0, 0.001,
		"a celebrated PC was not met 40 warmer than a ruinous one")
	assert_almost_eq(celebrated.loyalty() - obscure.loyalty(), 30.0, 0.001)


func test_while_the_pc_is_ruinous_he_offers_nothing() -> void:
	for trigger in OFFERS:
		assert_true(_gates(trigger).has("the_pc_is_not_ruinous"), "%s is offered to a ruinous PC" % trigger)
	for trigger in content.ids("triggers"):
		if not String(trigger).begins_with("trigger.patron.") or OFFERS.has(String(trigger)):
			continue
		assert_false(_gates(String(trigger)).has("the_pc_is_not_ruinous"),
			"%s is not an offer, and a ruinous name stopped it" % trigger)

	var context := LetterContext.new(WorldValues.initial_state(), null, &"")
	context.prestige = Prestige.new()
	context.prestige.value = -1.0
	assert_false(ColonyConditions.the_pc_is_not_ruinous({}, context))
	context.prestige.value = 10.0
	assert_true(ColonyConditions.the_pc_is_not_ruinous({}, context), "his offers did not return as the PC's name did")
