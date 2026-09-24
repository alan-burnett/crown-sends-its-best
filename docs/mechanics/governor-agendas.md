# Mechanics — Governor Agendas

> **Owner:** PO. **Draft, in progress with the Author.** Nothing here is built.
> When it is settled it replaces `governor-objectives.md` §4–§5 and the axis
> model, and that doc will point here. Until then **`governor-objectives.md`
> describes the shipping code, and this describes where it is going.**
>
> Devs implement from this once it is marked settled; devs do not edit it. If
> this doc ever contradicts SPEC.md, the spec wins.
>
> **Serves:** SPEC §8.2 (Intent), §8.5 (orders reach intent, never objective),
> §11.3 (towns run themselves), §6.1 (Mandate).
>
> **Units.** Population is counted in people, **a thousand to what one was
> before** (`population.md`). Every figure here is in those units.
>
> Marks: **⚠ assumed** is a PO default filling a gap the Author has not ruled
> on. Strike or correct it; unmarked rules are the Author's.

---

## 1. What changes, and what does not

**The axis model is retired.** Before, every candidate was scored on shared
axes and each intent weighted the axes. Now **each intent has its own ordered
menu of objectives**, each with its own rule for when it is wanted.

**What does not change:**

- **Personality lives only in the intent.** Choosing an objective has no
  personality, no weights and no dice. Two governors with the same intent in the
  same town build the same thing.
- **An order reaches intent, never objective** (SPEC §8.5). The PC urges an
  intent; the town picks the project.
- **Spec locks are filters, not weights.**

## 2. The intents

Six, replacing the eight in `governor-objectives.md` §4.

| Intent | The town is for | Replaces |
| :--- | :--- | :--- |
| **Go tall** | a few deep towns: people, experts, comfort | grow the population |
| **Go wide** | many towns, quickly | settle a new town |
| **Get rich** | the most gold **the town** receives from the Crown | increase economic output |
| **Military** | defending and attacking, one tree | strengthen defences; drive them off |
| **Education** | the library, the college, the printing press | educate the people |
| **Prepare for rebellion** | standing apart from the Crown | unchanged |

**Education does not come from the PC.** It is urged by **the Provost**, and
possibly the scholar — the lever #401 already designs, through #405's urging per
author. The PC has no letter for it. **A filter makes urging its only route in**
(§13), so it has no column in the considerations table.

**Survival is gone.** A starving town does not want a granary built of wood; it
wants food off its tiles, and the Work phase already turns tiles to food when the
food need is unmet (SPEC §11.3, needs before objectives).

**Get rich is the town's profit, not the Crown's.** It ranks resources by what
the town receives **after the PC's tax**, so a heavy tax on sugar pushes it
toward tobacco. The PC's tax rates steer its building.

**Military is always available.** It has no filter. What drives it is
**safety**, and a town that has never seen a native or a duke reads as perfectly
safe, so it rarely gets there on its own. The PC may still urge it, and must not
be simply wrong to: a military town builds a sound stockade line either way.
*Be rid of them* urges military; the company decides whom it marches on.

**Prepare for rebellion** keeps its loyalty-floor filter.

**The Crown's mandates map one to one onto the intents.** A mandate *is* an
intent the Crown names at the start of a run — profit is get rich, settlement is
go wide, a strategic foothold is military. Rebellion is never a mandate.

### What the PC writes

Placeholder prose; the Author will write the real lines.

| Intent | The PC writes |
| :--- | :--- |
| Go tall | *see that the town grows, and its people amount to something* |
| Go wide | *plant new settlements* |
| Get rich | *see that the town prospers* |
| Military | *see to your defences* / *be rid of them* |
| Education | — (the Provost's, not the PC's) |
| Prepare for rebellion | — (his alone) |

## 3. Walking a menu

Each Settle, if the town has no objective, it walks its intent's menu **top to
bottom** and takes the **first** item that is all of:

1. **wanted** — its gate passes;
2. **reachable** — prerequisites built, resources obtainable;
3. **placeable** — if it needs a tile or a choice (§5), a candidate exists;
4. **not already built**, for a one-off building.

If an item fails any test, the walk moves on.

### The shared fallback: no building

**When nothing on the menu is taken, the objective is *no building*.** It is the
same for every intent, and it gives **+10% yield on every tile the town works**
while it stands.

It **replaces the four standing postures** — stockpile food, harvest timber,
harvest stone, trap furs — which today bend Work toward their resource and make
the town sell none of it.

