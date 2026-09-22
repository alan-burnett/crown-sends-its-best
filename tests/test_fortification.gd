extends TestCase

## Terrain defence and forts (#215, `docs/mechanics/battles.md` §5,
## `docs/mechanics/tiles-and-improvements.md` §6).
##
## 🔒 **Authored where the thing is.** A terrain's defence sits beside its yields
## and a fort's two figures beside the cost of raising it — because a terrain
## that produced one thing and defended another from two different files would be
## two answers to what a mountain is.
##
## 🔒 **The fort is the exception in every direction.** It is the only
## improvement that affects no yield whatsoever — everything else exists to
## change what a tile produces, and this one exists to change what happens on it.
##
## 🔒 **And a tribe will never build one** (SPEC §11.1, locked). Villages shape
## the country without fortifying it, which is why a village is easier to take
## than a town and why taking one is worse.
##
## 🔒 **A rebel company in a fort on a mountain is close to unassailable**, and is
## meant to be. §6's damage curve accelerates as a defender weakens, so an
## implacable position yields eventually — slowly, and at a cost the PC feels.
## **That is the intended shape and not a balance problem to tune away.**

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
	Company.reset()
	Force.reset()
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
	Company.reset()
	Force.reset()
	content.free()


# --- 🔒 Terrain defence is authored in the terrain data --------------------

func test_the_three_tiers_are_authored_beside_the_yields() -> void:
	# The acceptance line: **not in code.** A dev retuning a mountain edits
	# `data/terrain/` and nothing else.
	var mountains := Terrain.find(&"mountains")
	var forest := Terrain.find(&"forest")
	var plains := Terrain.find(&"plains")

	assert_true(mountains.defence > forest.defence,
		"a forest is better cover than a mountain: %f against %f"
			% [forest.defence, mountains.defence])
	assert_true(forest.defence > plains.defence,
		"plains are better cover than a forest")
	assert_almost_eq(plains.defence, 1.0, 0.001, "open ground is an advantage")


func test_a_terrain_that_says_nothing_is_open_ground() -> void:
	# It must not silently become cover, and it must never be a penalty — the
	# ground does not make a man easier to kill.
	assert_almost_eq(Terrain.defence_of(&"a_terrain_nobody_has_written"), 1.0, 0.001)
	for id in Terrain.ids():
		assert_true(Terrain.defence_of(StringName(id)) >= 1.0,
			"'%s' makes the man standing on it easier to kill" % id)


func test_the_authored_figure_is_what_a_battle_reads() -> void:
	# 🔒 One answer, not two. `Force` asks the terrain rather than holding a
	# table of its own, so retuning the data moves the battle.
	for id in Terrain.ids():
		assert_almost_eq(Force.terrain_worth(StringName(id)),
			Terrain.defence_of(StringName(id)), 0.001,
			"'%s' defends differently in a battle than it says it does" % id)


func test_no_battle_table_names_a_terrain() -> void:
	# The failure this shape prevents: a second file listing mountains and
	# forests, which the first person to add a terrain updates one of.
	var text := FileAccess.get_file_as_string("res://data/battle/force.json")
	for id in Terrain.ids():
		assert_false(text.contains('"%s"' % id),
			"the battle table names the terrain '%s'" % id)


# --- 🔒 The fort, and its two distinct figures ------------------------------

func test_a_fort_is_worth_more_to_the_defender_than_to_the_attacker() -> void:
	var fort := Improvement.find(&"fort")
	assert_true(fort.defence_for(false) > 1.0,
		"a company attacking from a fort gets nothing for it")
	assert_true(fort.defence_for(true) > fort.defence_for(false),
		"a fort is worth no more to the man defending it: %f against %f"
			% [fort.defence_for(true), fort.defence_for(false)])


