# Mechanics — Prestige

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §14.1, §14.2, §14.3, §13.2, §10.2, §8.3, and the satire in
> §3.2.
>
> **Settles** the question SPEC §17 carried until v2.2: how the PC's financial
> contribution translates to prestige.

---

## 1. The Crown's running account of you

**Prestige is a running tally.** It moves every month, up and down, for the whole
run, and the number it has reached when the run ends *is* the final score.
Nothing is computed at the end that was not already accumulating.

That is what makes SPEC §13.2's lock work — *"prestige reflects the Crown's
current view of the PC, so it can fall as well as rise"* — and it is why retiring
from a losing position can beat hanging on.

## 2. It is denominated in gold

The court prices humiliation in money.

```
prestige = net_gold + patron_credit - optics_debt
```

Every term is in the same unit, which is the Crown's unit, because the Crown has
no other. A trade protest is worth so many pounds of embarrassment; a patron
pleased is worth so many pounds of goodwill.

**This is the satire load-bearing rather than decorative.** §14.1 locks that
prestige measures only how the Crown benefits and that nobody at court cares how
the colonists fared, and a gold-denominated score is the bluntest possible
statement of it. It also means the three sources need no invented currency to
share.

### 🔒 It never reads the colony's welfare

Prestige may read **what the Crown received, what it paid, and what made it look
foolish**. It may never read quality of life, rebel sentiment, population, or
anything else about how the colonists fared.

SPEC §18 lists *"scoring the colony's own welfare or productivity"* as a
non-goal, and §14.1 locks the same thing from the other side. A dev who reaches
for quality of life here has broken the pillar the ending rests on: **a PC can
leave behind a wretched, half-starved colony and retire in glory**, and the game
must let him.

## 3. Net gold

```
net_gold = net_position        // cumulative received, minus paid
```

**Already tracked.** `crown_accounts.gd` has it and `crown-standing.md` §2 names
it, and it is exactly what the Author means by *money earned for the Crown minus
money you have cost the Crown*.

It enters **linearly and with no ceiling.** Doubling what the PC netted the Crown
doubles that part of his score, because the Crown's appetite is the one thing in
this game that never saturates.

### The same number, asked a different question

Crown Standing reads `net_position` too. They are not the same mechanic and must
not collapse into one.

| | Reads | Asks | Acts on |
| :--- | :--- | :--- | :--- |
| **Crown Standing** | net position over monthly net | *Are you on track?* — a **rate** | refusing payments, during the run |
| **Prestige** | net position | *What did you net us?* — a **level** | letters, and the final score |

A PC deep in debt but newly profitable has **recovering standing and dismal
prestige**. One who banked a fortune and then stopped earning has **great
prestige and falling standing**. Two verdicts from one number, and both correct.

## 4. Optics never decay

**Something that made the Crown look bad in year one counts against the PC in
year forty, undiminished.** No forgetting, no half-life, no rehabilitation.

Each event is scored **once, when it happens**, as a fixed debt.

