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
| **Patron homes** | **generated** |
| **Tribes** | **not named at all** |

**Rivals are hardcoded on purpose.** They are a fixed cast like the officers, they
carry hand-written letters already (`tribute_demand_montargis.json`), and their
names do specific work — Don Íñigo de Alcaraz, Le Duc de Montargis and Grevé
Anders Vasterholm are three different nations against three different coasts. A
generator would have to be taught all of that to produce what three lines of data
already say.

**Tribes have no names by the Author's ruling.** They are known by what they are
and where they are, not by what they call themselves — which is the colonial view
the game is written from, and cheaper besides.

---

## 2. 🔒 The letterhead

**`<title> <name> of <location>`**

> **Governor Don Johnson of Morrisville**

`Contact` already carries `display_name`, `title` and `town`, so this is a render
rule rather than new state.

**The `of <location>` clause appears only when he has a location.** The Crown
officers do not — they are an ocean away and their titles are self-contained
(*Steward of the Revenue*), so they render as title and name and nothing else.

| Contact | Location is |
| :--- | :--- |
| Governor | his town |
| Clergyman, quartermaster, journalist, scholar | the town he is resident in (`institutional-contacts.md` §2) |
| Commander | his company |
| Patron | his home, back in the old country |
| Crown officer | none — no clause |

### It follows that the Diplomat's name changes

He lives in a town and asks to be rehomed when it turns dangerous (SPEC §8.1).
**His letterhead moves with him**, and a player who notices *of Ashmere* become
*of Kettleburn* has been told something real before he reads a word.

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

A bag holds **a list of given names and a list of family names**, joined on draw.
Twenty of each is four hundred men.

**This reverses an earlier draft**, and the reason is worth keeping. That draft
held whole names because the rivals' bag would have mixed nations, and drawing
parts separately would eventually pair a French given name with a Spanish
surname. **The Author then made rivals hardcoded**, which removed the only bag
that mixed cultures — and with it the whole argument. Every remaining bag is one
register, so recombining inside it is safe.

**A role that needs particular men does what the rivals did**: names them in
data. That is the escape hatch, and it is already proven.

---

## 4. Places

**Towns** are named when founded (SPEC §11.4), from the towns' bag. The first
town is named the same way as the fifth — run start is a founding like any other
(`map.md` §5).

**Patron homes** are a new thing this document introduces, because a patron needs
a location for §2's letterhead and `patrons.md` has never had one. A home is a
name and nothing else: **no tile, no map presence, no mechanics.** It exists so
that *Lord Ashcombe of Hartleigh* is possible, and it should stay that thin
unless the Author wants otherwise.

**They are separate bags.** A colonial town and a gentleman's seat in the old
country are different registers, and a town called *Hartleigh Hall* would be as
wrong as a patron of *Morrisville*.

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
data/names/<kind>.json    given[] and family[] for people; names[] for places
```

**No language suffix.** A bag carries no prose and is not translated, unlike
`data/letters_en/` (`CLAUDE.md`'s content pipeline). Letters already reach a name
through `{sender:}`, so a generated name needs nothing new in the renderer.

The content validator covers them: every role that generates has a bag, no bag is
empty, and no bag is too small to fill a long run without repeating.

---

## 7. Open items

- **Are governors always the PC's countrymen?** `immigration.md` brings settlers
  in; if the colony draws them from several nations then a governor's bag is not
  one register after all, and §3's recombination argument weakens. Worth checking
  before the bags are written rather than after.
- **How many names does a long run need?** Towns in the tens, patrons and
  commanders similar. Twenty given and twenty family per bag is almost certainly
  ample, but the validator's "too small" threshold should be set from a measured
  long run rather than guessed.
- **Does a company's name follow its commander, or the reverse?** §2 gives a
  commander his company as a location, which presumes companies are named. They
  may simply be *Ashcombe's*, after the man.
