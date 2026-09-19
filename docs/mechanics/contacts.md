# Mechanics — General Contact Behaviour

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8 (contacts), §8.5 (loyalty and compliance), §9.1 (tone),
> §9.3 (not replying).
>
> **This doc names no contact.** It describes what is true of **every** contact,
> including ones not yet designed. A rule stated here that turns out to need an
> exception is stated wrongly — the exception belongs in that contact's own doc.
> Roles are fine; individuals are not.

---

## 1. What a contact is

| Attribute | What it is |
| :--- | :--- |
| **Identity** | Name, title, role, portrait, and the town he lives in if he lives in one |
| **Personality** | A **weight vector over considerations**, not a tag with special-cased behaviour |
| **Leans** | Signed perception bias per topic, `[-1, +1]` |
| **Cares about** | The measures he judges the PC by |
| **Relationship** | Where he and the PC stand (§6) |

**Temperament** is the spec's broad word for the middle three together —
personality, what he cares about, and how he sees it. It is deliberately loose
in SPEC §10.2 so the mechanic can grow underneath it without the spec becoming
untrue.

**No contact has bespoke behavioural code.** Personality is data. That is what
SPEC §8 requires when it says personality drives behaviour and not merely prose,
and it is why a new contact is a new data file rather than a new branch.

## 2. Loyalty is one knob, read differently by role

Loyalty is a single scalar, `0–100`, neutral at `50`. **It is not a measure of
friendship.** It is a disposition, and what that disposition *means* depends on
what the contact wants from the PC.

For a contact whose interests broadly align with the Crown's, the scale runs
from *I will do what you say* down through *I will do what you want* — that is,
he starts substituting his own reading of the PC's interests for the PC's actual
instructions — and on to *I will do what I think best, and tell you after*.

For a contact whose interests are **opposed**, the same scale reads from *I
expect you will keep paying* down to *your destruction is the only option left*.
High loyalty there is not goodwill; it is a threat deferred. SPEC §8.4 says
accepting such a contact's demands "may defer the risk of an attack but will
never create a peaceful or mutually beneficial relationship," and this is that
sentence as a number.

**The knob is not renamed for those contacts.** One attribute, one set of
mechanics moving it, different readings at the point of use.

## 3. Where loyalty is checked

Three places. All three exist in code today.

### Writing to the PC

The director decides each month who writes, about what, and with what
parameters. Loyalty reaches all three: **tone is computed from the contact
directly**, and whether a letter fires at all is a trigger condition, which may
read loyalty like any other state.

A contact's regard therefore shapes not only how a letter sounds but whether it
is sent, and what it chooses to mention.

### Receiving an order

Compliance resolves an Order into one of six outcomes — comply, partial, delay,
reinterpret, refuse, act alone — through the deliberation kernel. **Loyalty is
the heaviest consideration in that decision**, well ahead of the cost of the
request, the payment offered, the clarity of the order, and the contact's taste
for autonomy.

The outcome becomes an Intent the sim executes (`world-month.md`). Which is the
important part: **a contact does not merely accept or decline. He forms an
intention, and it need not be the PC's.**

### Being ignored

Silence has its own resolution (SPEC §9.3). A request ignored is a rude refusal
and costs loyalty. A decision ignored is taken by the contact himself, in his own
interest or at random depending on personality, and also costs loyalty. A report
ignored costs nothing.

## 4. What to expect as loyalty shifts

| Loyalty | Writing to the PC | Receiving an order |
| :--- | :--- | :--- |
| **High** | Writes readily and warmly. Consults before acting. | Does what the PC asked. |
| **Neutral** | Writes when there is reason. | Does what the PC asked unless it is costly, in which case he weighs it. |
| **Low** | Writes less, and more coolly. More likely to decide without asking. | The order is one input among several. His own reading usually wins. |
| **None** | Writes only when he wants something. | The order may be taken as an affront, and produce an intention **directed against the PC**. |

That last cell is the one to hold onto. **At the bottom of the scale an order
does not merely fail — it can become the reason for what happens next.** A
resident contact insulted past bearing does not just decline; the thing he now
intends may be to turn his town against the Crown.

## 5. Drift: why should I be loyal to the Crown?

**Loyalty moves on its own, and for nearly everyone it is always moving.**

