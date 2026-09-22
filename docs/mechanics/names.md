# Names

> **Serves:** SPEC §8.1, §8.2, §8.3, §8.6, §11.4, §9.7 (content pipeline),
> §16.1 (determinism). **Extends:** `contacts.md` §1.

---

## 1. Who is named, and who is not

| | Named how |
| :--- | :--- |
| **The PC** | **the player's**, auto-filled from the aristocrats' bag |
| **The five Crown officers** | **fixed in data** — SPEC §8.1 makes them the same every run |
| **Rivals** | **fixed in data** — three named dukes, hand-written |
| Governors, patrons, commanders, clergy, quartermasters, journalists, scholars | **generated** |
| **Towns** | **generated** |
| **Tribes** | **not named at all** |
| **Patron homes** | **there are none** |

**Rivals are hardcoded on purpose.** They are a fixed cast like the officers, they
carry hand-written letters already (`tribute_demand_montargis.json`), and their
names do specific work — Don Íñigo de Alcaraz, Le Duc de Montargis and Grevé
Anders Vasterholm are three different nations against three different coasts. A
generator would have to be taught all of that to produce what three lines of data
already say.

**Tribes have no names by the Author's ruling.** They are known by what they are
and where they are, not by what they call themselves — which is the colonial view
the game is written from, and cheaper besides.

### 🔒 The PC is named by the player, and the game guesses first

SPEC §5: *the player chooses a name and a title for the PC which are referenced
in letters to the PC in that run. This is flavor only and has no effect.*

**Both fields arrive filled in.** The title defaults to **Lord**; the name is
drawn from the **aristocrats' bag**, which is the right bag because he is a minor
royal and it is the same pool his patrons come from.

**A guessed name he keeps is struck from the bag for that run.** §5's rule that
no two live things share a name, applied to the one thing that is not generated —
a patron who happened to share the PC's name would read as a mistake even though
nothing was wrong.

**Both are free text, and bounded.** The player is naming his own character, so
he types it; the bounds exist because it lands in period-style prose and in a
salutation line.

| | Min | Max |
| :--- | --: | --: |
| **Title** | 1 | **20** |
| **Name** | 1 | **48** |

**A minimum of one is what removes the empty case**, so nothing downstream needs
a fallback for a nameless PC — there is no such PC. Measure it **after trimming**
, or a single space satisfies the minimum and puts the empty case back.

**The old default was *Governor*, and it was a trap.** §2 makes the first word of
a letterhead the role, so a PC styled *Governor* read exactly like one of his own
colonial governors. *Lord* is not a preference; it removes a collision.

**A patron has no home**, by the same ruling. An earlier draft invented one so he
would have somewhere to be *of*; §2's qualifier does that job without inventing a
place, and a name with no mechanics behind it was a thing to maintain for nothing.

---

## 2. 🔒 The letterhead

**`<Role> <name>` and then a qualifier.**

> **Governor Don Johnson of Morrisville**
> **Commander Ames Harker of the town of Ashmere**
> **Patron Mingle Welkington**

### 🔒 The first word is always the role

Not an honorific. No *Captain*, no *Lord*, no *Father*.

**It is there to be scanned, not to be flavour.** An experienced player should be
able to look at the stack and know what came in without opening anything, and a
desk of *Lord*, *Sir* and *Captain* tells him nothing about who wants what. A
desk of **Governor. Commander. Patron. Journalist.** tells him the whole month.

This costs a little colour and buys a real thing, and it is the same trade
`the-director.md` makes when it refuses to sort the stack by importance: the
player does the judging, so the interface owes him legible inputs.

`Contact` already carries `display_name` and `town`. **The role word comes from
the role, not from the `title` field** — that field holds flavour like *Steward
of the Revenue*, no letter currently uses it, and the letterhead must not.

### The qualifier is data, not a branch

**A field holding a template, defaulted from the role and settled when the
contact is created.**

