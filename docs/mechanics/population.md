# Mechanics — Population

> **Owner:** PO. **Draft, in progress with the Author.** Nothing here is built.
> Devs implement from this once it is marked settled; devs do not edit it. If
> this doc ever contradicts SPEC.md, the spec wins.
>
> **Serves:** SPEC §12.1 (growth), §12.2 (workers, experts, livestock), §11.3.
>
> Marks: **⚠ assumed** is a PO default filling a gap the Author has not ruled
> on. Strike or correct it; unmarked rules are the Author's.

---

## 1. Population counts people

**A town holds people, not units of a thousand.** Author's ruling. A town, an
expedition or a company can hold 245, 1,984 or 3,933. Whole people, so still an
integer — but an integer of people, where today's `1` is `1000`.

**Why.** A 20% expedition from a town of 3,999 takes 799 people, not
`floor(0.8) = 0`. Shares, growth and immigration stop losing people to rounding,
and a growth curve reads as a curve.

### It is already how the player sees it

`Config.PEOPLE_PER_POPULATION = 1000` today multiplies every population the
player reads — letters, cutscenes, the summary (`core/text/figures.gd`). **The
display is already in people; the sim is not.** This change moves the thousand
from the display into the sim, and the constant goes to one.

## 2. What is counted in people

| | Scale |
| :--- | :--- |
| **Workers** | people |
| **Livestock** | **head, on the same scale as people** — a pasture carries thousands, and horses bought or sold are counted the same way |
| **Expedition parties, Crown foundings** | people |
| **Companies**, and a town fighting as one | people |
| **Native villages** | people — the same rescale, so a village of 30 becomes 30,000 and stands against towns as it does now |
| **Experts** | **individuals, unchanged.** A town of 3,933 might hold 3 tobacco experts. Each still adds his yield, his education, and moves between towns as one man |

`population()` stays workers plus experts. **An expert is one person** among
thousands — for food, clothing, tiles worked and every other measure of people.

**The one exception is wealth.** When the town reckons how much wealth its
people crave (`governor-agendas.md` §13), **an expert counts as a thousand
people**: a man of standing wants a great deal more than a labourer.

**Resources other than livestock are not rescaled.** Food, wood, guns and gold
keep their units. What changes is how many people a unit serves (§4).

## 3. Tiles worked

**One tile per thousand workers, floored.** A town of 1,999 workers works one
tile; 2,000 works two. The same for a conversion recipe: a worker-slot is a
thousand workers.

## 4. Rates per head become rates per thousand

**Every per-head figure is authored per thousand people**, so the numbers in the
data files do not change: *one food per head per month* becomes *one food per
thousand people per month*. Code multiplies by `people ÷ 1000` where it
multiplied by `people`.

This covers, among others: food and clothing needs, the luxury cap, reserves, the
pleasure purse, the comfortable purse, settlers' purse, build capacity, intent
stocks, a company's victuals and arms per man, livestock feed and slaughter
yield, and a village's stores.

**One exception — anything counted per expert stays per expert.** Education per
expert, the expert yield bonus and its falloff, `EXPERTS_A_TOWN_MIGHT_HOLD`.

**Livestock's per-head figures also go per thousand head** — feed, slaughter
yield and price — since a head is now a thousandth of what it was.

## 5. Thresholds scale by a thousand

Anything that compares a count of people or head against a number moves by a
thousand. The inventory, for the ticket:

