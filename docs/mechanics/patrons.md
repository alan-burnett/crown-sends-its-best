# Mechanics — Patrons

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.3, §14.1, §11.4, §10.2, and the Squeeze pillar.

---

## 1. A leech you can make use of

SPEC §8.3: a merchant, noble, bishop or scholar who takes an interest in the
colony, asks for things, proposes trades, and does not stay.

**Materially they are a net drain.** What they ask for over a run outweighs what
they hand over, and a PC who simply feeds every patron is poorer for it.

**What makes them worth keeping is prestige** (§14.1), and what makes them worth
*handling* is that a specialty used at the right moment is worth far more than it
cost. They are the one contact where playing well and paying well are different
things.

## 2. Three things rolled at arrival

| | |
| :--- | :--- |
| **Specialty** | something he can supply or arrange |
| **Need** | something that has particular value to him, never the same as his specialty |
| **Vice** | what makes him difficult |

**Vice, not personality.** `contacts.md` §1 reserves *personality* for the weight
vector over considerations, which every contact has including this one. A vice is
a named bundle of mechanical behaviour on top, and the two words must not merge.

## 3. Specialty and need are drawn from one catalogue

Resources, troops, gold, experts, livestock — and **rivals**, which is a different
kind of thing (§5).

Everything except rivals is a **shipment**: it arrives, or the PC sends it. A
patron with his own means is wealthy enough to move goods across an ocean, and
that is all the machinery it takes.

**Specialty and need are never the same**, so every patron is a mismatch by
construction. He has what you may not want and wants what you may not have, and
the trade is only interesting because of the gap.

## 4. Every offer is one object

Four shapes that look different in prose are one thing with fields left empty:

```
offer = { gives:  specialty | gold | nothing
          wants:  his need  | gold | nothing }
```

| gives → wants | Reads as |
| :--- | :--- |
| specialty → nothing | **a gift** |
| nothing → his need | **a request** |
| specialty → his need | **a barter** |
| specialty → gold | **a sale** |
| gold → his need | **a purchase** |

**One letter family, one resolution path.** Loyalty shifts which combinations he
will propose — gifts belong to high regard and bare requests to low — but nothing
branches on the shape of the offer.

The PC may also **ask** for a specialty rather than waiting to be offered one.
That is an ordinary letter resolved by ordinary compliance (§8.5): a well-regarded
patron obliges, a slighted one finds reasons.

## 5. The rival specialty, and the third door

**He interferes with a rival. He never touches the PC's relationship with that
rival** — which is what makes it work.

Granted, it does two things:

**1. Sabotage.** That rival's companies fight at a heavy disadvantage for **a
year**. They inflict less and they break sooner.

**2. A reply the PC would not otherwise have.** The next time that rival demands
tribute, a new option appears on the letter: *go and collect it from Lord
Magilicutty's house.* The patron writes afterwards, delighted — *he took the bait,
we arrested the men, well done on capturing those traitors* — and the duke
**skips his next demand** before resuming as though nothing happened.

**It costs nothing with the rival**, because he never puts it together. The patron
is sneaky enough to cover for the PC entirely.

### Why this is the strongest thing a patron has

`rival-pressure.md` gives a tribute demand exactly two answers, and both cost:

| | Costs |
| :--- | :--- |
| **Pay** | gold out of `net_position`, which lowers standing *and* prestige, plus an **optics debt that never decays** |
| **Refuse** | the duke's loyalty, driving him toward tile denial and war |

**This is a third door, and it costs neither.** No gold, no optic, no loyalty —
and it answers two demands, the one deflected and the one skipped.

### The two halves are useful in opposite weather

**Sabotage matters when the duke is low or at war**, because that is when his
companies are actually fighting. **The tribute trick matters when he is high**,
because that is when tribute demands are arriving at all.

So a PC almost never gets full value from both. **Which half is live depends on
where that duke already stands**, and that makes *when* to accept the gift a real
decision rather than a free yes.

### 🔒 It cannot undo the latch

