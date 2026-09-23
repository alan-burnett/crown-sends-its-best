class_name DiplomatMoveExecutor
extends IntentExecutor

## The Diplomat goes where he agreed to go (#393, `docs/mechanics/the-diplomat.md`
## §3, §7).
##
## `Diplomat.rehome` was written with #81 and **never called by anything but its
## tests**, so `diplomat.ask_to_move` charged the PC 240 gold for a move that did
## not happen: the promise settled, the gold left, and the Diplomat went on
## reporting from the town he had asked to leave.
##
## ## 🔒 An Order, and then his decision
##
## Nothing here decides whether he goes. The PC's letter became an Order
## addressed to **him**, compliance resolved it against his regard and his
## temperament, and this executes only what he agreed to — on the timing rule,
## so a move agreed in March happens in April, and a delayed one later (Seam B,
## `world-month.md` §3).
##
## ## 🔒 And it is how the PC sends him toward trouble
##
## §7: he can only cultivate the governor he lives with, and *"this gives the PC
## a reason to move him **toward** trouble instead."* The target is worked out
## from where he is each month (#285), so moving him is all it takes for the
## cultivation to follow — nothing here touches it.

const KIND: StringName = &"move_diplomat"

var colony: Colony = null
var contacts: Dictionary = {}


func handles(intent: Intent) -> bool:
	return intent.kind == KIND


func execute(intent: Intent, state: WorldState, log: EventLog) -> StringName:
	var him: Contact = contacts.get(String(intent.target))
	if him == null or him.is_dead:
		# **He died before he could go.** Not a stall: nothing could have carried
		# it out, and the letters about his death already say why.
		return Intent.OVERTAKEN_BY_EVENTS

	var to := town_named(colony, String(intent.data.get("town", "")))
	if to == null:
		# The town was lost while the letter crossed.
		return Intent.OVERTAKEN_BY_EVENTS
	if to.display_name == him.town:
		# Already there — the PC sent him where he already was, or events did.
		return Intent.OVERTAKEN_BY_EVENTS

	# A delayed answer is still an answer: he goes when the months are up.
	if not intent.advance():
		return Intent.IN_PROGRESS

	var context := ColonyContext.new(state, log, null, null)
	context.colony = colony
	Diplomat.rehome(him, to, context)
	return Intent.COMPLETED


## A town by its id or by the name a letter carries.
##
## **Letters carry names**, because a `town` param is what the player reads — so
## the executor has to accept one, and an id as well for anything that supplies
## the other.
static func town_named(in_colony: Colony, name: String) -> Town:
	if in_colony == null or name.is_empty():
		return null
	var by_id := in_colony.by_id(StringName(name))
	if by_id != null:
		return by_id
	for town in in_colony.in_order():
		if town.display_name == name:
			return town
	return null
