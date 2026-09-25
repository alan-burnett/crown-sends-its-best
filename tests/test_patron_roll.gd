extends TestCase

## What a patron is rolled with (#439, `patrons.md` §2, §3).
##
## 🔒 **A need is a resource or livestock kind**, never his specialty's; nobody
## asks the colony for its people, its gold or its rivals.
##
## 🔒 **Tea is never a specialty.**
##
## 🔒 **Two patrons to a kind, then none.** A resource or livestock specialty
## rolls one of two permanent bonuses; the second patron of a kind is given the
## other, and no third is rolled with it. The book of what each kind has been
## rolled with outlives the men, since a patron who goes home leaves the roster.

const SEED: int = 439
const PROBES: int = 200

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


func after_each() -> void:
	reset_world()
	content.free()


## `PROBES` men, each from his own stream, each rolled against his own copy of
## `rolled` so none of them closes a kind for the next.
func _probes(rolled: Dictionary = {}) -> Array:
	var men: Array = []
	for index in PROBES:
		var book := PatronBook.new()
		book.rolled = rolled.duplicate(true)
		men.append(Patron.generate(StringName("patron_probe_%d" % index), run.streams, 0, book))
	return men


## Every resource and livestock kind closed but the ones named, which keep what
## they are given.
func _closed_but(open: Dictionary) -> Dictionary:
	var rolled: Dictionary = {}
	for category in Patron.WITH_A_BONUS:
		for kind in Patron.specialty_kinds_of(category):
			rolled[kind] = Array(Patron.BONUSES).duplicate()
	for kind in open:
		rolled[kind] = (open[kind] as Array).duplicate()
	return rolled


# --- 🔒 His need -----------------------------------------------------------------------

func test_no_patron_needs_people_gold_or_the_rivals_or_his_own_kind() -> void:
	for entry in _probes():
		var man: Contact = entry
		assert_true(["resources", "livestock"].has(man.need),
			"%s needs %s, and a need is a resource or livestock kind" % [man.id, man.need])
		assert_true(Patron.kinds_of(man.need).has(man.need_kind),
			"%s needs '%s', which is not a kind of %s" % [man.id, man.need_kind, man.need])
		assert_ne(man.need_kind, man.specialty_kind, "%s needs his own kind" % man.id)


func test_both_resources_and_livestock_are_needed() -> void:
	var seen: Dictionary = {}
	for entry in _probes():
		seen[(entry as Contact).need] = true
	assert_true(seen.has("resources") and seen.has("livestock"),
		"two hundred patrons and their needs covered only %s" % [seen.keys()])


# --- 🔒 His specialty ------------------------------------------------------------------

func test_no_patrons_specialty_is_tea() -> void:
	# Tea is the one kind the colony can neither grow nor sell.
	assert_false(Patron.specialty_kinds_of("resources").has("tea"), "tea can be a specialty")
	var sugar_men := 0
	for entry in _probes():
		var man: Contact = entry
		assert_ne(man.specialty_kind, "tea", "%s specialises in tea" % man.id)
		if man.specialty == "resources":
			sugar_men += 1
	assert_true(sugar_men > 0, "no resource patron was rolled, so this proves nothing")


func test_a_resource_or_livestock_specialty_rolls_a_bonus_and_nothing_else_does() -> void:
	var seen: Dictionary = {}
	for entry in _probes():
		var man: Contact = entry
		if Patron.WITH_A_BONUS.has(man.specialty):
			assert_true(Patron.BONUSES.has(man.specialty_bonus),
				"%s deals in %s and was rolled with no bonus" % [man.id, man.specialty])
			seen[man.specialty_bonus] = true
		else:
			assert_eq(man.specialty_bonus, "",
				"%s deals in %s and was rolled with a bonus" % [man.id, man.specialty])
	assert_eq(seen.size(), Patron.BONUSES.size(), "the first of a kind never draws one of the bonuses")


