class_name IntentConsiderations
extends RefCounted

## What a governor weighs when he decides what his town is for (#53, #428,
## `docs/mechanics/governor-agendas.md` §13).
##
## 🔒 **A table, and the table is data.** Each row measures **how much of a
## problem** one thing is in his town, nought to one — nought is no problem, and
## then the row does nothing. Its score for an intent is that measure times the
## cell `data/colony/agendas.json` gives it: *when this is at its worst in my
## town, how strongly does it push me toward this intent?* The Author sets the
## cells; no row has a `match` on intents.
##
## The governor's personality is the weight vector over the rows, so a cautious
## man and a greedy man read the same town and want different things — with **no
## code per personality**. The mandate and the urging are not rows: each pulls
## toward one named intent.
##
## Written as named subclasses rather than lambdas: a `Callable` living in a
## static registry segfaults Godot 4.7 on shutdown (CLAUDE.md).

## **Always one.** What an untroubled town wants: tall and rich serve towns
## without problems, and in a town with none every other row reads nought.
const BASELINE: StringName = &"baseline"
## Hunger: how far below four months of food the town holds.
const FOOD: StringName = &"food_security"
## How badly the town is living.
const COMFORT: StringName = &"quality_of_life"
## How far the town's wealth per thousand people falls short of comfortable.
const WEALTH: StringName = &"wealth"
## How unsafe the town is, from any foe.
const SAFETY: StringName = &"safety"
## Unclaimed land the colony can see — **the one row that is an opportunity, not
## a problem.**
const ROOM: StringName = &"room_to_grow"

## **Too many mouths for the ground the town can work** (#175): people per tile
## of land, against 2,000 comfortable.
##
## Deliberately a *second* row rather than a term folded into `room_to_grow`,
## because personality is a weight vector: two rows give two weights and
## therefore two kinds of governor — **the ambitious man who settles because
## there is land, and the pragmatic one who settles because there are too many
## mouths.**
const CROWDING: StringName = &"crowding"

## **How far the governor's loyalty has fallen**: nought at neutral or above, one
## at rock bottom.
const LOYALTY: StringName = &"loyalty"

const MANDATE: StringName = &"mandate"
const URGING: StringName = &"crown_urging"

## The rows of the table, in the order `governor-agendas.md` §13 lists them.
const TABLE_ROWS: Array[StringName] = [
	BASELINE, FOOD, COMFORT, WEALTH, SAFETY, ROOM, CROWDING, LOYALTY,
]

## Consideration ids this system introduces, sorted. `Governor` gives each new
## governor a weight for every one of them.
const ALL: PackedStringArray = [
	"baseline", "crowding", "crown_urging", "food_security", "loyalty", "mandate",
	"quality_of_life", "room_to_grow", "safety", "wealth",
]

## Where the loyalty row reads nought: neutral, and anything above it.
const LOYALTY_NEUTRAL: float = 50.0

## 🔒 **Comfortable wealth: sixty gold per weighted thousand** (§13, a
## placeholder: twice the purse quality of life calls comfortable).
const COMFORTABLE_WEALTH: float = 60.0

## The Author's cells, row -> intent -> push. Loaded from `agendas.json`.
static var _table: Dictionary = {}


