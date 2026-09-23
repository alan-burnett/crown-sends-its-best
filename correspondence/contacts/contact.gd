class_name Contact
extends DeliberationActor

## Somebody the PC writes to.
##
## Every contact has a name, portrait, role, personality and loyalty (SPEC §8).
## Personality affects both the **tone** of their letters and their
## **behaviour** — how they read vague orders, what they choose when left to
## decide, and whether they act on their own.
##
## Personality is inherited from `DeliberationActor`: it is a **weight vector
## over considerations**, not a tag with special-cased behaviour. No contact has
## bespoke behavioural code, which is what SPEC §8 requires when it says
## personality drives behaviour and not merely prose.
##
## Contacts come from two places. Crown Officers are **fixed in every run and
## never randomised** (SPEC §8.1), so they load from data. Colony contacts and
## patrons are **generated semi-randomly** per run (SPEC §8.2, §8.3) from that
## contact's own RNG stream, so the same seed yields the same person however
## late in the run he appears.

## Roles. A contact's role decides which purposes the player may write to him
## about (SPEC §9.4).
const ROLE_CROWN_OFFICER: StringName = &"crown_officer"
const ROLE_GOVERNOR: StringName = &"governor"
const ROLE_COMMANDER: StringName = &"commander"
const ROLE_PATRON: StringName = &"patron"
const ROLE_RIVAL: StringName = &"rival"
const ROLE_INSTITUTIONAL: StringName = &"institutional"

## **The PC's only resident eyes** (#81, SPEC §8.1). A role of his own because
## nothing else in the game is a Crown officer who lives in a town — he is
## prominent where he lives, and his regard governs what he tells rather than
## what he does.
const ROLE_DIPLOMAT: StringName = &"diplomat"

## 🔒 **Every role there is**, so a letter file can name one (#361).
##
## `Director.senders_of` reads a letter's `sender` as a contact id first and as a
## role second; this is what makes the second reading possible without the
## director keeping a list of its own that would drift from this one.
const ROLES: Array[StringName] = [
	ROLE_COMMANDER, ROLE_CROWN_OFFICER, ROLE_DIPLOMAT, ROLE_GOVERNOR,
	ROLE_INSTITUTIONAL, ROLE_PATRON, ROLE_RIVAL,
]


static func is_role(name: StringName) -> bool:
	return ROLES.has(name)

## Personality weights are drawn from this range. A weight of 1.0 is average
## interest in a consideration. Tuning: `docs/mechanics/deliberation.md` §9 flags
## how far weights should be allowed to spread before a contact reads as broken
## rather than characterful.
## What a man wants of a topic he has said nothing about: the best there is.
const WANTS_THE_BEST: float = 1.0

## How far apart two men of one role are in their readiness to write. Tuning.
const WRITES_READILY_MIN: float = 0.5
const WRITES_READILY_MAX: float = 1.5

const WEIGHT_MIN: float = 0.5
const WEIGHT_MAX: float = 1.6

## How large each kind of man looms in the town he lives in. Tuning.
##
## The Crown's officers sit at nothing deliberately — they are an ocean away and
## live in no town at all, so they never push anybody's sentiment however the
## rest of the model changes.
const PROMINENCE: Dictionary = {
	"governor": 1.0,
	"commander": 0.5,
	"institutional": 0.3,
	# **A resident Crown man, and the town knows it.** He looms smaller than the
	# governor and larger than a merchant: he dines with the quality and writes
	# home about them, and a town can see him doing it.
	"diplomat": 0.4,
	"patron": 0.0,
	"rival": 0.0,
	"crown_officer": 0.0,
}


static func prominence_of(role: StringName) -> float:
	return float(PROMINENCE.get(String(role), 0.0))


## How large this man looms where he lives.
func prominence() -> float:
	return prominence_override if prominence_override >= 0.0 else prominence_of(role)

## How much weight this man's opinion carries where he lives
## (`rebel-sentiment.md` §4).
##
## **Prominence, not office.** A town listens to the people it has heard of, so
## what a contact does to its rebel sentiment is scaled by how large he looms
## there rather than by which box his role falls in. The governor is the town's
## leader and its voice; a clergyman is listened to on a Sunday.
##
## It cuts both ways, which is the point: **if the famous men of a town are all
## loyal to the Crown there is not much rebel sentiment in it**, and the same
## men slighted are what carries the town out.
##
## **Derived from the role unless the data overrides it**, so it cannot be
## forgotten. A contact built any other way — a test fixture, a scenario — has
## the prominence his office implies without anyone remembering to set it, which
## is the failure this shape exists to prevent.
##
## A particular clergyman may be a firebrand, so the field can still say so.
var prominence_override: float = -1.0

