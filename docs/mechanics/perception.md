# Mechanics — Perception

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §9.1 (Letters never lie about what has happened; Framing).

---

## 1. What this system is for

A letter must be able to say "your people are starving" without the game ever
telling the player something untrue. §9.1 draws the line: **quantities are
exact, judgments are biased.** Perception is the machinery for the judgment half.

Two contacts may describe the same event very differently and both be telling
the truth. Perception is how that happens without anybody lying.

## 2. Division of labor

| Owns | What it owns | Where it lives |
| :--- | :--- | :--- |
| Simulation | The true number | Sim state |
| Registry | What counts as high or low for that number | Code, per `measure` id |
| Contact | How much this person shades it, and which way | Contact data (`lean`) |
| Author | Every word the player reads | `data/letters_en/**` |

The author never needs to know that `crown_war_intensity` runs 0-100 while a
food ratio runs 0-3. The registry normalizes; the ladder supplies words.

## 3. The pipeline

**Step 1 — normalize.** Each `measure` id is registered in code with a
normalizer mapping the raw sim value to `p` in `[0.0, 1.0]`.

```
measure "food_security"
  raw        = stockpile / consumption
  normalized = 0.0 at ratio 0, 1.0 at ratio 3.0
```

**Step 2 — lean.** Each contact carries a signed `lean` in `[-1.0, +1.0]` per
topic, applied in normalized space:

```
perceived = clamp(p + lean, 0.0, 1.0)
```

`0.0` is an honest reporter. `-1.0` and `+1.0` are total distortion. Typical
authored values are small, roughly `±0.1` to `±0.3`. Applying the lean in
normalized space rather than as an index shift keeps it meaningful across
ladders of different lengths.

**Step 3 — climb the ladder.** Rungs are evenly spaced points, not bands. With
`N` rungs, rung `i` sits at `i / (N-1)`, and the reported word is the
**nearest** rung:

```
index = round(value * (N - 1))
```

Nearest rather than floor, so the top rung is reachable well before `1.0` and
the lower rungs are not unduly favored.

**Step 4 — cap the distortion.** The lean may never move the result more than
one rung from the truth:

```
truth_index  = round(p         * (N - 1))
biased_index = round(perceived * (N - 1))
final_index  = clamp(biased_index, truth_index - 1, truth_index + 1)
```

Without this cap a large lean on a short ladder produces flat contradiction
between two senders, which reads as lying rather than framing and violates §9.1.

## 4. Worked example

Month end, town of Ashmere. Stockpile 180 food, monthly consumption 200.

```
raw = 180 / 200 = 0.90
p   = 0.90 / 3.0 = 0.30
```

**The Governor of Ashmere** is aggrieved and wants relief, so he makes his own
town sound worse. `lean = -0.18` → `perceived = 0.12`.

```jsonc
"perception": {
  "larder": { "measure": "food_security",
              "ladder": ["starving", "hungry", "fed", "comfortable"] }
}
```

`N = 4`. Truth: `round(0.30 * 3) = 1` → *hungry*.
Biased: `round(0.12 * 3) = 0` → *starving*. Within one rung, so it stands.

> "My people are starving, and the Crown's ships pass us by."

**The Steward**, writing about the same town in the same month, minimizes
colony hardship because it argues against his tax policy. `lean = +0.15` →
`perceived = 0.45`. His letter carries its own ladder, with its own words and
its own rung count:

```jsonc
"larder": { "measure": "food_security",
            "ladder": ["in genuine want", "managing", "amply provisioned"] }
```

`N = 3`. Truth: `round(0.30 * 2) = 1` → *managing*.
Biased: `round(0.45 * 2) = 1` → *managing*.

> "Ashmere is managing, and would manage better still at a firmer rate on tea."

One sim number, 180 against 200. The Governor says *starving*, the Steward says
*managing*. Recognizably different, not contradictory, and neither reports a
false figure.

Note that *amply provisioned* is out of the Steward's reach here — the cap is
doing its job. Direct contradiction between two senders is the failure mode
this system is built to prevent.

## 4a. Ranges must track the size of the colony

A measure normalised against a **fixed** range stops meaning anything as the
colony grows. Two hundred gold is a fortune in year one and a rounding error in
year ten; five hundred bushels is a full granary for thirty people and a famine
for three thousand. A ladder pinned to absolutes will say *ruinous* forever, or
*trifling* forever, and the words stop carrying information.

**Prefer measures that are already ratios.** `food_security` is
`stockpile / consumption`, so it scales by construction — a town of thirty and a
town of three thousand both read 1.0 when they hold a month's food. Most measures
can be written this way, and should be.

**Where a raw quantity is unavoidable, the normaliser takes its reference from
current state**, not from a constant: gold against the colony's monthly trade
volume, a demand against the running size of recent demands, a war party against
the strength of the town it is walking toward.

### This is correct, not merely convenient

Perception is a person's judgement, and a person's scale is their own world. The
governor of a hamlet and the governor of a city both say *our granary is full*
when it is full **for them**, and both are telling the truth.

**Nothing is lost, because exact quantities are unaffected.** `{param:}` carries
the true figure and always did. A letter can say the town holds four thousand
bushels and that the granary is comfortable, in the same sentence, with the
number absolute and the judgement relative. The split between truth and framing
does the work.

## 5. Authoring notes

- **Ladders are local to the letter that uses them.** The same `measure` can
  carry entirely different words in different letters. "Putting good folks out
  of work" can live in the request-tax-decrease letter and appear nowhere else.
- **Ladder length controls how visible a lean is.** In the example above the
  Steward's `+0.15` changes nothing on a 3-rung ladder, because one rung spans
  half the range. If a contact's slant should be legible to the player, give the
  ladder more rungs. If the topic is coarse, few rungs is fine and the lean will
  mostly not show.
- **A strong lean and a mild lean often produce the same word**, because the cap
  saturates at one rung. Past roughly `1 / (N-1)` extra lean buys nothing.
- **Rung count is free.** Two rungs is legitimate for a yes/no flavor judgment.

## 6. Tuning and open items

- Actual `lean` values per contact and topic. Not yet designed; first pass will
  be authored alongside the Crown Officers and revised from playtest.
- Whether `lean` scales with loyalty, or is a fixed trait per contact per topic.
- The contents of the measure registry, which grows with the sim.
