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
	"perception_leans": "_perception_leans",
	"first_impression": "_first_impression",
	"favour_toward": "_favour_toward",
	"prominence_scale": "_prominence_scale",
	"amusement_worth": "_amusement_worth",
	"optics_favour": "_optics_favour",
	"crown_break_cost": "_crown_break_cost",
	"deed_worth_for_role": "_deed_worth_for_role",
	"urging_weight": "_urging_weight",
	"quality_felt": "_quality_felt",
	"immigration_flow": "_immigration_flow",
	"stakes_scale": "_stakes_scale",
	"tribe_standing_start": "_tribe_standing_start",
	"village_yield": "_village_yield",
	"war_party_share": "_war_party_share",
	"native_reserve": "_native_reserve",
	"post_crossing": "_post_crossing",
	"silence_cost": "_silence_cost",
	"damper_months": "_damper_months",
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
##
## 🔒 **From a fresh world's knobs, every time** — see `reset_knobs`. A run
## with nothing to apply still gets them, because a run with no perk is a run
## whose knobs are all at home, not a run whose knobs are whatever was left.
static func apply_all(run: RunState, content: ContentDatabase) -> void:
	reset_knobs()
	if run == null or run.setup == null or content == null:
		return
	_apply_one(run, content, PERKS_RECORD, String(run.setup.perk))
	var quirks := run.setup.quirks.duplicate()
	quirks.sort()
	for quirk in quirks:
		_apply_one(run, content, QUIRKS_RECORD, String(quirk))


## Every knob a modifier can turn, back where a fresh process has it.
##
## 🔒 **A knob is a static, and a static outlives the run that turned it.**
## `load_resources` runs once, at startup, and New Game and Continue go straight
## to a run — so without this a *Distant colony* run followed by New Game kept
## its extra month at sea, and a save loaded after another run kept every knob
## that run turned and the loaded one does not.
##
## 🔒 **The knob, never the table beside it.** Where a class holds content
## `load_resources` loaded as well as a knob, it has a narrower reset for the
## knob — the terrain, the ranks, the patron catalogue and the Squeeze's schedule
## are not a run's to clear, and clearing them would hand the next run an empty
## world rather than a fresh one.
##
## **Adding a modifier means adding its knob here, and its class to
## `TestCase.reset_world`.** Two lists, deliberately: `test_run_modifiers.gd`
## reads every static the game holds after a plain run and compares it with a
## world `reset_world` put back, so a knob left off this list, or a reset here
## that takes the table with it, fails there rather than in somebody's second
## run. A yardstick built from the list it measures could not see a line missing
## from both.
##
## `crown_grace` and `deed_worth_for_role` are absent because they write the run
## itself, and every run is made or loaded afresh.
static func reset_knobs() -> void:
	CrownPrices.reset()  # crown_price_scale
	Terrain.reset_yield_scale()  # yield_scale
	CommanderExperience.reset_starting_level()  # commander_start_level
	CommanderFate.reset()  # commander_survival
	Patron.reset_how_many()  # patrons_at_once
	DemandSchedule.reset_room()  # patrons_at_once
	Perception.reset()  # perception_leans
	Contact.reset()  # first_impression
	LoyaltyDrift.reset()  # favour_toward
	ContactRoster.reset_prominence()  # prominence_scale
	Building.reset_amusement_worth()  # amusement_worth
	OpticsRegister.reset()  # optics_favour
	Relationship.reset()  # crown_break_cost
	IntentConsiderations.reset_urging()  # urging_weight
	QualityOfLife.reset()  # quality_felt
	Immigration.reset()  # immigration_flow
	RebelSentiment.reset()  # stakes_scale
	Tribes.reset()  # tribe_standing_start
	Village.reset()  # village_yield
	Muster.reset()  # war_party_share
	TradeAgreement.reset()  # native_reserve
	Crossing.reset()  # post_crossing
	Silence.reset()  # silence_cost
	Pressure.reset()  # damper_months


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


## 🔒 **What a new run may choose from** (#465, SPEC §5): what is offered, and
## either unlocked from the start or unlocked by a past run. §5: *"only unlocked
## perk from the start… no unlocked quirks"* — so with nothing unlocked a run is
## offered the first-day perk and no quirks at all.
static func unlocked(
	content: ContentDatabase, record: String, unlocks: PackedStringArray
) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in entries_in(content, record):
		var id := String((entry as Dictionary).get("id", ""))
		if not bool((entry as Dictionary).get("offered", true)):
			continue
		if bool((entry as Dictionary).get(UNLOCKED_AT_START, false)) or unlocks.has(id):
			out.append(id)
	out.sort()
	return out