var display_name: String = ""

## 🔒 **What follows his name on a letter** (#304, `names.md` §2), as a
## template with at most a `{town}` in it.
##
## **Mutable state on the contact, not a lookup on the role.** A commander is one
## role with three allegiances (`commanders.md` §1) and each names a different
## master — and a town commander whose town revolts becomes *of the independent
## nation*, the same object serving somebody else. A qualifier derived from his
## role would have to be recomputed by something that knew what a rebellion was;
## one he carries is rewritten by the thing that turned him.
##
## Defaulted from the role when he is created, so adding a role with a new
## qualifier needs no code here.
var qualifier: String = ""

## 🔒 **The one word that goes first** (#304, `names.md` §2), when the role
## alone cannot say it.
##
## Four offices share `crown_officer`, and §2 wants *Steward Corvyn Thrale* — so
## the word is a field, defaulted from the role, exactly as the qualifier is.
## Empty means take the role's.
var role_word: String = ""

## Flavour, like *Steward of the Revenue*.
##
## 🔒 **No letter reads this and the letterhead must not** (§2). The first word
## of a letterhead comes from the role, because it is there to be scanned.
var title: String = ""
var role: StringName = &""

## An id into the asset registry, never a path (SPEC §16.3).
var portrait_asset: String = ""

## Where this contact lives, for the `{sender:town}` slot (#9). Empty for the
## Crown officers, who are an ocean away.
var town: String = ""

## **Gone, and not replaced** (#81, SPEC §8.1). Only the Diplomat can die so far,
## and nobody will take his post — so this is not a slot to be refilled, it is a
## fact the letters and the run have to live with.
var is_dead: bool = false

## The month he is writing again, if he is at sea (#81, `the-diplomat.md` §3).
##
## **A real blackout.** Agreeing to move him costs the PC two months of not
## knowing, which is the price of agreeing and the reason refusing is a genuine
## option rather than a formality.
var travelling_until: int = -1

## Signed bias per topic, in `[-1, +1]`, applied in normalised space by the
## perception resolver (#10). The machinery is
## `docs/mechanics/perception.md`; this is only where a contact's values live.
var leans: Dictionary = {}

## Measure ids this contact cares about.
##
## "Whether the things they care about are going well" is **read from world
## state and the diff when it is needed**, not cached here, so it can never go
## stale against the sim. This holds the "what they care about" half; the
## "going well" half belongs to the measure registry (#10).
var cares_about: PackedStringArray = PackedStringArray()

## **How his bias varies with how bad things are** (#279, `perception.md`).
##
## Flat for almost everybody — the same lean wherever the truth sits. The
## journalist is `alarmed`, steep where there is little wrong; the Marshal is his
## mirror. It is a property of the man rather than of the topic, because it is a
## fact about how he reads the world and not about what he is reading.
var lean_shape: StringName = Perception.SHAPE_FLAT

## **What he would be content with**, per topic he cares about (#254).
##
## Normalised like the measure itself, so `0.2` means *he wants the war nearly
## over* and `1.0` means *as good as it gets*. Absent means the latter, which is
## true of nearly everybody: a governor wants his people fed and there is no
## level of fed he would call too much.
##
## 🔒 **Not a second list of concerns.** The concerns are `cares_about`; this is
## a property of one he already has, and a topic here that he does not care about
## is read by nothing.
var wants: Dictionary = {}

## **What kind of manner moves him** (#260, `tone.md` §5): vanity, mettle, pity.
##
## Kept beside the weights rather than folded into them, because the three are
## what a save carries and what a reader asks about — the weights they set are
## derived, and `Temperament` is the only thing that derives them. A man is
## *proud*; the numbers on `annoyed`, `hateful` and `harshness` are how that
## shows up in a kernel.
var traits: Dictionary = {}

## **How readily he reaches for a pen** (#255, `the-director.md` §4).
##
## Not how strongly he feels — pressure is the world's business. This is the man
## who writes about a thing his neighbour would have let go, which is most of why
## two clergymen in two runs feel different. Around one; above it he is
## importunate and below it he keeps his own counsel.
var writes_readily: float = 1.0

