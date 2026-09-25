# Mechanics — Rival Pressure

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.4, §12.4, §14.1, §10.2, §11.2, and the Squeeze pillar.

---

## 1. A duke is an ordinary contact with his values inverted

**Almost nothing here is new machinery.** A rival duke has a name, a personality
and a **loyalty** like every other contact, moved by the same deeds through the
same path. What differs is only what he `cares_about`.

> **They want the PC paying and weak.**

| Moves his loyalty | Direction |
| :--- | :--- |
| The colony prospering | **down** |
| The PC refusing tribute | **down** |
| The PC paying tribute | **up** |

`GRANTED`, `REFUSED`, `DELIVERED` and `PROMISE_BROKEN` already carry the weights.
A duke needs no new deed and no second scalar.

### Which makes loyalty a protection racket, and the game never says so

The word doing double duty — a governor's regard and a duke's satisfaction with
his cut — is the joke, and it costs nothing to make because loyalty is one number
read differently by role.

**A "loyal" rival is not a friend. He is a man who is being paid.**

## 2. Prospering is what he can see

Prosperity here means **towns, population and territory** — what a duke observes
from across a border.

**It is not net gold.** The Crown's ledger is the Crown's, and a rival has no
sight of it. That distinction matters beyond flavour: if rival aggression read
net position, the same number would drive Crown Standing, prestige *and* the
rivals, and the player would be punished three ways for the single thing the
Crown demands of him. Prosperity and profit are different quantities and the
rivals watch only the first.

So a wide, populous colony draws rivals down whether or not it ever turned a
penny — and a small, ruthlessly profitable one is left comparatively alone.

## 3. The four bands

| Loyalty | What he does |
| :--- | :--- |
| **High** | Asks **reasonable** tribute. A missed payment costs loyalty, and he lets it go |
| **Medium** | Asks **dearer** tribute, and is far less forgiving of a missed payment |
| **Low** | **Attacks improvements.** Parks ships and soldiers on the colony's tiles so they cannot be worked. May strike expeditions and units |
| **Minimum** | Open war on towns and units, freely, **and there is no way back** |

Bands are read from the one loyalty value, exactly as `crown-standing.md` reads
its four stages from standing. No second state machine.

### 🔒 Minimum is a latch

Once a duke reaches the bottom he is **there for the run**, whatever his loyalty
does afterwards. Paying him no longer helps; there is nothing left to buy.

This is the same shape `natives.md` gives a tribe that has come to believe it is
to be eradicated, and the two docs mean it the same way: **a point of no return
that the player can see coming and cannot reverse.** Everything above it is
recoverable, which is what makes crossing it matter.

## 4. Paying works, and it is the most expensive thing in the game

Appeasement is **genuinely effective**. Paying raises loyalty, which keeps the
duke in the band where his demands are cheap and his patience is long. A player
who pays promptly can hold a rival at High for decades.

It also costs twice, and both costs are permanent:

- **The gold leaves `net_position`**, which lowers Crown Standing *and* prestige
  together (`prestige.md` §3).
- **Tribute is an optic** (§14.1). A fixed, undecaying debt against the PC's
  score, on top of the money.

> A PC can be solvent, meeting every Crown demand, and still despised at court
> for having paid a foreigner to leave him alone.

So **the safest course for the colony is the ruinous one for the score.** The man
who buys forty years of peace retires a pauper in the Crown's eyes, and the man
who refuses keeps his reputation and may lose his towns. That is the Squeeze
arriving from a direction the Crown's own demands cannot reach.

**This is why tribute is not dead content.** The obvious reading of §8.4 —
*accepting defers attack but never buys peace* — suggests never paying. The bands
are what make paying a real strategy rather than a trap, and the double cost is
what stops it being the only one.

### There is exactly one third door

A patron whose specialty is rivals can arrange for a demand to be answered with
neither gold nor a refusal — the duke is sent to collect from the patron's house
and his men are arrested there. It costs no loyalty, because he never puts it
together, and it costs no optic, because nothing was paid.

**It is the only answer to a tribute demand that costs nothing**, it is available
only while such a patron is present, and it is worth two demands. See
`patrons.md` §5.

## 5. Tile denial

**The low band's signature, and the one genuinely new mechanic here.**

A duke parks ships and soldiers on tiles inside a town's influence area (§11.2).
Those tiles **cannot be worked** — Work simply has no hands to assign to them —
and the town's yields fall accordingly.

It is not combat. Nothing is destroyed, nobody dies, **no defeat is scored**, and
so no optics debt is incurred. The colony is merely poorer, month after month,
for as long as he sits there.

Three things make it the right mechanic for this band:

- **It is visible.** The player watches it happen on the map and knows exactly
  which tiles and which town. §11.2's lock that the map shows only what the
  colony knows is satisfied — soldiers on your own doorstep are not a secret.
- **It is proportionate.** A duke short of open war can hurt the colony
  materially without the escalation that open war implies, which is what the
  spread between Low and Minimum needs in order to mean anything.
- **The only instrument is a letter with money in it.** The PC cannot order it
  cleared; he can raise the duke's loyalty until he leaves. That is the Rule by
  Correspondence pillar with nothing else to hide behind.

It also lands somewhere nothing else has touched: **the Work phase's tile list**,
rather than population or stockpiles. A town under denial is not being hurt, it
is being *diminished*, and its governor's letters should read differently for it.

**And the governor is how the PC finds out.** `contacts.md` §6: the victim writes.
There is no blockade bulletin — the man whose fields they are asks the PC to deal
with these people, and the ask is also how the player learns that tile denial
exists and that money answers it.

