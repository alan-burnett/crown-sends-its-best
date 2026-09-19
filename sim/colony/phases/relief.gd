class_name ReliefPhase
extends ColonyPhase

## **Relief.** Towns holding more than their reserve give to towns in deficit,
## free and expecting nothing in return (SPEC §11.3).
##
## ## What relief is
##
## Not trade. Nothing is paid, nothing is owed, no gold moves. A town with grain
## to spare sends it to a town without, because they are one colony and the
## Crown is three months away. Transfers are **instant and lossless** — the
## colony is small enough that carting is not a system.
##
## ## The rules that are locked
##
## - **Worst-first.** The town in the deepest trouble is served before the town
##   that is merely short (SPEC §11.3).
## - **Needs before wants.** Every need in the colony is covered before one
##   town's objective gets a plank. A town half-built is not an emergency.
## - **Never luxuries.** Rum is not relief. A town short of rum is not in
##   distress, and a town sending its rum away has not helped anybody.
##
## ## Why it is one calculation and not one per town
##
## Relief is a matching problem across the whole colony: who is short, who has
## spare, who gets served first. Solved once, from the snapshot, on the first
## town of the phase. Solving it again for each town would have the second town
## re-fill a deficit the first had already filled.
##
## ## The resentment accumulator
##
## **A town that repeatedly gives more than it receives resents the Crown for
## its mismanagement** (SPEC §12.3). Generosity is not free politically even when
## it is free materially. Each transfer moves `relief_balance` on both towns,
## valued at Crown prices so that a cart of grain and a cart of iron are not the
## same favour. M3 reads it into rebel sentiment; it has to have been
## accumulating before then or the rebellion arrives from nowhere.
##
## ## One town
##
## M2 ships one town, so this moves nothing and **emits nothing**. A phase that
## announced "relief complete, nothing given" every month would be a line in the
## log that reads as a finding when it is really an absence.

const EVENT_GIVEN: StringName = &"relief_given"
const EVENT_SUMMARY: StringName = &"relief_summary"

## Transfers smaller than this are noise.
const EPSILON: float = 0.001


func run(_town: Town, before: ColonySnapshot, context: ColonyContext) -> void:
	if not claim_month(context):
		return

	# **Needs, then wants**, each pass worst-first. The second pass spends only
	# what the first left behind, which is what makes the ordering locked rather
	# than merely usual.
	var available := _spare_by_town(before, context)
	var transfers: Array = []
	_serve(_deficits(context, true), available, transfers, context)
	_serve(_deficits(context, false), available, transfers, context)

	if transfers.is_empty():
		return

	var given: Dictionary = {}
	for transfer in transfers:
		given[String(transfer["to"])] = float(given.get(String(transfer["to"]), 0.0)) + float(transfer["value"])

	context.log.emit(EVENT_SUMMARY, &"colony", context.state.month, {
		"transfers": transfers.size(),
		"relieved": given.keys().size(),
	}, WorldPhase.COLONY_MONTH)


## Every town's spare, by town and resource, as the phase began.
##
## **Luxuries are dropped here** rather than checked at each transfer, so there
## is no path through this phase that can move one.
func _spare_by_town(before: ColonySnapshot, context: ColonyContext) -> Dictionary:
	var out: Dictionary = {}
	for id in before.ids():
		var reckoning: Reckoning = context.reckonings.get(id)
		if reckoning == null:
			continue
		var spare: Dictionary = {}
		for resource in reckoning.spare:
			if ResourceCatalogue.is_luxury(StringName(resource)):
				continue
			var amount := float(reckoning.spare[resource])
			if amount > EPSILON:
				spare[resource] = amount
		out[id] = spare
	return out


## Who is short of what, worst first.
##
## Ties break on town id then resource name, so the order is the colony's rather
## than the dictionary's — two runs of the same seed serve the same town first.
func _deficits(context: ColonyContext, needs: bool) -> Array:
	var entries: Array = []
	var ids: PackedStringArray = PackedStringArray(context.reckonings.keys())
	ids.sort()
	for id in ids:
		var reckoning: Reckoning = context.reckonings[id]
		var source: Dictionary = reckoning.shortfall if needs else reckoning.wants
		for resource in source:
			if ResourceCatalogue.is_luxury(StringName(resource)):
				continue
			var amount := float(source[resource])
			if amount > EPSILON:
				entries.append({"town": id, "resource": String(resource), "amount": amount})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["amount"]), float(b["amount"])):
			return float(a["amount"]) > float(b["amount"])
		if String(a["town"]) != String(b["town"]):
			return String(a["town"]) < String(b["town"])
		return String(a["resource"]) < String(b["resource"]))
	return entries


func _serve(deficits: Array, available: Dictionary, transfers: Array, context: ColonyContext) -> void:
	var colony := context.colony
	if colony == null:
		return

	for deficit in deficits:
		var receiver := colony.by_id(StringName(deficit["town"]))
		if receiver == null:
			continue
		var resource := StringName(deficit["resource"])
		var wanted := float(deficit["amount"])

		# Givers in id order. Which town gives is not a judgement the colony
		# makes — only how much is left after it has kept its own reserve.
		var giver_ids: PackedStringArray = PackedStringArray(available.keys())
		giver_ids.sort()
		for giver_id in giver_ids:
			if wanted <= EPSILON:
				break
			if giver_id == String(receiver.id):
				continue
			var spare: Dictionary = available[giver_id]
			var on_hand := float(spare.get(String(resource), 0.0))
			if on_hand <= EPSILON:
				continue
			var giver := colony.by_id(StringName(giver_id))
			if giver == null:
				continue

			var moved := giver.take(resource, minf(on_hand, wanted))
			if moved <= EPSILON:
				continue
			receiver.store(resource, moved)
			spare[String(resource)] = on_hand - moved
			wanted -= moved

			# Valued, not counted. Ten head of cattle is a larger favour than
			# ten bushels of grain and the resentment should know it.
			var value := moved * ResourceCatalogue.price_of(resource)
			giver.relief_balance += value
			receiver.relief_balance -= value

			transfers.append({"from": giver_id, "to": String(receiver.id), "value": value})
			context.log.emit(EVENT_GIVEN, StringName(giver_id), context.state.month, {
				"from": giver_id,
				"to": String(receiver.id),
				"resource": String(resource),
				"amount": moved,
				"value": value,
				"for_need": context.reckonings[String(receiver.id)].shortfall_of(resource) > 0.0,
			}, WorldPhase.COLONY_MONTH)