**It does not hold.** Every other objective holds until complete; *no building*
never completes, so **the menu is walked again every Settle**, and the first
month a gate opens the town takes it.

**Menus are exclusive but thorough.** Anything not on an intent's menu is never
built under that intent. The same objective may appear on several menus at
different places — the dock and the granary are on both go wide and go tall.

**A menu must contain its items' prerequisites**, or they are unreachable. The
content validator checks this.

**Repeatable items need a gate that can close** — an improvement, an expedition
or a company can be taken again, and one with an always-open gate at the top of
a menu would be taken for ever.

### How long an objective is held

**Until it is complete, or the governor's intent changes.** Nothing else ends
it. A town that goes broke keeps the objective and makes no progress — too bad.
There is no stall detection and no crisis override.

## 4. The shape of a menu

Every menu opens with the same three kinds of slot, each with its own gate, size
and scoring per intent, and then an ordered list of buildings:

| Slot | Objective | Its gate reads |
| --: | :--- | :--- |
| 1 | **Create a company** | the population, the companies the town is already supporting |
| 2 | **Create an expedition** | the population, the companies it is supporting, how many towns the colony has |
| 3 | **Make a tile improvement** | how many improvements the town already has |
| 4+ | **An ordered list of buildings**, some with conditions | per building |

An intent may leave a slot out or reorder them — get rich raises no companies,
rebellion sends no expeditions, education has buildings only.

**Most months slots 1–3 will be skipped.** Their gates exist so a town does not
send out expedition after expedition to its own detriment, or cover every tile
it holds with improvements. A skipped slot is not closed for good: the next time
the town picks an objective the conditions may have changed, and it is asked
again.

**A building's condition is its own.** For example, a **tea house** is built only
if there is **no trade protest on tea** and **quality of life is below a
threshold**. A building with no condition is taken whenever the walk reaches it.

## 5. Sub-choices are scored

The **order** is fixed. **Where** and **which** are scored, deterministically.

### Which tile

**Each intent evaluates improvements differently and chooses tiles on different
criteria** (§8).

A tile qualifies only if the improvement would raise what it yields. No tile
qualifies, and the slot fails *placeable* and the walk moves on.

### Which of several

Where a slot can be filled by more than one thing — get rich choosing between a
sugar plantation and a distillery — each is measured on **this month's yields**:

```
worth = extra per month / cost
```

**Cost is valued at town prices** (`town-economy.md` §3), not the Crown's, so a
town that can cut its own timber reads timber as cheap. The highest worth wins.

### Improve yield

**One menu slot that weighs every way of getting more out of the ground**, on go
tall and get rich:

| Kind | Candidates |
| :--- | :--- |
| buildings | irrigation station, windmill, river mill, mineworks, sawmill, stonecutters |
| improvements | farm, mine, pasture — **never a plantation**, which is get rich's own slot |

Each is measured against **today's harvest**:

```
worth = what it would have added to this month's harvest / its resource cost
```

The highest worth is built. **A farm goes only on a tile that harvested food,
a mine only on one that harvested ore**, because what the improvement would have
added is measured from what the tile gave.

**Both sides are valued at town prices**, so a unit of ore and a unit of food
count by what the town thinks each is worth, and the ratio compares like with
like.

**An improvement is a candidate here only while the town holds fewer than one
improvement per thousand people**, or the slot would cover every tile in farms.

⚠ **Deferred to an authored session: how a pasture is measured** (#PASTURE). It
yields no crop — it carries livestock — so *what it would have added to this
month's harvest* has no obvious answer yet. **Until it is ruled, improve yield
does not offer a pasture.**

## 6. Expeditions and companies

### Expeditions

**Go wide sends a lean expedition and go tall a thick one.** Neither sends the
other kind.

| | Gathers for | Takes |
| :--- | --: | --: |
| **Lean** (go wide) | 2 months | 20% of the town |
| **Thick** (go tall) | 5 months | 40% of the town |

- **While it gathers**, the town raises its reserve of **wood, stone, tools and
  food**.
- **When it leaves**, it takes everything of those four **above the town's
  normal reserve**.
- **Resources only, never buildings.** A new town starts with what it carries.
- **It takes the same share of the gold as of the people** — unchanged from
  `founding-towns.md` §2.

These replace `founding-towns.md` §2's cargo rule (*set by what he can spare,
launch when met*). Starting numbers; the Author expects to tweak them.