| Mechanic | Today | Becomes |
| :--- | :--- | :--- |
| Influence ring | `1 + pop / 12` | `1 + pop / 12,000` |
| Village influence | `1 + people / 22` | `1 + people / 22,000` |
| Crowding comfortable | 2 per land tile | 2,000 |
| Expedition: town keeps at least | 4 | 4,000 |
| Raising: worker floor | 6 | 6,000 |
| Native war party: village keeps | 6 | 6,000 |
| Starting town | 12 workers | 12,000 |
| Crown foundings | 10–30 people | 10,000–30,000 |
| Tribe villages at start | 26–48 | 26,000–48,000 |
| Rival landing | 45 men | 45,000 |
| Natives joining | 0.5 a month | 500 a month |
| Immigration flow | people a month | × 1,000 |
| Pasture capacity | town pasture 24; improvement 4 | 24,000; 4,000 |
| Commander ranks | 12 / 40 / 90 / 180 / 320 men inflicted | × 1,000 |
| Glory | 80 men | 80,000 |
| Last-chance rungs | 40 / 25 / 15 / 8 / 3 people | × 1,000 |
| Colony reach at full | 900 people | 900,000 |

Proportional rates **do not** change: birth rate, livestock breeding rate,
expedition and raising shares, battle lethality, attrition share.

### Experts are the one place a rate shrinks

Experts arrive as a **share of people**: a share of births, of settlers and of
native arrivals. With people a thousand times more numerous and experts still
individuals, **those shares fall by a thousand**, or a town would gain hundreds
of experts a month.

| | Today | Becomes |
| :--- | :--- | :--- |
| Expert share of births | `0.4 × edu / (edu + 5)` | ÷ 1,000 |
| Expert share of settlers | 0.04 + knob | ÷ 1,000 |
| Native teachers | 0.02 experts a month | unchanged — already counted in experts |

The fractional accrual that exists today (`experts_accrued`) carries these, so
a town still gets its tenth-of-a-scholar a month and meets him in the tenth.

## 6. 🔒 Hardship is a proportional drain

**No longer one population at a time.** Author's ruling. Famine, shortage and a
bad winter take **a share** of the town, in one event that says how many — the
same shape a battle already has.

- **Famine** already computes its toll proportionally (`pop × unmet × 0.12`).
  What changes is that it is removed **in one step and reported in one event**
  carrying the count, rather than one event per life.
- **A hungry village** loses a share rather than one person a month — the same
  share a town's famine takes.
- **Workers still go before experts, always.** An expert is lost only when no
  worker remains. That rule is untouched and is what keeps education safe from a
  bad winter.
- **Growth, immigration, calves**: whole people land each month, remainders
  carried as now. The cap of one calf per kind per month goes.

**Anything that counted famine events as people counts the people instead** —
the run summary, the run-end *hunger* reading.

### The Diplomat's death roll

**He dies as any man in the town might.** Rolled whenever enemy attack costs
his town people (SPEC §8), with the chance

```
people lost / the town's population before the loss
```

A storming that takes a fifth of the town kills him one time in five. The odds
no longer depend on the scale of population at all.

**Famine does not roll.** Only enemy attack can kill him, as the spec says.

### CLAUDE.md

Its section *Population moves one at a time, except under arms* no longer holds,
and changes to:

> **Population is people, and hardship takes a share.** A town counts people in
> whole numbers — thousands of them. Famine, shortage and war each take a share
> of the people they fall on, in one event that says how many. **Workers go
> before experts, always**: an expert is lost only when no worker remains.
> **A body of people in the open is not a town** … *(unchanged)*

## 7. Presentation

- **`PEOPLE_PER_POPULATION` goes to one**, and `Figures` prints what the sim
  holds.
- Two event params are printed raw today — `expedition_attacked.lost_people`,
  `expedition_turned_back.souls` — and are **already right** after the change.
- How large figures read (*4,000*, *some four thousand*) is the presentation's
  business and the Author's.

## 8. Saves and tests

- **The save version goes up**, and old saves are refused, as `CLAUDE.md`
  requires during development.
- **Determinism and save round-trip tests must still pass** with the new figures.
- Tests that pin a population figure (the inventory lists some twenty files)
  are rescaled with it. None of them is a balance test in `CLAUDE.md`'s sense;
  they pin behaviour at a size, and the size moves.

## 9. Sequencing

**Before the agenda rework** (`governor-agendas.md`), which is written in these
units. Landing this first means every gate is authored once.

## 10. Open items

- How large figures read to the player.
