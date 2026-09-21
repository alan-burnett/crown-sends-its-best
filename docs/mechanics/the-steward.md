# The Steward

> **Serves:** SPEC §8.1 (the officer), §10.2 (taxes and gold), §8.5 (compliance),
> §12.3 (trade protests). **Extends:** `contacts.md`.

He was deferred. `README.md` said the deferral ended the moment anything was
built on top of him that the spec does not describe, and `set_tax_rate` orders
are exactly that — the Steward refused a tax rise on turn one of a real run
(#302) and there was no doc to say he should not have.

---

## 1. The one thing that makes him different

Every other Crown officer is asked for something that costs him. **The Steward is
asked to do the thing he already wants to do**, and the whole of his behaviour
follows from that.

SPEC §10.2:

> The steward will **follow your instruction about adjusting tax rates**, and
> offer his advice with his bias (**he prefers high taxes**).

So two rules, and they are not the same rule:

- **A tax instruction costs him nothing.** He is doing his job. Pricing it is the
  defect in #302.
- **A tax instruction can still agree or disagree with him**, and that changes
  *how* he answers — never *whether*.

---

## 2. 🔒 His bias is dissonance, not cost and not a refusal

The kernel already has the consideration this needs.
`DissonanceConsideration` — *against his judgement* — pulls toward
**reinterpret**, **act alone** and **delay**, away from **comply**, and
**deliberately not toward refuse**, with a lock in the code saying so.

That is the right shape for him without changing anything:

| The PC orders | Dissonance | He |
| :--- | :--- | :--- |
| a **rise** | none | does it, and says something pleased about it |
| a **small cut** | some | does it slowly, or reads it generously |
| a **deep cut** | high | reinterprets it, or does it his way and tells you after |

**He never flatly refuses**, which is correct for a Crown officer and is what the
spec describes. A man who disagrees with the Crown's revenue policy does not
write back *"no"*; he finds that the instruction admitted of another reading.

### What has to change to reach it

`dissonance_of()` returns 0.0 for every order kind except `urge_intent`, so today
**only a governor can find an order disagreeable.** It needs to answer for a tax
order too: **how far the ordered rate sits below the rate he would have set.**

That is a generalisation of an existing consideration, not a new mechanism, and
it is the difference between the Steward having a personality and having a
weight vector nobody reads.

---

## 3. Acting without being asked is a different thing entirely

SPEC §10.2:

> If your crown standing is lost **and** the steward's loyalty is low, he may
> unilaterally raise taxes and inform you after the fact, ignoring your input.

**This is not compliance.** Nothing was ordered. It is Seam C — he deliberates,
produces will, and that becomes an Intent the sim executes.

**The two conditions are a filter, not weights** (`CLAUDE.md`): the spec locks
them, so they gate the candidate before scoring rather than making it merely
likely. Standing lost **and** loyalty low, or the option is not on the table.

**What he raises, and how far, is his judgement** once the gate opens — and it
should be the rate he has been advising all along, which is what makes it read as
a man finally doing what he has been saying for a year.

---

## 4. What he says, and when

Three of his four spec duties are the director's business rather than this
document's, and are listed here so they are not lost:

| Duty | Fires on |
| :--- | :--- |
| **Warns** when gold income is hurting crown standing | `crown-standing.md` |
| **Praises** good revenue | revenue above his own expectation |
| **Reports** trade protests | `trade-protests.md` |
| **Pushes** for higher taxes | standing pressure, and his bias above |

**His praise is the cheapest instrument the game has for teaching taxes.** He is
the only contact who reacts to a number the player set directly, and a pleased
letter after a rise is how a player learns the lever exists.

---

## 5. Tuning targets

- The rate he would set — a function of standing pressure and the colony's
  revenue, and the reference point everything in §2 measures against.
- How far below it a cut has to be before he reinterprets rather than delays.
- The loyalty threshold on §3's gate.

## 6. Open items

- **Does his preferred rate move with the colony's condition?** A steward who
  wants the same number in a famine as in a boom is a simpler character and a
  worse one, but tying it to quality of life risks him arguing against the Crown.
- **Per-resource or overall?** Tax rates are per-resource (`CLAUDE.md`
  terminology). He may have a view on the base rate only, or on each — the first
  is much cheaper and probably enough.