### Companies

**The company go wide and go tall raise is a scouting party**, sized for
exploring rather than fighting: **10% of the town**.

| | Led by |
| :--- | :--- |
| **Small company** | always a **militia** |
| **Big company** | a **commander** — or a militia if the town had **5,000 or fewer** people |

**Both may leave the town.** A militia is not a garrison.

**Every company chooses its own standing order when it is raised**, from **the
state of the map** and **the intent of the governor who raised it**. A company
raised under go wide that sees no threat nearby sets itself to *explore*; others
might *attack Crown troops*, and so on. **`commanders.md` defines this, for a
militia and a commander alike** — a deep design pass of its own, still to come.

**A militia serves a set number of months**, then disbands and **its people
return to the town that raised it**: **12 months**.

**The town feeds its companies** in the field, every month they are out.

This replaces `commanders.md` §2's rule that the order decides whether a
commander is needed.

## 7. The menus

**A PO draft for the Author to correct.** Every threshold is a placeholder, to
live in data (§12) and be tuned there. *Harvested* always means **last month's
yield**, as §5 measures it.

Conditions used below, each an id in the condition registry:

| Condition | Reads |
| :--- | :--- |
| `unexplored_within` *n* | unexplored territory lies within *n* tiles of the town |
| `companies_out_below` *n* | the town is supporting fewer than *n* companies in the field |
| `expeditions_launched_below` *n* | this town has launched fewer than *n* expeditions, ever |
| `outgrows_the_colony` *offset*, *factor* | `(population ÷ 1000 − offset) × factor > towns + active expeditions`, colony-wide |
| `population_at_least` *n* | the town's population, in people |
| `improvements_per_thousand_below` *n* | improvements the town has, per thousand people |
| `harvested_at_least` *resource*, *n* | last month's yield of that resource |
| `coastal` | the town has sea in reach |
| `safety_below` *n* | the town's safety (`quality-of-life.md`), nought to one |
| `quality_of_life_below` *n* | the town's quality of life |
| `no_trade_protest_on` *resource* | no trade protest stands on that resource |

### Go wide

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | **Scouting company** | `unexplored_within 8`, `companies_out_below 1` |
| 2 | **Lean expedition** | `outgrows_the_colony 2 2` |
| 3 | **Tile improvement** — farm or pasture, *wide* scoring | `improvements_per_thousand_below 0.5` |
| 4 | Scouts | — |
| 5 | Dock | `coastal` |
| 6 | Stockade | — |
| 7 | Guard towers | — |
| 8 | Irrigation station | — |
| 9 | Worker cabins | — |
| 10 | Town pasture | — |
| 11 | Fairgrounds | — |
| 12 | Granary | — |
| 13 | Sawmill | `harvested_at_least wood 10` |
| 14 | Stonecutters | `harvested_at_least stone 10` |
| 15 | Windmill | — |
| 16 | River mill | — |
| 17 | Church | — |

**The expedition gate grows with the colony.** `(population ÷ 1000 − 2) × 2`
must exceed the towns there are plus the expeditions already on their way. A
town of 3,000 launches when it is the only town; with six towns and a seventh
being founded, a town waits until it holds 6,000. **The formula is the whole
gate**; there is no cap per town.

**Built for leaving.** Expansion buildings early because every one widens the
land a town can work; wood and stone because every expedition carries them.

### Go tall

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | **Thick expedition** | `expeditions_launched_below 2`, `population_at_least 8000` |
| 2 | **Tile improvement** — farm, pasture or mine, *tall* scoring | `improvements_per_thousand_below 0.4` |
| 3 | **Scouting company** | `unexplored_within 8`, `companies_out_below 1` |
| 4 | Granary | — |
| 5 | Dock | `coastal` |
| 6 | Irrigation station | — |
| 7 | Church | — |
| 8 | Town pasture | — |
| 9 | Theatre | — |
| 10 | Library | — |
| 11 | Stockade | — |
| 12 | Ale house | `no_trade_protest_on beer`, `quality_of_life_below 0.6` |
| 13 | Tea house | `no_trade_protest_on tea`, `quality_of_life_below 0.6` |
| 14 | **Improve yield** (§5) | a candidate exists |
| 15 | Foundry | `harvested_at_least ore 10` |
| 16 | Toolworks | `harvested_at_least iron 4` |
| 17 | College | — |
| 18 | Cathedral | — |
| 19 | Printing press | — |