static func load_table(record: Dictionary) -> void:
	_table = {}
	var rows: Variant = record.get("considerations", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return
	for row in rows:
		var cells: Variant = rows[row]
		if typeof(cells) == TYPE_DICTIONARY:
			_table[String(row)] = (cells as Dictionary).duplicate()


## The table as loaded, for the validator.
static func table() -> Dictionary:
	return _table


## How strongly this row, at its worst, pushes toward this intent. Nought where
## the table says nothing.
static func cell(row: StringName, intent: StringName) -> float:
	var cells: Dictionary = _table.get(String(row), {})
	return clampf(float(cells.get(String(intent), 0.0)), -1.0, 1.0)


## How long the Crown's Mandate keeps half its pull. SPEC §6.1 says "especially
## in the early game" and nothing more, so this is tuning.
const MANDATE_HALF_LIFE: float = 18.0

## How long the PC's last pronouncement keeps half its pull.
##
## **A letter is not a standing order** — a governor remembers it and it fades,
## and one urged this spring is running his own town again eighteen months later.
## That property is the point and is not up for negotiation.
##
## 🔒 **A year, and not six months** (#212). At six the PC re-sent the same
## instruction two or three times a year to hold a man on course, watched him
## drift back in between, and wondered why. **That is nagging, not ruling**, and
## it turned the game's central lever into an upkeep chore.
##
## Much longer would be wrong the other way: one letter setting a town's course
## for a decade is too strong for how little it costs to send.
const URGING_HALF_LIFE: float = 12.0

## 🔒 **How much the Crown's urging weighs** (#287, *Hard to say no to*).
##
## One in every run without the perk.
##
## **On the score rather than on the drawn weight**, because the first town's
## governor exists before a perk is applied — `RunState.new_run` makes him and
## `use_content` turns the knobs — so a scale at generation would miss the one
## governor every run has. Weight times score is one product either way.
##
## 🔒 **It never overrides him.** `crown_urging` is still weighed against
## every other consideration and his own reading of his town, so this **wins close
## arguments and loses hopeless ones**: the Crown's pressure, not the Crown's
## command. And because a fresh urging is already at the ceiling, what the perk
## really buys is that the letter is *still scoring* next spring when an
## ordinary one has faded.
static var _urging_weight: float = 1.0


static func urging_weight() -> float:
	return _urging_weight


static func set_urging_weight(weight: float) -> void:
	_urging_weight = maxf(0.0, weight)


static func reset_urging() -> void:
	_urging_weight = 1.0


## What the manner of the letter does to how hard it pulls, and for how long
## (#262, `docs/mechanics/tone.md` §4).
##
## ## 🔒 The axis is intensity, not warmth
##
## Pleased and annoyed both **lower** it; desperate and hateful both **raise**
## it. That is not accidental symmetry.
##
## A governor who reads a letter as *the Crown is truly angry we have not built
## the second town* **still remembers it next spring.** A letter that is flowery,
## or merely peevish, is easy to **roll your eyes at and get on with your own
## life** — the out-of-touch aristocrat being out of touch again.
##
## **Mild feeling reads as fussiness. Extreme feeling reads as meaning it.**
##
## ## 🔒 And hateful raising it is not a contradiction
##
## §4 has hateful pushing toward refusal *and* raising the urging. The two touch
## different moments: this is consulted only **if he complied.** He is less likely
## to take the order, and harder-driven when he does. *He did it because he was
## afraid, and he has not forgotten why.*
##
## One factor, applied to the weight and to the half-life alike, because the
## thing that varies is how much he took the letter to mean. A table per tone,
## never a scale — the five are not ordered, and pleased and annoyed differ here
## because flattery says nothing at all about how much the Crown wants a thing
## while peevishness at least says it is wanted.
##
## Desperate is the strongest: §6 has it pulling harder and for longer than any
## other tone, which is what the loyalty and the permanent prestige mark buy.
## Dutiful is one, being the plain register. All of it is tuning.
const URGING_INTENSITY: Dictionary = {
	Tone.PLEASED: 0.65,
	Tone.DUTIFUL: 1.0,
	Tone.ANNOYED: 0.8,
	Tone.DESPERATE: 1.5,
	Tone.HATEFUL: 1.3,
}


## How much a letter written in this manner was taken to mean.
##
## **One for anything unrecognised**, which is the plain register — a saved run
## from before the field existed, or an urging that came from nowhere in
## particular, must pull exactly as it always did.
static func intensity_of(tone: StringName) -> float:
	return float(URGING_INTENSITY.get(tone, 1.0))


## 🔒 **How much an author's urging counts, against the PC's** (#405).
##
## One for everybody, which is the PC's weight today and so changes nothing
## while only the PC urges. **Not decided here** — `governor-objectives.md` §4
## leaves it to the first act that urges on someone else's behalf, and this is
## the one place that act will change.
static func author_weight(_author: StringName) -> float:
	return 1.0

## Months of food at which a town stops thinking about food at all.
const COMFORTABLE_MONTHS: float = 4.0

static func register_all() -> void:
	var kinds: Array = [DecisionKind.GOVERNOR_INTENT]
	Deliberation.register_consideration(Baseline.new(), kinds)
	Deliberation.register_consideration(FoodSecurity.new(), kinds)
	Deliberation.register_consideration(Comfort.new(), kinds)
	Deliberation.register_consideration(Wealth.new(), kinds)
	Deliberation.register_consideration(Safety.new(), kinds)
	Deliberation.register_consideration(RoomToGrow.new(), kinds)
	Deliberation.register_consideration(Crowding.new(), kinds)
	Deliberation.register_consideration(Loyalty.new(), kinds)
	Deliberation.register_consideration(Mandate.new(), kinds)
	Deliberation.register_consideration(CrownUrging.new(), kinds)
	Deliberation.register_filter(OnlyIfHeLoathesYou.new(), kinds)
	Deliberation.register_filter(OnlyWhenLearningIsUrged.new(), kinds)


## Halve every `half_life` months. Used for both decaying pulls.
static func decayed(months: float, half_life: float) -> float:
	if half_life <= 0.0:
		return 0.0
	return pow(0.5, maxf(0.0, months) / half_life)


# --- The rows -----------------------------------------------------------------

## A row of the table: a measure, nought to one, times the Author's cell.
##
## @LOCK@ **No row ever pushes the other way on its own account.** A measure at
## nought scores nought for every intent; only the cell's sign says which way a
## problem pushes.
class TableRow extends Consideration:
	func score(actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var push := IntentConsiderations.cell(id, candidate.id)
		if is_zero_approx(push):
			return 0.0
		return clampf(measure(actor, context), 0.0, 1.0) * push

	## How much of a problem this is in his town, nought to one.
	func measure(_actor: DeliberationActor, _context: DeliberationContext) -> float:
		return 0.0


class Baseline extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.BASELINE)

	func measure(_actor: DeliberationActor, _context: DeliberationContext) -> float:
		return 1.0


## Hunger: how far below four months of food the town holds.
class FoodSecurity extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.FOOD)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		if town == null:
			return 0.0
		var monthly := town.mouths() * ColonyNeeds.per_head(&"food")
		var months_held := town.held(&"food") / maxf(0.001, monthly)
		return clampf(1.0 - months_held / IntentConsiderations.COMFORTABLE_MONTHS, 0.0, 1.0)


