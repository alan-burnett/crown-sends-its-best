extends SceneTree

## The content validator CLI.
##
##     godot --headless --script res://tools/validate_content.gd
##
## Runs standalone, checks the whole `data/` tree in one pass, and **exits
## non-zero on any failure** so CI (#26) can gate on it. Catching a bad letter
## here is the difference between a build failing and a player being shown
## `I require {param:amount}`.

const EXIT_OK: int = 0
const EXIT_CONTENT_INVALID: int = 1
const EXIT_LOAD_FAILED: int = 2


func _init() -> void:
	# The registry has to exist before content can be checked against it: an
	# unregistered effect id is only detectable if something knows what is
	# registered.
	ContentRegistry.reset()
	MeasureRegistry.reset()
	M1Registrations.register_all()

	var content := ContentDatabase.new()
	if not content.load_all("en"):
		print("content failed to load:")
		print(content.error_report())
		content.free()
		quit(EXIT_LOAD_FAILED)
		return
	M1Registrations.load_resources(content)

	var validator := ContentValidator.new()
	validator.validate(content)
	validator.check_trigger_targets(content)
	validator.check_companions(content)
	validator.check_trigger_params(content)
	validator.check_effects_are_reachable(content)
	validator.check_building_reserves(content)
	validator.check_expedition_outfitting(content)
	validator.check_tile_yield_bonuses(content)
	validator.check_colony_reach(content)
	validator.check_buildings_do_something(content)
	validator.check_no_authored_durations(content)
	validator.check_severity(content)
	validator.check_epitaphs(content)
	validator.check_balance_policies(content)
	validator.check_name_bags(content)
	validator.check_run_modifiers(content)
	validator.check_patrons(content)
	validator.check_commander_experience(content)
	validator.check_cutscenes(content)
	validator.check_agendas(content)
	validator.check_troop_requests(content)
	validator.check_policy_targets(content)
	validator.check_company_urgings(content)
	validator.check_tribe_answers(content)
	print(validator.report())

	var ok := validator.ok()
	content.free()
	quit(EXIT_OK if ok else EXIT_CONTENT_INVALID)