## 6. A duke arrives as the Squeeze's fourth dimension

**Prospering does not attract rivals.** A duke arrives because the Squeeze has
decided to put a new strain on the player — and that decision is already
specified. It is **`crown-demands.md` §6, dimension 4, *more hands out***, whose
catalogue of new sources names rival dukes alongside Crown officers who were not
asking before and, from M7, patrons.

**There is no second schedule and no separate director.** A duke spawns when the
annual draw lands on dimension 4 and the source taken from the catalogue is a
rival. That is the whole of it.

Three things fall straight out:

**They arrive staggered.** One source enters per draw, so the colony faces one
duke, then two, then three across a run rather than three demands in one spring.
§12.4's "pressure grows as a run goes on" needs no mechanism of its own.

**They cannot bunch.** §7's bucket guarantees dimension 4 is drawn at most twice
in any four years, so the worst case is bounded and an aberrant run is impossible
rather than unlikely.

**And a duke is the sharpest thing dimension 4 can produce**, which §6 says
already: his demands cost **prestige** rather than standing, so he adds pressure
of a kind the player's existing defences do not answer.

What this doc owns is the **consequence**: on arrival he has a starting loyalty,
opens with a tribute demand, and behaves thereafter as §3 describes.

## 7. Misleading about intentions is prose

§8.4 says rivals mislead the PC about their intentions. **This needs no mechanic.**

SPEC §9.1 already permits it: a letter never lies about what has *happened*, but a
statement of intent is not a statement of fact, and any contact may say a thing
and reconsider. A duke writing *"after this payment we shall have no reason to
ask again"* is telling the truth about his present disposition and nothing else.

An experienced player knows it is worthless. **A new player learning that it is
worthless is the lesson**, and it is taught entirely in prose. Nothing in the sim
needs a truthfulness dial, and nothing should acquire one.

## 8. What a rival never does

SPEC §8.4 is unusually prescriptive, and these are locks rather than defaults:

- **Never asks for help** against another rival or against the natives.
- **Never offers his own resources** to the PC. There is no trade with a rival,
  ever. Backing a rebel town is not an exception: that town has repudiated the
  PC (below).
- **Never becomes peaceful or mutually beneficial**, at any loyalty. High loyalty
  is a cheap racket, not an alliance.
- **One duke per rival**, and he is the PC's only contact with that empire.

A dev who finds himself writing a rival offer, a rival alliance, or a second
rival contact has left the spec.

### They back rebel towns

Author's ruling (#403). SPEC §12.3 has a rebel town handling its own diplomacy,
and says **rivals can court it**. This is what courting is: **an offer the town
cannot refuse.**

**When.** Once a town has been rebelling for **three months**, every duke who has
arrived and has not yet backed a rebellion rolls, each month, to back one. **His
loyalty to the PC sets the chance**: certain at none, never at full, and in
proportion between.

**Where.** If his roll succeeds, he backs **the most populous** town that has
been rebelling three months or more, ties to town order.

**What he sends.** He writes to that town's governor, not to the PC, pledging
his support, and with it:

- **gold, food and guns**, into the town's purse and stores;
- **a company with a commander**: new people from outside the colony, never the
  town's own.

All of it scales with the town's population (§9).

**The company is loyal to the rebellion.** Its allegiance is rebel and its
commander is a rebel commander, who corresponds with the PC as any rebel general
does (`commanders.md` §1). It takes its standing order as the rebel town's own
companies do, and fights for the same ends.

**The duke feeds it**, as the Crown feeds its troops (`battles.md` §3), so the
town never pays for it.

**Once in his life.** Each duke backs one rebellion, ever. With three dukes, three
towns may be backed, and nothing stops two of them backing the same town.

**The town is never lost to him.** Backing is not conquest. The town stays a
rebel town of the colony, and only being taken makes a town lost (SPEC §12.3).

**If the town comes back to the Crown**, returned or retaken, **the duke's
company goes home**, commander and all. He backed a rebellion, not the colony.

#### What it does to the PC

**It blunts his foothold.** A rebel town finds its way back as its quality of
life falls (`rebel-sentiment.md` §5). The duke's gold and stores hold that up,
his company stands against the Crown's troops, and a rebel town that looks
prosperous and unpunished spreads (§12.3).

**He hears of it from the Diplomat.** The duke's letter goes to the governor. If
the Diplomat is in the colony, he writes to the PC explaining what happened.
Otherwise the PC has only the map, if the colony can see the new company.

**Nothing is aimed at it.** He fights a backed rebellion the way he fights any
rebellion: Crown troops, punishment, persuasion.

**It does not break §8.4.** *"They will not offer any of their own resources to
you"*: the rebel town is not the PC. It has repudiated him, and the duke's gift is
aimed at him, not given to him.

## 9. Tuning targets

- Starting loyalty on spawn, and the band boundaries.
- How fast prosperity drags loyalty down, against how much a payment lifts it —
  the ratio is the whole of whether appeasement is affordable.
- Tribute size per band, and how it grows (`crown-demands.md` §6).
- How many tiles a duke can deny, and for how long.
- The tribute optic's gold-equivalent, which is #187's to set against every other
  optic rather than here.
- The size of a duke's backing of a rebel town, per thousand people: its gold,
  food, guns, and the company's size (§8).

## 10. Open items

- Whether the PC can play dukes against one another. §8.4 forbids them asking for
  help against each other, but says nothing about the PC volunteering it.
- What a duke does when the colony is plainly dying. Continuing to demand tribute
  from a PC with two starving towns is comic, but it may simply be dull.
