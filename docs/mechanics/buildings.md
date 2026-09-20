# Mechanics — Buildings

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 (buildings and the tree), §10.1 (resources), §12.1,
> §12.2, and the Squeeze pillar.

---

## 1. The branches are the intent axes

The tree has six branches — **food, trade, defence, expansion, comfort,
capacity** — and those are exactly the axes a governor's intent weights in
`governor-objectives.md`.

So a branch is not a label. **It is the intent that will pursue it.** A governor
set on defence walks the stockade line; one set on growing his population wants
comfort and capacity. The tree and the deliberation kernel speak the same
language by construction, and that should survive any later reshuffle.

## 2. The town hall

**Every town has one from the moment it is founded.** It is never built, never
chosen, never disabled, and destroyed only when the town itself is.

Its job is to **define the base conversion ratios** (§5), which means the base
case is not a special case in code — it is a building like any other, and the
rule stays uniform: *the best building the town has for a conversion sets its
terms.*

It carries **no cost and no upkeep**, and it is the natural anchor for town-wide
effects added later.

## 3. Rules that hold for every building

**Costs are wood, stone and iron.** Nothing costs food, and nothing costs gold to
raise.

**Build time is not authored.** A town has a **build capacity** — resources per
month it can put into construction, derived from its population and multiplied by
`build_speed` effects. Duration is cost divided by capacity, so a large town
raises a granary in weeks and a hamlet labours over it for a year.

**Upkeep disables; it never destroys.** Many buildings cost the town gold every
month. A town that cannot pay **keeps the building and loses the effect**, and it
switches back on the moment it can afford it again. Upkeep is a squeeze, not a
punishment.

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
| **irrigation station** | 20 wood, 20 stone | medium | Grassland and plains yield more food, **doubled where there is a farm** | — |
| **windmill** | 20 stone, 10 wood | medium | Bonus yield from farms | irrigation station |
| **river mill** | 20 wood, 10 stone | medium | Bonus yield from farms | irrigation station |

Windmill and river mill do the same thing at **mirrored costs**, so a wood-rich
town reaches one first and a stone-rich town the other. A large town eventually
wants both: food capacity has to keep climbing as a town grows.

### Trade

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **wharf** | 50 wood, 20 stone | **none** | All gold received in trade with the Crown **+10%** | dock |
| *conversion buildings* | 40 wood, 10 stone, 10 iron | medium | See §5 | crane |
| **gunsmith** | 20 iron, 20 stone, 20 wood | **high** | **Allows guns to be made at all** — the only gated conversion | foundry |

### Defence

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **stockade** | 40 wood | none | Defence | — |
| **palisade** | 30 stone, 40 wood, 10 iron | low | More defence | stockade |
| **guard towers** | 20 stone, 20 wood | medium | Defence, **town vision**, and **town influence** — the tiles it can work | stockade |
| **trenches** | 15 stone, 15 wood | none | Defence | stockade |

### Expansion

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **scouts** | 20 wood | low | Expeditions from this town are safer and start better supplied. **Town influence** | — |
| **worker cabins** | 40 wood, 10 stone | medium | Improvements build faster and **cost no upkeep**. **Town influence** | scouts |
| **fairgrounds** | 40 wood, 30 stone | medium | Immigration, local amusement, **amusement to every town**, and **town influence** | town pasture, stockade |

**Town influence is the expansion branch's signature** — more land to work — and
guard towers quietly share it, so a governor building for defence gets an economy
as a side effect.

### Comfort

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **church** | 30 wood, 10 stone | low | Amusement, **perceived safety**, brings a clergyman | — |
| **cathedral** | 120 stone | high | Increases the church's effect, and extends **safety and amusement to every town without a church** — but not the contact | church |
| **theatre** | 20 stone, 30 wood | medium | Amusement. Attracts experts | — |
| **tea house** | 20 wood, 10 stone | **none** | More quality of life from tea. Raises tea's desired stock | — |
| **ale house** | 20 wood, 10 stone | **none** | More quality of life from beer. Raises beer's desired stock | — |
| **printing press** | 10 stone, 10 wood, 10 iron | **high** | Attracts experts. Amusement **in every town**. **Raises rebel sentiment.** Brings a contact | college, stockade |

### Capacity

| Building | Cost | Upkeep | Effect | Needs |
| :--- | :--- | :--- | :--- | :--- |
| **town pasture** | 20 wood | none | Supports livestock, as the pasture improvement does | — |
| **granary** | 30 wood | low | Natural population growth is faster, livestock included. Raises food's desired stock | — |
| **crane** | 30 wood, 20 iron | low | Build speed | — |
| **stonecutters** | 20 wood, 20 iron | medium | More stone | — |
| **sawmill** | 20 stone, 20 iron | medium | More wood | — |
| **mineworks** | 20 wood, 20 stone | medium | More ore | — |
| **library** | 30 wood, 10 stone | medium | Amusement. **Experts here generate more experts.** Brings a contact who wants them spread about the colony | theatre |
| **college** | 50 wood, 30 stone, 20 iron | **high** | **Experts elsewhere count here** — three tobacco experts in three towns make this town work as though it held all three | library |