| Role | Qualifier | Reads |
| :--- | :--- | :--- |
| Governor | ` of {town}` | *Governor Don Johnson of Morrisville* |
| Clergyman, quartermaster, journalist, scholar | ` of {town}` | *Journalist Aldous Crane of Kettleburn* |
| Diplomat | ` of {town}` | *Diplomat Wren Halloway of Ashmere* |
| Commander, town | ` of the town of {town}` | *Commander Ames Harker of the town of Ashmere* |
| Commander, Crown | ` of the Crown's service` | *Commander Ames Harker of the Crown's service* |
| Commander, rebel | ` of the independent nation` | *Commander Ames Harker of the independent nation* |
| Patron | *(empty)* | *Patron Mingle Welkington* |
| Marshal, Chancellor, Steward, Provost | *(empty)* | *Steward Corvyn Thrale* |
| Rival | *(empty)* — **and no role word either** | *Le Duc de Montargis* |

**The patron's qualifier went empty when the title became his role.** It read
*, patron to the crown*, which said what *Lord* could not. *Patron* says it in
the first word, and saying it twice is worse than saying it once.

### A rival is the one exception, and it is a principled one

**His name is the whole letterhead.** *Le Duc de Montargis*. No role word, because
*Rival* is a game term and no man was ever called one.

The rule survives it because of **why** the rule exists. The role word is a
crutch for a name the player has never seen: a generated *Ames Harker* means
nothing until *Commander* is in front of it. **Rivals are a hardcoded cast of
three whose names carry their own titles** — *Le Duc*, *Grevé*, *Don* — so the
fiction has already done the job the role word was hired for.

It does not extend to the Crown officers, who are equally fixed and equally
learned. *Master Corvyn Thrale* does not say **Steward**, so he keeps his word.
**The test is whether the name itself announces the man**, and only the rivals'
do.

It has to be on the contact rather than the role because **a commander is one
role with three allegiances** (`commanders.md` §1: *colonial, Crown and rebel
commanders are the same object*), and each names a different master.

### 🔒 And a commander's qualifier changes when he turns

A town commander whose town goes into revolt stops being *of the town of
Ashmere* and becomes **of the independent nation**. He is the same contact, the
same object and the same company; what changed is who he serves.

**That is why the qualifier is mutable state on the contact and not a lookup.** A
qualifier derived from his role would have to be recomputed by something that
knew what a rebellion was; a qualifier he carries is simply rewritten by the
thing that turned him, and nothing else in the game needs to know.

It also says the right thing. A rebel commander is not a local difficulty in
Ashmere — **he serves a nation now**, which is exactly what SPEC §13.1 means
when it says the colony becomes one.

### 🔒 How the PC is addressed is the tone's business

The letterhead above is how a **sender** is shown. How the PC is **addressed** is
a different thing and it belongs to `tone.md`, because it moves with the writer's
tone:

> *pleased* — **To the most noble Lord Frank Zappa**
> *hateful* — **To the despicable Frank Zappa**

**Note what the hateful form does: it drops the title.** So this is not an
adjective swapped in front of a fixed name — **the whole salutation is
tone-keyed**, and a contact refusing the PC his title is doing something the
prose has to be able to say.

That needs no new machinery. `{insert:}` is already a tone-keyed fragment local
to its line (`CLAUDE.md`), incoming letters already carry the sender's tone, and
`{param:pc_title}` and `{param:pc_name}` already ship — the Chancellor's squeeze
letters use them. **A tone-keyed salutation line is the existing tools pointed at
the top of the letter.**

### It follows that the Diplomat's name changes

He lives in a town and asks to be rehomed when it turns dangerous (SPEC §8.1).
His qualifier is ` of {town}`, so **his letterhead moves with him**, and a player
who notices *of Ashmere* become *of Kettleburn* has been told something real
before he reads a word.

---

## 3. A bag is a register, and roles map onto it

**Not one bag per role.** Several roles can draw from one bag, and two of them do.

