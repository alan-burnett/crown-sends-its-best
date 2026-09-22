class_name PatronBook
extends RefCounted

## What has to be remembered about the patrons between months (#282,
## `docs/mechanics/patrons.md` §6, §7).
##
## 🔒 **Almost nothing.** Who a patron is — his specialty, his need, his vice —
## is a fact about the man and lives on the contact, exactly as his name does.
## What lives here is what only makes sense across time:
##
## | | |
## | :--- | :--- |
## | `arrived` | how many patrons the run has ever had, so numbers are never reused |
## | `heard` | where each man's regard stood when the court last heard from him |
##
## `heard` is what makes gossip a **movement** rather than a level. A patron who
## is merely low is a patron the court has already heard about, and he must not
## go on costing the PC every month for the same slight — so the comparison is
## against the last time it was carried, not against a threshold.
##
## **And it is saved with the run.** Ironman means a corrupt save is a lost run
## (SPEC §16.2); a book kept on a driver would quietly reset the court's memory
## every time the game was loaded, and the next month's letter would repeat a
## slight the PC had already paid for.

## How many patrons have ever arrived. **Counts arrivals, not seats**, so the man
## who follows a departed patron is a different man at a different id.
var arrived: int = 0

## Contact id -> his regard when the court last heard from him.
var heard: Dictionary = {}


func has_heard_of(patron: StringName) -> bool:
	return heard.has(String(patron))


## How far this man has fallen since the court last heard, nought if he has risen
## or if this is the first the court knows of him.
##
## **Nought on a first sighting** rather than his whole distance from neutral: a
## patron who arrives out of sorts has not been slighted by anybody yet.
func fall_of(patron: Contact) -> float:
	if patron == null or patron.relationship == null:
		return 0.0
	if not has_heard_of(patron.id):
		return 0.0
	return maxf(0.0, float(heard[String(patron.id)]) - patron.relationship.loyalty)


## Note where a man stands now, so next month measures from here.
func note(patron: Contact) -> void:
	if patron == null or patron.relationship == null:
		return
	heard[String(patron.id)] = patron.relationship.loyalty


## The id the next patron to arrive goes by.
func next_id() -> StringName:
	arrived += 1
	return Patron.id_for(arrived)


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray(heard.keys())
	ids.sort()  # Ordered, so the same run writes the same save.
	for id in ids:
		out[String(id)] = float(heard[String(id)])
	return {"arrived": arrived, "heard": out}


static func from_dict(data: Dictionary) -> PatronBook:
	var book := PatronBook.new()
	book.arrived = int(data.get("arrived", 0))
	for id in data.get("heard", {}):
		book.heard[String(id)] = float(data["heard"][id])
	return book
