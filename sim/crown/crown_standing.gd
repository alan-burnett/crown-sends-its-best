class_name CrownStanding
extends RefCounted

## The Crown-side jaw of the Squeeze (SPEC §10.3,
## `docs/mechanics/crown-standing.md`).
##
## ## 🔒 A financial measure, not a political process
##
## **Standing is arithmetic. Refusing to pay is a decision the Crown takes
## slowly**, through warnings and deadlines, and it has its own state (#68).
## Conflating them is the main way to get this wrong.
##
## Standing may crash from comfortable to nothing in a single month, and nothing
## here stops it. That is safe *because* it is separate: SPEC §10.3 locks the
## guarantee that the player always gets the Chancellor's warning before the
## Crown first refuses, and that guarantee is kept by the refusal machine's gate
## rather than by blunting this arithmetic.
##
## ## The PC never has to clear the debt
##
## He has to look like he is on track to. That is the whole design, and it is why
## recovery reads off the **horizon** — months to recoup at the current rate —
## rather than off the size of the hole.
##
## | | net position | monthly net | horizon | The Crown's view |
## | :--- | --: | --: | --: | :--- |
## | Thrifty | −500 | +50 | 10 months | Recovering nicely |
## | Spendthrift | −50,000 | +50 | 1,000 months | Not seriously trying |
##
## Identical profit, opposite verdicts.
##
## ## 🔒 Never a number the player sees
##
## The four bands are the entire interface, and `tools/lint.gd` fails if
## anything under `presentation/` reads this at all. The **Ledger** is the
## compensating instrument: it shows every transaction and the monthly totals,
## so a diligent player can derive the inputs — they simply cannot see the
## Crown's judgement of them. Reading the gap between the sheet and the letters
## is a skill the game is meant to reward.

# --- The bands (doc §2). Illustrative on 0-100; tuning, not design ----------

const MAXIMUM: float = 100.0
const START: float = 80.0

const CONTENT: float = 60.0
const CONCERN: float = 40.0
const ALARM: float = 20.0

const BAND_CONTENT: StringName = &"content"
const BAND_CONCERN: StringName = &"concern"
const BAND_ALARM: StringName = &"alarm"
const BAND_LOST: StringName = &"lost"

## Worst first. **Not an ordering anything may infer over** — it is here so a
## letter trigger can name a band, not so something can say "alarm or worse".
const BANDS: Array[StringName] = [BAND_LOST, BAND_ALARM, BAND_CONCERN, BAND_CONTENT]

# --- Direction and rate (doc §2) -------------------------------------------

## How hard a month of overspending bites, per unit of burn ratio.
##
## **Tuned against the harness**, not guessed. At 1.5 a third of seeds were
## already in Concern by the end of year one; at 1.0, 39 of 40 are still in
## Content, which is what `crown-standing.md` §7 asks for — standing is not a
## system the player needs to understand in his first twelve turns.
const K_FALL: float = 1.0

## How fast a profitable month climbs, at best.
const K_RISE: float = 1.0

## **Larger below the threshold**, so the climb out is achievable rather than
## theoretical.
const K_RISE_LOST: float = 2.5

## The horizon at which recovery reads as hopeless. Ten years to recoup.
const H_MAX: float = 120.0

## **Small, and not zero.** Without it a player who is genuinely profitable but
## catastrophically deep is pinned below the threshold for ever with no route
## back, and the only remaining move is retirement. The floor turns a dead end
## into a long punishment.
const RISE_FLOOR: float = 0.08

## What reaching a revenue target is worth, and what missing one costs.
##
## **Missing costs more than reaching is worth**, and more than declining does.
## Placeholders pending the calibration in `crown-demands.md` §8.
const TARGET_REACHED: float = 3.0
const TARGET_MISSED: float = 8.0

const EVENT_MOVED: StringName = &"crown_standing_moved"

## `0` to `100`, and **never shown to the player**.
var standing: float = START

## Cumulative revenue minus cumulative spending. The size of the hole.
var net_position: float = 0.0

## The band as of the last time it moved, so a change of band is detectable
## without anything having to remember the previous number.
var band: StringName = BAND_CONTENT