## 🔒 **The one tone this contact ever writes in**, or empty for everybody who
## writes as §9.1 says (#268, `endings.md` §3).
##
## Authored in `data/contacts/`, because it is a fact about a person and not a
## branch about an id. Exactly one contact has it: **the Chancellor writes
## `pleased` about ruin.** His loyalty begins very low and he cherishes giving
## the PC news of his failures, so gilded leaves and the warmest possible
## phrasing over the worst possible content is not a bug in his tone — it is the
## joke the character exists to make.
##
## 🔒 **It is a fixed tone and not an inversion.** The five tones are **not
## ordered** (`CLAUDE.md`), so *the opposite of annoyed* is not a thing that
## exists; what §3 asks for is the warmest, and warmest is a value rather than a
## direction.
##
## A dev who "fixes" this to match the news has removed the joke.
var writes_in: StringName = &""

## The month he joined the correspondence.
##
## 🔒 **Redundancy ranks by arrival** (#255). The man who was already writing
## keeps his low bar; ranking by id would let a governor founded in year six
## whose name sorts early quietly raise the threshold of one who has been writing
## since month one.
var known_since: int = 0

## 🔒 **What he can supply, and what he wants** (#282, `patrons.md` §2, §3).
##
## Empty on everybody else, and that is the honest shape: SPEC §8.3 makes a
## patron a contact with three things rolled at arrival, and two of them are
## facts about the man in the same way his name is. `Patron` does the rolling and
## `PatronVices` reads the third; nothing here knows what a specialty is for.
##
## 🔒 **Never equal**, guaranteed by the draw rather than by a check — the need
## is taken from the catalogue with the specialty removed.
var specialty: String = ""
var need: String = ""

## 🔒 **What makes him difficult** (#282, `patrons.md` §6).
##
## **Vice, not personality.** `contacts.md` §1 reserves *personality* for the
## weight vector above, which a patron has like everybody else. This is a named
## bundle of mechanical behaviour on top of it, and the two words must not merge.
var vice: StringName = &""

## The month a patron goes home, or `-1` while he has not settled on one (#283,
## `patrons.md` §8).
##
## 🔒 **Hidden, and drawn once.** Every patron stays at least two years; at that
## mark he privately decides how much longer he wants — anything from nothing to
## two further years — and **the PC is told none of it.** At two years a man may
## have a month left or another two, so there is no planning for it, only the six
## months once they start.
##
## Nought on everybody who is not a patron, and `Contact` carries it rather than
## a book because it saves and loads with him and departs with him.
var leaves_month: int = -1

var relationship: Relationship = null


func _init(p_id: StringName = &"", p_weights: Dictionary = {}) -> void:
	super(p_id, p_weights)
	relationship = Relationship.new(p_id)


## What this man thinks of the Crown, including whatever somebody is buying on
## the PC's behalf (#285).
##
## 🔒 **One accessor, so the cultivated term reaches every reader** — compliance,
## the director, rebel sentiment, his own letters. A bonus that only some of them
## knew about would be a governor who complied like a friend and wrote like a
## stranger.
func loyalty() -> float:
	return clampf(
		relationship.loyalty + relationship.cultivated,
		Relationship.MIN_LOYALTY, Relationship.MAX_LOYALTY)


func lean_for(topic: String) -> float:
	return clampf(float(leans.get(topic, 0.0)), -1.0, 1.0)


## What he would be content with, on a topic he cares about (#254).
##
## **The best there is, unless he has said otherwise.** A governor wants his
## people fed and there is no level of fed he would call too much; the Marshal
## wants his war over, and says so.
func want_for(topic: String) -> float:
	return clampf(float(wants.get(topic, WANTS_THE_BEST)), 0.0, 1.0)


# --- Construction ----------------------------------------------------------

