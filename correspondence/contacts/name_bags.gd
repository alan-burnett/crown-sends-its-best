class_name NameBags
extends RefCounted

## Where a generated name comes from (#304, `docs/mechanics/names.md` §3, §5, §6).
##
## ## 🔒 A bag is a register, and roles map onto it
##
## **Not one bag per role.** Several roles draw from one, and two of them do:
##
## | Bag | Drawn by |
## | :--- | :--- |
## | `aristocrats` | patrons, **Crown commanders** |
## | `colonists` | governors, **colony commanders**, the institutional contacts |
## | `towns` | towns |
##
## **A company is given to the same sort of man either way.** The Marshal's
## commander comes from the pool a patron comes from; a colonial company goes to
## one of the well-to-do colonists a governor comes from. Simpler than a bag each
## and truer than a bag each.
##
## An earlier draft gave every role its own bag on the reasoning that a clergyman
## and a journalist should sound unalike. **They are both colonists**, and the
## register that matters is *aristocrat or colonist*, not what a man does for a
## living.
##
## ## 🔒 Given and family, drawn separately
##
## Twenty of each is four hundred men. **No titles in a bag** — the letterhead's
## first word is the role (§2), so there is nothing per-man to draw.
##
## That reverses an earlier draft which held whole names, because the rivals' bag
## would have mixed nations and parts drawn separately would eventually pair a
## French given name with a Spanish surname. **The Author then made rivals
## hardcoded**, which removed the only bag that mixed cultures and with it the
## whole argument. A role that needs particular men does what the rivals did and
## names them in data.
##
## ## 🔒 From the subject's own stream
##
## `hash(run_seed, contact_id)` for a man and the equivalent for a town, per
## `CLAUDE.md`. So the same seed gives the same men and the same towns **whatever
## else happens in the run**, and naming somebody never shifts another system's
## rolls: a town founded in month nine instead of month eight gets the same name.

const COLLECTION: String = "names"

const ARISTOCRATS: String = "aristocrats"
const COLONISTS: String = "colonists"
const TOWNS: String = "towns"

const ALL: PackedStringArray = [ARISTOCRATS, COLONISTS, TOWNS]

## 🔒 **Which bag each generating role draws from** (§3).
##
## A role absent here is not generated — the five Crown officers and the three
## rival dukes are hand-written and must stay byte-identical, and a rebel
## commander draws nothing because he was a colony commander who turned and keeps
## the name he already had.
const BY_ROLE: Dictionary = {
	Contact.ROLE_GOVERNOR: COLONISTS,
	Contact.ROLE_INSTITUTIONAL: COLONISTS,
	Contact.ROLE_PATRON: ARISTOCRATS,
}

static var _bags: Dictionary = {}


static func load_from(content: ContentDatabase) -> void:
	_bags = {}
	if content == null:
		return
	for id in content.ids(COLLECTION):
		_bags[String(id)] = content.record(COLLECTION, String(id)).duplicate(true)


## Names this run may not give to anybody, because something living already has
## one (#358, §5 *no two live things share a name*).
##
## 🔒 **The PC is the one thing in the game that is not generated**, so he is
## the one thing a bag cannot avoid on its own — a patron who happened to share
## his name would read as a mistake even though nothing was wrong. Everybody else
## is drawn from here and could in principle be checked against everybody else;
## this is the case that has to be told.
##
## It costs a set membership. Run-scoped, like everything else a run turns.
static var _struck: Dictionary = {}


static func reset() -> void:
	_bags = {}
	_struck = {}


## Take a name out of circulation for this run.
static func strike(name: String) -> void:
	var trimmed := name.strip_edges()
	if not trimmed.is_empty():
		_struck[trimmed] = true


static func is_struck(name: String) -> bool:
	return _struck.has(name.strip_edges())


static func has(bag: String) -> bool:
	return _bags.has(bag)


## The list a bag holds under a key, or empty.
static func entries(bag: String, key: String) -> Array:
	return (_bags.get(bag, {}) as Dictionary).get(key, [])


## Which bag a role draws from, or empty for a role that is not generated.
##
## 🔒 **A commander's bag depends on who raised him** (§3), which the role alone
## cannot say — a Crown commander is an aristocrat and a colony commander is a
## colonist. So he is asked for separately rather than listed above, and a role
## with no answer here is one nobody generates.
static func bag_for(role: StringName, crown: bool = false) -> String:
	if role == Contact.ROLE_COMMANDER:
		return ARISTOCRATS if crown else COLONISTS
	return String(BY_ROLE.get(role, ""))


## A man's name, drawn from his own stream.
##
## Given and family are two draws from one stream, **in that order**, so the same
## seed always assembles the same man.
static func person(bag: String, rng: RandomNumberGenerator) -> String:
	var given := entries(bag, "given")
	var family := entries(bag, "family")
	if given.is_empty() or family.is_empty() or rng == null:
		return ""
	# 🔒 **Two draws, always**, whatever is struck. Walking forward from the
	# drawn family name rather than drawing again is what `place` does and for the
	# same reason: a run that has struck a name must not consume a different number
	# of rolls than one that has not, or the PC typing his own name would change
	# who his patrons are.
	var first := String(given[rng.randi_range(0, given.size() - 1)])
	var at := rng.randi_range(0, family.size() - 1)
	for step in family.size():
		var whole := "%s %s" % [first, String(family[(at + step) % family.size()])]
		if not is_struck(whole):
			return whole
	# Every surname in the bag makes a struck name with this given one. Better a
	# repeat than a man with no name.
	return "%s %s" % [first, String(family[at])]


## A town's name, avoiding any the colony already uses.
##
## 🔒 **No two live things share a name** (§5), which is a redraw rather than a
## property the bags must guarantee. Walking forward from the drawn index rather
## than drawing again keeps it one draw, so a colony that has used half the bag
## does not consume a different number of rolls than one that has used none.
static func place(rng: RandomNumberGenerator, taken: PackedStringArray = PackedStringArray()) -> String:
	var names := entries(TOWNS, "names")
	if names.is_empty() or rng == null:
		return ""
	var at := rng.randi_range(0, names.size() - 1)
	for step in names.size():
		var name := String(names[(at + step) % names.size()])
		if not taken.has(name):
			return name
	# Every name in the bag is in use. Better a repeat than a town with none.
	return String(names[at])
