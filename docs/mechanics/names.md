# Names

> **Serves:** SPEC §8.1, §8.2, §8.3, §8.6, §11.4, §9.7 (content pipeline),
> §16.1 (determinism). **Extends:** `contacts.md` §1.

---

## 1. Who is named, and who is not

| | Named how |
| :--- | :--- |
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

**A patron has no home**, by the same ruling. An earlier draft invented one so he
would have somewhere to be *of*; §2's qualifier does that job without inventing a
place, and a name with no mechanics behind it was a thing to maintain for nothing.

---

## 2. 🔒 The letterhead

**`<title> <name>` and then a qualifier.**

> **Governor Don Johnson of Morrisville**
> **Lord Mingle Welkington, patron to the crown**

`Contact` already carries `display_name`, `title` and `town`, so this is a render
rule rather than new state.

### The qualifier is data, not a branch

**A field holding a template, defaulted from the role and settled when the
contact is created.** Not a lookup by role, and not cases in code.

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

| Role | Qualifier | Reads |
| :--- | :--- | :--- |
| Governor | ` of {town}` | *Governor Don Johnson of Morrisville* |
| Clergyman, quartermaster, journalist, scholar | ` of {town}` — the town he is resident in | *Father Aldous Crane of Kettleburn* |
| Patron | `, patron to the crown` | *Lord Mingle Welkington, patron to the crown* |
| Commander, town | ` of the town of {town}` | *Captain Ames Harker of the town of Ashmere* |
| Commander, Crown | ` of the Crown's service` | *Captain Ames Harker of the Crown's service* |
| Commander, rebel | ` of the independent nation` | *Captain Ames Harker of the independent nation* |
| Crown officer | *(empty)* | *Steward of the Revenue Corvyn Thrale* |
| Rival | *(empty)* — his title already names his coast | *Le Duc de Montargis* |

A patron needs no location because his qualifier is not a place. **That is what
made patron homes unnecessary**, rather than a decision to do without them.

### A patron's title is drawn too

*Lord Mingle Welkington* is **three words from the bag** — honorific, given name,
family name. A governor is always *Governor*, so his title is fixed by his role
and only two words are drawn.

So **a bag may carry a `titles` list**, and where it does the title is drawn with
the rest. Where it does not, the role's own title stands.

### It follows that the Diplomat's name changes

He lives in a town and asks to be rehomed when it turns dangerous (SPEC §8.1).
His qualifier is ` of {town}`, so **his letterhead moves with him**, and a player
who notices *of Ashmere* become *of Kettleburn* has been told something real
before he reads a word.

That is a consequence of the rule rather than a feature bolted on, which is the
sign the rule is the right one.

---

## 3. One bag per kind

**Every role draws from its own bag**, and so does every kind of place. Every
journalist from the journalists', every governor from the governors', every town
from the towns'.

Not one pool, and not pools keyed by country. **Two men from the same country
should still not sound alike** — a clergyman and a journalist may both be the
PC's countrymen and want different registers, one scriptural and old, the other
plainer. A key based on where a man is from cannot express that. A key based on
what he is can.

### Given and family, not whole names

A bag holds **a list of given names and a list of family names**, joined on draw
— and a list of titles where the role's title varies (§2). Twenty of each is four
hundred men.

**This reverses an earlier draft**, and the reason is worth keeping. That draft
held whole names because the rivals' bag would have mixed nations, and drawing
parts separately would eventually pair a French given name with a Spanish
surname. **The Author then made rivals hardcoded**, which removed the only bag
that mixed cultures — and with it the whole argument.

**Every bag is one register**, by the Author's ruling: all governors draw from
one bag whatever the colony's settlers happen to be, and that is an artistic
liberty taken deliberately rather than an oversight. So recombining inside a bag
is always safe.

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
data/names/<kind>.json    given[] and family[] for people, titles[] where the
                          role's title varies; names[] for towns
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
- **Do Crown commanders draw from the colonial bag?** They are the same role and
  the same object, so one bag is the simple answer and matches the ruling that
  every bag is one register. But a man the Marshal sends comes from the old
  country and a man raised in Ashmere does not, and that is the same distinction
  that earns the rivals their hand-written names. **One bag is cheap and
  probably fine**; two is one more file and slightly truer. Author's call, and
  nothing blocks on it.
- **Companies appear to need no names.** The commander's qualifier was the only
  place one would have shown, and it now names his town or the Crown instead. If
  nothing else wants them, they are *Ashcombe's*, after the man, and there is no
  bag to write.
