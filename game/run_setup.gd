class_name RunSetup
extends RefCounted

## The decisions that shape a run before it begins
## (#79, SPEC §5, §6.1, §15, §16.1).
##
## ## 🔒 The seed and the choices are the whole of it
##
## SPEC §16.1 locks seeded generation: **the same seed and the same choices
## always produce the same run.** So everything that shapes a colony has to pass
## through here — a decision made anywhere else would be a decision a saved run
## could not reproduce.
##
## ## What is flavour and what is not
##
## SPEC §5 is explicit that the PC's name, title, portrait and colour are
## **flavour with no mechanical effect**. They are here because letters address
## him by them, and for no other reason. Nothing may read them to decide
## anything, and `test_run_setup.gd` says so.
##
## Everything else on this object changes the colony: where it stands, what it
## started with, what the Crown told the first governor it was for, and what the
## PC brought with him.
##
## ## Built so meta-progression is data
##
## SPEC §6.1 gives one perk and any number of quirks, and M7 unlocks more. At
## game start exactly one perk is available and no quirks are, so **adding
## entries must never mean adding code** — the offered list comes from
## `data/run/perks.json` and the only thing the code knows is how to apply the
## ids it finds there.

## The first day. The only perk unlocked at game start (SPEC §6.1).
##
## Grants an extra Chancellor warning before the Crown first refuses payment —
## the grace `CrownRefusal` has carried since #68 with nothing able to switch it
## on.
const PERK_FIRST_DAY: StringName = &"its_my_first_day"

## What the Crown told the first governor the colony was for.
##
## **The founding governor's starting intent** (SPEC §6.1), increasingly
## displaced as the run goes on — `IntentConsiderations.MANDATE_HALF_LIFE` is
## what does the displacing, so this is a strong opening pull rather than a
## standing order.
const MANDATES: Array[StringName] = [
	GovernorIntent.ECONOMY,
	GovernorIntent.DEFENCE,
	GovernorIntent.SETTLEMENT,
]


## How the opening grant may be split.
##
## **One grant, three ways to take it** (SPEC §6.1). A larger party eats more
## and works more ground; gold buys what the ground will not give; stores are
## the safe answer and the dullest.
const SPLIT_PEOPLE: StringName = &"people"
const SPLIT_GOLD: StringName = &"gold"
const SPLIT_STORES: StringName = &"stores"

const SPLITS: Array[StringName] = [SPLIT_PEOPLE, SPLIT_GOLD, SPLIT_STORES]

# --- Flavour, and nothing but ----------------------------------------------

## 🔒 **The PC is named by the player, and the game guesses first**
## (#358, `names.md` §1; SPEC §5 — *flavor only and has no effect*).
##
## 🔒 **The default title is *Lord*, and that is not a preference.** It was
## *Governor*, and `names.md` §2 makes the first word of a letterhead the role —
## so a PC styled *Governor* read exactly like one of his own colonial governors.
## **It removes a collision.**
##
## The name is a placeholder until `suggest_a_name` has a bag to draw from, which
## is content and arrives later than this object does.
var pc_name: String = "Ashcombe"
var pc_title: String = DEFAULT_TITLE

## What the player is allowed to type, **measured after trimming**.
##
## 🔒 **A minimum of one is what removes the empty case**, so nothing
## downstream needs a fallback for a nameless PC — there is no such PC. It has to
## be after trimming, or a single space satisfies a naive length check and puts
## that case straight back.
##
## The maxima exist because both land in period-style prose and in a salutation
## line that has to fit a phone (SPEC §15).
const DEFAULT_TITLE: String = "Lord"
const TITLE_MIN: int = 1
const TITLE_MAX: int = 20
const NAME_MIN: int = 1
const NAME_MAX: int = 48
var portrait: String = "portrait_default"
var colour: Color = Color(0.42, 0.29, 0.20)

# --- Everything that shapes the colony -------------------------------------

var seed_value: int = 0
var perk: StringName = PERK_FIRST_DAY
var quirks: PackedStringArray = PackedStringArray()
var mandate: StringName = GovernorIntent.ECONOMY
var split: StringName = SPLIT_STORES

## 🔒 **What the colony is for, not where it goes** (#273, `map.md` §4).
##
## This replaced a `site_choice` index into a list of three coordinates. §11.4
## locks that the PC never chooses a tile when founding a town — run start is the
## same act by the same sort of person — and a coordinate means nothing to a
## player who has never played.
var request: StringName = SiteRequest.QUICK_GROWTH

## The two answers, named here as well as in `sim/`.
##
## **Not a second source of truth**: they are the sim's ids, aliased so the setup
## screen can offer them. `tools/lint.gd` keeps `Tribes` out of `presentation/`
## entirely — the rule exists so no screen can leak a village's position or a
## people's regard, and it is worth more than the convenience of naming the class
## in one more place.
const PROXIMITY_NEAR: StringName = Tribes.NEAR
const PROXIMITY_APART: StringName = Tribes.APART
const PROXIMITIES: Array[StringName] = Tribes.PROXIMITIES