**Built for staying.** Improve the ground before scouting past it; food held and
grown, then comfort and learning; then whatever gets the most out of the ground
before the works. The metal tree for tools, since a tall town builds a great deal. It
stops at tools — guns are rebellion's.

### Get rich

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | **Tile improvement** — a plantation, mine or farm, by *worth* (§9) | `improvements_per_thousand_below 0.6` |
| 2 | **A trade conversion** — by *worth* (§9) | its input `harvested_at_least 6` |
| 3 | Dock | `coastal` |
| 4 | Wharf | — |
| 5 | Stockade | — |
| 6 | Granary | — |
| 7 | Church | — |
| 8 | **Improve yield** (§5) | a candidate exists |
| 9 | Foundry | `harvested_at_least ore 10` |
| 10 | Toolworks | `harvested_at_least iron 4` |

**No company, no expedition.** Neither earns the town a shilling.

### Military

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | **Big company** | `safety_below 0.5`, `companies_out_below 1` |
| 2 | **Scouting company** | `unexplored_within 8`, `companies_out_below 1` |
| 3 | **Tile improvement** — a fort, *military* scoring | `improvements_per_thousand_below 0.3` |
| 4 | Stockade | — |
| 5 | Guard towers | — |
| 6 | **Big company** | `companies_out_below 1` |
| 7 | Trenches | — |
| 8 | Palisade | — |
| 9 | Scouts | — |
| 10 | Granary | — |
| 11 | Church | — |
| 12 | Dock | `coastal` |
| 13 | Irrigation station | — |

**Military means armies.** The first big company answers a threat; the second is
raised with no threat at all, once the walls are up.

**It buys its guns** (§10), and keeps them in hand through its stockpile (§11).

### Prepare for rebellion

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | **Big company** | `companies_out_below 1` |
| 2 | Stockade | — |
| 3 | Mineworks | `harvested_at_least ore 10` |
| 4 | Foundry | `harvested_at_least ore 10` |
| 5 | Gunsmith | — |
| 6 | Toolworks | `harvested_at_least iron 4` |
| 7 | Palisade | — |
| 8 | Guard towers | — |
| 9 | Trenches | — |
| 10 | Armoury | — |
| 11 | Theatre | — |
| 12 | Library | — |
| 13 | College | — |
| 14 | Printing press | — |

**Men under arms, walls, and guns made at home.** No expedition — a rebel town
never founds one (SPEC §11.4), a filter. No tile improvements and no food
buildings. No dock, no wharf: every shilling of Crown trade is a thread back to
London. Guns made at home, because it cannot count on buying them. **And a
printing press**, which raises rebel sentiment — after the armoury, since the
chain to it is long.

### Education

| # | Objective | Wanted when |
| --: | :--- | :--- |
| 1 | Theatre | — |
| 2 | Library | — |
| 3 | College | — |
| 4 | Stockade | — |
| 5 | Printing press | — |

**Buildings only**, in the order their prerequisites demand: the library needs
the theatre, the college the library, and the printing press the college and the
stockade. No improvements, expeditions or companies.

### Coverage

**Trade conversions and plantations** are get rich's alone. **Fairgrounds** and
**worker cabins** are go wide's. Every building is on at least one menu.

**Every menu ends in *no building*** (§3), which is not listed.

## 8. What each improvement scoring looks for

