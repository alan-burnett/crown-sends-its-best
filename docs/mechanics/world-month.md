# Mechanics — The World Month

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §7 (Order of time), §11.3 (the Colony Month), §13.1
> (last-chance stage), and the Distance pillar in §2.

---

## 1. Scope

SPEC §11.3 specifies the **Colony Month**: nine phases that towns move through
together. That is one phase of a larger cycle. Expeditions, armies, tribes,
rivals, the Crown itself and every contact also act each month, and they are not
towns.

This document defines the **World Month** that wraps the Colony Month, and the
timing rule that governs when a player's order becomes a thing that happens.

## 2. The nine phases

Each phase completes for every actor before the next phase begins, on the same
principle §11.3 locks for towns. No actor benefits from being simulated first,
and ties are broken by a rule fixed by the seed.

| # | Phase | What resolves |
| :-- | :--- | :--- |
| 1 | **Arrivals** | Everything in transit from the Crown makes landfall |
| 2 | **Movement and action** | Units execute standing Intents; battles resolve |
| 3 | **Territory** | Borders, vision and influence areas recomputed |
| 4 | **The Colony Month** | The nine phases of SPEC §11.3 |
| 5 | **The Crown's Month** | Standing, demands, distant wars, promises |
| 6 | **Run-end check** | Fail conditions, last-chance stage, the 50-year cap |
| 7 | **Reckoning** | Everyone evaluates; relationship and loyalty update |
| 8 | **Intent** | Everyone deliberates and commits |
| 9 | **Dispatch** | Correspondence goes out |

### 1. Arrivals

The westbound crossing resolves. The PC's post reaches the colony, and with it
everything else that was at sea: promised gold and resources, Crown troops the
Marshal sent, immigrants arriving with their own supplies and gold (§12.1),
experts from the Provost.

Material arrivals land here because units act in phase 2 and towns work their
tiles in phase 4; both need this month's arrivals already on the ground.

Letters arrive here but are not *read* until phase 7. A dispatch reaches a
commander in the field after the fighting he was already committed to. This is
the delay theme working, not a bug.

### 2. Movement and action

Units execute the Intents they committed to last month: moving, building a fort,
razing an improvement, besieging or attacking a town. Battles resolve here.

Nothing in this phase consults this month's post. Everything here was decided
last month.

### 3. Territory

Units moved and towns may have changed hands, so colony border, vision, and town
influence areas (§11.2) are recomputed.

**This must sit between movement and the Colony Month.** Phase 4 assigns
population to tiles inside influence areas; recomputing those mid-Colony-Month
would break §11.3's locked phase ordering in a way that is cheap to prevent and
expensive to debug.

### 4. The Colony Month

SPEC §11.3: Work, Reckon, Relief, Exchange, Consume, **Convert**, Build, Sell,
Settle. Every town completes a phase before any town begins the next.

**Convert sits between Consume and Build**, so a town cannot brew the grain its
people need and this month's ore can reach this month's frame. See
`town-economy.md` §11.

By now the colony knows what it lost. Yields reflect the three farms the natives
burned in phase 2, not the farms that stood last month.

### 5. The Crown's Month

The other side of the ocean advances. Crown standing updates, demands grow, the
Crown's wars elsewhere move on and may stretch the Marshal thin, and **promises
are honored or broken** against the treasury (§9.5, §10.3).

This must precede phase 7. A contact cannot acknowledge a promise the Crown has
not yet broken.

### 6. Run-end check

Fail conditions, the last-chance stage, and the 50-year cap (§13.1, §13.2).

**This must precede Dispatch.** §13.1 locks that every fail condition passes
through a last-chance stage with a formal Chancellor warning. If the check ran
after correspondence went out, the warning would always arrive a month late and
the invariant would break. Running it here lets the Chancellor's warning, or his
news of final defeat, ride out with the same month's post.

### 7. Reckoning

Every actor evaluates: what the post said, which promises were kept and which
were not, and what the world now looks like. **Relationship and loyalty update
here** (§8.5).

Feelings settle before decisions are made. If this merged with phase 8, contacts
would deliberate on last month's loyalty.

