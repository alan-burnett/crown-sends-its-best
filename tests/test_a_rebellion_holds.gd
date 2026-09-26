extends TestCase

## A rebellion holds, and a town that comes back is garrisoned (#230,
## `rebel-sentiment.md` §5, `quality-of-life.md` §3).
##
## 🔒 **In rebellion, a lift**: +0.2 on the whole of quality of life, clamped to
## one, for as long as the town is out. 🔒 **A town that comes back is garrisoned
## for a year**: a Crown troops policy the Marshal enacts on it, the PC bearing
## the whole charge, and while it stands the town cannot declare. When it sails
## home, or is destroyed, the bar ends with it.

const SEED: int = 230

var content: ContentDatabase = null
var run: RunState = null


func before_each() -> void:
	reset_world()
	M1Registrations.register_all()
	content = ContentDatabase.new()
	content.load_all("en")
	M1Registrations.load_resources(content)
	run = RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	run.world.month = 12


func after_each() -> void:
	reset_world()
	content.free()


# --- Fixture ---------------------------------------------------------------------

func _town() -> Town:
	return run.colony.in_order()[0]


func _context() -> ColonyContext:
	var context := ColonyContext.new(run.world, run.log, run.streams, run.map)
	context.colony = run.colony
	context.companies = run.companies
	return context


func _resolve(town: Town, sentiment: float, quality: float) -> StringName:
	town.rebel_sentiment = sentiment
	town.quality_of_life = quality
	return Rebellion.resolve(town, _context())


## Declared this month at 0.6, and back the next, living worse.
func _came_back(town: Town) -> void:
	_resolve(town, 90.0, 0.6)
	run.world.month += 1
	assert_eq(String(_resolve(town, 90.0, 0.5)), String(Rebellion.EVENT_RETURNED))


func _troops() -> void:
	CrownTroops.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)


func _garrison_policy() -> Policy:
	for policy in run.policies.active():
		if policy.effect == PolicyEffects.CROWN_TROOPS \
				and String(policy.params.get(CrownTroops.QUARTERED_ON, "")) == String(_town().id):
			return policy
	return null


func _garrison() -> Company:
	for entry in run.companies.in_resolution_order():
		var company: Company = entry
		if not company.is_empty() and company.garrisons == _town().id:
			return company
	return null


## Came back, and next month the garrison is ashore.
func _garrisoned() -> void:
	_came_back(_town())
	run.world.month += 1
	_troops()


func _ended(reason: String) -> bool:
	for entry in run.log.of_type(PolicyBook.EVENT_ENDED):
		if String(entry.payload.get("reason", "")) == reason:
			return true
	return false


# --- 🔒 The lift ------------------------------------------------------------------

func test_a_rebel_town_lives_better_by_the_lift_clamped_to_one() -> void:
	var town := _town()
	var context := _context()
	var loyal := float(QualityOfLife.of(town, context)["quality_of_life"])
	town.rebelling = true
	var out := float(QualityOfLife.of(town, context)["quality_of_life"])
	assert_almost_eq(out, minf(1.0, loyal + QualityOfLife.REBELLION_LIFT), 0.0001,
		"a town in rebellion lived no better for being free of the duty")


# --- 🔒 The garrison --------------------------------------------------------------

func test_a_town_that_comes_back_is_garrisoned_for_a_year_at_the_pcs_charge() -> void:
	# A bigger loyal town elsewhere, so landing where the people are and landing
	# on the town that came back are two different places.
	var bigger := Town.new(&"zzz_bigger", "Bigger", _town().at + Vector2i(4, 0))
	bigger.workers = _town().population() + 20_000
	run.colony.add(bigger)
	_garrisoned()
	var policy := _garrison_policy()
	assert_true(policy != null, "a town came back and the Marshal sent nobody")
	if policy == null:
		return
	assert_eq(String(policy.enactor), String(CrownTroops.MARSHAL))
	assert_eq(String(policy.split), String(Policy.ALL), "the PC does not bear the whole charge")
	assert_eq(policy.expires_month, run.world.month + CrownTroops.GARRISON_MONTHS)
	var company := _garrison()
	assert_true(company != null, "the garrison never landed")
	if company == null:
		return
	assert_eq(company.size, CrownTroops.men_for(CrownTroops.A_GARRISON))
	assert_eq(company.at, _town().at, "the garrison landed somewhere other than the town it holds")


func test_a_town_that_never_went_is_not_garrisoned() -> void:
	_troops()
	assert_true(_garrison_policy() == null)


func test_the_garrison_is_on_the_ledger() -> void:
	_garrisoned()
	run.policies.bill(run.contacts, run.log, run.world.month)
	assert_true(Ledger.of(run.log).page(run.world.month).paid() >= CrownTroops.GARRISON_COST - 0.01,
		"the garrison's charge is not on the Ledger")


func test_a_garrisoned_town_cannot_declare() -> void:
	_garrisoned()
	_resolve(_town(), 99.0, 0.1)
	assert_false(_town().rebelling, "a town declared with the Crown's garrison in its streets")


func test_after_a_year_it_sails_home_and_the_town_may_declare_again() -> void:
	_garrisoned()
	run.world.month = _garrison_policy().expires_month
	run.policies.take_stock(run.log, run.world.month)
	assert_true(_garrison_policy() == null, "the garrison outstayed its year")
	assert_true(_ended("served_its_term"), "its going was not a term served")
	_troops()
	assert_true(_garrison() == null, "the policy ended and the men stayed")
	_resolve(_town(), 99.0, 0.1)
	assert_true(_town().rebelling, "the garrison sailed and the bar stayed")


func test_a_destroyed_garrison_is_not_sent_again_and_the_bar_ends() -> void:
	_garrisoned()
	_garrison().size = 0
	run.world.month += 1
	_troops()
	assert_true(_garrison_policy() == null, "a destroyed garrison's policy stood on")
	assert_true(_ended("destroyed"))
	assert_true(_garrison() == null, "a destroyed garrison was sent again")
	_resolve(_town(), 99.0, 0.1)
	assert_true(_town().rebelling, "the garrison was gone and the bar stayed")


# --- 🔒 Saved ---------------------------------------------------------------------

func test_the_garrison_survives_a_save() -> void:
	_garrisoned()
	var company := Company.from_dict(bytes_to_var(var_to_bytes(_garrison().to_dict())))
	assert_eq(String(company.garrisons), String(_town().id), "a reload forgot whom the garrison holds")
	var policy := Policy.from_dict(bytes_to_var(var_to_bytes(_garrison_policy().to_dict())))
	assert_eq(policy.expires_month, _garrison_policy().expires_month, "a reload forgot when it sails")
