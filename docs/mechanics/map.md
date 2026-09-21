# Mechanics — The Map

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.1, §11.2, §6.1, §12.5, §16.1.

---

## 1. Seven terrains, on purpose

SPEC §11.1 names desert, grassland, plains, forest, mountains, sea and ocean, and
that is the whole list. It is short deliberately.

**Few terrains offer an interesting choice without offering much to tune.** Every
terrain added is another row in every yield table, another case in every
improvement's terrain factor, and another thing to balance against six others. A
colony is meant to face a legible question about its ground, not a spreadsheet.

What each yields is `tiles-and-improvements.md` §1, and not repeated here. This
document is about **how the world is made and how a colony is placed in it.**

## 2. Generation

A map is grown from the seed, and §16.1 locks that the same seed produces the same
world.

- **Two to four landmasses**, grown to a share of the grid, with a compactness
  term so they read as country rather than as noise.
- **Terrain painted by weighted draw**, with **coastal and inland tables that
  differ** — so a shoreline is not simply the inland map with water beside it.
- **Shallows cut** around the coast, which is what separates *sea* from *ocean*
  and therefore separates a tile worth working from one worth almost nothing.

## 3. 🔒 A map must be able to answer every request

§4 lets the player state what he wants from his ground. **A seed that cannot
honour one of those requests is a broken seed, not an unlucky one.**

Generation therefore guarantees, and mapgen retries or repairs until it does:

- at least one **coastal mountain**, or the defensive request cannot be met
- enough contiguous **grassland and plains** for the cultivation request
- enough **forest and mountain** together for the economic one
- **shallow sea** adjacent to workable land, which §5 requires of every start

That last is the one to watch: shallows are cut after the land is grown, so a map
can in principle produce a coastline with no sea worth working.

## 4. You state what you want. You do not choose a tile

**The player does not pick a site from a list of coordinates.** He says what the
colony is for, and the map answers.

That is the same rule the game already holds everywhere else. §11.4 locks that
**the PC never chooses a tile** when founding a town — he states preferences and
a competent man finds the ground. Run start is the same act, made by the same
sort of person, and it would be strange for the one decision he makes before
anything exists to be the one where he reads a map better than his own governors.

It is also the only version that is honestly playable. **A coordinate means
nothing to a player who has never played**, and three of them mean nothing three
times.

### The four requests

| | Values highly | Values moderately |
| :--- | :--- | :--- |
| **"We want quick growth"** | **sea** | grassland, plains |
| **"We want economic opportunity"** | **forest, mountains** | grassland, plains |
| **"We want a defensive position"** | **mountain — the town stands on one** | nearby mountain and forest |
| **"We want long-term cultivation"** | **grassland, plains, mountains** | — |

Each is a **weight vector over terrain**, scored across the tiles a town would
work. Adding a request is adding a row, not a branch — the same shape as a
governor's intent profiles in `governor-objectives.md` §5.

**The defensive request is the only one that constrains the town's own tile.** The
others describe the country around it.

## 5. 🔒 Every starting town has sea within reach

**Not negotiable, whatever was asked for.**

The Crown reaches the colony by ship. A landlocked first town cannot be supplied,
cannot be traded with, and cannot support a single one of the early mechanics —
Exchange, the Crown's prices, arriving immigrants, the Marshal's troops.

**Later towns may be landlocked and that is fine.** By then there are roads, carts
and neighbours, and `relief.md`'s transfers reach anywhere. It is only the
first town, alone on a shore with an ocean between it and everything it needs,
that has no alternative.

So the four requests operate **above a floor**, and *how coastal* is a
consequence of which one was asked for rather than a dial of its own.

### And nobody mentions the other half of that

How much coastline a colony has also decides how exposed it is when rivals
eventually come by sea. **Run start does not say so**, and should not — the player
who asks for quick growth is buying a shoreline, and finding out what a shoreline
costs is a thing that happens in year six.

## 6. The real question is speed against ceiling

The four requests read as flavour and are not. **They are a choice about how soon
the colony eats and how high it can climb**, and the tree is what makes them
different.

**Sea is one building.** A **dock** — 30 wood, no tools, no prerequisite — and
every sea tile in reach feeds the town. Nothing else is needed and nothing else
improves it.

**Plains is four.** A **farm** on the tile, then an **irrigation station**, then a
**windmill** and a **river mill** — an improvement and three buildings, two of
them wanting tools the colony cannot yet make (`buildings.md` §5).

So:

| | Time to value | Ceiling |
| :--- | :--- | :--- |
| **Sea** | one cheap building | **capped**, and it never rises |
| **Plains** | an improvement and three buildings | **high**, and it keeps climbing |

**Quick growth is quick and stops. Cultivation is slow and does not.** That is the
whole decision, and a player learns it by living through one of each rather than
by being told.

**Economic opportunity is the third shape**: forest and mountain feed no one. They
supply wood, stone and ore — the things everything else is *built* from — so that
colony can raise anything and must buy or farm its dinner.

## 7. The natives are placed after the site, and relative to it

**The order matters and it is the whole of how the second question is honoured.**

1. The map is generated
2. The **site is chosen** against the request
3. **Then the villages are placed**, at a distance that answers a second question:

> **Do we settle near the natives, or keep our distance?**

| | |
| :--- | :--- |
| **Near** | the nearest tribe sits at **medium** distance |
| **Apart** | it sits **far** |

**There is no adjacent.** Even the bold answer is not suicidal, and the timid one
does not put the tribes off the map.

### Why placement follows the site rather than the site following placement

Searching for ground that happens to be the right distance from a village would
fight the terrain request — and lose, because a good defensive mountain that is
also exactly six tiles from a tribe is a great deal to ask of one seed.

**Placing the villages afterwards honours both questions exactly**, every time,
on every seed.

### What proximity actually buys

Both directions of `natives.md` at once.

**Near** means trade agreements are reachable early — and those are the colony's
**one escape from the Crown's monopoly** (`natives.md` §5), untaxed in a game
where duty is charged twice on a round trip. It also means a tribe's population
may join yours, which is the cheapest growth in the game.

And it means **your expansion offends sooner.** §11.4 offends a tribe in
proportion to the intrusion, and a colony that starts close runs out of
inoffensive ground first.

**🔒 Being placed near a tribe is not itself an offence.** The colony did not
choose its neighbours' land — it was put there. Standing starts where it starts;
what the colony *does* next is what moves it.

## 8. Tuning targets

- The four weight vectors, and whether a request reliably produces a site a
  player would recognise as answering it.
- **Medium and far**, in tiles, against how fast a colony's influence grows.
- The generation guarantees in §3, and how often a seed needs repairing to meet
  them — a high rate means the weights are wrong, not the guarantees.
- Whether three requests would do. Four is a lot to read on a phone before a
  player knows what any of it means.

## 9. Open items

- **Whether the player should see the chosen site before committing.** Showing it
  makes the request legible; it also invites re-rolling until the map gives
  something that looks nice, which is choosing a tile by the back door.
- **What the second and third tribes do.** The question places the nearest; the
  others fall where the map allows, and nothing says whether that should be
  deliberate too.
- Whether **desert** should feature in any request. It is the one terrain no
  profile wants, which either makes it the map's honest bad ground or makes it
  content nobody meets.
- Whether the **defensive** request should be available at all before the player
  has met anything that attacks him. It is the only one whose payoff is invisible
  for several years.