This covers contacts, governors and commanders, and also tribes and rivals as
**factions** — §12.4 and §12.5 make them full actors with their own goals, not
map furniture.

### 8. Intent

Every actor deliberates through the kernel and commits to an Intent for next
month. See `docs/mechanics/deliberation.md`.

Nothing in this phase changes the world. Will is not a write.

### 9. Dispatch

The eastbound crossing. Correspondence goes out, reporting the month and
**announcing intent**. The player learns what people are about to do before they
do it.

---

## 3. The timing rule

### Turns and months are different clocks

A **Turn** (SPEC §4) is the player's unit: one round trip of correspondence. A
**World Month** is the simulation's unit: the nine phases above. They interleave,
and **they are not the same index.**

Within turn T, per SPEC §7:

| Turn T step | What the player sees |
| :--- | :--- |
| Date card | |
| Map playback | the world month that ran at the end of turn T-1 |
| Desk | letters dispatched by that same world month, in its phase 9 |
| Send the post | |
| Resolution | **a new world month runs** |

**The desk is not inside the month it is reading about.** It sits between the
month just reported and the month about to run. A dev who reads "the current
month" as "the month I am looking at on the desk" is off by one, because the
month being looked at has already finished and the next has not started.

This is the most common way to misread the timing rule, so ticket acceptance
criteria should say **acknowledgment** or **physical consequence** explicitly and
should count in **turns**, never in bare "months".

### The rule

**An Intent committed in month N executes in phase 2 of month N+1.**

Stated in the player's clock, which is how tickets should phrase it:

> An order written on turn T is **acknowledged** in turn T+1's letters, and its
> **physical consequence** happens during turn T+1's resolution, which the player
> watches in turn T+2's map playback.

Trace a player order through the cycle:

```
end of month N     player writes "break off and return to the town"
month N+1 phase 1  the letter arrives
month N+1 phase 7  the commander reads it; relationship updates
month N+1 phase 8  he commits to a new Intent
month N+1 phase 9  he writes back announcing it
month N+2 phase 2  he actually does it
```

**One month to hear back. Two months to see it happen.**

### The countermand property

A player can never stop an announced intent. He writes "I shall retreat to the
town"; you write back "no, attack." Your letter arrives in phase 1 of the
following month, but he retreats in phase 2, four phases before he reads you. You
watch the retreat, and the month after that he attacks.

This is correct and intended. It is the Distance pillar with teeth, and it is why
phase 9 announcing intent matters: the player is never blindsided, only ever too
late.

### The design rule that follows

**Make consequential actions multi-month, so they can be interrupted.**

A single-month action cannot be stopped, and that is where "your orders arrived
too late" should sting. But if *every* action were single-month the player would
be a spectator. §11.4 already does this for expeditions, which cross the map over
months and can be turned back partway.

Apply it generally. A commander marching three tiles to attack takes three
months, and a letter can turn him around in month two. A siege takes months. A
skirmish does not.

### Note for tickets

SPEC §7 says letters are "acted on during the next simulation step." That is
true: they are read, they change relationships, and they produce new Intent, all
in the next step. A dev could reasonably read it as meaning the *physical*
consequence lands in the next step too, implement one-month effects, and quietly
destroy the announce-then-act property. It does not mean that.

## 4. Events

Every phase emits to the event log (Seam A). The log drives map playback,
cutscene triggers, letter content and the ledger, so a phase that changes state
without emitting desyncs what the player sees from what the letters say.

Phases 7 and 8 emit **deliberation traces**, which give letters their motive: the
reason in the prose is the reason in the trace.

## 5. Open items

- Whether phase 5 needs to split, with promise resolution ahead of standing so
  standing reflects this month's payments.
- Whether tribes and rivals need reckoning inputs distinct from contacts', or
  whether one shape serves both.
- Where a contact's death or replacement (§8.2) resolves. Currently assumed to be
  phase 7, but a casualty from phase 2 may want to be visible sooner.
- Typical durations for multi-month actions. Tuning, and it needs playtest.