## How badly the town is living: Settle's quality of life, turned round.
class Comfort extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.COMFORT)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		return 0.0 if town == null else clampf(1.0 - town.quality_of_life, 0.0, 1.0)


## How far the town's own purse falls short of comfortable, per weighted
## thousand (§13). **Its gold only**: stores are not wealth.
class Wealth extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.WEALTH)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		return 0.0 if town == null else town.wealth_craving(IntentConsiderations.COMFORTABLE_WEALTH)


## How unsafe the town is, from any foe — natives, a duke, Crown troops. Read
## off the safety Settle stored, so the governor fears what his people fear.
class Safety extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.SAFETY)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		var town: Town = context.get_value("town")
		return 0.0 if town == null else clampf(1.0 - town.safety, 0.0, 1.0)


## The share of the land the colony has seen that no town has claimed.
class RoomToGrow extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.ROOM)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		return IntentConsiderations.room_in_the_colony(context)


## Too many mouths for the ground the town can work.
class Crowding extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.CROWDING)

	func measure(_actor: DeliberationActor, context: DeliberationContext) -> float:
		return IntentConsiderations.crowding_of(context)


## How far his loyalty has fallen: nought at neutral or above, one at nought.
class Loyalty extends TableRow:
	func _init() -> void:
		super(IntentConsiderations.LOYALTY)

	func measure(actor: DeliberationActor, _context: DeliberationContext) -> float:
		var contact := actor as Contact
		if contact == null:
			return 0.0
		return clampf(
			(IntentConsiderations.LOYALTY_NEUTRAL - contact.loyalty()) / IntentConsiderations.LOYALTY_NEUTRAL,
			0.0, 1.0)