| Bag | Drawn by |
| :--- | :--- |
| **`aristocrats`** | **the PC's suggested name**, patrons, Crown commanders |
| **`colonists`** | governors, **colony commanders**, and the institutional contacts |
| **`towns`** | towns |

**A company is given to the same sort of man either way.** The Marshal's
commander comes from the pool of aristocrats a patron comes from; a colonial
company is handed to one of the well-to-do colonists a governor comes from. That
is simpler than a bag each and truer than a bag each, which is the good kind of
simplification.

**A rebel commander draws nothing.** He was a colony commander who turned, so he
keeps the name he already had — only his qualifier changes (§2).

### Two men from the same bag still differ, and that is fine

An earlier draft gave every role its own bag, arguing a clergyman and a
journalist should sound unalike. **They are both colonists**, and the register
that actually matters is *aristocrat or colonist*, not *what he does for a
living*. A colony is not so large that its journalist and its clergyman came from
different peoples.

### 🔒 Every bag is one register

All colonists from one bag whatever the colony's settlers happen to be, and all
aristocrats from another. **An artistic liberty, taken deliberately** — nothing
downstream should try to be cleverer about where a man is from.

### Given and family, not whole names

A bag holds **a list of given names and a list of family names**, joined on
draw. Twenty of each is four hundred men.

**No titles in a bag.** The letterhead's first word is the role (§2), so there is
nothing per-man to draw.

**This reverses an earlier draft**, and the reason is worth keeping. That draft
held whole names because the rivals' bag would have mixed nations, and drawing
parts separately would eventually pair a French given name with a Spanish
surname. **The Author then made rivals hardcoded**, which removed the only bag
that mixed cultures — and with it the whole argument.

**A role that needs particular men does what the rivals did**: names them in
data. That is the escape hatch, and it is already proven.

---

## 4. Places

**Towns are the only generated places.** They are named when founded (SPEC
§11.4), from the towns' bag, and the first town is named the same way as the
fifth — run start is a founding like any other (`map.md` §5).

Nothing else on the map has a name. Tribes do not (§1), patrons have no home
(§2), and a rival's coast is part of his hand-written title rather than a place
the generator knows about.

**The independent nation is not named either.** A rebel commander is *of the
independent nation*, in those words — the Crown does not dignify it with a name,
which is the joke and also one less bag.

---

## 5. Determinism, and the stream a name comes from

A name is drawn from the **subject's own stream** — `hash(run_seed, contact_id)`
for a contact, the equivalent for a town — per `CLAUDE.md`.

So the same seed produces the same men and the same towns **whatever else
happens in the run**, and naming somebody never shifts another system's rolls.
A run where the player founds a town in month 9 instead of month 8 gets the same
name for it.

**No two live things share a name**, which is a redraw rather than a property the
bags must guarantee.

---

## 6. Data

```
data/names/<bag>.json     given[] and family[] for people; names[] for towns
						  aristocrats · colonists · towns
```

**No language suffix.** A bag carries no prose and is not translated, unlike
`data/letters_en/` (`CLAUDE.md`'s content pipeline). Letters already reach a name
through `{sender:}`, so a generated name needs nothing new in the renderer.

The content validator covers them: every role that generates has a bag, no bag is
empty, and no bag is too small to fill a long run without repeating.

---

## 7. Open items

- **How many names does a long run need?** Towns in the tens, patrons and
  commanders similar. Twenty given and twenty family per bag is almost certainly
  ample, but the validator's "too small" threshold should be set from a measured
  long run rather than guessed.
- **Do the institutional contacts really share `colonists`?** §3 puts them there
  and the reasoning holds — they are colonists, and a colony is not large enough
  for its clergyman and its journalist to come from different peoples. But the
  Author ruled only on commanders, so this is my extension of it rather than his
  ruling, and it is one file either way.
- **Companies appear to need no names.** The commander's qualifier was the only
  place one would have shown, and it now names his town or the Crown instead. If
  nothing else wants them, they are *Ashcombe's*, after the man, and there is no
  bag to write.
