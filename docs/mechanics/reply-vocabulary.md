# The reply vocabulary

> **Serves:** SPEC §9.2 (responding), §9.4, §9.7 (content pipeline), §6.2
> (balance targets). **Extends:** `tone.md`, which owns *how* a thing is said.
> This owns *what can be said at all.*

---

## 1. Where we are

Measured across `data/letters_en/`:

| | |
| :--- | --: |
| letters with a reply | 48 |
| distinct step ids | 25 |
| distinct **option ids** | **87** |
| option ids used in exactly one letter | **69** |

**Every letter invented its own words.** There is no answer to *what can a player
say*, only a list of what 48 letters happened to offer — and no way to know
whether a new letter is offering a choice the game already has.

### It is already costing us

The tuner's personalities are lists of option ids to prefer
(`data/balance/policies.json`). Checked against the ids that actually exist:

| Preferred | Exists? |
| :--- | :--- |
| `yes` | **no** |
| `no` | **no** |
| `partial` | **no** |

**Seven of the eight shipped personalities prefer something that matches
nothing.** *the spendthrift* asks for `yes`, *the miser* and *the tyrant* for
`no`, and four steady-hand variants for `partial`. Those preferences silently do
nothing, every balance run to date has been quieter than it looks, and **nothing
failed** — which is the real problem.

### And a third of the one-offs are the same four words

Twenty of the sixty-nine singletons are **five identical ladders** with five
prefixes:

```
livestock_none  livestock_little  livestock_lot  livestock_great
curriculum_none curriculum_little curriculum_lot curriculum_great
volume_none     volume_little     volume_lot     volume_great
provision_none  provision_little  provision_lot  provision_great
experts_none    experts_little    experts_lot    experts_great
```

One idea — *how much?* — written five times. A personality that means *always
sparing* has to name all twenty, and will miss the twenty-first.

---

## 2. 🔒 An option is a rung on a family, not a word chosen per letter

**A letter picks a family. The rungs come with it.**

That is the whole change, and everything below is a consequence. The families
below are not invented — each is a cluster already in the data, given a name.

| Family | Rungs | Already appears as |
| :--- | :--- | :--- |
| **assent** | refuse · accept | `accept` ×5, `refuse` ×6, `deny`, `decline`, `grant`, `turn` |
| **magnitude** | none · a little · a lot · a great deal | the five ladders above |
| **purse** | nothing · part · fair · full · double | `pay`, `full`, `half`, `all`, `double`, `fair`, `part` |
| **priority** | the governor intents — eight since *educate the people* | `defence` ×9, `growth` ×8, `profit` ×7, `survival` ×6, `settle` ×5, `trade`, `be_rid_of_them` |
| **preference** | good ground · coast · ore · away from tribes | `map.md` §4's four requests |
| **manner** | ask · press · command | `ask` ×5, `press`, `command` |
| **terms** | let it rest · on conditions · ask what would keep them | `clemency`, `conditions`, `future` |

**Seven families cover most of eighty-seven ids.**

### Two ids already say the same thing

`endure` is labelled *"attend to the colony's profit"* and `profit` is the same
pronouncement. `survive` and `survival` likewise. **Two ids, one utterance**, and
a personality preferring `profit` gets it in seven letters and misses it in the
eighth. Nothing could have caught that.

---

## 3. What this buys: a personality is a lean per family

Today a personality is a list of words someone hoped were option ids. With
families it is a **position on each ladder**, which is a thing that can be
written once and be right about letters that do not exist yet.

| | purse | assent | magnitude | manner |
| :--- | :--- | :--- | :--- | :--- |
| the spendthrift | double | accept | a great deal | ask |
| the miser | nothing | refuse | none | press |
| the steady hand | fair | accept | a little | ask |
| the tyrant | nothing | refuse | none | **command** |

**A letter written next month is automatically answered by all four**, because it
offers families rather than words. That is the property the tuner needs and does
not have.