## The field that marks an entry available before anything is unlocked.
const UNLOCKED_AT_START: String = "unlocked_at_start"


## One entry's name and blurb, for a screen to show.
static func entry(content: ContentDatabase, record: String, id: String) -> Dictionary:
	for found in entries_in(content, record):
		if String((found as Dictionary).get("id", "")) == id:
			return found
	return {}


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
## 🔒 **One knob, and it reaches the Squeeze** (#339). A draw of *more hands
## out* chooses among the sources with room left, so a count of patrons the
## Squeeze could never fill would be a number in a file. The room is made here,
## beside the count, so the two cannot disagree.
##
## Args: `{"count": 5}`.
static func _patrons_at_once(_run: RunState, args: Dictionary) -> void:
	var count := int(args.get("count", 3))
	Patron.set_how_many(count)
	DemandSchedule.make_room(DemandGrowth.SOURCE_PATRON, count)


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


## **Good PR**: the PC's optics all land in his favour.
##
## 🔒 **It does not make an optic decay. Nothing does.** It scales what each is
## worth in the tally, so a run with two rebellions in it is still a run with two
## rebellions in it, and merely less ruinous — which is the difference between a
## perk and a pardon.
##
## Args: `{"scale": 0.6}`.
static func _optics_favour(_run: RunState, args: Dictionary) -> void:
	OpticsRegister.set_favour(float(args.get("scale", 1.0)))


## **My boss is a jerk**: when the *Crown* breaks a promise it costs far less
## regard.
##
## 🔒 **Scaled on who refused, never on the promise.** `REFUSING` breaks every
## gold promise at once, and because the PC typically owes several people it
## lands as a broad collapse in goodwill rather than one penalty — then worse
## compliance, then rising sentiment. This defuses the nastiest spiral in the
## game, and only ever matters once the PC is already in trouble.
##
## A promise he broke himself costs exactly what it always did.
##
## Args: `{"scale": 0.3}`.
static func _crown_break_cost(_run: RunState, args: Dictionary) -> void:
	Relationship.set_crown_break_scale(float(args.get("scale", 1.0)))


## **Well connected at court**: granting a Crown officer's demand earns more
## regard than it should.
##
## 🔒 **The gold leaves exactly as it would have.** What the PC buys with it is
## worth more, which makes the officers cheaper to keep and the Squeeze's *more
## hands out* dimension less punishing. So it turns what a deed is **worth** and
## never the promise, the payment or the Crown's books.
##
## **Through `deed_scale`, the per-man seam `patrons.md` §6 already uses** — the
## Crown's five are fixed in every run (SPEC §8.1) and all present from the
## first month, so setting it on each of them at setup reaches every one of them
## and needs no new machinery.
##
## Args: `{"role": "crown_officer", "deed": "granted", "scale": 1.6}`.
static func _deed_worth_for_role(run: RunState, args: Dictionary) -> void:
	var role := StringName(args.get("role", Contact.ROLE_CROWN_OFFICER))
	var deed := StringName(args.get("deed", Relationship.GRANTED))
	var scale := float(args.get("scale", 1.0))
	for id in run.contact_ids():
		var contact: Contact = run.contacts[id]
		if contact != null and contact.role == role and contact.relationship != null:
			contact.relationship.scale_deed(deed, scale)


## **Hard to say no to**: the PC's urging weighs more in a governor's intent
## deliberation.
##
## 🔒 **It never overrides him.** `crown_urging` is still weighed against
## eight other considerations and his own reading of his town, so this **wins close
## arguments and loses hopeless ones** — the Crown's pressure, not the Crown's
## command.
##
## Args: `{"weight": 1.8}`.
static func _urging_weight(_run: RunState, args: Dictionary) -> void:
	IntentConsiderations.set_urging_weight(float(args.get("weight", 1.0)))


## **It could be worse**: everything that measures quality of life does so with a
## dampened effect.
##
## 🔒 **It flattens the curve in both directions**, which is the quirk and
## not a softening. Misery hurts less — less rebel sentiment, fewer complaints, a
## steadier colony — and comfort helps less — weaker immigration appeal, slower
## births, less of the virtuous circle. Rewards a player who never meant to invest
## in how people live; punishes one whose whole plan was to make the colony
## pleasant.
##
## On the **measure**, never on the five components: the food really did run out,
## and what the quirk changes is how much anybody makes of it.
##
## Args: `{"scale": 0.6}`.
static func _quality_felt(_run: RunState, args: Dictionary) -> void:
	QualityOfLife.set_felt(float(args.get("scale", 1.0)))