# --- A month ----------------------------------------------------------------

## Advance one month, and say what happened.
##
## Returns `{before, after, delta, band, was, monthly_net, horizon}`. The caller
## emits; this decides.
func advance(revenue: float, spending: float, judgement: float = 0.0) -> Dictionary:
	var before := standing
	var was := band

	var monthly_net := revenue - spending
	net_position += monthly_net

	var delta := 0.0
	var horizon := 0.0
	if monthly_net <= 0.0:
		delta = -K_FALL * burn_ratio(revenue, monthly_net)
	else:
		horizon = horizon_at(net_position, monthly_net)
		delta = rise_rate() * maxf(RISE_FLOOR, 1.0 - horizon / H_MAX)

	standing = clampf(standing + delta + judgement, 0.0, MAXIMUM)
	band = band_of(standing)

	return {
		"before": before, "after": standing, "delta": standing - before,
		"band": band, "was": was,
		"monthly_net": monthly_net, "net_position": net_position,
		"horizon": horizon, "judgement": judgement,
	}


## What the Crown thinks of him, over and above what he cost it.
##
## ## Why standing is not only arithmetic
##
## The bands are the Crown's *opinion*, and an opinion is formed by conduct as
## well as by accounts (`crown-demands.md` §4). A governor who undertook a figure
## and reached it has told the Treasury something about his judgement that the
## gold alone does not say; one who undertook it and missed has told it something
## worse. An honest refusal costs something too, and deliberately costs **less**
## than a broken undertaking — that asymmetry is the decision the Steward's
## letter puts in front of the player, and without it here the letter is
## decoration.
##
## Magnitudes are placeholders. §8 calibrates them against the reference players,
## and `refusal_cost` is the `desperation` axis reaching the one thing it moves.


## **Falling scales with what the colony actually earns**, so a hundred gold of
## overspend hurts a small colony more than a large one.
##
## Deliberately unbounded above: a catastrophic promise should be able to take
## standing from comfortable to nothing in one month, which the doc is explicit
## about.
static func burn_ratio(revenue: float, monthly_net: float) -> float:
	if monthly_net > 0.0:
		return 0.0
	return absf(monthly_net) / maxf(revenue, 1.0)


## Months to recoup at this rate. Zero when there is no hole to climb out of.
static func horizon_at(position: float, monthly_net: float) -> float:
	if position >= 0.0 or monthly_net <= 0.0:
		return 0.0
	return absf(position) / monthly_net


## How fast this month can climb. Faster once the Crown has lost confidence,
## so that getting back is achievable rather than theoretical.
func rise_rate() -> float:
	return K_RISE_LOST if standing < ALARM else K_RISE


## **Political credit, alongside the arithmetic** (doc §6, SPEC §10.3). Meeting a
## Crown demand is worth more than the gold; missing one costs more than the
## revenue. The demands themselves are #69; this is the door they come through.
func adjust(amount: float) -> void:
	standing = clampf(standing + amount, 0.0, MAXIMUM)
	band = band_of(standing)


# --- Bands ------------------------------------------------------------------

## Which stage the Crown is at.
##
## **Below the alarm threshold is one flat band.** A standing of 19 and a
## standing of 0 behave identically; what separates a warned PC from a cut-off
## one is the refusal machine, not the number.
static func band_of(value: float) -> StringName:
	if value >= CONTENT:
		return BAND_CONTENT
	if value >= CONCERN:
		return BAND_CONCERN
	if value >= ALARM:
		return BAND_ALARM
	return BAND_LOST


## Whether the Crown has lost confidence. The one question the rest of the game
## asks; nothing else may ask for the number.
func has_lost_confidence() -> bool:
	return band == BAND_LOST


# --- Serialisation ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"standing": standing,
		"net_position": net_position,
		"band": String(band),
	}


static func from_dict(data: Dictionary) -> CrownStanding:
	var restored := CrownStanding.new()
	restored.standing = float(data.get("standing", START))
	restored.net_position = float(data.get("net_position", 0.0))
	restored.band = StringName(data.get("band", String(band_of(restored.standing))))
	return restored
