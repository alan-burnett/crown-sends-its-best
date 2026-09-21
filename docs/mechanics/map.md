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

## 2. 🔒 The world is made first. The colony arrives into it

**The map is not a surface for towns to be placed on.** It is a country, made on
its own terms, and the colony is put down somewhere in it afterwards.

That ordering is the whole of whether the map reads as a place. A world generated
to suit a colony produces sites; **a world generated as geography produces a
swath of desert, a ridge of mountains, a forest with grassland dotted through
it** — and then somebody finds a place to land in it.

§16.1 locks that the same seed produces the same world.

### What is wrong with what ships

Terrain is currently a **per-tile weighted draw** — 30% plains, 28% grassland, 27%
forest, 10% mountains, 5% desert, with a gentler table near the coast.

Every tile is rolled **independently of its neighbours.** That does not make
country, it makes **confetti**: a mountain beside a desert beside a forest, no
ranges, no regions, and a desert that is five per cent of everywhere rather than
a place.

### Two fields, and the geography falls out of them

**Elevation** and **moisture**, each a continuous field across the grid.

| | |
| :--- | :--- |
| **Elevation** | high ground is mountains; the sea floor is ocean, and shallow water near land is sea |
| **Moisture** | dry is desert, open country is grassland and plains, wet is forest |

Nothing is placed. **A ridge of mountains is a ridge because elevation runs in
ridges**, and a forest is a region because moisture is. The seven terrains of
§1 are read off two numbers, and their arrangement is a consequence rather than
an authoring job.

### Rain shadow, which is why a desert is where it is

**Moisture falls away behind high ground.** That single rule gives the driest
country a reason to sit where it does — inland, behind a range, in the lee of the
weather — instead of appearing as scattered tiles nobody can explain.

It also gives the map its shape without a second system: **wet coasts, a spine,
and dry country behind it.**

### Regions are not uniform, and that is the point

**A forest has grassland dotted through it.** Where the moisture field dips inside
a wet region, the terrain dips with it, and clearings appear without anybody
authoring clearings.

That is the difference between a region and a blob, and it comes free: a little
noise on both fields is all it takes. **Homogeneous patches read as a map editor.
Mixed ones read as country.**

### And the rest

- **Two to four landmasses**, grown to a share of the grid, with a compactness
  term so they read as country rather than as noise.
- **Shallows cut** around the coast, separating *sea* from *ocean* — and therefore
  separating a tile worth working from one worth almost nothing.

### Seeds will differ in character, not merely in layout

A world made on its own terms **will not serve all four of §4's requests equally.**
One seed has a great belt of forest and mountain and answers *economic
opportunity* handsomely; another is open country from end to end and has little to
offer it.

**That is correct and should not be corrected.** §4 finds the best site available
for what was asked, and sometimes the best available is modest. A generator that
guaranteed every request a fine answer would be back to building a surface for
towns.

## 3. 🔒 One guarantee, and it is the only one

**Every map must offer at least one site with shallow sea adjacent to workable
land** (§6). A seed that cannot is a broken seed, not an unlucky one, and mapgen
repairs it.

**Nothing else needs guaranteeing**, because §4's requests never demand terrain the
map may not have. A request **tilts the score of a generally good site**; it does
not go hunting for a rare one. And the single request that *does* need a
particular tile gets it by fiat rather than by search.

Watch the shallows: they are cut **after** the land is grown, so a map can in
principle produce a coastline with only ocean beside it and nothing worth
working.

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

### 🔒 A request tilts a good site. It does not pick a strange one

There is a **base score** for a site — what the ground around it is worth, with
**desert always the lowest-valued terrain there is**. A request adds weight on top
of that; it never replaces it.

So *prioritise sea* does not find the most maritime tile on the map regardless of
what surrounds it. **It finds a good site that happens to lean seaward**, and a
player who asks for one thing is never handed somewhere bad at everything else.

### The four requests

| | Tilts toward |
| :--- | :--- |
| **"We want quick growth"** | **sea** |
| **"We want economic opportunity"** | **forest, mountains** |
| **"We want long-term cultivation"** | **grassland, plains, mountains** |
| **"We want a defensive position"** | **nothing — see below** |