func test_the_fort_affects_no_yield_whatsoever() -> void:
	# 🔒 §6: **the only improvement that does not.** Everything else exists to
	# change what a tile produces; this one exists to change what happens on it,
	# and a fort that quietly improved a mine would be a fort somebody built for
	# the wrong reason.
	var fort := Improvement.find(&"fort")
	assert_empty(fort.scale, "a fort scales a yield")
	assert_empty(fort.adds, "a fort adds a yield")
	assert_eq(fort.livestock_capacity, 0, "a fort pastures livestock")
	for id in Terrain.ids():
		assert_almost_eq(fort.factor_on(StringName(id)), 1.0, 0.001,
			"a fort changes what %s yields" % id)


func test_it_is_the_only_improvement_that_fortifies() -> void:
	var fortifying := PackedStringArray()
	for id in Improvement.ids():
		if Improvement.find(StringName(id)).is_a_fortification():
			fortifying.append(String(id))
	assert_eq(fortifying, PackedStringArray(["fort"]),
		"more than one improvement is cover: %s" % [fortifying])


func test_everything_else_is_as_good_as_bare_ground_to_fight_over() -> void:
	for id in Improvement.ids():
		if String(id) == "fort":
			continue
		var improvement := Improvement.find(StringName(id))
		assert_almost_eq(improvement.defence_for(true), 1.0, 0.001,
			"a %s is cover" % id)
		assert_almost_eq(improvement.defence_for(false), 1.0, 0.001,
			"attacking from a %s is worth something" % id)


# --- 🔒 A tribe will never build one ----------------------------------------

func test_nothing_among_the_natives_builds_anything_at_all() -> void:
	# 🔒 SPEC §11.1, locked. **Villages shape the country without fortifying it**,
	# which is why a village is easier to take than a town and why taking one is
	# worse — and the way that stays true is that no native code can put an
	# improvement on the map by any path, not that it happens to avoid forts.
	var builders := PackedStringArray()
	for path in _scripts_in("res://sim/natives"):
		var code := _code_of(path)
		for token in [".build(", "improvements[", "clear_improvement("]:
			if code.contains(token):
				builders.append("%s calls %s" % [path.get_file(), token])
	assert_empty(builders,
		"the natives can put something on the map: %s" % ", ".join(builders))


func test_a_fort_cannot_be_raised_on_water() -> void:
	# Not a native rule, but the same shape: the allowed list is authored and a
	# fort in the sea would be a fort nobody could ever reach.
	var fort := Improvement.find(&"fort")
	for id in ["ocean", "sea"]:
		assert_false(fort.can_build_on(StringName(id)),
			"a fort may be raised on %s" % id)
	assert_true(fort.can_build_on(&"mountains"))


# --- 🔒 A mountain fort is close to unassailable ---------------------------

func test_a_company_in_a_mountain_fort_is_dramatically_harder_to_reduce() -> void:
	# §5 says so in as many words, and it is the intended shape rather than a
	# balance problem. The figure is held above a threshold so a careless retune
	# cannot quietly remove it — §6's curve is what lets it yield eventually.
	var in_the_open := Force.terrain_worth(&"plains") \
		* Improvement.find(&"farm").defence_for(true)
	var holed_up := Force.terrain_worth(&"mountains") \
		* Improvement.find(&"fort").defence_for(true)
	assert_true(holed_up > in_the_open * 3.0,
		"a mountain fort is worth %f against %f in the open" % [holed_up, in_the_open])


func test_horses_are_no_answer_to_a_wall() -> void:
	# §8: cavalry ignores the ground and **never the fort**, which is only
	# possible because the two are separate figures in separate files.
	assert_true(Improvement.find(&"fort").defence_for(true) > 1.0)
	assert_true(Terrain.defence_of(&"mountains") > 1.0)


## A script with its comments taken out.
##
## **The lock is about call sites, not prose.** `village.gd` says in its header
## that villages build farms and never forts, and a scan that counted the
## explanation would forbid explaining it.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			kept.append(String(line))
	return "\n".join(kept)


func _scripts_in(at: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := at.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_scripts_in(path))
		elif entry.ends_with(".gd"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	assert_false(out.is_empty(), "no scripts were found under %s to check" % at)
	return out