Every contact has an answer to *why should I be loyal to the Crown* — they send
me what I need, they keep me safe, they pay me, they leave me alone. That answer
is his `cares_about`: the measures he judges the PC by.

As those measures move, so does his regard. **Only a contact whose world is
untouched and who has had no correspondence has no drift**, and the Squeeze
tightening while the colony grows means almost nobody is in that position for
long.

So loyalty has two sources, in the same shape as quality of life and rebel
sentiment:

- **A standing term**, recomputed from whether what he cares about is going well.
- **Accumulated deeds**, which are memory — what the PC granted, refused,
  delivered, broke, and ignored.

Neither alone is enough. Deeds without drift means a contact is indifferent to a
colony falling apart around him as long as the PC is polite. Drift without deeds
means the PC's choices do not matter, which is the game.

## 6. The Relationship is the single source of truth

Everything about where the PC and a contact stand lives in **one** place:
loyalty, outstanding promises, what has been granted and refused and delivered
and broken, and how long since the PC last wrote.

**The contact does not keep a second copy.** He holds a reference. There is one
source of truth and it is the Relationship, which is how it stays possible for a
letter to say something true about the past.

**It is not a Ledger.** SPEC §4 fixes that word for the gold screen.

### It should be a history, not a tally

Today it counts: how many times each deed has happened, how many promises broke,
when the last one did. Counts answer *how often*. They cannot answer *what*.

A contact asking for something new should be able to reach back and find the
last time the PC was generous to him, and **name it**:

> *Your Grace was good enough to send two hundred measures of iron in the spring,
> when we had none. I would not ask again so soon were the need not greater.*

That requires a **bounded log of notable events**, each carrying enough to be
described: the month, the kind of deed, its size, and what it concerned. The
director picks one when building a letter and supplies it as a parameter, the
same way it supplies any other.

Three properties make this work:

- **It is always true.** Referring to a real past event is a fact about the past,
  which SPEC §9.1 requires letters to get right. The bias lives in *which* event
  a contact chooses to remember, and that is framing, which §9.1 allows.
- **It is free characterisation.** One contact reaches for the last kindness; a
  sourer one reaches for the last slight. Same log, same query shapes, different
  weights.
- **It must be bounded.** A fifty-year run cannot keep every deed for every
  contact in a save. Keep the most significant and the most recent, and let the
  middle fall away — which is also how people remember.

## 7. Death, and what does not happen

**A contact can be killed.** The conditions belong to whatever kills him and are
that mechanic's business, not this doc's.

**There are no successors.** No replacement, no promotion, no defection. When a
contact is gone he is gone, and the run continues without him.

This is deliberate. A roguelike already asks the player to learn a new cast every
run; a stream of new names arriving mid-run to replace the ones he had just
learned is churn without payoff. **You get who you get**, and losing someone is a
loss rather than an inconvenience.

**This contradicts SPEC §8.2**, which currently says colony contacts can change
"through death, replacement, promotion, or defection." The spec needs amending;
until it is, the spec wins.

## 8. Loyalty can always be recovered

**The base rule is that there is no permanent break.** Loyalty can always be
gained and always be lost, for every contact, at any point.

An individual contact may be **authored** with a condition that snaps his loyalty
to nothing — a line he will not have crossed. That is an exception written into
that contact, deliberately, with its reason. It is not a general mechanic, and no
code outside that contact's own definition may create one.

Note what this is not: SPEC §12.5 lets a native tribe's *trust* break
permanently. Trust is not loyalty and tribes are not contacts.

## 9. Tuning targets

- The loyalty bands in §4, and what each means in the compliance scoring.
- The balance between the standing drift term and accumulated deeds (§5). Too
  much drift and the player's letters stop mattering; too little and a contact
  ignores a collapsing world.
- How far personality weights may spread before a contact reads as broken rather
  than characterful.
- How many events a Relationship keeps, and how significance is scored (§6).

## 10. Open items

- Whether the drift term should be capable of moving loyalty faster than deeds
  can repair it. A contact whose world is falling apart may be unreachable by any
  letter, which is either a powerful thing or a frustrating one.
- Whether a contact's `cares_about` is fixed at generation or can shift with his
  circumstances.
- Whether the PC should be able to perceive *why* a contact's regard is falling,
  beyond the tone of his letters.
- Which events count as notable enough to keep, and whether a contact's
  personality should bias what he retains as well as what he reaches for.
