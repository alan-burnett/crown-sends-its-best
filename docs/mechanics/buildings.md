# Mechanics — Buildings

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 (buildings and the tree), §10.1 (resources), §12.1,
> §12.2, and the Squeeze pillar.

---

## 1. The branches are a map, not a rule

The tree is drawn in seven branches — **food, trade, defence, expansion,
comfort, education, construction** — so a reader can find a building.

**They no longer decide what a governor builds.** Each intent has its own
ordered menu of objectives (`governor-agendas.md` §7), and a building is wanted
by whichever menus list it, at whatever place. The dock and the granary are on
both go wide's and go tall's; the metal tree is on go tall's, get rich's and
rebellion's; the trade conversions are get rich's alone.

There was once a rule that the branches **were** the axes a governor's intent
weighted. The axis model is retired, and the rule with it. **Every building is
on at least one menu** — the content validator checks that, and that every
building sits below its prerequisites on each menu that lists it.

## 2. The town hall

**Every town has one from the moment it is founded.** It is never built, never
chosen, never disabled, and destroyed only when the town itself is.

Its job is to **define the base conversion ratios** (§6), which means the base
case is not a special case in code — it is a building like any other, and the
rule stays uniform: *the best building the town has for a conversion sets its
terms.*

It carries **no cost and no upkeep**, and it is the natural anchor for town-wide
effects added later.

## 3. Rules that hold for every building

**Costs are wood, stone, iron and tools.** Nothing costs food, and nothing costs
gold to raise. See §5 for what tools do to the shape of the tree.

