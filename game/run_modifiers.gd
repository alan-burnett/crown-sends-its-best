class_name RunModifiers
extends RefCounted

## What a perk or a quirk actually turns (#286,
## `docs/mechanics/perks-and-quirks.md` §1, §2).
##
## ## 🔒 A perk names a knob. It never adds a number
##
## *Righteous* is not `+5 clergy loyalty`. It is **a drift term on one class of
## contact** — a knob that already exists, turned.
##
## That is what keeps perks out of the engine (SPEC §16.1's lock that content is
## data-driven), what lets the Author add one without a code change, and what
## **stops forty of them becoming forty special cases**.
##
## **Where a perk wants a knob that does not exist, the knob is the work** — not
## the perk. Two of §3's will need one: *Read between the lines* modifies
## perception leans, and *Distant colony* changes the post's transit time.
##
## ## 🔒 Perks are about you, quirks are about the world
##
## | | Is | Therefore |
## | :--- | :--- | :--- |
## | **A perk** | a fact about the PC | **pure benefit**, one per run |
## | **A quirk** | a fact about the world he was given | **benefit and drawback**, any number |
##
## A fact about you is yours; a fact about the world cuts both ways. That is the
## whole of SPEC §5's asymmetry, and it needs no second rule — **nothing here
## enforces it**, because a quirk with only benefits is a content mistake the
## Author makes and not a state the code can be in.
##
## ## The registry
##
## Ids into a code-side table with typed params, **exactly as effects and
## conditions are** (`CLAUDE.md`). A modifier id nobody has registered is a
## content error the validator catches, not a silent no-op.
##
## Named static functions rather than lambdas: a `Callable` living in a static
## registry segfaults Godot 4.7 on shutdown (`CLAUDE.md`).

const PERKS: String = "run"
const PERKS_RECORD: String = "perks"
const QUIRKS_RECORD: String = "quirks"

## Modifier id -> the name of the static function that applies it.
##
## **A table of names, not of callables.** Looked up by name at the moment of
## use, so nothing holds a `Callable` at shutdown.
const APPLIES: Dictionary = {
	"crown_grace": "_crown_grace",
	"crown_price_scale": "_crown_price_scale",
	"yield_scale": "_yield_scale",
	"commander_start_level": "_commander_start_level",
	"commander_survival": "_commander_survival",
	"patrons_at_once": "_patrons_at_once",
	"hands_out": "_hands_out",
	"perception_leans": "_perception_leans",
	"first_impression": "_first_impression",
	"favour_toward": "_favour_toward",
	"prominence_scale": "_prominence_scale",
	"amusement_worth": "_amusement_worth",
}


static func is_modifier(id: String) -> bool:
	return APPLIES.has(id)


static func ids() -> PackedStringArray:
	var out := PackedStringArray(APPLIES.keys())
	out.sort()
	return out


## Turn every knob this run's perk and quirks name.
##
## 🔒 **One perk and any number of quirks** (§1), and the perk goes first so that
## a quirk which happened to turn the same knob is the later word. Applied at run
## setup, once, because a modifier is a fact about the run rather than a thing
## that happens in it.
static func apply_all(run: RunState, content: ContentDatabase) -> void:
	if run == null or run.setup == null or content == null:
		return
	_apply_one(run, content, PERKS_RECORD, String(run.setup.perk))
	var quirks := run.setup.quirks.duplicate()
	quirks.sort()
	for quirk in quirks:
		_apply_one(run, content, QUIRKS_RECORD, String(quirk))


## Everything a run may be offered, in id order.
##
## 🔒 **Adding an entry to the file adds it to the list**, which is the whole
## point: the code knows how to apply the ids it finds, and nothing else.
static func offered(content: ContentDatabase, record: String) -> PackedStringArray:
	var out := PackedStringArray()
	if content == null:
		return out
	for entry in entries_in(content, record):
		if bool((entry as Dictionary).get("offered", true)):
			out.append(String((entry as Dictionary).get("id", "")))
	out.sort()
	return out


## The raw entries a file holds, offered or not.
static func entries_in(content: ContentDatabase, record: String) -> Array:
	if content == null or not content.has_record(PERKS, record):
		return []
	return content.record(PERKS, record).get("entries", [])


static func _apply_one(
	run: RunState, content: ContentDatabase, record: String, id: String
) -> void:
	if id.is_empty():
		return
	var _turning := RunModifiers.new()
	for entry in entries_in(content, record):
		if String((entry as Dictionary).get("id", "")) != id:
			continue
		for modifier in (entry as Dictionary).get("modifiers", []):
			for modifier_id in modifier:
				if not APPLIES.has(String(modifier_id)):
					push_error(
						"'%s' names the modifier '%s', which nothing registers."
						% [id, modifier_id])
					continue
				# **Dispatched by name through an instance**, which is the only way
				# GDScript will `call` into this script — and it is the shape that
				# matters anyway: the instance is made here and dropped here, so
				# nothing holds a `Callable` at shutdown (`CLAUDE.md`).
				_turning.call(
					String(APPLIES[String(modifier_id)]), run, modifier[modifier_id])
		return


# --- The knobs -------------------------------------------------------------

