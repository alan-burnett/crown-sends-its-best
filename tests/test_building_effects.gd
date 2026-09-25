extends TestCase

## 🔒 Every building does something (#416).
##
## Since #429 a town builds whatever its intent's menu lists, for its place and
## not its effect, so a building with no effects is a town spending wood and
## stone on nothing, and an empty `effects` passes every other check.

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


func test_a_building_with_no_effects_fails_validation() -> void:
	var validator := ContentValidator.new()
	validator.check_buildings_do_something(content)
	assert_true(validator.ok(), "a shipped building does nothing")
	content.collection("buildings")["dock"]["effects"] = {}
	validator = ContentValidator.new()
	validator.check_buildings_do_something(content)
	assert_false(validator.ok(), "a dock that does nothing passed")
