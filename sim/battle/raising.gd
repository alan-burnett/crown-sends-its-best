class_name Raising
extends RefCounted

## A governor puts men under arms (#342, `docs/mechanics/battles.md` §1).
##
## **The expedition is the pattern.** `founding-towns.md` §7 already has a body of
## people leaving a town with a share of its stores, and `CLAUDE.md` already
## treats the two alike when they are attacked. Raising mirrors launching.
##
## ## 🔒 It is an objective, on the menu like every other
##
## A **scouting party** or a **big company** (#432, `governor-agendas.md` §6, §7),
## each where its intent's menu puts it and behind its own gate. That is how a
## governor **declines** to raise one because something else comes first — and
## the refusal is what makes raising one mean something.
##
## | | Size | Led by |
## | :--- | :--- | :--- |
## | **Scouting party** | a tenth of the town, sized for exploring | always a militia |
## | **Big company** | what the town can spare, above its worker floor | a commander, or a militia from a town of 5,000 or fewer |
##
## The figures are data (`data/colony/objectives.json`).
##
## ## What it takes with it
##
## | | |
## | :--- | :--- |
## | **Men** | from **workers**, never experts |
## | **Arms** | guns, tools and horses at §2's supply ratio, from the town's stores, **at launch** |
## | **Support** | the town that raised it (§3) |
##
## 🔒 **Workers, never experts.** `CLAUDE.md` holds that workers go before experts
## and that accumulated expertise is what a bad month cannot take. **A town does
## not send its smith to carry a musket.**
##
## 🔒 **And it takes its men at once.** `CLAUDE.md`'s one-population-at-a-time
## rule governs *hardship* — famine, shortage, a bad winter. Enlistment is a
## decision rather than a misfortune, so it is not that rule's business, and a
## company raised one man a month would never assemble.
##
## 🔒 **§2's lock still binds: a company never resupplies its arms.** What it
## carries out is what it has, so how well it is armed is settled in the month it
## is raised — which is exactly the point at which the PC's letter is a month old.

const EVENT_RAISED: StringName = &"company_raised_by_town"

## The company a caller means when it names none: sized by what the town can
## spare, as every company was before #432.
const BIG: StringName = &"big_company"

## 🔒 **A town must keep enough workers to work** (§1), and this is the answer to
## *may a town of twelve put ten under arms*. It may not.
##
## Tuning (§12), and it trades directly against how threatened the town is — a
## colony about to be overrun should be able to empty itself further than a
## comfortable one. That softening is not built; the floor is flat for now.
static var _worker_floor: int = 6_000

## What share of the workers above the floor a governor is willing to send.
## Tuning.
static var _raises_share: float = 0.5


static func load_from(record: Dictionary) -> void:
	_worker_floor = maxi(0, int(record.get("worker_floor", _worker_floor)))
	_raises_share = clampf(float(record.get("raises_share", _raises_share)), 0.0, 1.0)


static func reset() -> void:
	_worker_floor = 6_000
	_raises_share = 0.5


static func worker_floor() -> int:
	return _worker_floor


## How many men this town could spare, if it raised one now.
static func spare_workers(town: Town) -> int:
	return maxi(0, town.workers - _worker_floor) if town != null else 0


## 🔒 **Whether the governor may take it as an objective at all** (§1).
##
## A filter rather than a weight, for the same reason a rebel town may never take
## an expedition: a town that cannot keep enough workers to work is not a town
## that should be talked into it by an enthusiastic intent.
static func may_raise(town: Town, company: StringName = BIG) -> bool:
	return town != null and not town.rebelling and size_for(town, company) > 0


## How large a company the governor raises.
##
## **A scouting party is a share of the town** (§6), sized for exploring rather
## than fighting, and out of workers whatever the floor: it takes a tenth, and a
## tenth leaves a town that works. **A big company is what the town can spare**
## above its floor. What either can *arm* is settled below, separately, because
## a town with men and no muskets still raises a company; it raises a bad one.
static func size_for(town: Town, company: StringName = BIG) -> int:
	if town == null:
		return 0
	var share := Objective.company_share(company)
	if share > 0.0:
		return mini(town.workers, int(floorf(float(town.population()) * share)))
	return int(floorf(float(spare_workers(town)) * _raises_share))


## 🔒 **What the town can put in their hands, at §2's ratio** (§1).
##
## Capped by the stores, so a town that has been stockpiling guns under
## `military` launches an armed company and one that has not launches
## a mob. That is the whole of what the intent's stockpiling was for — and until
## now those guns were bought, held against the reserve, and never used.
static func arms_for(town: Town, size: int) -> Dictionary:
	var out: Dictionary = {}
	if town == null or size <= 0:
		return out
	for resource in Company.armed_resources():
		var id := StringName(resource)
		var wanted := Population.amount_for(id, Company.want_per_head(id), float(size))
		if wanted <= 0.0:
			continue
		var taken := minf(wanted, town.held(id))
		if taken > 0.0:
			out[String(resource)] = taken
	return out


## 🔒 **The standing order comes from the intent that raised it** (§1), never
## from a separate choice.
##
## **Every company defends its town for now** (#428, #432). How a company
## picks an order that leaves is #434's (`commanders.md` §3, the Author's
## ruling on #423). Until then a raised company holds the town.
static func order_for(_intent: StringName) -> StringName:
	return StandingOrder.DEFEND_THE_TOWN


## The one order in the game that leaves the town. Named here because §1's table
## names it and `StandingOrder` deliberately holds only the defensive list.
const MARCH: StringName = &"march_on_them"


## 🔒 **Who leads a company of this kind** raised from a town of `people`
## (#432, `governor-agendas.md` §6): a scouting party is always a militia, and a
## big company has a commander **unless its town held 5,000 or fewer**. This
## replaces the order deciding it (`commanders.md` §2).
static func led_by_for(kind: StringName, people: int) -> StringName:
	var leadership := Objective.company_leadership(kind)
	var led_by := StringName(leadership["led_by"])
	var up_to := int(leadership["militia_up_to"])
	if led_by == Company.COMMANDED and up_to >= 0 and people <= up_to:
		return Company.MILITIA
	return led_by


## Raise it, out of the town that chose to (Seam A).
##
## Returns the company, or null when the town could not after all — which is
## possible, because the objective was chosen months ago and a famine may have
## happened since.
static func raise_from(town: Town, context: ColonyContext) -> Company:
	var kind := town.objective if town != null and Objective.is_company(town.objective) else BIG
	if context == null or context.companies == null or not may_raise(town, kind):
		return null
	var size := size_for(town, kind)
	if size <= 0:
		return null
	# **Who leads it is settled now**, from the town as it stands before the men
	# leave it (#432).
	var led_by := led_by_for(kind, town.population())

	var arms := arms_for(town, size)
	for resource in arms:
		town.take(StringName(resource), float(arms[resource]))
	# 🔒 **Out of workers, all at once, and never out of experts.**
	town.workers -= size

	var company := context.companies.raise_company(
		Company.COLONIAL, size, arms, town.id, town.at, context,
		order_for(town.intent), led_by)

	context.log.emit(EVENT_RAISED, town.id, context.state.month, {
		"town": String(town.id),
		"company": String(company.id),
		"kind": String(kind),
		"intent": String(town.intent),
		"order": String(company.order),
		"size": size,
		"arms": arms.duplicate(),
		"workers_left": town.workers,
		# 🔒 **Whether he still needs a man for it**, so the driver that
		# commissions one next month has something to read and the letters have
		# something to say.
		"needs_a_commander": company.wants_a_commander(),
	}, WorldPhase.COLONY_MONTH)
	return company
