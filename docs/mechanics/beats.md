# Beats

> **Serves:** SPEC §15 (screens), §10.4, §14.2, §9.2, §16.3 (replaceable assets),
> §7, and Seam A in `CLAUDE.md`.

The sound engine and the animation engine are **one system**, because they answer
one question: of everything that just happened, which few things deserve the
player's attention, and in what order?

Two selectors would drift, and a sound for something the map never drew is the
letters/map desync Seam A exists to prevent, arriving through a different door.

---

## 1. One queue, three producers

What the screens share is **not** the event log. It is the queue and the
fast-forward contract. The event log is only the largest of three producers.

| Producer | Feeds | Selection needed |
| :--- | :--- | :--- |
| **The event log** | map playback, the end-of-run recap | **Yes** — hundreds of events, a handful of beats |
| **The reply wizard** | the drafting hand | **None** — one beat per choice, in order |
| **A cutscene script** | cutscenes | **None** — authored; the only choice is *which* cutscene |

So the selector is one component that only the first producer uses, and the queue
is the component all three share. **Building the queue first is the cheaper
order**, because the hand and the cutscene need it without needing the selector at
all.

### The split follows the house style

`ReplyWizard` is logic and `letter_view.gd` is its screen, and that separation is
what lets the wizard be tested without a viewport. Beats take the same shape:
**selection is a `RefCounted` that returns a list of beats; the runner is a node
that plays it.** A month's beat list can then be asserted headless.

---

## 2. Three layers of sound, and only one of them is beats

The music question and the page-turn question have different answers, and
conflating them is what would make this system too big.

| Layer | What it is | Driven by | Queued? |
| :--- | :--- | :--- | :--- |
| **Bed** | music and ambience | the **screen**, and the colony's condition | no — continuous, cross-faded |
| **Beats** | the scratch of the pen, a town starving | the queue | **yes** |
| **Feedback** | a click, a page turn, a confirm | player input | no — immediate, never delayed |

**Feedback is never queued.** A click that waits its turn behind an animation
feels broken, and the desk is a place where a fast player clicks quickly. Only
beats wait.

**The bed runs under everything and survives a fast-forward.** Music playing while
the player drafts is a bed; it does not restart when the hand is skipped, and it
does not restart when he moves from the desk to the map.

---

## 3. 🔒 Fast-forward settles. It never cancels.

**Every beat's outcome exists before its animation starts.** The animation
interpolates toward a destination already known; it never computes it.

Skipping is therefore: stop the tween, apply the remaining beats' outcomes
instantly, done. There is no half-finished state to unwind, no beat that must be
allowed to finish for correctness, and no path where the player sees a different
result for having been impatient.

**The shipped code already has this property**, which is why it is a lock rather
than a proposal:

- `ReplyWizard.assemble()` is a pure function of the choices made so far. The
  hand reveals text that already exists.
- The map's month-end state is the sim's state. Skipping playback draws the map
  it was going to draw anyway.

**A system that makes the animation the source of truth breaks this**, and it
breaks it silently — everything looks right until someone skips.

### What a skipped beat does to sound

**Its sound is dropped, not compressed.** Four skipped sentences must not fire
four pen-scratches at once. One resolution sound covers the whole skip — the
letter being folded, the map settling — and the bed carries on underneath.

---

## 4. The beat

```
kind       StringName   registry id: picks the art and the sound
subject    StringName   town, contact, company — who it is about
place      Vector2i     where, when it has a where
magnitude  float        0..1, how hard to draw it and how loud
```

**A beat carries no prose.** `SimEvent` already holds this line — *"the payload is
never prose"* — for the same reason: a sentence here would decide the language in
code, in English. Where playback needs a caption it comes from `data/` like a
letter does.

**A beat names assets, it never paths them.** SPEC §16.3 requires replaceable
references, so `kind` resolves through a registry to a sound and a sprite.
Placeholders until M9's swap-in, and the swap must need no code change.

> ⚠️ **The registry holds data or named static functions, never lambdas.** Godot
> 4.7 segfaults on shutdown with a lambda still held in a static registry
> (`CLAUDE.md`). A beat registry is exactly the shape that invites one.

---

## 5. The drafting hand

The clearest case, and the one that sets the contract.

**Two things run at once and at different speeds.** The wizard is the player's
pace; the hand is the letter's pace. A player who knows what he wants clicks
through every step and leaves the hand four sentences behind, writing dutifully.
A player reading each option never sees a queue at all, because the hand keeps
up.

Each choice pushes **one beat**: the sentence that choice just added. The hand
draws it; the pen scratches; the bed plays under both.

