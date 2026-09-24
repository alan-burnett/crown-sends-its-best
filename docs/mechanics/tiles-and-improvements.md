# Mechanics — Tiles and Improvements

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.1, §11.2, §12.4, §12.5, §12.6, §9.1.

---

## 1. The tile

SPEC §11.1 gives seven terrains and describes each yield as *low*, *medium* or
*high*. **That word is the authored thing; the number behind it is not.**

```
none 0    low 1    medium 3    high 6
```

**Yields are data twice over.** A terrain says it is *high* in wood, and a
separate table says what high is worth. Balancing every forest in the game is
then one number rather than seven files that have to agree.

How a world of these is generated, and how a colony is placed in one, is
`map.md`.

A worker eats **1 food** a month, so a hand on high-food plains feeds six and one
on medium grassland feeds three. **That ratio is the foundation the whole colony
sits on** — see `town-economy.md` §11 for what multiplies it.

## 2. One improvement to a tile

A tile holds **one**. Building a farm where a mine stood replaces it cleanly,
because **every improvement computes from the terrain** rather than from whatever
was there before. There is no accumulated state to unwind and no order-of-
construction history to carry.

### "Best on plains" is a number in a file

§11.1 says a farm is *best on plains, decent on grassland*. That is a
**terrain factor** scaling what the improvement contributes — 1.0 on plains, 0.6
on grassland, 0.2 anywhere else — so nothing in code knows which terrain is which.

An improvement also declares **what it may be built on at all**, which is a
separate question from how well it does there. A mine is allowed nearly
everywhere and only worth building in mountains.

### How they change a tile

Three dials, and between them they express every improvement in §11.1:

| | |
| :--- | :--- |
| **scale** | multiplies the tile's existing yields |
| **keeps** | resources exempt from that scaling |
| **adds** | what the improvement contributes, at a level, times the terrain factor |

So a farm *raises food and lowers everything else* is `scale 0.3`, `keeps food`,
`adds medium food`. A plantation *introduces its resource and retains the food
yield, eliminating all others* is `scale 0.0`, `keeps food`, `adds medium sugar`.
**Neither needs a rule of its own.**

## 3. The six

| | Cost | Upkeep | What it does | Best on |
| :--- | :--- | --: | :--- | :--- |
| **farm** | 12 wood | 1 | food up, everything else down hard | plains, then grassland |
| **pasture** | 10 wood | 1 | supports livestock without feeding them; all yields down | grassland, then plains or forest |
| **plantation** | 18 wood, 2 tools | 2 | adds sugar, cotton or tobacco; keeps food, kills the rest | grassland or plains |
| **mine** | 20 wood, 4 tools | 2 | ore where there was none, some stone, nothing else | mountains |
| **road** | **free** | 0 | every yield +15%, and armies move faster | anywhere |
| **fort** | 30 wood, 20 stone | 3 | combat only. **No effect on yield at all** | anywhere |

**Plantations are three improvements, not one with a setting.** The town picks
which according to its objective, and the three differ only in what they add.

Note what costs no tools: **farm, pasture, road and fort.** Earth, timber and
labour. The same instinct as `buildings.md` §5, where the stockade and the
trenches are the two defences a desperate town can still raise.

## 4. Built like a building, but not by the same hands

An improvement goes through **the same path as a building** — the town takes it
as an objective, gathers, and invests resources into it month by month out of its
build capacity (`buildings.md` §3).

**🔒 Nothing that speeds buildings speeds improvements.** Improvements answer to
**worker cabins**, which build them faster and carry their upkeep.

