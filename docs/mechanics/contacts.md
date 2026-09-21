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
| **Cares about** | The measures he judges the PC by, and what he writes to the PC about (§6) |
| **Prominence** | How large he looms in the town he lives in |
| **Relationship** | Where he and the PC stand (§7) |

**Prominence** scales his effect on rebel sentiment (`rebel-sentiment.md` §4),
replacing what was once a hard split between the governor and everybody else. It
is derived from his role — the governor's office is a large one — with a
per-contact override in the data, so a particular clergyman can be a firebrand
without any code knowing he is unusual.

**It cuts both ways, and that is the point.** If the famous men of a town are all
loyal to the Crown there is not much rebel sentiment in it. The same men slighted
are what carries the town out.

**Temperament** is the spec's broad word for the middle three together —
personality, what he cares about, and how he sees it. It is deliberately loose
in SPEC §10.2 so the mechanic can grow underneath it without the spec becoming
untrue.

**No contact has bespoke behavioural code.** Personality is data. That is what
SPEC §8 requires when it says personality drives behaviour and not merely prose,
and it is why a new contact is a new data file rather than a new branch.

### Names are `names.md`

**The five Crown officers and the three rivals are fixed and named in data.**
Everybody else — governors, patrons, commanders, and the institutional contacts
as they arrive — is generated from a bag per role.

A contact's letterhead is **`<title> <name> of <location>`**, which uses
`display_name`, `title` and `town` as they already stand.

`names.md` owns the bags, the letterhead, the places, and the streams they draw
from. It is not repeated here.


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
reinterpret, refuse, act alone — through the deliberation kernel.

**The considerations**, each weighted by personality like any other:

| | Reads | Pulls toward |
| :--- | :--- | :--- |
| **loyalty** | his regard for the PC | **the heaviest of them.** High complies, low refuses or acts alone |
| **cost** | what the order asks in **gold** | a large ask is easier to shave, put off or decline |
| **payment** | what the PC offered against that cost | comply |
| **harshness** | whether the letter leaned on him | comply, and **away from the sideways answers** — a man told plainly does not quietly reinterpret |
| **tone** | which of the five the PC chose | five considerations, one per tone, weighted by three traits (`tone.md` §5) |
| **clarity** | how vague the order is | **reinterpret**, which without this axis could never happen at all |
| **autonomy** | his disaffection | act alone, reinterpret |

**And one filter.** Full payment is a guaranteed yes while Crown Standing can
cover it (§12.6) — a filter rather than a heavy weight, because a guarantee that
can lose a close vote is not a guarantee.

Two of these are worth reading twice. **Harshness is the surest way to be
obeyed**, which is the whole reason the PC would write one, and he pays for it
twice — in the governor's regard and in what the town holds against the Crown
afterwards (`rebel-sentiment.md` §4). And **clarity means saying exactly what you
want is a real choice**: an order with no figure in it leaves room to decide what
the PC must have meant.

### 🔒 Harsh is a second axis, not a sixth tone

**The PC chooses both, separately.** Harshness is a yes-or-no the wizard asks
after the tone is set, and the two are orthogonal: five tones times harsh-or-not
is **ten registers**, and every one of them is a letter somebody might send.

**Saying yes adds a sentence.** Nothing else about the letter changes, and the
sentence is a tone-keyed `{insert:}` fragment — the same machinery every other
tone-varying line uses:

> **pleased** — *Please see to this matter most promptly, lest we allow room for
> unpleasantness.*
> **annoyed** — *Failure to meet this requirement will be met with most dire
> consequences.*

Saying no adds nothing at all. **A harsh letter is a letter with one more line in
it**, and that line is what the governor's town remembers.

### Harsh and urgency are on opposite sides of the desk

They sound alike and are easy to confuse. They have nothing to do with each
other:

| | Set by | Direction | Feeds |
| :--- | :--- | :--- | :--- |
| **harsh** | **the player**, per letter | **outbound** | compliance, and rebel sentiment |
| **urgency** | **the trigger**, authored | **inbound only** | the *sender's* choice of tone (§9.1) |

**The PC never sets urgency and a contact never sets harshness.** A dev who
wires either across the desk has crossed two unrelated systems.

### 🔒 Compliance asks whether he engages, not whether he agrees

**None of these reads what the order is for.** `cost` measures gold, so an order
that costs none — urging a governor's intent, most obviously — is decided almost
entirely on regard and wording.

**That is correct and deliberate.** Whether a governor *agrees* is settled in his
own deliberation afterwards, where the urging meets his reading of his town as
two of eight weighted considerations (`governor-objectives.md` §4). Compliance
decides whether he listens; deliberation decides what he concludes. **Collapsing
the two would put the PC's letter and the governor's judgement in the same
scoring pass, and the argument would stop being an argument.**