| Optic | When it fires | Available |
| :--- | :--- | :--- |
| **Trade protest declared** | the month a town refuses the Crown's price | M3 (#75) |
| **A town declares rebellion** | the declaration, not each month of it | M3, shipped |
| **Tribute paid to a rival** | the PC accepts a rival's demand | M5 |
| **A company destroyed** | its last man is gone | M6 |
| **A town lost** | it leaves the colony entirely | M5–M6 |
| **The run ends in a fail condition** | §13.1, at the end | M3 (#78) |

**There is no such thing as losing a battle.** `battles.md` §6 has no rout and no
surrender — two companies exchange casualties and both walk away poorer — so an
optic priced on *a battle lost* could never fire. The discrete defeat the court
actually hears about is **a company wiped out**, and that is what is priced.

### 🔒 The money is not counted twice

A trade protest costs the Crown its tax income on that resource, and a rebel town
stops trading with the Crown altogether. **Both of those already land in
`net_position`.**

The optics debt is for the **embarrassment only**. Charging the gold again would
double-count the same event and make protests and rebellions read far worse than
the design intends.

### 🔒 A mechanic emits the event. It never prices it

**No mechanic decides whether it affects prestige.** Trade protests, rebellion,
tribute, battles and lost towns each emit an event saying what happened. **One
table, here, decides which events are optics and what each is worth.**

This is the same split the content pipeline uses, where triggers decide *whether*
a letter is sent and the letter file decides *how it reads*. The reason is the
same: a price is only meaningful against every other price, so pricing cannot be
distributed across the mechanics that generate the events.

It also means **a new optic is a row in a table, not a change to the mechanic
that causes it.** A dev adding rival tribute in M5 emits `tribute_paid` and stops
there; whether the court minds, and how much, is not his to decide and not his
ticket's.

### Fixed debts, not proportional ones

An optic is an absolute figure, not a share of anything. A lost town is a fixed
black mark, and whether it ruins the PC depends entirely on what else he has
done.

So **one rebellion destroys a small-time governor and merely embarrasses a great
one**, because the great one's net gold dwarfs it. That is the court forgiving a
man who made them rich, and it should not be tuned away.

## 5. Patrons

SPEC §14.1: *helping them and keeping their loyalty is a **major** source.* §8.3:
*patrons come and go and are not permanent.*

Two halves, and the second is what makes patrons worth timing.

**Deeds bank immediately.** A favour granted to a patron adds to prestige the
month it is granted and stays there. It survives his departure, because he
remembers it and says so at court.

**His regard is a live term while he is present**, contributing according to his
current loyalty and rising and falling month to month like anything else.

**On departure his final loyalty banks.** He returns to court and speaks well or
ill of the PC, permanently, at whatever regard he left with.

That last rule is the whole shape of it: **a patron about to leave is worth
pleasing right now**, and one neglected in his final months carries that neglect
to court with him. It also keeps prestige moving during a run without needing
optics to decay.

Patrons are M7. Until then this term exists, is named, and reads zero.

## 6. Where it sits in the month

**World month phase 5, the Crown's Month** — after promises are honoured or
broken and after standing updates, reading the same accounts.

It must fall **before phase 7, Reckoning**, so contacts writing this month's
letters read this month's prestige rather than last month's.

**Stored, not recomputed**, written once a month as quality of life is, so two
readers cannot disagree about it halfway through a month.

## 7. What the player sees

**Never a number. Never a screen. Never a bar.**

He sees it in **the tone and content of letters from Crown contacts, and above
all from patrons.** §14.1 says some contacts change what they ask of the PC based
on it, and names patrons as the clearest case: a well-regarded PC is offered
ventures and treated as a peer, a laughing-stock is condescended to or not
written to at all.

### Prestige is not loyalty, and the two must not be confused

**Loyalty is how a contact feels about the PC personally. Prestige is how the
court regards him.** A contact may like the PC enormously and still know he is a
joke in the capital, and his letters should carry both.

So prestige is a **tone input alongside loyalty**, never a substitute for it. Two
dials into the same prose.

Patrons being M7 means that for M3 the audible channel is the Crown officers —
the Steward, the Chancellor, the Provost and the Marshal — and it should be
working there before patrons ever exist.

## 8. The retirement decision

SPEC §13.2: *retiring from a losing position can earn more prestige than hanging
on while gold and goodwill drain away.*

**Permanence is what makes this work rather than what works against it.** Old
damage does not fade, so the reason to leave is never that waiting heals
anything. It is that waiting **accrues new damage**:

- `net_position` falls as the Crown honours promises a failing colony cannot repay
- every further month is another chance at a protest, a rebellion, a defeat
- patrons lose regard, and then bank it

So the question the player is really asking is **"is my prestige still rising?"**
A profitable, quiet colony says stay. One bleeding gold with a town in revolt
says every month from here is worse. That is a real read, and it is available
through the ledger and the letters without a number ever appearing.

## 9. How the run ended

§14.1 says the ending affects the final score.

- **Forced retirement at fifty years** (§13.2) is normally very prestigious, and
  mostly earns that on its own — six hundred turns of accumulated net gold
  against a fixed set of black marks.
- **Voluntary retirement** scores the tally as it stands. No bonus, no penalty:
  the timing *was* the decision.
- **A fail condition** carries a large final optics debt. Losing the colony is
  the most embarrassing thing that can happen to the Crown.

## 10. Meta-progression

§14.3 gates unlocks on prestige and locks that **unlocks add variety, not power.**

One thing to watch: because net gold accumulates with time, **a long run will
almost always out-score a short one**, so thresholds set against long runs would
put unlocks out of reach of the players who need them most. Either the thresholds
are generous, or some unlocks gate on something other than the total. Not settled
here.

## 11. The reckoning, in M7

**Prestige is not finished until every optic exists.** Until then each mechanic
contributes an event to a register that is deliberately incomplete, and the
prices in it are placeholders that have never been weighed against one another.

The last optic arrives in **M6** — defeats at the hands of natives and rivals. The
other source, **patrons**, arrives in **M7**, and patrons are also the loudest
reader (§7). So **M7 is the first moment prestige is whole**, and it gets a
deliberate pass there:

- every event the register can price, listed in one place
- every price set **against every other price** rather than in the ticket that
  introduced it
- the run-end debts weighed against a typical run's accumulated net gold
- §14.3's unlock thresholds set once the range of achievable scores is known
- the letters checked: does a player with falling prestige actually hear it?

**This is why the emit-not-price rule above matters.** Every milestone between now
and then can add optics freely without anyone having to guess what a rebellion is
worth relative to a lost town — the question is asked once, with all the answers
visible.

M8 then tunes the numbers against the harness. M7 decides what the numbers *are
for*.

## 12. Tuning targets

- **The gold-equivalent of every optic.** The ratio between a trade protest and a
  month's revenue is a design statement rather than a balance value: it decides
  whether the player should eat the protest and keep the duty, or cut the duty
  and keep face.
- What a patron favour is worth, and what his regard is worth per month.
- The fail-condition debt, against a typical run's accumulated net gold.
- §14.3's unlock thresholds.

## 13. Open items

- **Whether prestige may go negative.** Currently yes: a PC who cost the Crown a
  fortune and lost the colony is worse than nothing, and an epitaph reads better
  for it. A floor buys nothing that has been identified.
- **Whether each month of an ongoing protest or rebellion costs anything**, or
  only the declaration. Currently only the declaration, on the reasoning that the
  continuing cost already arrives through lost trade in `net_position`.
- Whether a perk or quirk (§5) might begin the PC admired or notorious. Nothing
  requires it.
- How loudly prestige should colour an officer's letter against how loudly
  loyalty does. Two dials into one voice, and only playtest can set the mix.
