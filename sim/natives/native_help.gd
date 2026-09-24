class_name NativeHelp
extends RefCounted

## What high standing brings (#207, SPEC §12.5, §12.6;
## `docs/mechanics/natives.md` §6).
##
## ## 🔒 Their people join, and afterwards they are colonists
##
## A tribe on good terms adds its own population to a town and to an expedition
## passing through. **Contributed population is ordinary population**: there is
## no field on `Town` recording where a man came from and nothing anywhere that
## could tell one of these apart afterwards. The event names the tribe so the
## letters can say who helped; the town itself does not know.
##
## ## 🔒 The cheapest population in the game
##
## This makes trust a **third source of growth**, alongside immigration and
## birth, and the only one that does not answer to the Crown.
##
## `immigration.md` §9 makes growth expensive: settlers the PC asked for move
## `net_position`, and that costs him standing and prestige. **Nothing here
## touches the Crown's books.** There is no path from this file to
## `CrownAccounts`, so a frontier town fed by its neighbours grows for free — and
## the people paying for it are the ones the colony is displacing.
##
## ## What each band buys
##
## Population first and gifts later, because a people will send their sons to
## live in a town some way before they will send their stores.

const EVENT_JOINED: StringName = &"natives_joined"
const EVENT_GAVE: StringName = &"natives_gave"
const EVENT_EXPERT: StringName = &"natives_sent_a_teacher"

## Where a people begin sending their own to live among colonists. Tuning.
const JOIN_ABOVE: float = 62.0

## And where they begin sending what they have and who they have. **Higher than
## population**, per the ticket. Tuning.
const GIVE_ABOVE: float = 74.0

## How fast they come, per month, at the very top of the scale. Tuning.
const JOIN_AT_BEST: float = 500.0

## What share of a village's spare stores they will part with as a gift, per
## month, at the very top. Tuning.
const GIFT_SHARE: float = 0.06

## Scholars a month at the very top. They send someone who knows the country.
const TEACHERS_AT_BEST: float = 0.02


## How readily this people help, nought to one.
##
## Zero below the band and rising across what is left of the scale, so a tribe
## that has just crossed the line sends almost nobody and one that thinks well of
## the colony sends a steady few.
static func warmth(tribe: Tribe, above: float) -> float:
	if tribe == null or tribe.is_irreconcilable_with(Tribe.COLONY):
		return 0.0
	# **The clamp is the threshold**, rather than a guard above it saying the
	# same thing. A people below the band come out negative and clamp to nought,
	# and a separate `if` would be a rule nobody would notice had stopped working
	# — which is how the coastal filter in #180 spent a milestone doing nothing.
	return clampf((tribe.trust() - above) / maxf(1.0, Tribe.MAXIMUM - above), 0.0, 1.0)


## A month of their people coming to live in a town (Seam A).
##
## 🔒 **One at a time** (`CLAUDE.md`). No single event moves a town by more than
## one population, so each arrival is its own event and the Diplomat's death roll,
## quality of life and the letters all see them the way they see everybody else.
static func join(
	tribe: Tribe,
	village: Village,
	town: Town,
	context: ColonyContext,
) -> int:
	if tribe == null or village == null or town == null:
		return 0
	var eagerness := warmth(tribe, JOIN_ABOVE)
	if eagerness <= 0.0:
		return 0

	# 🔒 **Their own remainder** (`Town.native_arrivals_accrued`). Sharing
	# immigration's pool meant a colony attractive enough to draw settlers spent
	# this fraction on them, and the neighbours who actually walked in were logged
	# as passengers off a ship.
	# **Whole people, the fraction carried** (#426): hundreds a month now, in one
	# event that says how many.
	town.native_arrivals_accrued += JOIN_AT_BEST * eagerness
	var joining := mini(int(floorf(town.native_arrivals_accrued)), maxi(0, village.people - 1))
	if joining <= 0:
		return 0
	town.native_arrivals_accrued -= float(joining)
	town.workers += joining
	# **And the village is that many fewer**, because these are their people and
	# not a fountain. A tribe that empties itself into a colony is a tribe the
	# colony has absorbed, which is a different thing from a tribe that likes it.
	village.people = maxi(1, village.people - joining)

	context.log.emit(EVENT_JOINED, town.id, context.state.month, {
		"tribe": String(tribe.id),
		"town": String(town.id),
		"village": String(village.id),
		"people": joining,
	}, WorldPhase.ARRIVALS)
	return joining


