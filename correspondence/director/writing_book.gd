class_name WritingBook
extends RefCounted

## What each man has already said, and when (#256,
## `docs/mechanics/the-director.md` §6).
##
## Writing a letter sets **two dampers**, and both decay.
##
## | | Damps | Means |
## | :--- | :--- | :--- |
## | **Topic** | that concern alone | *I have said this* |
## | **Contact** | every concern he has | *I shall not pester the Crown* |
##
## ## 🔒 The topic damper is counted in writings, not in months
##
## The obvious failure is a clergyman alternating between the same two
## complaints for a year while never mentioning his other three.
##
## > **The topic damper should last about as long as it takes him to say
## > everything else he has to say.**
##
## So it is measured in **his own letters**, not in the calendar: a man with five
## concerns damps each for roughly five writings. **Rotation then falls out
## instead of being enforced**, and this book tracks no such thing as a topic he
## has "used" — only the writing at which he last raised it, which is a fact
## about the past rather than a plan for the future.
##
## ## 🔒 Per individual contact, never per role
##
## Ending a policy six churches cared about brings six letters, and that is
## correct. A damper that quieted a role would make the sixth church's outrage a
## consequence of the first church having already written, which is not how
## people work.

## One entry per man: how many letters he has sent, the month of the last, and
## the writing at which he last raised each concern.
var wrote: Dictionary = {}


func _entry(contact: StringName) -> Dictionary:
	return wrote.get(String(contact), {"count": 0, "month": -1, "topics": {}})


## How many letters this man has sent.
func writings_by(contact: StringName) -> int:
	return int(_entry(contact).get("count", 0))


## How long since he last troubled the Crown at all, or -1 if he never has.
func months_since(contact: StringName, month: int) -> int:
	var when := int(_entry(contact).get("month", -1))
	return -1 if when < 0 else maxi(0, month - when)


## How many letters he has written since he last raised this concern, or -1 if
## he never has.
##
## **His letters, not the calendar.** A man who has said nothing for a year has
## said nothing since, and the concern is as damped as the day he raised it — he
## has not worked through the rest of what he had to say.
func writings_since(contact: StringName, topic: String) -> int:
	var entry := _entry(contact)
	var topics: Dictionary = entry.get("topics", {})
	if not topics.has(topic):
		return -1
	return maxi(0, int(entry.get("count", 0)) - int(topics[topic]))


## He wrote, about this.
func record(contact: StringName, topic: String, month: int) -> void:
	var entry := _entry(contact)
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["month"] = month
	var topics: Dictionary = entry.get("topics", {}).duplicate()
	topics[topic] = int(entry["count"])
	entry["topics"] = topics
	wrote[String(contact)] = entry


## Contact ids, sorted. Never iterate `wrote` where the result depends on order.
func in_order() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray(wrote.keys())
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in in_order():
		out[String(id)] = wrote[id]
	return {"wrote": out}


static func from_dict(data: Dictionary) -> WritingBook:
	var book := WritingBook.new()
	book.wrote = data.get("wrote", {}).duplicate(true)
	return book