### 🔒 The hand only ever appends

**Tone is step one and must stay step one.** Tone resolves every line in the
letter, not only the opening — `ReplyWizard.assemble()` re-renders inserts,
`only_tones` lines and per-line overrides against it. A format that asked for
tone at step three would rewrite sentences the hand had already drawn, and the
player would watch his own letter change behind the pen.

`next_step_index()` returns 0 while tone is unchosen, so this holds today. It is
written down because nothing currently stops a new letter file breaking it.

**Rewriting is a reopen, not an edit.** SPEC §16.2 lets the player change his mind
until the post is sent; reopening a letter clears the sheet and the hand starts
again. That keeps append-only true without taking the rewrite away.

### Sign and post

The last step is not a sentence. **It resolves the queue and ends the letter:**

1. The hand fast-forwards — §3's settle, one sound, not four.
2. The full prose is readable for a beat. **This is the only moment the player
   sees what he actually wrote**, so it is not optional and it is not skippable.
3. The letter folds and goes to the post, quickly.
4. The desk is clear and the next letter is selectable.

**Step 2 is the reason the hand exists.** The mad-libs wizard shows fragments; the
assembled letter is the first time the choices read as a letter in his voice. An
animation that skipped straight from the last click to a clear desk would save
two seconds and lose the point.

---

## 6. Map playback, and the only place selection is needed

A busy month emits hundreds of events across 96 kinds. Drawing them all is
unwatchable, so playback has the director's problem and takes the director's
shape: **filters first, then scoring, then a budget.**

### Filters — locked rules, applied before scoring

- **Nothing outside the known map.** The map shows what the colony knows
  (§11.2). An event in unexplored country is not a beat, however large.
- **Nothing without a place.** Crown standing moving is not a map event. It
  belongs to the ledger and the letters.

### Scoring

Magnitude first — a town losing its last worker outranks a good harvest — then
novelty. **Routine repetition is damped exactly as the director damps a topic:**
a town that grew every month for a year should stop being worth a beat.

### 🔒 The budget is time, not count

The director budgets **letters** because reading speed is the player's own.
Playback budgets **seconds** because it runs at the game's pace, and beats differ
in length. A month that is ten short beats and a month that is four long ones
should take about as long.

**Target: about 20 seconds for a month, and it is always skippable.** Both
numbers are tuning targets for M8.

### 🔒 A beat that didn't play is not an event that didn't happen

The director's rule, restated where it will be forgotten. A culled beat still
reached the ledger, still reached the letters, still moved the state. **Playback
is the least authoritative view of the month**, and the one place it is safe to
drop things.

---

## 7. Cutscenes have no fast-forward

SPEC §15: *the only input is advance.* **Advance is the skip** — it moves to the
next beat of an authored sequence rather than collapsing the whole thing.

So a cutscene needs the queue and nothing else. **The only selection is which
cutscene fires**, and that reads the event log the way a letter trigger does.
A run opens with one (§6.1).

---

## 8. What Godot gives us, and what it does not

Recorded because it shapes the work, not because it belongs in a design doc.

- **`AnimationPlayer` for authored sequences** — the fold-and-post flourish,
  cutscene transitions. `seek(t, true)` snaps to a time, which is fast-forward
  for free.
- **`Tween` for procedural motion** — the hand along a line of text. Fast-forward
  is kill the tween and set the final value, which is only safe because of §3.
- **Sound is non-positional.** The map is read-only and browsable; audio that
  panned with the camera would make the same month sound different depending on
  where the player had scrolled.
- **The bed wants a cross-fade, not a cut.** Two `AudioStreamPlayer`s and a
  fade is the boring version and probably the right one; Godot's
  `AudioStreamPlaylist` may do it, and is **unproven here**.

---

## 9. Tuning targets

- Seconds per month of playback, and the per-beat floor and ceiling.
- The damper on routine repetition, measured in months.
- How long the assembled letter is held before it folds (§5, step 2).
- Bed cross-fade length between screens.

## 10. Open items

- **Does the end-of-run recap use the same budget?** It covers a whole run rather
  than a month, and 20 seconds of it would be a slideshow. It likely wants
  scoring by magnitude across the run with no per-month floor at all — but that
  is a different selector, and it is M9's problem rather than this doc's.
- **Does the bed know the colony's condition?** Music that darkens as the colony
  fails is cheap to state and easy to overdo, and it risks telling the player
  something the letters are supposed to tell him. Author's call.
- **Placeholder sound during development.** Silence is a defensible placeholder;
  a beep per beat would surface missing registry entries early. Worth a cheap
  decision before M9.