`rival-pressure.md` §3 locks that a duke at **minimum** loyalty is there for the
run. A patron may help the PC survive that; **nothing brings a duke back from open
war**, and no specialty may be written that does.

## 6. Vices

Most of a vice is data on machinery that already exists. One is not.

| Vice | What he does | Built from |
| :--- | :--- | :--- |
| **Thin-skinned** | a harsher register, and refusals cut deeper | a per-contact weight on `REFUSED` |
| **Importunate** | he will not take no. He writes again and again, sliding into `desperate` | the director's volume and tone |
| **Credulous** | he reads the colony as richer than it is — **so his asks grow** | perception leans |
| **Loudmouth** | he talks. Granting banks more prestige; refusing costs it outright | the prestige term |
| **Pragmatic** | his regard follows **the colony's net contribution to the Crown** | `cares_about` |
| **Respectable** | he watches rebel sentiment, and **a rebellion ends his business** | `cares_about`, plus cancellation |
| **Doctrinaire** | he will not touch certain resources, and objects when the colony trades them | a catalogue filter |
| **Dilatory** | his side of a bargain arrives late, or short | the promise machinery, aimed at him |
| **Impatient** | his offers expire within the turn — silence is refusal, not delay | §9.3 |
| **Well-connected** | **his displeasure spreads** — see below | new |

Most of these are a per-contact override on machinery that already exists.

### Credulous asks for more without a rule that says so

Worth pulling out, because it is the pattern the rest should follow. **He has no
escalation rule.** He has a bias — his leans run positive on every colony measure
— and because he sincerely believes the colony is prospering, what he asks for
grows on its own.

The greed is *derived from the perception*, not bolted on beside it. A vice
built this way needs no bespoke behaviour at all, which is what `contacts.md` §1
demands of everything else.

### Pragmatic and Respectable are a pair

Both judge the PC by the **colony** rather than by what he sends them, and they
watch different things: **one reads your books, the other reads your streets.**

**Pragmatic** follows `net_position` — the colony's net contribution to the Crown
— and deliberately **not prestige**, which would be a feedback loop: pleasing a
patron banks prestige, prestige would lift his regard, and his regard is itself
part of prestige.

It has a consequence worth keeping. Paying a patron in gold **lowers**
`net_position`, so **you cannot buy a pragmatic man's good opinion.** He respects
a colony that turns a profit, and money spent on him is money off the very figure
he respects. The only way to please him is to run the place well.

**Respectable** cannot be seen doing business with a man who is losing his
colony. He writes about rebel sentiment because he cares about it (§6 of
`contacts.md` — `cares_about` decides what a contact writes about unprompted), and
when a town actually declares, his regard collapses and **his standing
arrangements are cancelled.**

That makes him the one patron whose value evaporates exactly when the PC needs
help most, which is both the correct behaviour for a careful man and the worst
possible timing.

### Well-connected is a new mechanic

**It is the first time one contact's opinion moves another's.**

When a well-connected patron's loyalty falls, the Crown officers lose a little of
their own regard for the PC — and, per `contacts.md` §6, **they write to say so.**
*Lord Ashby gives us to understand that Your Grace has been difficult.*

The victim writing is what makes it land. A silent contagion would be a number
moving behind the curtain; a letter from the Steward repeating gossip is the PC
discovering that a man he brushed off has a voice at court.

**Keep it one-directional and shallow.** A patron reaches the Crown officers; the
officers reach nobody. Contagion between contacts generally is a spiral nobody
has designed and it should not arrive by accident.

## 7. Arrival

**Patrons spawn from the Squeeze**, not from a schedule of their own.
`crown-demands.md` §6, dimension 4 — *more hands out* — names them alongside
dukes and Crown contacts who were not asking before. Same draw, same bucket,
same guarantee that they cannot bunch.

**And no order.** A patron is not behind the dukes and does not wait on a count
of hands: any draw of dimension 4 can produce any of the three, so the first
source a run meets may be a patron. §6 has the reasoning, and the measurement
that forced it.

