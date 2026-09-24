# Mechanics — Commanders

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.6, §12.6, §8.5, §12.3, and `battles.md`.

---

## 1. A commander is a contact attached to a company

He has a name, a personality, leans, `cares_about` and a **relationship** with
the PC, exactly as every other contact does (`contacts.md` §1). What makes him a
commander is that a company is attached to him.

**Colonial, Crown and rebel commanders are the same object.** A rebel general
corresponding with the Crown about terms is the mechanism working, not a special
case — which is the channel §12.3 implies when it says the PC keeps writing to a
rebel town and never names for its soldiers.

## 2. Who leads a company

**The size of the town that raised it decides**, not its order. Author's ruling
(`governor-agendas.md` §6):

| | Led by |
| :--- | :--- |
| **Small company** | always a **militia** |
| **Big company** | a **commander** — or a militia if its town had **5,000 or fewer** people |

**A militia may leave the town.** It is not a garrison. It serves **12 months**,
then disbands, and its people go home to the town that raised it.

**Every company chooses its own standing order when it is raised** — from the
state of the map and the intent of the governor who raised it. A company raised
under go wide that sees no threat nearby sets itself to *explore*. **How a
militia and a commander each choose is not yet designed** (#423), and this doc
will carry it when it is.

### Three outcomes at raising

1. **A big company, and a veteran is waiting in this town** (§7) — he takes the
   command, at the level he left at.
2. **A big company, no veteran** — a new commander is generated, at level zero.
3. **A small company, or a big one from a small town** — a militia, with no
   commander, and it disbands at the end of its term.

## 3. Orders are not objectives

Worth being exact, because the words carry weight elsewhere.

A town has an **objective** that it holds until complete or until its
governor's intent changes (`governor-objectives.md` §7). A militia has none of
that. It has a **standing order**, chosen once when it is raised (§2), and every
map move executes against it until the company disbands or dies.

**No reconsideration machinery applies to a militia**, and a dev who wires it
there has misread both docs.

A **commanded** company is the opposite: its commander deliberates afresh every
month, and his intent can change.

## 4. Coordination, without a general staff

A commander is the first actor in this game that reasons about **other actors'
plans**. Everything else deliberates about its own situation alone.

**This needs no new layer and no faction brain.** It is the ordinary kernel with
considerations that read the `IntentBook`:

- is somebody already besieging this place
- is a town sitting undefended
- is a friendly company about to be overwhelmed
- is this the only road left open

Each reads Intents **other commanders committed last month**, which is the same
one-month lag everything else in the world runs on. Coordination therefore
**emerges** rather than being directed — consistent with governors, who optimise
independently while nobody plans the colony.

It also has to be this way in fiction. §12.6 locks that the PC never commands,
and the Marshal is an ocean away. **There is no general staff to model.**

### The failure mode to watch

Emergent coordination goes wrong in two specific ways: every commander converges
on the same attractive target, or nobody covers a gap because each assumes
another will.

If the harness shows either, **the fallback is a faction-level assessment that
assigns roles before anyone deliberates** — two levels, exactly as governor intent
precedes town objective. Do not build it pre-emptively, and do not paper over the
symptom by scripting behaviour into particular commanders.

## 5. 🔒 Refusal is not a branch

**There is no "will he obey" check anywhere.**

A commander scores every option open to him — attack, hold, march, withdraw to the
town and disband — and takes the best. *Refusing to attack* is simply **attack
scoring below retreat**, and it needs no code of its own.

**Keeping his army alive is one of his considerations**, weighted by personality.
A cautious man weights it heavily and will not spend his men on a fort; a
glory-seeker weights it low and will. Both are reading the same board.

So the answer to *can a commander refuse to attack* is yes, and the answer to
*how* is: the same way everybody in this game refuses anything. Compliance with
the PC's letters runs through the identical path (§8.5) — the letter moves the
weights, it does not move the company.

**And the trace is the letter.** `choose()` emits its scoring, so when a commander
writes to say he will not assault the fort, the reason in his prose is the reason
in his trace.

## 6. Experience

**Commanders accumulate.** They gain experience in the field and each level buys
something new.

### What earns it

**Casualties inflicted**, not battles won — because `battles.md` §6 has no rout
and no surrender, so *winning* is not a quantity that exists. A battle exchanges
losses and that is all.

Casualties inflicted scales correctly on its own: grinding a fort down over two
years earns far more than a skirmish, which is the right ordering. A commander
who has done nothing but garrison duty learns nothing, and should not.

### What levels buy

Drawn from the genre, with one constraint of our own: **every bonus must be
sayable in a letter.** A commander should be able to tell the PC what he has
become without the prose reading like a character sheet.

| | |
| :--- | :--- |
| **Bearing** | a multiplier on the company's force |
| **Marches** | an extra move |
| **Hardiness** | less attrition while unsupported |
| **Country** | a specialism in one terrain |
| **Husbandry** | fewer arms wanted per head, so the same cargo arms more men |
| **Siegecraft** | part of a fort's defensive bonus ignored |

They stack, and a long-lived commander becomes genuinely formidable. That is
intended: **he is the one competent person in the PC's employ, and the PC cannot
direct him.**

## 7. Death, and coming back

**When a company is destroyed, its commander does not automatically die.**

A coin flip, from a named RNG stream like everything else:

- **He is killed with his men.** His experience dies with him. There is no
  recovering it and nothing to inherit.
- **He survives, injured**, and writes to the PC from the town that dispatched
  him — hoping to take the field again whenever the town can spare the men.

### Which is why no resupply mechanic is needed

A company still **only ever dwindles** (`battles.md` §2). It is never reinforced
and never re-equipped.

**The commander is the thing that persists, not the company.** A veteran waits in
his town and takes the next command raised there, at the level he left at. So
experience survives across companies without any of the machinery that
reinforcing them would demand — and `battles.md`'s dwindling lock stays intact.

A commander whose company **disbands** on its timer rather than being destroyed
needs no coin flip at all. He simply goes home and waits.

### And his letter is an instrument

The surviving commander writing from the town is not flavour. It tells the PC
that a veteran is sitting idle, and the PC's answer is a letter to the governor
arguing for the men to give him one. **A general without a command is a standing
argument for raising another company**, made by the man himself.

Which also means the PC can get his best commander killed by refusing to pay for
horses, and can lose him permanently on a coin flip afterwards. The Marshal's
fury at casualties (`the-marshal.md` §4) acquires a second edge here.

### Rebel commanders too

A rebel general who survives three years of this becomes very hard to remove, and
is corresponding with the PC the whole time. That is the shape the design wants:
**the man the PC must eventually negotiate with is one his own colony made.**

## 8. What the PC can do

Nothing directly (§12.6, locked). By letter he can:

- **Argue with a commander's intent**, never his target. §12.6 gives the PC goals
  and allocations; the tile is the commander's, exactly as it is the governor's.
- **Press a governor to raise a company**, and to give it to a particular veteran.
- **Send gold** when a commander asks for horses (`battles.md` §2).
- **Pay the Marshal** enough that his troops, and their officer, stay.

Each is a month or more early, and each moves the weights rather than the
company.

## 9. Tuning targets

- Casualties per level, and how many levels there are.
- What each bonus is worth.
- The survival coin flip. It is currently even; it need not be.
- How long a veteran waits before he stops being available.
- The weight of *keep my army alive* in a default personality, which decides
  whether commanders read as brave or as sensible.

## 10. Open items

- **Whether a veteran is bound to the town that dispatched him**, or can be sent
  to another. Bound is simpler and gives a well-defended town a natural officer
  corps; portable makes veterans a colony-wide asset the PC has to move by letter.
- Whether the PC learns a commander's level, or only infers it from how he writes
  and what he achieves. Inference is more in keeping; it may be too opaque.
- Whether a commander's `cares_about` should include his own men, so that a PC
  who spends them freely loses his loyalty. Probably yes, and it would give
  `contacts.md` §6's *the victim writes* a military voice.
- What happens to a commander whose town is lost while he is in the field. He has
  nowhere to go home to, and nothing says whether he disbands, defects, or
  persists.
