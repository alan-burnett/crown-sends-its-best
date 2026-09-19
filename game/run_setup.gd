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

## How many sites the player is offered.
##
## Three is enough to be a choice and few enough to read on a phone. They are
## spread across the ranked list rather than taken from the top, or all three
## would be the same good ground with different coordinates.
const SITES_OFFERED: int = 3

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

var pc_name: String = "Ashcombe"
var pc_title: String = "Governor"
var portrait: String = "portrait_default"
var colour: Color = Color(0.42, 0.29, 0.20)

# --- Everything that shapes the colony -------------------------------------

var seed_value: int = 0
var perk: StringName = PERK_FIRST_DAY
var quirks: PackedStringArray = PackedStringArray()
var mandate: StringName = GovernorIntent.ECONOMY
var split: StringName = SPLIT_STORES

## Which of the offered sites was taken, as an index into `sites_for`.
var site_choice: int = 0


## The sites this seed offers.
##
## **Spread across the ranked list, not the top of it.** Three neighbouring
## tiles of the same good ground is not a decision; a rich site, a middling one
## and a hard one is. M5 gives natives and rivals, and the same three sites will
## then differ in neighbours as well as in soil.
static func sites_for(seed_value_in: int) -> Array[Vector2i]:
	var streams := RngStreams.new(seed_value_in)
	var ranked := MapGenerator.sites_by_score(MapGenerator.generate(streams.stream("mapgen")))
	var out: Array[Vector2i] = []
	if ranked.is_empty():
		return out
	for at in SITES_OFFERED:
		var index := int(float(ranked.size() - 1) * (float(at) / float(SITES_OFFERED)) * 0.7)
		out.append(ranked[clampi(index, 0, ranked.size() - 1)])
	return out


## Where this setup puts the first town.
func site() -> Vector2i:
	var offered := sites_for(seed_value)
	if offered.is_empty():
		return Vector2i(-1, -1)
	return offered[clampi(site_choice, 0, offered.size() - 1)]


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
		"site_choice": site_choice,
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
	setup.site_choice = int(data.get("site_choice", 0))
	return setup