⚠ **Deferred to an authored session** (#TILES), with the tile-and-site pass
(§14). These stand as placeholders until then. Each is a `choose` scorer in the
registry.

| Scorer | Considers | Picks the tile with |
| :--- | :--- | :--- |
| *wide* | farm, pasture | a farm only where food was harvested last month; the largest food gain |
| *tall* | farm, pasture, mine | the largest gain in food, then ore (the early slot; *improve yield* covers the rest) |
| *worth* (get rich) | plantations, mine, farm | the highest §5 worth, after tax |
| *military* | fort | the border tile facing the nearest threat |

## 9. Get rich — what it chooses between

**The only intent that builds plantations and the trade conversions** —
furriers, weaving shed, rolling house, distillery, brewhouse. Plantations are
pure economy and nobody else wants them.

It chooses **which plantation, or which conversion building**, by §5's *worth*:
where the town gets the most for its outlay, from what it harvested last month,
ranked by what the town receives **after the PC's tax**. A distillery is not
considered by a town that harvested no sugar.

## 10. The metal tree

**Ore → iron → tools and guns** — the mine, mineworks, foundry, toolworks,
gunsmith and armoury — is supported by **go tall, get rich and prepare for
rebellion**.

**Military is not on it, deliberately.** A military town has things to fight; it
does not start smelting ore to win. It **buys its guns** and arms its companies
with them. If the town already makes guns, so much the better, but it will not
set out to.

## 11. Stockpiles

**Every intent raises the town's reserve of some resources**, per thousand
people — the
`stocks` each intent already carries in `objectives.json`, which feed desired
stock (`town-economy.md` §3). A town short of its reserve values the resource
more, and **buys it from the Crown** once it is worth buying.

That is how **military and rebellion keep guns and horses in hand**, and buy
them, even when no company is being armed.

Placeholders, per thousand people, carried over from the old intents and tuned
in M8:

| Intent | Reserve per thousand | From |
| :--- | :--- | :--- |
| Go tall | wood 1.5, stone 1.0, clothing 0.4 | grow the population |
| Go wide | food 2.0, wood 1.0, tools 0.6 | settle a new town |
| Get rich | wood 1.2, stone 0.8, tools 0.4 | increase economic output |
| Military | **guns 1.0, horses 0.5**, food 1.8, stone 1.5 | defences and drive them off, merged; no iron, since it does not smelt |
| Education | wood 1.5, stone 1.0 | new |
| Prepare for rebellion | **guns 0.9, horses 0.5**, iron 0.6, food 2.5, stone 1.2 | unchanged, horses added |

## 12. The data

**Menus and gates are data**, so the Author can reorder a menu or move a
threshold without a code change. As with letters, **a condition in data is an id
into a code-side registry with typed params, never logic.**

```jsonc
// data/colony/agendas.json
{
  "intents": [
    {
      "id": "go_wide",
      "name": "a new settlement",            // placeholder prose
      "stocks": { "wood": 1.2, "food": 2.0 }, // per-intent desired stock, as today
      "menu": [
        { "objective": "scouting_company",
          "when": [ { "is": "unexplored_within", "n": 8 },
                    { "is": "companies_out_below", "n": 1 } ] },
        { "objective": "lean_expedition",
          "when": [ { "is": "outgrows_the_colony", "offset": 2, "factor": 2 } ] },
        { "objective": "improvement", "choose": "wide",
          "when": [ { "is": "improvements_per_thousand_below", "n": 0.5 } ] },
        { "objective": "scouts" }
        // no building is implicit at the end of every menu
      ]
    }
  ]
}
```

- **`menu`** is read top to bottom; the first entry that passes is taken.
- **`when`** conditions must **all** hold. For an *or*, list the same objective
  twice with different conditions.
- **`choose`** names a scorer (§8).

The content validator checks that every objective, condition and scorer id
resolves, every param is typed correctly, and every building's prerequisites sit
higher on the same menu.

## 13. Considerations

**What moves a governor toward one intent or another.** This table is what each
consideration says about each intent; personality is how much each governor
listens to each consideration (below).

Each consideration measures **how much of a problem** one thing is in his town,
**nought to one**. Nought means no problem, and then **the row does nothing** —
it does not push the other way. Its score for an intent is that measure times
the cell:

> *When this is at its worst in my town, how strongly does it push me toward
> this intent?* **+1** strongly toward · **0** nothing to say · **−1** strongly
> away.

It is a push, not a probability: every intent's pushes are summed and the
highest total wins.

**Mandate and urging are not in the table.** Each pulls toward one named intent
— the Crown's, or the one urged — and needs no row.

### The table (Author)

| Consideration | The problem, nought to one | Tall | Wide | Rich | Military | Rebellion |
| :--- | :--- | :-: | :-: | :-: | :-: | :-: |
| `baseline` | **always one** | 0.4 | 0 | 0.3 | 0 | 0 |
| `food_security` | hunger: how far below four months of food the town holds | −0.5 | 0.5 | −1 | 0.2 | 1 |
| `quality_of_life` | how badly the town is living | 0.5 | 0.3 | −0.7 | 0 | 1 |
| `wealth` | **replaces `revenue`**: how far the town's wealth per thousand people falls short of comfortable | 0 | 0 | 1 | 0 | 0 |
| `safety` | **replaces `native_threat`**: how unsafe the town is, from any foe — natives, a duke, Crown troops | −0.2 | −0.3 | −1 | 1 | 0.5 |
| `room_to_grow` | unclaimed land the colony can see | −0.2 | 1 | −0.4 | −0.5 | 0 |
| `crowding` | people per tile of land, against 2,000 comfortable | −0.8 | 0.8 | 0.4 | 0.6 | 1 |
| `loyalty` | **new**: how far the governor's loyalty has fallen — nought at neutral (50) or above, one at rock bottom | −0.5 | 0 | −0.5 | 0 | 1 |

**The baseline is what an untroubled town wants.** Tall and rich serve towns
*without* problems, and in a town with none every problem row reads nought — so
without the baseline they could win only through the mandate or a letter. Like
every row, it is multiplied by the governor's weight, so how much a man wants a
quiet life of building or trade is part of his personality.

**Checked against six towns** (PO, weights at one): a quiet prosperous town goes
tall; a crowded, hungry one goes wide; one under threat goes military; a young
one with room to spare goes wide; a poor, content one goes rich; a governor at
the loyalty floor goes for rebellion.

### Wealth

**How much wealth people crave.** Get rich now serves the town's own profit, so
it reads the town's own purse, not the Crown's revenue.

```
wealth per thousand = the town's total gold value / (weighted population ÷ 1000)
craving             = clamp(1 − wealth per thousand / comfortable, 0, 1)
```

- **Total gold value** — **its gold only**. Stores are not wealth.
- **Weighted population** — a worker counts one, **an expert a thousand**, and
  livestock nothing. Here only; everywhere else an expert is one person
  (`population.md` §2).
- **Comfortable** — **60 gold per weighted thousand**, a placeholder: twice the
  purse quality of life calls comfortable (`quality-of-life.md`, means).

Placeholders, all three; this belongs to a much larger tuning.

### Filters

Applied before scoring. A filtered intent cannot be chosen, whatever its total.

| Intent | Reachable only |
| :--- | :--- |
| **Prepare for rebellion** | at or below the loyalty floor |
| **Education** | while a Provost or scholar urging stands. It has no cells, so without this it would score nought — and nought wins whenever every other intent totals below it |

**Go wide has no filter.** The old rule that a town cannot intend to settle when
the colony sees no unclaimed land is **dropped**: go wide's first move is a
scouting company to *find* land, and an expedition still needs a site before it
can leave (`founding-towns.md` §5).

**Hunger pushes a town out, not up.** A hungry town is discouraged from going
tall: its people want to pack up and go where food comes easily. Food grows
scarce when the town grows crowded, and the table reads both that way.

**`room_to_grow` is the one row that is an opportunity, not a problem.** It is
colony-wide: the share of the land the colony has **seen** that lies outside
every town's border. Scouting raises it by revealing land; founding lowers it by
claiming land. Every town in the colony reads the same figure.

**`native_land` is gone as a consideration.** Native land will matter in
choosing which tiles to work and where an expedition goes (§14).

### How personality shapes it

**A governor's personality is one weight per consideration**, drawn when he is
generated — between **0.5 and 1.6**, from his own seeded stream — and fixed for
his life (`deliberation.md` §4). Each month, for each intent the filters allow:

```
total = Σ over considerations ( his weight × measure × cell )
        + mandate pull + urging pull
```

The highest total is his intent. Ties break on the intent's id.

So **personality decides what he is sensitive to, not what he likes.** A man
with a heavy weight on `safety` reaches for military at the first sign of a foe,
and his neighbour with a light one shrugs at the same foe.

**In a quiet town the baseline speaks**, and his weight on it is how much he
wants a quiet life of building and trade. Past that, the mandate or the PC's
letter decides.

**Nobody ignores a consideration**, and nobody reads one backwards. The table's
signs are the same for every governor; personality only scales them.

His **temperament** — mettle, pity, vanity — is separate. It shapes how he takes
the PC's orders (compliance), not which intent he holds.

## 14. 📌 Pinned

**Tribes react to what the colony does near them**: land worked, improvements
built, companies on their ground. They should **write to the governor**, who
may write to the PC, before they decide what to do. That is a tribes design pass
of its own, not this doc's.

**Choosing a tile for an improvement, and a site for an expedition.** Both need
their own pass: which tiles are best by each intent's lights (§8), and where a
new town should go. **Native land comes into play here** — ground a tribe holds
is weighed when choosing where to build and where to settle — which is why it is
no longer a consideration on intent (§13).