**Build time is not authored.** A town has a **build capacity** — resources per
month it can put into construction, derived from its population and multiplied by
any `build_speed` a policy grants — no building grants it since the crane went
(#327). Duration is cost divided by capacity, so a large town
raises a granary in weeks and a hamlet labours over it for a year.

**🔒 Nothing in the tree speeds building.** Improvements answer to **worker
cabins** (`tiles-and-improvements.md` §4) and have their own reason to exist;
buildings have no counterpart and want none.

**Build speed is a policy's business, not a building's** — Author's ruling
(#327). A building whose only effect is *build faster* is a building a governor
can never sensibly want, because everything it would accelerate outscores it.

**Upkeep disables; it never destroys.** Many buildings cost the town gold every
month. A town that cannot pay **keeps the building and loses the effect**, and it
switches back on the moment it can afford it again. Upkeep is a squeeze, not a
punishment.

**Four buildings bring a contact, and three more extend one.** The church brings
the clergy, the gunsmith the quartermaster, the printing press the journalist and
the library the scholar. The cathedral, armoury and college **widen what those men
can do rather than adding anyone**. No other building brings a contact — one whose
man would have nothing unique to offer brings none, which is why the theatre does
not. See `institutional-contacts.md`.

**There is no *nearby*.** A building affects **one town or every town**, and no
distance is ever considered. People travel to the fair from anywhere in the
colony. This is deliberate: it saves an entire distance system and nothing in the
design has yet wanted one.

**Colony-wide effects do not stack.** Each town gets one *somebody has a
fairgrounds* bonus regardless of how many exist. A second one buys only its own
local effects.

**Quality of life is reached through its components, never as a flat number.** A
building raises health, or pleasure, or perceived safety. A raw `+2 quality of
life` would bypass variety, saturation and masking all at once, in the same way a
blanket reserve bypassed valuation.

**Reserve effects are per-resource.** A building that gives the town a use for
something should raise that resource's desired stock, or the town will go on
selling the very thing the building now needs.

## 4. The tree

Upkeep is **none / low / medium / high**; the gold figures behind those are
tuning.

### Food

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **dock** | 30 wood | low | Sea and ocean tiles yield more food | — |
| **irrigation station** | 20 wood, 20 stone, 4 tools | medium | Grassland and plains yield more food, **doubled where there is a farm** | — |
| **windmill** | 20 stone, 10 wood, 8 tools | medium | Bonus yield from farms | irrigation station |
| **river mill** | 20 wood, 10 stone, 8 tools | medium | Bonus yield from farms | irrigation station |
| **town pasture** | 20 wood | none | Supports livestock, as the pasture improvement does | — |
| **granary** | 30 wood | low | Natural population growth is faster, livestock included. Raises food's desired stock | — |

Windmill and river mill do the same thing at **mirrored costs**, so a wood-rich
town reaches one first and a stone-rich town the other. A large town eventually
wants both: food capacity has to keep climbing as a town grows.

**The pasture and the granary moved here from the old capacity branch.** Both are
food — livestock, and food held against a lean month — and the granary's faster
births count as food too, because a well-fed town is a growing one.

### Trade

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **wharf** | 50 wood, 20 stone, 4 tools | **none** | All gold received in trade with the Crown **+10%** | dock |
| *conversion buildings* | 40 wood, 10 stone, 10 iron, 8 tools | medium | See §6 | — |
| **gunsmith** | 20 iron, 20 stone, 20 wood, 25 tools | **high** | **Allows guns to be made at all** — the only gated conversion. Brings the **quartermaster** | foundry |

### Defence

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **stockade** | 40 wood | none | Defence | — |
| **palisade** | 30 stone, 40 wood, 10 iron, 4 tools | low | More defence | stockade |
| **guard towers** | 20 stone, 20 wood, 2 tools | medium | Defence, **town vision**, and **town influence** — the tiles it can work | stockade |
| **trenches** | 15 stone, 15 wood | none | Defence | stockade |

### Expansion

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **scouts** | 20 wood, 2 tools | low | Expeditions from this town are safer and start better supplied. **Town influence** | — |
| **worker cabins** | 40 wood, 10 stone, 2 tools | medium | Improvements build faster and **cost no upkeep**. **Town influence** | scouts |
| **fairgrounds** | 40 wood, 30 stone | medium | Immigration, local amusement, **town influence**, and quality of life **to every town that has none** | town pasture, stockade |

**Town influence is the expansion branch's signature** — every building on it
grants more land to work — and guard towers quietly share it, so a governor
building for defence gets an economy as a side effect.

### Comfort

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **church** | 30 wood, 10 stone | low | Amusement, **perceived safety**, brings the **clergy** | — |
| **cathedral** | 120 stone, 15 tools | high | Increases the church's effect, and extends **safety and amusement to every town without a church**, and **widens what the clergy can do** — but brings no second contact | church |
| **theatre** | 20 stone, 30 wood, 4 tools | medium | Amusement. Attracts experts | — |
| **tea house** | 20 wood, 10 stone | **none** | More quality of life from tea. Raises tea's desired stock | — |
| **ale house** | 20 wood, 10 stone | **none** | More quality of life from beer. Raises beer's desired stock | — |
| **printing press** | 10 stone, 10 wood, 10 iron, 25 tools | **high** | Attracts experts. Amusement **in every town**. **Raises rebel sentiment.** Brings the **journalist** | college, stockade |

### Education

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **library** | 30 wood, 10 stone | medium | Amusement. **Turns resident experts into education**, so experts here generate more experts. Brings the **scholar**, who moves experts between towns | theatre |
| **college** | 50 wood, 30 stone, 20 iron, 15 tools | **high** | Extends the **scholar**. **Experts elsewhere count here** — three tobacco experts in three towns make this town work as though it held all three, education included | library |

**The branch the Provost argues for** (#401). The **education** intent builds
theatre, library, college and printing press, in that order
(`governor-agendas.md` §7).

### Construction

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **stonecutters** | 20 wood, 20 iron, 15 tools | medium | More stone | — |
| **sawmill** | 20 stone, 20 iron, 15 tools | medium | More wood | — |
| **mineworks** | 20 wood, 20 stone, 15 tools | medium | More ore | — |

**What the tree is built from.** Every one of these yields a resource that
appears in some building's cost. On go tall's and get rich's menus they are
weighed in **improve yield**, against the mills, irrigation, farms and mines, by
what each would have added to this month's harvest for its cost
(`governor-agendas.md` §5).

Stonecutters and sawmill each cost the resource the other produces, which makes
them a natural pair rather than a choice.

## 5. Tools

Tools are the only build cost the colony has to **make**. Wood and stone come off
a tile; iron is one conversion deep. Tools sit **two** conversions deep — ore to
iron, iron to tools — and that changes what the tree means.

### What it buys the design

**The deep chain gets a domestic customer.** Before this, ore to iron to tools
existed to sell to the Crown, to supply an expedition, or to tempt a tribe
(§10.1). Now the colony's own growth eats them, so the construction branch —
mineworks, then the foundry, then the toolworks — pays for itself in
construction rather than in gold.

**And it taxes haste without gating anything.** A new town has no foundry and no
toolworks, so it makes tools on the town hall's dismal base terms — ten ore to a
bar of iron, three bars to a tool — or it buys them. Neither is a wall. But the
patient town grinds its own and the impatient one buys from the Crown, which is
dependence arriving by the front door rather than through a lock.

**The mineworks is where that bites hardest.** It costs fifteen tools, and it is
the building that makes ore plentiful enough to make tools — roughly four hundred
and fifty ore at base terms to buy your way out of needing to buy. Nothing is
locked, because ore comes off a tile without it and the mineworks only raises the
yield. But a town that wants to mine in earnest buys its entry from the Crown,
and the Crown is therefore selling the means of not needing the Crown. That is
the Squeeze in a single building.

### 🔒 Measured, and the bands stand

The bands were once reported as a wall (#192): every town completed **exactly
one** building and ended holding `ore 0, iron 0, tools 0`.

**That measurement was void.** It was taken thirty-five minutes before the fix
that derives conversion throughput from the ratio (`building.gd`, #185) — so
every conversion in it ran at half rate, and tools are two conversions deep, so
they came out at roughly a quarter. The wall was the defect, not the prices.

Re-measured on the same terms, three seeds, five years:

| | then | now |
| :--- | --: | --: |
| buildings completed | **1** | **13** |
| tools held at year five | **0** | **~93** |

A town now raises the mineworks, the stonecutters, the sawmill and the college —
four of the five *works*-band buildings — **and has ninety tools spare**. Nothing
in §5 needs repricing, and lowering the bands on the old figures would have left
the tree far too cheap.

**What did not change is more interesting**, and it is §11's business rather than
this section's: the buildings a town never gets to are not the expensive ones.

**Nothing gates the way out, and that is the point.** A conversion building is
eight tools and ten iron, reachable by any town that has ground through enough
ore to afford one. There is no cheap entry fee ahead of it and no cheaper thing
to build first.

An earlier draft put a **crane** in front of all nine at four tools, meaning the
route out to be *cheap to start and expensive to finish*. It failed in play: the
crane's only effect was build speed, so a governor scored it at **0.07** against
a foundry at **5.13** and never reached for it — and nine buildings sat behind
the one thing nobody wanted (#327). **The counterweight was the gate, and the
gate was the whole problem.**

### Which buildings cost them

**Wood and stone are what a town gathers; iron and tools are what it makes.** A
building that is carpentry or masonry costs the first pair. A building with a
mechanism, a precision or metalwork in it costs tools.

| Band | Tools | Buildings |
| :--- | --: | :--- |
| Fittings | 2 | guard towers, scouts, worker cabins |
| Gearing | 4 | irrigation station, wharf, palisade, theatre |
| Machinery | 8 | windmill, river mill, conversion buildings |
| Works | 15 | mineworks, stonecutters, sawmill, college, cathedral |
| Precision | 25 | gunsmith, printing press |

**The top band costs twelve times the bottom one.** That spread is the point:
tools are what separate a frontier town from an industrial one, and no amount of
patience with wood and stone closes the gap.

### What costs none, and why the list matters

**dock, granary, town pasture, library, fairgrounds, church, tea house, ale
house, stockade, trenches.** Sheds, barns, earthworks and faith.

Read it once for what it is and once for what it does, because it says what a
town can still raise when it is cut off. **The two cheapest defences cost no
tools at all.** A town under blockade, embargo or siege can always throw up a
stockade and dig trenches, and every branch keeps one building a poor town can
still reach. That is deliberate: this is the one place the tree refuses to
compound a crisis.

## 6. Conversions

**A building does not multiply a conversion — it defines its terms.** Two dials
move independently:

| Dial | What it is |
| :--- | :--- |
| **ratio** | Input per unit of output. Lower is better |
| **throughput** | How much input one worker puts through in a month |

### The base is anchored on the output

**A town worker makes two of the processed good.** That is the anchor, and
everything else is derived from it: at a ratio of 3:1 he consumes six to make his
two, at 10:1 he consumes twenty.

Anchoring on the *output* rather than the input is what makes the table below
fall out of a single number. Experts, buildings and whatever comes later are
multipliers arriving on top of it.

**Two is a ceiling, not a promise.** A worker with less input than his recipe
wants makes proportionally less, so a smelter in a town with six ore produces
0.6 iron rather than failing. Nobody stands idle for want of a full batch.

A conversion building **doubles the throughput and improves the ratio**, because
a tool factory is shipped far more iron than a village blacksmith ever was.

| Conversion | Building | Base | With the building |
| :--- | :--- | :--- | :--- |
| tobacco → cigars | **rolling house** | 6 → 2 | 12 → 6 *(2:1)* |
| ore → iron | **foundry** | 20 → 2 | 40 → 8 *(5:1)* |
| furs → clothing | **furrier's** | 6 → 2 | 12 → 6 *(2:1)* |
| cotton → clothing | **weaving shed** | 10 → 2 | 20 → 6.7 *(3:1)* |
| sugar → rum | **distillery** | 20 → 2 | 40 → 8 *(5:1)* |
| food → beer | **brewhouse** | 8 → 2 | 16 → 8 *(2:1)* |
| iron → tools | **toolworks** | 6 → 2 | 12 → 6 *(2:1)* |
| iron → guns | **armoury** — extends the quartermaster | 6 → 2 | 12 → 6 *(2:1)* |

Every ratio here is authored; **every throughput is derived.** Base throughput is
`2 x ratio` and a building's is twice that, so a change to a ratio carries its
own throughput with it and the two columns cannot drift apart.

**There is no second tier.** One building per conversion, and that is the whole
improvement available.

### What a conversion building is worth to a governor

**The trade conversions** — furriers, weaving shed, rolling house, distillery,
brewhouse — **are get rich's alone**. It weighs them against plantations by what
each would add for its cost, after the PC's tax, and **never considers one whose
input it did not harvest last month** (`governor-agendas.md` §9).

**The metal chain** — foundry, toolworks, gunsmith, armoury — sits on go tall's,
get rich's and rebellion's menus, gated on ore or iron harvested. **Military does
not smelt**: it buys its guns (§10 of that doc).

The old rule, that a conversion was worth its margin on trade, construction and
comfort axes, went with the axes. It existed because the old scorer could not
see a conversion at all (#311); a menu cannot miss one.

**The worst conversions improve most.** Ore to iron and sugar to rum quadruple
their output; the 3:1 chains merely triple theirs. That falls out of the rule
rather than being designed, and it is the right shape — the expensive chains are
the ones worth investing in.

**Prices are balanced around these ratios**, so they are a fixed point the
economy rests on rather than a tuning value free to drift.

### Guns are the one gate

Every other conversion runs without any building at all. **Guns require a
gunsmith**, and the armoury that improves them requires the gunsmith in turn,
which requires the foundry.

Guns are the right thing to gate: they arm the militia, they are what SPEC §10.1
says the natives covet most, and a colony that could arm itself with no
investment would have skipped a decision that ought to cost something.

## 7. Amusement

**Amusement is pleasure without trade.** It feeds quality of life through the
same path as a consumed luxury, and it counts as a distinct type for the variety
bonus — a town with beer and a theatre is better off than a town with beer alone.

What makes it strategically different is that **it cannot be embargoed.** Beer
and rum arrive through Exchange and can be cut off by a trade protest, a
blockade, a rebellion, or simply having no gold. A theatre cannot.

**And it makes bread and circuses buildable.** `quality-of-life.md` has pleasure
masking the shortfall, strongest when life is worst. Amusement builds that
masking permanently into a town, so a colony the PC cannot feed can be given
something to watch and will be **measurably, truthfully content** about it.

That is the satire in SPEC §3.2 working as designed and it should not be balanced
away. Upkeep is its counterweight: a town too poor to pay watches its amusements
go dark in the same month its larder empties.

## 8. The two comfort traps

**Tea house and ale house are the same building weighed against different
dangers**, and the pair is the sharpest thing in the tree.

| | Raises quality of life from | Weighed against |
| :--- | :--- | :--- |
| **tea house** | tea, which the colony **can never produce** | **dependence** on the Crown |
| **ale house** | beer, which is made from **food** | **hunger** |

Neither costs upkeep, because the building is not the cost — **the habit is.** A
tea house makes a town need the very thing a duty on tea can take away, and an
ale house sets its pleasure in direct competition with its supper.

## 9. What is inert, and until when

| Works now | Small additions | M4 — population | M5 — safety | M6 — defence |
| :--- | :--- | :--- | :--- | :--- |
| stonecutters, sawmill, mineworks, town pasture, conversion buildings, gunsmith, granary *(reserve)*, tea house, ale house | dock, irrigation station, windmill, river mill, wharf, guard towers *(vision, influence)* | fairgrounds, theatre, printing press, library, college, scouts, worker cabins, granary *(growth)* | church, cathedral *(perceived safety)* | stockade, palisade, trenches, guard towers *(defence)* |

**Roughly two thirds of the tree does nothing yet**, which is fine but means an
M3 playtest exercises the construction and trade branches only.

## 10. Tuning targets

- The four upkeep tiers in gold.
- Build capacity per thousand people.
- Every effect magnitude — yields, amusement, influence, growth.
- Whether a developed town can actually afford its own upkeep. Fifteen buildings
  at medium is a great deal of gold a month, and a large town browning out every
  winter is either the Squeeze working or a tuning failure.

## 11. Open items

- **The wharf looks underpriced.** A permanent **+10% on all Crown trade for no
  upkeep** partly offsets the duty forever, and at 50 wood and 20 stone it is an
  automatic build for any town that trades. Worth watching in the harness.
- Whether a **second** conversion building tier is ever wanted. Currently not.
- Whether the journalist's prestige contribution wants a cap, so a PC cannot
  build a press in every town and print his way to a score
  (`institutional-contacts.md` §6).
- How the printing press's rebel sentiment compares with its amusement. It is the
  clearest case of a building that is worth having and dangerous to own, and it
  should be tuned so that both are true.