## **It's my first day**: an extra Chancellor warning before the Crown first
## refuses payment.
##
## The grace `CrownRefusal` has carried since #68 with nothing able to switch it
## on — which is exactly the shape §2 asks for. The perk names it; it does not
## invent a number.
static func _crown_grace(run: RunState, _args: Dictionary) -> void:
	if run.refusal != null:
		run.refusal.has_grace = true


## **Scarce iron**, the Crown's half: what it charges for a named resource, for
## the whole run.
##
## 🔒 **A price, never an instruction** (SPEC §11.3). It reaches the towns
## through `Valuation.crown` exactly as the war lift does, so they turn away from
## dear resources because they are dear.
##
## Args: `{"resources": {"iron": 2.4, ...}}`.
static func _crown_price_scale(_run: RunState, args: Dictionary) -> void:
	CrownPrices.scale_prices(args.get("resources", {}))


## **Scarce iron**, the ground's half: what every tile gives of a named resource.
##
## The asymmetry between this and the price above **is the whole quirk**
## (`perks-and-quirks.md` §4): the Crown's price rises far more than the yield
## falls, so buying your way out stops working and the way out is your own
## foundry.
##
## Args: `{"resources": {"ore": 0.8, ...}}`.
static func _yield_scale(_run: RunState, args: Dictionary) -> void:
	Terrain.scale_yields(args.get("resources", {}))


## **Commando commanders**, the benefit: a man knows his trade before his first
## battle.
##
## Args: `{"levels": 2}`.
static func _commander_start_level(_run: RunState, args: Dictionary) -> void:
	CommanderExperience.start_at(int(args.get("levels", 0)))


## **Commando commanders**, the cost: he is likelier to die with his men.
##
## The pair is the quirk — a colony that breeds veterans is one that buries them
## faster — and `commanders.md` §7 already notes the flip *need not be even*.
##
## Args: `{"chance": 0.3}`.
static func _commander_survival(_run: RunState, args: Dictionary) -> void:
	CommanderFate.set_survives(float(args.get("chance", 0.5)))


## **Busy patrons**: how many may be in the correspondence at once.
##
## 🔒 **More prestige and more of the desk**, which SPEC §9.6 makes the real
## constraint. The drawback is not a penalty bolted on; it is the letters.
##
## Args: `{"count": 5}`.
static func _patrons_at_once(_run: RunState, args: Dictionary) -> void:
	Patron.set_how_many(int(args.get("count", 3)))


## **Busy patrons**, the half that makes the other half mean anything: how many
## hands the world holds out at full reach.
##
## 🔒 **Raising the count alone does nothing**, because `DemandSchedule`'s reach
## ceiling is what actually caps arrivals — seven hands, of which the last three
## are the patrons. A quirk that promised five and delivered three would be a
## number in a file, and that is precisely what it was until a test asked for
## the fifth.
##
## Args: `{"reach_ceiling": 9}`.
static func _hands_out(_run: RunState, args: Dictionary) -> void:
	DemandSchedule.raise_ceiling(
		DemandGrowth.REACH, int(args.get("reach_ceiling", 0)))


## **Read between the lines**: contacts' perception leans are reduced when
## reporting to the PC.
##
## 🔒 **They still deceive themselves.** The Marshal goes on minimising every
## threat and the clergy goes on seeing the worst — they present it more plainly.
## That is why this turns the pipeline's scale and not anybody's `leans`, which
## is what the man believes.
##
## The only perk that changes what the PC can **see** rather than what he can do.
##
## Args: `{"scale": 0.5}`.
static func _perception_leans(_run: RunState, args: Dictionary) -> void:
	Perception.set_lean_scale(float(args.get("scale", 1.0)))


## **Good first impression**: every new contact starts warmer.
##
## Generated contacts only — the Crown's officers are fixed in every run and
## their authored loyalties are characterisation.
##
## Args: `{"warmth": 8.0}`.
static func _first_impression(_run: RunState, args: Dictionary) -> void:
	Contact.set_first_impression(float(args.get("warmth", 0.0)))


## **Righteous**: clergy gain loyalty every turn.
##
## 🔒 **A drift term on one class of contact**, which is §2's own example of what
## naming a knob means. Quietly a sentiment perk as much as a charity one: a
## contented clergyman is a standing weight against his town's rebel sentiment.
##
## Args: `{"kinds": {"clergyman": 0.5}}`.
static func _favour_toward(_run: RunState, args: Dictionary) -> void:
	LoyaltyDrift.favour(args.get("kinds", {}))


## **A pious colony**: clergy carry higher prominence everywhere.
##
## Both directions at once, which is the quirk: a contented priest holds his town
## down harder and a slighted one carries it out faster.
##
## Args: `{"kinds": {"clergyman": 1.3}}`.
static func _prominence_scale(_run: RunState, args: Dictionary) -> void:
	ContactRoster.scale_prominence(args.get("kinds", {}))


## **A pious colony**, the drawback: amusement contributes less pleasure.
##
## They disapprove, so bread and circuses buy less — which closes
## `quality-of-life.md` §8's rum trap from the other end.
##
## Args: `{"worth": 0.7}`.
static func _amusement_worth(_run: RunState, args: Dictionary) -> void:
	Building.set_amusement_worth(float(args.get("worth", 1.0)))