There used to be a **crane** on the other side of this pair, speeding buildings
as worker cabins speed improvements. **It was removed** (#327): its only effect was
build speed, so a governor never wanted it and nine conversion buildings sat
behind it. Build speed for buildings is now **a policy's business**, not a
building's (`buildings.md` §3).

The pair survives in a different shape. Worker cabins are still the only thing
that makes a town faster at *spreading out*, and nothing a town can build makes it
faster at *building up* — so the two remain separate investments, and a town still
cannot buy its way into being good at both with a single project.

## 5. Upkeep disables; it never destroys

An improvement costs gold a month, and **a town that cannot pay keeps it and
loses it**. The farm is still standing; nobody is working it, and the tile yields
as though bare.

It switches back on the month the town can afford it again. Same rule as
buildings, and it is the poverty trap `town-economy.md` needs: **a town too poor
to pay watches its farms yield like scrubland**, which makes it poorer.

**Worker cabins remove improvement upkeep entirely**, which is most of why that
building is worth its place.

## 6. The fort is the exception in every direction

It is the only improvement that:

- **affects no yield whatsoever** — everything else exists to change what a tile
  produces, and this one exists to change what happens on it
- **a commander can build**, not only a town (§11.1). A Crown company in the
  field raises its own fort; `commanders.md` has the commander doing it, not the
  company
- **a rival will build** — §11.1 makes it the *only* improvement they raise
- **a tribe will never build** (§11.1, locked). Villages shape the country
  without fortifying it, which is why a village is easier to take than a town and
  why taking one is worse

In battle it is a heavy multiplier: a medium boost attacking *from* it, a very
high one defending *in* it (`battles.md` §5). **A rebel company in a fort on a
mountain is close to unassailable**, and is meant to be.

### A fort has an owner

**It records who built it** — a town, a Crown commander or a duke — so that its
fall can say whose it was.

**Its walls serve whoever stands in it.** Author's ruling (#419). The owner is
who built it, not whom it shelters: an enemy company standing in an empty fort
to raze it is defended by it for as long as it stands there.

### How a fort falls

Author's ruling (#419). Two ways, by whether anybody is in it.

| | It falls |
| :--- | :--- |
| **Manned** | **with its last defender.** The moment the last company standing in it is destroyed in battle, the fort is destroyed with it. No month of razing follows |
| **Empty** | **razed, like any improvement** (§7). An enemy company spends its month on it |

**A fort is empty when nobody stands in it** — never garrisoned, marched out
of, or its company disbanded or starved. A fort whose company marches away is
not lost; it stands, empty, until somebody comes to raze it.

**The last defender need not be the owner's.** The walls serve whoever is in
them, so a company that destroys an enemy standing in its own fort destroys the
fort with him.

**Either way it is one event**, naming the fort's owner, its tile and the side
that brought it down, and it is what *The Fort Falls* paints (`cutscenes.md`
§6). A razed fort is a fort that fell, not a farm that burned, so it is never
*They Burned It*.

## 7. They can be attacked, and that is the point

**An improvement can be razed.** A company simply destroys it — world month
phase 2 already names *razing an improvement* as one of the things a unit does
with its month.

The tile reverts to its unimproved yield. The town must rebuild: the cost again,
the months again, and the lost yield in between.

### 🔒 It is harassment, not war

This is the sharpest thing about the mechanic. **Razing an improvement is
aggression that stops short of everything that counts as a war.**

| | |
| :--- | :--- |
| No town changes hands | so no **town lost** optic |
| No company is destroyed | so no **defeat** optic (`prestige.md` §4) |
| Nothing is besieged | so nothing escalates on its own |

So a rival at **Low** loyalty (`rival-pressure.md` §3) or a tribe at low standing
(`natives.md` §7) can hurt the colony **month after month, materially, without
ever declaring anything.** It is the pressure that fills the long gap between
*being asked for money* and *being at war*, and without it that gap is empty.

### And the PC may not know who did it

SPEC §9.1's own example of a letter omitting what does not flatter its sender is
**exactly this**:

> *A rival duke may report that "it seems your coastal defenses have been
> destroyed" without mentioning whose ships destroyed them.*

**An attacked improvement is the game's clearest case of knowing what happened
and not knowing who did it.** The governor reports a burnt farm truthfully; who
burnt it depends on whether anyone saw, and §11.2 locks that the map shows only
what the colony knows.

A PC who retaliates against the wrong neighbour has done exactly what the real
culprit hoped.

### What stops it being a dominant strategy

Razing is **cheap for the attacker and dear for the defender**, which is what
harassment means and is not a balance problem to be tuned away.

What limits it is that **a company spends its month doing it** — and a company
never gains men, never resupplies, and only dwindles (`battles.md` §2). A duke
burning farms is a duke whose men are not growing his own colony, and every month
he spends on it is a month of attrition he cannot replace.

**No cap is needed and none should be added.**

### Taking ground is a different thing

§12.5 has tribes *taking tiles*, and that is **not** razing. Razing destroys what
stands on a tile; taking it is a contest over **influence** (§11.2) — whose town
or village works it. A village that grows onto a town's ground has taken nothing
and destroyed nothing, and the town simply has less country.

`natives.md` §10 has that contest as its open item and it stays there.

## 8. Roads are built by trade, not by decision

§11.1: roads are **built naturally, requiring no resources or effort**,
connecting towns with frequent trading partners.

So no town ever takes a road as an objective and no letter ever asks for one.
**They appear where the traffic already is**, which makes the road network a
*readout* of how the colony actually trades rather than a thing the player
builds.

They raise every yield on their tile slightly and speed armies (§11.1) — so a
well-connected colony is quietly richer and quietly easier to march through, and
both of those are consequences of prosperity the PC never chose.

## 9. Tuning targets

- The four yield levels. **One number each, and they set everything.**
- Terrain factors per improvement.
- Improvement costs and upkeep, against building costs — they should read as the
  cheap, quick, many-of-them option beside a building.
- How much a road adds, and how much traffic earns one.
- The fort's two combat multipliers (`battles.md` §5).
- How often a hostile company chooses to raze rather than do something else.

## 10. Open items

- **Whether a razed improvement leaves anything behind.** Currently the tile
  reverts completely and the rebuild is full price. A partial rebuild would be
  gentler and might make raiding less punishing than intended.
- Whether a town can **choose not to rebuild** — abandoning a farm on ground it
  keeps losing is a sensible decision and nothing currently allows it.
- Whether the natives **raze** improvements or only take ground. §12.5 says they
  take tiles and §11.4 has founding offend them; the raiding behaviour in
  `natives.md` §7 is not yet specific.
- Whether a fort raised by a commander belongs to the Crown or to the colony when
  the company that built it is gone.