## A fixed contact, from a data file. Crown Officers take this path, so adding
## the Provost and the Diplomat later is a new data file and no new code.
static func from_data(record: Dictionary) -> Contact:
	var contact := Contact.new(StringName(record.get("id", "")), record.get("weights", {}))
	contact.display_name = String(record.get("name", ""))
	contact.title = String(record.get("title", ""))
	contact.role = StringName(record.get("role", ""))
	# **After the role**, which is what it defaults from. Read first it silently
	# took the empty role's qualifier, and the Diplomat's letterhead lost its town.
	contact.qualifier = String(record.get("qualifier", Letterhead.qualifier_for(contact.role)))
	contact.role_word = String(record.get("role_word", ""))
	contact.prominence_override = float(record.get("prominence", -1.0))
	contact.portrait_asset = String(record.get("portrait", ""))
	contact.town = String(record.get("town", ""))
	contact.is_dead = bool(record.get("is_dead", false))
	contact.travelling_until = int(record.get("travelling_until", -1))
	contact.leans = record.get("leans", {}).duplicate()
	contact.cares_about = PackedStringArray(record.get("cares_about", []))
	contact.lean_shape = StringName(record.get("lean_shape", Perception.SHAPE_FLAT))
	# **Authored for a named character**, filled in at the middle for anyone the
	# data is silent about — a contact with no temperament at all would be one
	# the tone considerations could never distinguish.
	contact.wants = record.get("wants", {}).duplicate()
	contact.traits = Temperament.from_record(record.get("traits", {}))
	Temperament.write_into(contact.traits, contact)
	contact.writes_readily = float(record.get("writes_readily", 1.0))
	contact.writes_in = StringName(record.get("writes_in", ""))
	contact.specialty = String(record.get("specialty", ""))
	contact.need = String(record.get("need", ""))
	contact.vice = StringName(record.get("vice", ""))
	contact.leaves_month = int(record.get("leaves_month", -1))
	contact.known_since = int(record.get("known_since", 0))
	contact.relationship = Relationship.new(
		contact.id,
		float(record.get("loyalty", Relationship.NEUTRAL_LOYALTY)),
	)
	return contact


## A semi-random contact, from its own stream.
##
## Drawn from `streams.contact_stream(id)` rather than a shared stream, so the
## same seed produces the same person regardless of how many contacts were
## created before him or in what order.
static func generate(
	id: StringName,
	role: StringName,
	streams: RngStreams,
	consideration_ids: PackedStringArray,
	starting_loyalty: float = Relationship.NEUTRAL_LOYALTY,
) -> Contact:
	var rng := streams.contact_stream(String(id))
	var weights: Dictionary = {}
	# Sorted, so the draws are consumed in a fixed order and the same seed gives
	# the same personality however the caller assembled the list.
	var sorted_ids := consideration_ids.duplicate()
	sorted_ids.sort()
	for consideration_id in sorted_ids:
		weights[consideration_id] = rng.randf_range(WEIGHT_MIN, WEIGHT_MAX)

	var contact := Contact.new(id, weights)
	contact.role = role
	contact.qualifier = Letterhead.qualifier_for(role)
	# 🔒 **His name comes from his own stream** (#304, `names.md` §5), and
	# **before the weights above are drawn** would be wrong — it is drawn here so
	# that adding a name does not shift a personality that was rolled first, and
	# the same seed keeps giving the same men.
	var bag := NameBags.bag_for(role)
	if not bag.is_empty():
		var drawn := NameBags.person(bag, rng)
		if not drawn.is_empty():
			contact.display_name = drawn
	# 🔒 **After the ordinary draw.** Harshness is among the considerations rolled
	# above, and a mettle written first would be rolled over — the trait would
	# then decide nothing and every man would take being leaned on the same way.
	contact.traits = Temperament.draw(rng)
	Temperament.write_into(contact.traits, contact)
	contact.writes_readily = rng.randf_range(WRITES_READILY_MIN, WRITES_READILY_MAX)
	contact.relationship = Relationship.new(id, starting_loyalty)
	return contact


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"weights": weights.duplicate(),
		"name": display_name,
		"qualifier": qualifier,
		"role_word": role_word,
		"title": title,
		"role": String(role),
		"prominence": prominence_override,
		"portrait": portrait_asset,
		"town": town,
		"is_dead": is_dead,
		"travelling_until": travelling_until,
		"leans": leans.duplicate(),
		"cares_about": cares_about.duplicate(),
		"lean_shape": String(lean_shape),
		"wants": wants.duplicate(),
		"traits": traits.duplicate(),
		"writes_readily": writes_readily,
		"specialty": specialty,
		"need": need,
		"vice": String(vice),
		"leaves_month": leaves_month,
		"known_since": known_since,
		"relationship": relationship.to_dict(),
	}


static func from_dict(data: Dictionary) -> Contact:
	var contact := Contact.from_data(data)
	contact.relationship = Relationship.from_dict(data.get("relationship", {}))
	return contact
