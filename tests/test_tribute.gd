extends TestCase

## The fourth asker, and the fourth currency (#69, `crown-demands.md` §4,
## SPEC §8.4, §14.1).
##
## 🔒 **A rival bills the PC in reputation.** The Steward, the Marshal and the
## Provost all charge him in things the Crown keeps books on. This one does not
## touch the books at all, which is what makes him dangerous: a PC can be
## solvent, meeting every Crown demand on time, and still despised at court for
## having paid a foreigner to go away.
##
## 🔒 **Paying defers the risk. It never buys peace.**

const SEED: int = 3307

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


func _intent(months: int = 9) -> Intent:
	var intent := Intent.new()
	intent.kind = TributeExecutor.KIND
	intent.data = {
		"to": "rival_duke", "resource": "iron", "amount": 60, "months": months,
	}
	return intent


func _paid(month: int = 4, months: int = 9) -> Dictionary:
	var state := WorldValues.initial_state()
	state.month = month
	var log := EventLog.new()
	var outcome := TributeExecutor.new().execute(_intent(months), state, log)
	return {"state": state, "log": log, "outcome": outcome}


# --- 🔒 The court hears about it, and the Treasury does not ------------------

func test_paying_is_an_optic_and_the_register_prices_it() -> void:
	# 🔒 `prestige.md` §4: **a mechanic emits the event and never prices it.** The
	# executor says what happened; `OpticsRegister` decides what the court makes
	# of it.
	var run := _paid()
	assert_not_empty(run["log"].of_type(OpticsRegister.EVENT_TRIBUTE_PAID),
		"the PC paid a foreign power and nobody at court heard")
	assert_true(OpticsRegister.price_of(OpticsRegister.EVENT_TRIBUTE_PAID) > 0.0,
		"paying tribute cost the PC no face at all")


func test_paying_costs_prestige_and_not_standing() -> void:
	# 🔒 §4's whole reason for a fourth asker: the currency is different. Nothing
	# here reaches `CrownAccounts`, so a PC meeting every Crown demand on time is
	# not protected by having done so.
	var run := _paid()
	var before := float(Prestige.of(EventLog.new())["total"])
	var after := float(Prestige.of(run["log"])["total"])
	assert_true(after < before, "paying tribute did not reach the court's account of him")
	assert_almost_eq(CrownAccounts.of(run["log"]).net_position(), 0.0, 0.001,
		"tribute landed on the Crown's books, where standing would answer for it")


func test_it_defers_and_does_not_settle() -> void:
	# SPEC §8.4: accepting puts the attack off **without ever buying peace**. He
	# comes back, and comes back asking for more.
	var run := _paid(4, 9)
	var state: WorldState = run["state"]
	var key := TributeExecutor.DEFERRED_PREFIX + "rival_duke"
	assert_true(state.has_value(key), "paying bought nothing at all")
	assert_eq(int(float(state.get_value(key, 0.0))), 13,
		"the quiet he bought does not run out")

	var paid: Array = run["log"].of_type(OpticsRegister.EVENT_TRIBUTE_PAID)
	assert_false(bool(paid[0].payload["bought_peace"]),
		"the record says the matter is closed, and it is not")


func test_the_deferral_goes_through_apply_like_any_world_value() -> void:
	# Seam A. A value written around `apply` is a change to the world nothing
	# else can see happen.
	var run := _paid()
	assert_not_empty(run["log"].of_type(TributeExecutor.EVENT_DEFERRED),
		"the world moved and nothing said so")


func test_the_intent_completes_rather_than_stalling() -> void:
	# A stall means "nothing could carry this out", which is a much louder claim
	# than this deserves: sending goods to a man waiting for them always works.
	assert_eq(String(_paid()["outcome"]), String(Intent.COMPLETED))


func test_only_the_tribute_executor_answers_for_it() -> void:
	var executor := TributeExecutor.new()
	assert_true(executor.handles(_intent()))
	var other := Intent.new()
	other.kind = EmbargoExecutor.KIND
	assert_false(executor.handles(other), "the tribute executor answered for an embargo")


# --- The letter reaches the player ------------------------------------------

func test_the_player_can_actually_reach_it() -> void:
	# The reachability gate caught this when the effect was registered with no
	# letter using it: a registered effect the player cannot reach is machinery
	# that looks wired and is not.
	var record := content.record("letters", "rival_duke.tribute_demand")
	assert_false(record.is_empty(), "the rival never writes")
	assert_false(bool(record.get("skippable", true)),
		"a demand from a foreign power was culled with the rest of the month's post")

	var options: Array = record["reply"]["steps"][0]["options"]
	var kinds: PackedStringArray = PackedStringArray()
	for option in options:
		for effect in option.get("effect", {}):
			kinds.append(String(effect))
	kinds.sort()
	assert_eq(",".join(kinds), "pay_tribute,refuse",
		"the two answers are not paying and refusing, which are the only two there are")


func test_he_is_a_rival_and_not_one_of_the_crown_s_officers() -> void:
	# He must not be swept up by anything that reasons about the Crown's people:
	# the whole point of him is that he answers to nobody the PC can appeal to.
	var run := RunState.new_run(SEED)
	ContactRoster.load_into(run, content)
	var him: Contact = run.contacts.get("rival_duke")
	assert_true(him != null, "the rival was never loaded")
	assert_eq(String(him.role), String(Contact.ROLE_RIVAL))
	for officer in ContactRoster.crown_officers(run):
		assert_true(officer.id != him.id, "a foreign power was counted as a Crown officer")
	assert_almost_eq(Contact.prominence_of(Contact.ROLE_RIVAL), 0.0, 0.0001,
		"a rival overseas pushes a town's sentiment, and he lives nowhere near it")