## 🔒 **How close the colony settles to the tribes** (#274, `map.md` §8).
##
## The villages are placed **after** the site and relative to it, so both
## questions are honoured exactly on every seed. Only the nearest neighbour is in
## question: two tribes are distant whatever he answers.
##
## 🔒 **Being placed near a tribe is not itself an offence.** The colony did not
## choose its neighbours' land, it was put there.
var proximity: StringName = Tribes.APART


## Where this setup puts the first town.
##
## **The map answers.** The request tilts a good site and never picks a strange
## one, and every answer has sea within reach whatever was asked for.
func site_in(map: WorldMap) -> Vector2i:
	return SiteRequest.choose(map, request)


## Whether what the player typed is a title, once it has been trimmed.
static func is_a_title(text: String) -> bool:
	var trimmed := text.strip_edges()
	return trimmed.length() >= TITLE_MIN and trimmed.length() <= TITLE_MAX


## Whether what the player typed is a name, once it has been trimmed.
static func is_a_name(text: String) -> bool:
	var trimmed := text.strip_edges()
	return trimmed.length() >= NAME_MIN and trimmed.length() <= NAME_MAX


## A name for a minor royal, from the **aristocrats'** bag.
##
## 🔒 **The same pool his patrons come from**, which is the point: he is one
## of them, sent out. `names.md` §1.
##
## From the run's own seed, through a stream of its own, so the suggestion is the
## same for a given chart and **drawing it shifts nobody else's rolls** — a PC who
## retyped his name would otherwise have got different patrons
## (`CLAUDE.md`, determinism).
static func suggest_a_name(seed_value: int) -> String:
	return NameBags.person(
		NameBags.ARISTOCRATS, RngStreams.new(seed_value).contact_stream("the_pc"))


## What the screen should pre-fill the name field with.
##
## The player's, if he has already typed one — a run rerolled to another chart
## keeps the name he chose.
func suggested_name() -> String:
	if not pc_name.strip_edges().is_empty():
		return pc_name.strip_edges()
	var suggested := RunSetup.suggest_a_name(seed_value)
	return suggested if not suggested.is_empty() else pc_name


## Why these two will not do, or "" if they will.
##
## 🔒 **One function, so the screen and a test ask the same question.** A
## screen with its own idea of what is too long is a second source of truth and
## the one the player actually meets.
static func what_is_wrong_with(title: String, name: String) -> String:
	if not is_a_title(title):
		return "A style is between %d and %d characters." % [TITLE_MIN, TITLE_MAX]
	if not is_a_name(name):
		return "A name is between %d and %d characters." % [NAME_MIN, NAME_MAX]
	return ""


## Fill in what the player has not chosen, and strike the name he keeps.
##
## 🔒 **A guessed name he keeps is struck from the bag for that run**
## (`names.md` §1, §5's rule applied to the one thing that is not generated). A
## patron who happened to share the PC's name would read as a mistake even though
## nothing was wrong, and it costs a set membership.
##
## It strikes whatever he ends up with, typed or suggested. A player who names
## himself after a man the bag also holds has the same claim on it.
func settle_the_name(seed_value: int) -> void:
	if pc_name.strip_edges().is_empty():
		var suggested := RunSetup.suggest_a_name(seed_value)
		if not suggested.is_empty():
			pc_name = suggested
	pc_name = pc_name.strip_edges()
	pc_title = pc_title.strip_edges()
	NameBags.strike(pc_name)


func has_perk(id: StringName) -> bool:
	return perk == id


func to_dict() -> Dictionary:
	return {
		"pc_name": pc_name,
		"pc_title": pc_title,
		"portrait": portrait,
		"colour": [colour.r, colour.g, colour.b],
		"seed_value": seed_value,
		"perk": String(perk),
		"quirks": Array(quirks),
		"mandate": String(mandate),
		"split": String(split),
		"request": String(request),
		"proximity": String(proximity),
	}


static func from_dict(data: Dictionary) -> RunSetup:
	var setup := RunSetup.new()
	setup.pc_name = String(data.get("pc_name", setup.pc_name))
	setup.pc_title = String(data.get("pc_title", setup.pc_title))
	setup.portrait = String(data.get("portrait", setup.portrait))
	var rgb: Array = data.get("colour", [])
	if rgb.size() >= 3:
		setup.colour = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	setup.seed_value = int(data.get("seed_value", 0))
	setup.perk = StringName(data.get("perk", PERK_FIRST_DAY))
	setup.quirks = PackedStringArray(data.get("quirks", []))
	setup.mandate = StringName(data.get("mandate", GovernorIntent.ECONOMY))
	setup.split = StringName(data.get("split", SPLIT_STORES))
	setup.request = StringName(data.get("request", SiteRequest.QUICK_GROWTH))
	setup.proximity = StringName(data.get("proximity", Tribes.APART))
	return setup
