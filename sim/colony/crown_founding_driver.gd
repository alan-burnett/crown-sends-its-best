class_name CrownFoundingDriver
extends RefCounted

## Crown-sent towns appearing, in **world month phase 1, Arrivals** (#180,
## `founding-towns.md` §3).
##
## Phase 1 because that is where everything crossing from the Crown lands, and a
## shipload of settlers with a granary in the hold is the same kind of thing as a
## shipload of settlers. **There is no map unit at any point** — the Crown
## managed the ships and the guards, which is exactly what the PC paid standing
## for.
##
## 🔒 And its governor **inherits from the man who proposed it** (#178), not from
## a parent town it never had. A patron the PC has treated well hands him a
## governor already inclined to listen; a Provost he has stiffed for two years
## hands him one who is not.

var colony: Colony = null
var map: WorldMap = null
var contacts: Dictionary = {}
var streams: RngStreams = null

## The proposals in hand. The same array the run and the executor share.
var foundings: Array = []


func on_phase(phase: StringName, state: WorldState, log: EventLog, p_streams: RngStreams) -> void:
	if phase != WorldPhase.ARRIVALS or colony == null or map == null:
		return

	var context := ColonyContext.new(state, log, p_streams, map)
	context.colony = colony
	context.contacts = contacts

	var pending: Array = []
	# Sorted, so two towns due in the same month arrive in a fixed order and the
	# coast is claimed by the same one every time.
	var due: Array = foundings.duplicate()
	due.sort_custom(func(a: CrownFounding, b: CrownFounding) -> bool:
		return String(a.id) < String(b.id))

	for entry in due:
		var founding: CrownFounding = entry
		if founding.abandoned:
			continue
		if not founding.is_due(state.month):
			pending.append(founding)
			continue

		var town := founding.arrive(colony, map, context)
		if town == null:
			# Nowhere on the coast to put them, which a crowded map can produce.
			# It waits rather than vanishing, because a town the PC paid for and
			# never saw would be a bug he could not tell from a bug.
			pending.append(founding)
			continue
		_give_it_a_governor(town, founding, p_streams)

	foundings.clear()
	for founding in pending:
		foundings.append(founding)


## 🔒 **Inherited from the proposing contact** (#178, §4). The same rule as a
## town-launched governor, asked of a different man.
func _give_it_a_governor(town: Town, founding: CrownFounding, p_streams: RngStreams) -> void:
	var party := ExpeditionParty.new()
	party.id = founding.id
	var elected := Governor.generate_for(
		party, contacts.get(String(founding.proposer)), p_streams)
	elected.town = town.display_name
	elected.title = "Governor of %s" % town.display_name
	town.governor_id = elected.id
	contacts[String(elected.id)] = elected