Nothing here adds a clock.

## 8. Departure, and the window that closes

**Every patron stays at least two years.**

At the two-year mark he privately settles on how much longer he wants: **anything
from nothing to two further years.** The PC is told none of this.

When that runs out he enters **LEAVING**:

- He writes, sends his regard, and says he will be gone **in six months**.
- **Business continues as normal.** He still offers, still asks, still trades.
- Every letter from here names the date.

Then he goes, and **whatever he had made up his mind about the PC is locked in.**

### This is the closing window, and it is the point

`prestige.md` §5 banks a patron's **final loyalty** permanently when he departs —
he returns to court and speaks well or ill of the PC forever.

So those six months are the last chance to move it, and the PC **knows it to the
month**. It is the same shape as the Chancellor's warning in `crown-standing.md`
§3: a deadline stated in fiction, actionable, with the business still open while
it runs.

**And the roll is hidden until it fires.** At two years the PC cannot tell whether
this man has a month left or another two years, so there is no planning for it —
only the six months, once they start. A patron cultivated for three years and
neglected in his last spring banks that neglect and takes it home.

## 9. Prestige

Specified in `prestige.md` §5 and **not re-specified here**: deeds bank
immediately, his regard is a live term while he is present, his final loyalty
banks on departure.

The only thing this document adds is §8's window, which is where the live term
stops being live.

## 10. What the PC can do

- **Grant or refuse a request**, which is a deed and banks.
- **Ask for a specialty**, resolved by compliance.
- **Meet a need**, which is the surest way to lift regard.
- **Time the rival specialty** against where that duke already stands (§5).
- **Spend the last six months well** (§8).

### 🔒 Every one of those happens in a reply

**The PC never writes to a patron unprompted.** Author's ruling, and it is the
duke's model exactly: you read what he sends and you answer it, and there is no
letter you may decide to send him.

So *ask for a specialty* is **a reply option on a letter he wrote**, not a
composed letter. A patron who has not written cannot be asked.

**That is the whole shape of the relationship.** He is a man who takes an
interest in you; the correspondence is his, and the PC's power in it is the
power to answer well. A patron the PC could summon would be a resource, and §1
is careful that he is a leech you make use of rather than a supplier.

### And it is still how the prestige term moves

`prestige.md` §2 has `patron_credit` in the sum, and a term the player cannot
touch is not a term (#388).

**A reply produces an Order addressed to the sender**, which is the same path
every other contact's compliance runs on — so answering a patron banks credit
without the PC ever composing anything. The lever is real; it is simply
**reactive**, which is what the ruling above makes it.

**It follows that a patron who never writes is a patron who cannot be scored.**
That is why §7's arrival has to produce a letter, not merely a contact.

## 11. Tuning targets

- How far a specialty's worth exceeds what a need costs, and whether *net drain*
  holds across a run at every loyalty.
- The sabotage magnitude, and its one-year term.
- Loyalty bands: where gifts start and where bare requests begin.
- The contagion's size, and how many officers hear it.
- Whether two years, zero-to-two, and six months are the right three numbers.

## 12. Open items

- **How many patrons may be present at once.** Nothing fixes it, and §9.6's letter
  volume is the real constraint. Three is probably the ceiling.
- Whether a patron's need can be something the colony cannot supply at all, as tea
  is for luxuries. A patron who wants what the PC has no way of getting is a
  relationship doomed from the roll, which may be good.
- Whether **Respectable** reads colony-wide sentiment or his worst town. The worst
  town is sharper and makes one bad province poison every deal he holds.
- Whether a **departed** patron can return later in a long run, at his banked
  regard. §8.3 says they come and go; it does not say they never come back.
- What a patron makes of a colony in open rebellion. He is invested in the place
  and has no stake in the Crown's dignity, and nothing says whether that makes him
  flee or bargain.
- Whether the rival specialty's deception can ever be discovered. Currently never,
  which is clean; a small chance of exposure would be a different and nastier
  mechanic.