## **Boom town**, the benefit: the crossing runs harder all run.
##
## On the flow rather than on a town's appeal, so it multiplies the reasons a
## town has already earned. **A wretched town still draws nobody.**
##
## Args: `{"scale": 1.5}`.
static func _immigration_flow(_run: RunState, args: Dictionary) -> void:
	Immigration.set_flow_scale(float(args.get("scale", 1.0)))


## **Boom town**, the cost that is the same sentence: the stakes multiplier runs
## higher with it.
##
## 🔒 **`immigration.md` §9's chain made into a choice** — growth is the engine of
## prosperity and the engine of rebellion at once. A player who can hold a large
## colony gets a larger one sooner; a player who cannot gets to the cliff faster.
##
## Args: `{"scale": 1.4}`.
static func _stakes_scale(_run: RunState, args: Dictionary) -> void:
	RebelSentiment.set_stakes_scale(float(args.get("scale", 1.0)))


## **Restless country**: the tribes begin further down.
##
## A shift on the band the three are drawn from, so they all start lower and
## still differ from one another by as much — three neighbours, not one people in
## triplicate.
##
## Args: `{"shift": -14.0}`.
static func _tribe_standing_start(_run: RunState, args: Dictionary) -> void:
	Tribes.set_start_shift(float(args.get("shift", 0.0)))


## **Restless country**: their villages take more off the tiles they work.
##
## On what they gather and never on the map — the ground is the same ground the
## colony farms, and moving it would hand the PC richer tiles too.
##
## Args: `{"scale": 1.3}`.
static func _village_yield(_run: RunState, args: Dictionary) -> void:
	Village.set_gathers(float(args.get("scale", 1.0)))


## **Restless country**: their forces are more numerous.
##
## *Stronger, not merely grumpier* — which is what makes low standing genuinely
## dangerous and the richer agreements worth reaching for. On the share that
## marches, never on the one-party-per-village rule, which exists to stop the
## same men being counted twice.
##
## Args: `{"scale": 1.4}`.
static func _war_party_share(_run: RunState, args: Dictionary) -> void:
	Muster.set_party_scale(float(args.get("scale", 1.0)))


## **Restless country**: their trade agreements are richer.
##
## 🔒 **Volume, never the ratio.** `natives.md` §5 fixes that each side receives
## at fair value; a people who get more off their land can put more of it on the
## table and still keep the winter.
##
## Args: `{"scale": 0.6}`.
static func _native_reserve(_run: RunState, args: Dictionary) -> void:
	TradeAgreement.set_keeps_back(float(args.get("scale", 1.0)))


## **Distant colony**: correspondence takes an extra month each way.
##
## 🔒 **One knob for both directions** (#390, §4 — *an extra month **each
## way***). `OrderDriver` holds an Order for it going out and `Crossing` queues a
## composed letter coming back, and both read this. Two numbers would let a run
## exist in which the PC hears late and is obeyed promptly, which is a slow
## contact rather than a distant colony.
##
## 🔒 **And the inbound half is a queue, not a delay.** A held letter says
## what was true the month it was written, because `InboundLetter` is already a
## snapshot — the director decides the letter *and its values* at composition.
## A delay that re-read the state on arrival would give the PC timely news late,
## which is the opposite of distance.
##
## Args: `{"months": 1}`.
static func _post_crossing(_run: RunState, args: Dictionary) -> void:
	Crossing.set_months(int(args.get("months", 0)))


## **Distant colony**, the patience it buys: silence costs less.
##
## A man who knows his letter spent two months on a ship does not conclude he is
## being ignored the moment it goes unanswered. **He gives the ocean the benefit
## of the doubt** — and a quirk that made everything later without making anybody
## more forgiving would be a straight penalty rather than a different game.
##
## Args: `{"scale": 0.5}`.
static func _silence_cost(_run: RunState, args: Dictionary) -> void:
	Silence.set_cost_scale(float(args.get("scale", 1.0)))


## **Distant colony**, the other half of the patience: dampers run longer.
##
## A contact who knows the crossing takes months does not write again in three
## weeks, so **the desk is thinner** — which is §4's own compensation for
## everything arriving late: *you manage less and plan further.*
##
## Args: `{"months": 6}`.
static func _damper_months(_run: RunState, args: Dictionary) -> void:
	Pressure.set_damper_months(int(args.get("months", Pressure.CONTACT_MONTHS)))