What the list is missing is smaller and real: the **manner** of his answer takes
no account of the conflict, so a governor with a tribe on his border and one in a
quiet province reinterpret an unwelcome order at the same rate. A ninth
consideration belongs here for that, pulling toward reinterpretation and acting
alone — and pointedly **not** toward refusal, because refusing is about regard,
and a man who disagrees with the PC but likes him finds a way to do both.

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

## 6. The victim writes

**The PC learns what is happening to the colony from the people it is happening
to.** There is no narrator, no bulletin, and no report from nobody in particular.
A governor whose fields are blockaded writes to say so. If no one is affected
enough to put pen to paper, **the PC does not hear about it at all.**

That is the Correspondence pillar taken literally, and it means the world's
events reach the desk already attached to somebody's interest in them.

### `cares_about` does two jobs

It already drifts loyalty (§5). The same list also says **what a contact
considers his business** — and therefore what he writes to the PC about,
unprompted, when something happens to it.

One field, two uses. A contact who cares about the Crown's finances writes when
they worsen; a governor who cares about his town writes when it is harmed. **No
second list, and no per-contact table of subscriptions.**

### One event, several letters, several complaints

The same thing happening produces **different letters from different people, each
with a different ask** — which is §9.1's framing clause working as a content
multiplier rather than as a caveat.

The PC begins paying tribute to a rival:

| Who writes | What he says |
| :--- | :--- |
| **The Steward** | questions the spending. He watches the money and this is money leaving |
| **The Marshal** | insists the PC stop. He is funding an enemy's war effort |

Neither is wrong and neither is the same letter. A duke's tile denial, meanwhile,
brings a letter from **the governor whose fields they are** — *deal with these men
blocking our people* — and from nobody else, because nobody else is losing
anything.

### Who writes tells the player how bad it is

**This is the part worth protecting.** A complaint's sender is information.

If only the local governor writes about the blockade, it is a local problem. When
the Diplomat starts mentioning it, it has become the colony's problem. When a
Crown officer writes, it has reached the capital — and that is much worse news
than anything in the letter's text.

So escalation is **characterisation rather than a severity field**. The player
reads the envelope before the letter.

### And the complaint carries the remedy

A letter naming a problem is usually also how the PC learns there is anything he
can do about it. *Deal with these men* tells him tile denial exists, that it is
his to answer, and — by who is asking — roughly what it will cost to answer it.

**A problem no one writes about is a problem the player cannot act on**, which is
the correct consequence and not a gap to be papered over with a notifications
panel.

### The volume rule

SPEC §9.6 caps the desk, and a rule that *everyone who cares writes about
everything* would flood it in a year.

**`cares_about` is therefore also the input to how loudly a man wants to speak.**
Each concern carries a **pressure** — how far the world is from what he wants,
plus what happened last month — and he writes when one clears a threshold of his
own. Writing damps that concern and, more gently, every other concern he has.

So the most affected party writes first because his gap is largest, and the
escalation above falls out of pressure rather than needing a rule. See
`the-director.md`.

## 7. The Relationship is the single source of truth

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

## 8. Death, and what does not happen

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

## 9. Loyalty can always be recovered

**The base rule is that there is no permanent break.** Loyalty can always be
gained and always be lost, for every contact, at any point.

An individual contact may be **authored** with a condition that snaps his loyalty
to nothing — a line he will not have crossed. That is an exception written into
that contact, deliberately, with its reason. It is not a general mechanic, and no
code outside that contact's own definition may create one.

Note what this is not: SPEC §12.5 lets a native tribe's *trust* break
permanently. Trust is not loyalty and tribes are not contacts.

## 10. Tuning targets

- The loyalty bands in §4, and what each means in the compliance scoring.
- The balance between the standing drift term and accumulated deeds (§5). Too
  much drift and the player's letters stop mattering; too little and a contact
  ignores a collapsing world.
- How far personality weights may spread before a contact reads as broken rather
  than characterful.
- How many events a Relationship keeps, and how significance is scored (§6).

## 11. Open items

- Whether the drift term should be capable of moving loyalty faster than deeds
  can repair it. A contact whose world is falling apart may be unreachable by any
  letter, which is either a powerful thing or a frustrating one.
- Whether a contact's `cares_about` is fixed at generation or can shift with his
  circumstances.
- Whether the PC should be able to perceive *why* a contact's regard is falling,
  beyond the tone of his letters.
- Which events count as notable enough to keep, and whether a contact's
  personality should bias what he retains as well as what he reaches for.