Stonecutters and sawmill each cost the resource the other produces, which makes
them a natural pair rather than a choice.

## 5. Conversions

**A building does not multiply a conversion — it defines its terms.** Two dials
move independently:

| Dial | What it is |
| :--- | :--- |
| **ratio** | Input per unit of output. Lower is better |
| **throughput** | How much input one worker puts through in a month |

The base is **one batch per worker**, set by the town hall. A conversion building
**doubles the throughput and improves the ratio**, because a tool factory is
shipped far more iron than a village blacksmith ever was.

| Conversion | Building | Base | With the building |
| :--- | :--- | :--- | :--- |
| tobacco → cigars | **rolling house** | 3 → 1 | 6 → 3 *(2:1)* |
| ore → iron | **foundry** | 10 → 1 | 20 → 4 *(5:1)* |
| furs → clothing | **furrier's** | 3 → 1 | 6 → 3 *(2:1)* |
| cotton → clothing | **weaving shed** | 5 → 1 | 9 → 3 *(3:1)* |
| sugar → rum | **distillery** | 10 → 1 | 20 → 4 *(5:1)* |
| food → beer | **brewhouse** | 4 → 1 | 8 → 4 *(2:1)* |
| iron → tools | **toolworks** | 3 → 1 | 6 → 3 *(2:1)* |
| iron → guns | **armoury** | 3 → 1 | 6 → 3 *(2:1)* |

**There is no second tier.** One building per conversion, and that is the whole
improvement available.

**The worst conversions improve most.** Ore to iron and sugar to rum quadruple
their output; the 3:1 chains merely triple theirs. That falls out of the rule
rather than being designed, and it is the right shape — the expensive chains are
the ones worth investing in.

**Prices are balanced around these ratios**, so they are a fixed point the
economy rests on rather than a tuning value free to drift.

### Guns are the one gate

Every other conversion runs without any building at all. **Guns require a
gunsmith**, and the armoury that improves them requires the gunsmith in turn,
which requires the foundry, which requires the crane.

Guns are the right thing to gate: they arm the militia, they are what SPEC §10.1
says the natives covet most, and a colony that could arm itself with no
investment would have skipped a decision that ought to cost something.

## 6. Amusement

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

## 7. The two comfort traps

**Tea house and ale house are the same building weighed against different
dangers**, and the pair is the sharpest thing in the tree.

| | Raises quality of life from | Weighed against |
| :--- | :--- | :--- |
| **tea house** | tea, which the colony **can never produce** | **dependence** on the Crown |
| **ale house** | beer, which is made from **food** | **hunger** |

Neither costs upkeep, because the building is not the cost — **the habit is.** A
tea house makes a town need the very thing a duty on tea can take away, and an
ale house sets its pleasure in direct competition with its supper.

## 8. What is inert, and until when

| Works now | Small additions | M4 — population | M5 — safety | M6 — defence |
| :--- | :--- | :--- | :--- | :--- |
| crane, stonecutters, sawmill, mineworks, town pasture, conversion buildings, gunsmith, granary *(reserve)*, tea house, ale house | dock, irrigation station, windmill, river mill, wharf, guard towers *(vision, influence)* | fairgrounds, theatre, printing press, library, college, scouts, worker cabins, granary *(growth)* | church, cathedral *(perceived safety)* | stockade, palisade, trenches, guard towers *(defence)* |

**Roughly two thirds of the tree does nothing yet**, which is fine but means an
M3 playtest exercises the capacity and trade branches only.

## 9. Tuning targets

- The four upkeep tiers in gold.
- Build capacity per head of population.
- Every effect magnitude — yields, amusement, influence, growth.
- Whether a developed town can actually afford its own upkeep. Fifteen buildings
  at medium is a great deal of gold a month, and a large town browning out every
  winter is either the Squeeze working or a tuning failure.

## 10. Open items

- **The wharf looks underpriced.** A permanent **+10% on all Crown trade for no
  upkeep** partly offsets the duty forever, and at 50 wood and 20 stone it is an
  automatic build for any town that trades. Worth watching in the harness.
- Whether a **second** conversion building tier is ever wanted. Currently not.
- What the library's contact and the cathedral's "more with the contact" actually
  unlock. Both are M7.
- How the printing press's rebel sentiment compares with its amusement. It is the
  clearest case of a building that is worth having and dangerous to own, and it
  should be tuned so that both are true.
