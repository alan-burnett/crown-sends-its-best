# Mechanics — The Diplomat

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.1, §12.3, and the satire in §3.2.
>
> **SPEC §8.1 matches this document as of v2.0.**

---

## 1. What he is

The PC's only **resident** eyes. Every other view of the colony arrives from
someone with a stake in what it says — a governor defending his town, a Steward
arguing for taxes. The Diplomat's job is to tell the PC what is actually
happening.

He is not, however, a saint. He is a courtier posted overseas who would like his
comforts, and **what he reports degrades as his regard for the PC does.** For
every other contact, low loyalty spoils compliance; for the Diplomat, low loyalty
spoils the intelligence. That is the whole of his design.

The satire is in the gap: he writes about starvation in one paragraph and asks
for money for his own luxuries in the next, and both letters are true.

## 2. Where he lives

He is **aware of every town but housed in one.**

### On every town

- Rebel sentiment
- Low safety
- Starvation, and lack of clothing
- Low quality of life

With **suggestions**: lower the tax on luxuries, order the governor to stop
rebelling, to build defences, to focus on food. **His suggestions are surface
level.** He sees one town's problem and proposes the obvious remedy for it,
taking no account of the PC's whole situation — the Crown's demands, the other
towns, what a tax cut would do to standing.

**His suggestions are locally correct and globally naive.** They would genuinely
work for the problem he named. Shipping the town rum really would raise its
quality of life — it is simply not a responsible way to run a colony, and he has
no view of the Crown's demands, the other towns, or what a tax cut does to
standing.

**He never suggests something mechanically false.** He will not propose raising
taxes to quell rebellion. That would be confusing rather than characterful, and
it would teach the player to stop reading him.

### On his home town only

- The **intent, loyalty and relationship** of the governor and every other
  contact in that town
- **Every time an order is refused** by a contact there

This is the sharpest intelligence in the game, and it covers exactly one town.

## 3. Rehoming

### When he asks

When his town's **rebel sentiment** or **safety** reaches a low point. Either
alone is enough.

### Where he asks to go

The town where the **sum of those two problems is least**, breaking ties toward
the **largest** town.

### What it costs

Three things, which is what makes refusing a real option:

- **Gold**, paid like any other promise.
- **A couple of months without reports** while he travels.
- **The home-town intelligence moves with him**, and the PC probably wants it in
  his capital rather than wherever happens to be quietest.

So the decision is never obvious: agreeing goes blind for two months and moves
the sharp reporting away from the town the PC most wants to watch; refusing keeps
it where the fire is and risks the man.

## 4. His price

When quality of life in his town is low, **he asks the PC for additional gold.**

It does not reach the town. It is for his own luxuries, because the place has
become unpleasant to live in. Mechanically it is a patron's request: pay and his
loyalty rises, refuse and it falls.

A man who reports on a starving town by asking for money to make his own life
there more bearable is the satire working exactly as SPEC §3.2 intends — and he
is never lying about the starving town.

## 5. Loyalty, and what he stops telling you

His loyalty governs the **quantity and tone** of his reporting, on a ladder:

| Loyalty | What arrives |
| :--- | :--- |
| High | Everything, warmly, with useful suggestions |
| Falling | Tone cools; suggestions get curter |
| Low | **He stops reporting on his own matters** — the home-town detail goes first |
| None | Only two letters ever: a request for gold, or a request to be rehomed |

**Both of those letters are a way back.** Granting either raises his loyalty, so a
PC who has neglected him can buy his way back into being informed. That matters,
because a Diplomat at zero loyalty is a PC flying blind in the milestone where
rebellion is the likeliest way to lose.

## 6. His death

Two ways, and only two.

**Rebellion kills him outright.** If his town flips to rebellion he dies, full
stop. No roll. This is what gives the rehoming request its teeth: the letter is
the warning, and ignoring it is how the man is lost.

**Enemy attack may kill him.** Every time his town loses population to an enemy
attack, he dies with probability `1 / new_population`. Going from ten to nine is
a long shot; going from two to one is certain. A town reduced to nothing takes
him with it.

**No event ever costs more than one population** (see `CLAUDE.md`), so this is
always a single roll against `old - 1`. Five lost battles in a month are five
separate losses and five separate rolls, not one large one.

Note what this excludes: **population lost to famine does not endanger him.** Only
enemies do.

Between them these cover both halves of SPEC §8.1's intent — towns that rebel and
towns that suffer at the hands of rivals and natives — while keeping his death a
consequence of something the PC can see coming. The "every town rebels" case
needs no special rule: wherever he is will flip, and that kills him.

Afterwards the run continues with **no Diplomat and no replacement** — SPEC §8.1
is clear that nobody will take the post.

## 7. Tuning targets

- The sentiment and safety thresholds that trigger a rehoming request.
- The gold cost of rehoming, and of his personal requests.
- How many months of silence a move costs.
- The loyalty bands at which each tier of reporting stops.
- How much accepting a request restores.

## 8. Open items

- Whether a second rehoming costs more than the first.
- Whether he reports on rival or native activity at all, or only on the colony.
  Currently only the colony.
- How his reports interact with a town that has already rebelled, where the
  governor will not speak to the PC but the Diplomat might still be living there.