It also makes a personality *legible*: *the tyrant* differs from *the miser* in
exactly one column, and that is a hypothesis a balance run can test.

### A personality must also say what it writes unprompted

`tone.md` §3 has three letter kinds — **directing, answering, asking** — and the
harness has never produced an `asking` one (#334), because `balance.gd` only ever
walks the inbox. The two asking order kinds, `request_troops` and
`ship_resource`, come from letters the PC **composes**.

**So a personality carries a `composes` list as well as its leans**: which of
`Composer.purposes(run)` it takes up, and how readily.

| | Composes |
| :--- | :--- |
| the spendthrift | freely — he is the man who promises what is wanted |
| the steady hand | when the colony's condition calls for it |
| the miser | rarely, and asks for nothing he would have to pay for |
| the tyrant | readily, and harshly |

**The frequencies are tuning and belong in `policies.json`**, not here. What
belongs here is that composing is **a lean like any other**, scored the same way
— not a separate hardcoded script of actions, which would make the harness's
player a different animal from the one the families describe.

### Why this is the register with the most to lose

Asking has a knob the other two kinds do not: **partial magnitude**. Leaning on a
man enlarges the half measure, and the tone decides how generous he is underneath
the threat. **Both are asking-only, and neither has ever run** — so a miser who
composes nothing is a correct and informative result, and a harness that can
never compose is not a result at all.

---

## 4. The one-offs are allowed, and counted

Some choices are genuinely particular to their letter. *Move him* or *he stays
where he is* is not a rung on anything, and forcing it into a family would be
worse than leaving it alone.

**A letter may declare a one-off**, and the validator **counts them**. The number
is the health of this document: a handful is a living game, forty is the
vocabulary failing again with extra ceremony.

**A one-off cannot be preferred by a personality**, and that is the honest
consequence rather than a limitation — a personality is a disposition, and a
disposition has no opinion about whether the Diplomat is rehomed.

---

## 5. 🔒 The validator is the part that makes this stick

The vocabulary is not a convention. Conventions decay, and this one already did.

The content validator must fail on:

- an **option id that is neither a known family rung nor a declared one-off**;
- a **personality preferring something that does not exist** — the defect in §1,
  which shipped and ran for weeks;
- a **family offered with rungs missing**, so *a little* and *a great deal*
  cannot appear without *none*.

**The second is the one that matters.** Everything else is tidiness; that one is
a balance harness reporting on a player who was never simulated.

---

## 6. Getting from here to there

Not a rewrite. The families already exist in the data under other names, so this
is renaming plus a validator.

1. **Declare the seven families** and their rungs, in data.
2. **Fix `policies.json`** — `yes` → `accept`, `no` → `refuse`, `partial` →
   `part`. Three words, and seven personalities begin working.
3. **Collapse the five ladders** into `magnitude`. Twenty ids become four.
4. **Merge the duplicates** — `endure` into `profit`, `survive` into `survival`.
5. **Map the rest**, family by family, and declare what is left as one-offs.
6. **Turn on the validator**, which is what stops step 6 being needed again.

**Steps 1 and 2 are worth doing before anything else**, because until they are
done every number the tuner produces is from a player who does not answer the way
his description says.

---

## 7. Tuning targets

- How many one-offs is too many (§4). A number, set once there is a real corpus.
- Whether `manner` belongs here or in `tone.md`. It looks like tone and behaves
  like harshness, and `tone.md` §5 already owns the harsh clause.

## 8. Open items

- **Does every family need every rung in every letter?** *Purse* has five and
  some letters plainly want three. Either the rungs are a maximum a letter draws
  from, or families need declared subsets. **The first is simpler and probably
  right**, but it weakens §5's third check.
- **Is `priority` really a family, or is it the intent list wearing a hat?** It
  had seven rungs because `GovernorIntent` had seven members, and it has already
  changed once — *educate the people* made it eight — and it will again whenever
  that list does. **That is the argument settled by example.** Worth deciding whether it is authored here or derived there —
  **derived is better**, and it is the only family that could be.