Each tilt is a **weight vector over terrain**, scored across the tiles a town
would work. Adding a request is adding a row, not a branch — the same shape as a
governor's intent profiles in `governor-objectives.md` §5.

### The defensive request is answered by fiat

It takes the **highest-scoring site with no tilt at all**, and then **the tile
beneath the town is made a mountain.**

No search, no guarantee, no rare-terrain hunt. **The colony gets its high ground
and no say in what surrounds it** — which is honest, since it asked for a
position rather than a country, and the site underneath was a good one before the
mountain arrived.

## 5. 🔒 The player never sees the site, because he is asked by letter

**He does not see where he is going and he does not approve it.** Showing him
invites re-rolling until the map looks pretty, which is choosing a tile by the
back door and undoes §4 entirely.

Instead, **the first thing that happens in a run is a letter.**

### The Governor's opening letter

The founding governor writes before he has landed anywhere. He introduces
himself, the PC learns a little of **what sort of man he is**, and he speaks about
**the supplies and the mandate the PC chose** — addressing him by the name and
title the PC picked, which is the first and best use of §5's flavour.

Then he asks his two questions: **what is this colony for, and how close do we
settle to the tribes.**

**It is a simpler letter than most: no tone and no harshness.** The PC is not
granting, denying, urging or leaning on anybody. He is answering a question from
a man he has not met, and the reply wizard should offer nothing but the two
choices.

### This is the same act as any other founding

`founding-towns.md` §5: *the governor sets out toward an intended region, and the
PC's letter can shift him while he travels.* **The opening is that, at the start
of the run** — an expedition in transit, and the PC's first letter directing where
it lands.

Which means the colony begins with **no towns and one expedition**, and the
Overrun test counting expeditions (`endings.md` §1) is what stops month one being
a fail condition. That is not a coincidence; it is the same rule.

### Where the other decisions live

| | Chosen |
| :--- | :--- |
| Seed, PC name and title, portrait, colour, **perk and quirks**, **mandate**, **the grant's split** | in the **main menu**, before the run loads |
| **The site request** and **the tribes** | **turn one, by letter** |

**Acceptable fallback.** If a world month with no towns proves awkward — a colony
month has a great deal to say about towns and there are none — putting both
questions in the run-start menu beside mandate and supplies is fine. **The letter
is better and it is not worth a fortnight.**

## 6. 🔒 Every starting town has sea within reach

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

## 7. The real question is speed against ceiling

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

## 8. The natives are placed after the site, and relative to it

**The order matters and it is the whole of how the second question is honoured.**

1. The map is generated
2. The **site is chosen** against the request
3. **Then the villages are placed**, at a distance that answers a second question:

> **Do we settle near the natives, or keep our distance?**

**Four bands, and the question moves one tribe between two of them:**

| | The first tribe | The other two |
| :--- | :--- | :--- |
| **Near** | **close** | far, and very far |
| **Apart** | **medium** | far, and very far |

**Only the nearest neighbour is in question.** Two tribes are distant whatever the
PC answers, so the rest of the native game arrives in its own time however he
chose — what he is deciding is who is over the next ridge, not how many there
are.

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

## 9. Tuning targets

- The four weight vectors, and whether a request reliably produces a site a
  player would recognise as answering it.
- **The scale of the two fields** — how many tiles a ridge runs for, how wide a
  desert gets. Tuned to make a 34 by 26 grid read as a continent, and **not** to
  any town's influence area, which is a consequence of where a town lands rather
  than a target to hit.
- How much noise the fields carry. Too little and regions are blobs; too much and
  the confetti comes back wearing two fields instead of one.
- **Medium and far**, in tiles, against how fast a colony's influence grows.
- The generation guarantees in §3, and how often a seed needs repairing to meet
  them — a high rate means the weights are wrong, not the guarantees.
- Whether three requests would do. Four is a lot to read on a phone before a
  player knows what any of it means.

## 10. Open items

- **How much of the governor's disposition his opening letter gives away** is not
  this document's to decide, and not the letter's either. **It gives away exactly
  what his tone gives away** — which is why `tone.md` §6 now has a register, so
  that two governors rolled differently open a run in different voices. Nothing
  here digs into a personality vector to announce what sort of man he is.