# --- 🔒 Two to a kind, then none -------------------------------------------------------

func test_the_second_patron_of_a_kind_offers_the_other_bonus() -> void:
	# Every kind closed but sugar, which one patron has held with the price bonus:
	# every resource man from here is a sugar man, and he offers more of it.
	var resource_men := 0
	for entry in _probes(_closed_but({"sugar": [Patron.BONUS_PRICE]})):
		var man: Contact = entry
		assert_ne(man.specialty, "livestock", "%s holds a closed kind of livestock" % man.id)
		if man.specialty != "resources":
			continue
		resource_men += 1
		assert_eq(man.specialty_kind, "sugar", "%s holds a closed kind" % man.id)
		assert_eq(man.specialty_bonus, Patron.BONUS_MORE,
			"the second sugar man was rolled with the bonus the first one offered")
	assert_true(resource_men > 0, "no resource patron was rolled, so this proves nothing")


func test_no_third_patron_is_rolled_with_a_kind() -> void:
	# Sugar has been held twice; everything else is open.
	var resource_men := 0
	for entry in _probes({"sugar": [Patron.BONUS_PRICE, Patron.BONUS_MORE]}):
		var man: Contact = entry
		if man.specialty != "resources":
			continue
		resource_men += 1
		assert_ne(man.specialty_kind, "sugar", "%s is the third sugar man" % man.id)
	assert_true(resource_men > 0, "no resource patron was rolled, so this proves nothing")


func test_with_every_kind_closed_he_specialises_in_something_else() -> void:
	# Experts, troops, gold and the rivals have no limit, so a man is never rolled
	# with nothing — and the experts' kinds are not the resource patrons' to close.
	var experts := 0
	for entry in _probes(_closed_but({})):
		var man: Contact = entry
		assert_false(Patron.WITH_A_BONUS.has(man.specialty),
			"%s holds %s %s, and every kind was closed" % [man.id, man.specialty, man.specialty_kind])
		assert_false(man.specialty.is_empty(), "%s specialises in nothing" % man.id)
		if man.specialty == "experts":
			experts += 1
			assert_false(man.specialty_kind.is_empty(), "%s is an expert in nothing" % man.id)
	assert_true(experts > 0, "no experts patron was rolled, so this proves nothing")


func test_the_driver_enters_every_arrival_in_the_book() -> void:
	for _patron in Patron.how_many():
		run.demands.sources.append(String(DemandGrowth.SOURCE_PATRON))
	PatronDriver.new(run).on_phase(WorldPhase.ARRIVALS, run.world, run.log, run.streams)
	var entered := 0
	for entry in Patron.all_in(run):
		var man: Contact = entry
		if man.specialty_bonus.is_empty():
			continue
		entered += 1
		assert_true((run.patrons.rolled.get(man.specialty_kind, []) as Array).has(man.specialty_bonus),
			"%s arrived and his kind's book does not show it" % man.id)
	assert_true(entered > 0, "no arrival dealt in resources or livestock, so this proves nothing")
	var noted := 0
	for kind in run.patrons.rolled:
		noted += (run.patrons.rolled[kind] as Array).size()
	assert_eq(noted, entered, "the book holds a roll no patron made, or misses one")


# --- 🔒 Saved ------------------------------------------------------------------------------

func test_the_book_of_kinds_and_his_bonus_survive_a_save() -> void:
	var book := PatronBook.new()
	book.rolled = {"sugar": [Patron.BONUS_PRICE, Patron.BONUS_MORE], "horses": [Patron.BONUS_MORE]}
	var restored := PatronBook.from_dict(book.to_dict())
	assert_eq(restored.rolled, book.rolled)

	var man := Patron.generate(&"patron_saved", run.streams, 0)
	man.specialty = "livestock"
	man.specialty_kind = "horses"
	man.specialty_bonus = Patron.BONUS_MORE
	assert_eq(Contact.from_data(man.to_dict()).specialty_bonus, Patron.BONUS_MORE)