## How many mouths there are for each tile the town can actually work.
##
## Shared with anything else that needs to ask, so "crowded" cannot come to mean
## two different things — the same reason `room_in_the_colony` is shared.
##
## Zero when the town has room to spare and climbing past one when it does not.
static func crowding_of(context: DeliberationContext) -> float:
	var town: Town = context.get_value("town")
	var territory: Territory = context.get_value("territory")
	var map: WorldMap = context.get_value("map")
	if town == null or territory == null or map == null:
		return 0.0

	# 🔒 **Land, not influence** (#321, `founding-towns.md` §2). The class above
	# has always said *against workable ground*; this counted every tile the town
	# held, **sea and ocean included**, and sea is not fields.
	#
	# It made the measure unreachable rather than merely generous. Influence grows
	# as `1 + population / 12` rings capped at four, so a town of thirty-six
	# already commands eighty-one tiles and every further person only lowers the
	# ratio — crowding stayed at exactly nought until about a hundred and sixty
	# people, which no town in a smoke run ever reached. It read `0.0000` across
	# 576 scorings.
	#
	# Counting land also makes the measure answer to the **map**: influence is the
	# same seventy-two tiles for every grown town, while the land inside it ran
	# from twenty-eight to forty-one across three seeds. A town on a spit is
	# crowded sooner than one on a plain, which is the whole idea.
	var ground := 0
	for at in territory.influence:
		if StringName(territory.influence[at]) != town.id:
			continue
		var terrain := Terrain.find(map.terrain_at(at.x, at.y))
		if terrain != null and terrain.land:
			ground += 1
	if ground <= 0:
		# Nowhere at all to work is as crowded as a town can be. A town whose
		# whole reach is water is exactly that, and one was: five tiles of
		# influence and not one of them land.
		#
		# **And it is the only thing standing between here and a NaN.** Dividing
		# by nought gives `inf`, which clamps to the same 1.0 and looks harmless
		# — but a town that has lost its last man as well as its last field
		# divides nought by nought, and `clampf(NaN)` is not 1.0. `balance.gd`
		# treats a NaN as a failed run, correctly, so this is the difference
		# between a crowded town and a batch reporting a broken seed.
		return 1.0

	var mouths_per_tile := float(town.population()) / float(ground)
	return clampf(
		(mouths_per_tile - COMFORTABLE_MOUTHS_PER_TILE) / COMFORTABLE_MOUTHS_PER_TILE,
		0.0, 1.0
	)


## How many people a tile of the town's own ground supports before it feels full.
##
## **The shared open item** between `founding-towns.md` §11 and
## `immigration.md` §10 — how crowded before a town starts shedding people — and
## it wants tuning against the two together rather than being settled here.
const COMFORTABLE_MOUTHS_PER_TILE: float = 2_000.0


## What the Crown appointed him to do (SPEC §6.1).
##
## **Its pull decays over the run.** Early on he is doing what he was sent to do;
## later he is doing what his circumstances demand. The decay lives in the score
## rather than in the actor's weight, so that a governor's personality — which is
## what `weights` means, and what the save stores — is not quietly rewritten
## month by month. His weight is how much he cares what the Crown wanted; this is
## how long ago they wanted it.
class Mandate extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.MANDATE)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		var mandate := StringName(context.get_value("mandate", ""))
		if String(mandate).is_empty():
			return 0.0
		var pull := IntentConsiderations.decayed(
			float(context.month), IntentConsiderations.MANDATE_HALF_LIFE
		)
		return pull if candidate.id == mandate else -pull * 0.25