## And a month of them joining an expedition crossing their country (Seam A).
##
## The same rule, for a party in the field. A frontier that survives at all may
## survive because the people already living there decided it should.
static func join_party(
	tribe: Tribe,
	village: Village,
	party: ExpeditionParty,
	context: ColonyContext,
) -> int:
	if tribe == null or village == null or party == null:
		return 0
	if warmth(tribe, JOIN_ABOVE) <= 0.0 or village.people <= 1:
		return 0
	# **A party is a handful of people walking**, so a guide who throws in with
	# them is a whole person immediately rather than a fraction accrued over
	# months they do not have.
	# The chance is as it was; what joins is what one used to be (#426).
	if context.streams.stream("sim").randf() \
			> JOIN_AT_BEST / float(Population.THOUSAND) * warmth(tribe, JOIN_ABOVE):
		return 0

	var joining := mini(Population.THOUSAND, village.people - 1)
	if joining <= 0:
		return 0
	party.people += joining
	village.people = maxi(1, village.people - joining)
	context.log.emit(EVENT_JOINED, party.id, context.state.month, {
		"tribe": String(tribe.id),
		"expedition": String(party.id),
		"people": joining,
	}, WorldPhase.ARRIVALS)
	return joining


## A month of gifts: what they have, and who they have (Seam A).
##
## 🔒 **Gated higher than population** (§6). A people will send their sons to
## live in a town some way before they will send their winter stores to it.
static func gifts(
	tribe: Tribe,
	village: Village,
	town: Town,
	context: ColonyContext,
) -> Dictionary:
	var given: Dictionary = {}
	if tribe == null or village == null or town == null:
		return given
	var generosity := warmth(tribe, GIVE_ABOVE)
	if generosity <= 0.0:
		return given

	# Resources, out of what the village genuinely has spare — the same measure
	# a trade agreement uses, so a gift and a bargain cannot disagree about what
	# a village can afford to part with.
	var offering: Array = village.stores.keys()
	offering.sort()
	for id in offering:
		var resource := StringName(id)
		var spare := TradeConsiderations.spare_in(village, resource)
		var amount := spare * GIFT_SHARE * generosity
		if amount <= 0.01:
			continue
		village.stores[String(resource)] = float(village.stores[String(resource)]) - amount
		town.store(resource, amount)
		given[String(resource)] = amount

	if not given.is_empty():
		context.log.emit(EVENT_GAVE, town.id, context.state.month, {
			"tribe": String(tribe.id),
			"town": String(town.id),
			"given": given.duplicate(),
		}, WorldPhase.ARRIVALS)

	# And someone who knows the country. **Through `Experts`**, so a man the
	# natives sent and a man a library raised are the same man arriving by two
	# roads — and are indistinguishable once he is here.
	Experts.accrue(town, TEACHERS_AT_BEST * generosity)
	return given


## 🔒 **Troops are M6** (SPEC §12.6; `natives.md` §6).
##
## §12.6 already permits it — *colonial forces can be supplemented by friendly
## natives* — and there is nothing yet for them to supplement, because a company
## is #214. This answers nought, deliberately and out loud, because a hook that
## quietly did nothing would be indistinguishable from one nobody wired up.
##
## When M6 arrives this is the one function that has to learn about companies.
static func troops(_tribe: Tribe, _town: Town) -> int:
	return 0