## What the PC last told him the town was for.
##
## **This is the lever the whole game turns on.** The player cannot name a
## project; he can say what matters, and a governor who takes it to heart builds
## the granary himself, on a better tile than the player would have picked.
class CrownUrging extends Consideration:
	func _init() -> void:
		super(IntentConsiderations.URGING)

	func score(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> float:
		# 🔒 **Every live urging toward this candidate, whoever wrote it**
		# (#405). Two toward the same intent both count; urgings toward different
		# intents pull different ways and the kernel weighs them as it weighs
		# everything else.
		var urgings: Array = context.get_value("urgings", [])
		# 🔒 **Both knobs, from one factor, and the factor is the half-life**
		# (#262, §4). How hard it pulls and how long it lasts are the same question
		# — how much he took the letter to mean — and a letter read as the Crown
		# meaning it is one he is still thinking about next spring.
		#
		# **Not a multiplier on the pull as well.** A consideration scores in
		# `[-1, +1]`, so a fresh urging is already at the ceiling and multiplying
		# it is thrown away by the clamp — which looks like a second knob and is
		# nothing at all. The month the letter lands every urging is at full
		# strength, which is true; what differs is how fast it goes.
		#
		# Measured at any month after that, this is both: a desperate urging
		# scores higher than a dutiful one **and** is still scoring when the
		# dutiful one has gone.
		var pull := 0.0
		for entry in urgings:
			var urging: Urging = entry
			if urging.target != candidate.id:
				continue
			pull += urging.pull(context.month, IntentConsiderations.URGING_HALF_LIFE) \
				* IntentConsiderations.author_weight(urging.author)
		if pull <= 0.0:
			return 0.0
		# 🔒 **Clamped here, not left to the kernel's guard.** `scored()` treats a
		# score outside `[-1, +1]` as a bug and says so, which is right — a
		# consideration that shouts drowns out the weight vector and personality
		# stops meaning anything. So the perk cannot buy a louder letter than the
		# contract allows; what it buys is the tail.
		return minf(1.0, pull * IntentConsiderations.urging_weight())


# --- The filters ------------------------------------------------------------

## Loyalty at or below which a governor will consider turning his town.
##
## **A filter and not a weight** (`deliberation.md` §5). A weight can lose a
## close vote and then win one; this must be unreachable to a man who does not
## loathe the PC, however the rest of his temperament falls. It is also what
## makes recovery work: raise him back over the line and the candidate simply
## stops existing for him (`contacts.md` §8).
const SEDITION_AT: float = 12.0


class OnlyIfHeLoathesYou extends DeliberationFilter:
	func _init() -> void:
		super(&"only_if_he_loathes_you")

	func permits(actor: DeliberationActor, candidate: Candidate, _context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.SEDITION:
			return true
		var contact := actor as Contact
		return contact != null \
			and contact.loyalty() <= IntentConsiderations.SEDITION_AT


## 🔒 **Education only while the Provost or the scholar urges it** (§13).
##
## It has no cells, so without this it would score nought — and nought wins
## whenever every other intent totals below it. **Stands** means still pulling:
## at least an eighth of a fresh urging, three half-lives at its own strength.
## Past that the Provost's letter is a memory, not an argument.
class OnlyWhenLearningIsUrged extends DeliberationFilter:
	func _init() -> void:
		super(&"only_when_learning_is_urged")

	func permits(_actor: DeliberationActor, candidate: Candidate, context: DeliberationContext) -> bool:
		if candidate.id != GovernorIntent.EDUCATION:
			return true
		for entry in context.get_value("urgings", []):
			var urging: Urging = entry
			if urging.target != GovernorIntent.EDUCATION:
				continue
			if not GovernorIntent.EDUCATION_URGED_BY.has(urging.author):
				continue
			if urging.pull(context.month, IntentConsiderations.URGING_HALF_LIFE) \
					>= IntentConsiderations.LEARNING_STANDS:
				return true
		return false


## How much of a fresh urging toward learning must remain for it to stand.
const LEARNING_STANDS: float = 0.125


## The share of the land the colony **has seen** that no town has claimed
## (`governor-agendas.md` §13): scouting raises it by revealing land, founding
## lowers it by claiming land (#434). With no knowledge to hand, what is visible
## now stands in.
##
## Shared with anything else that asks, so "there is room" cannot come to mean
## two different things.
static func room_in_the_colony(context: DeliberationContext) -> float:
	var map: WorldMap = context.get_value("map")
	var territory: Territory = context.get_value("territory")
	var knowledge: MapKnowledge = context.get_value("knowledge")
	if map == null or territory == null:
		return 0.0

	var seen := 0
	var free := 0
	var looked_at: Array = knowledge.explored() if knowledge != null else territory.visible.keys()
	for at in looked_at:
		if not map.is_land(at.x, at.y):
			continue
		seen += 1
		if not territory.inside_border(at):
			free += 1
	if seen <= 0:
		return 0.0
	return clampf(float(free) / float(seen), 0.0, 1.0)
