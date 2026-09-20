# Mechanics — Institutional Contacts

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.2, §12.3, §14.1, and `buildings.md`.

---

## 1. The framework, and it is the patron's

SPEC §8.2: *some buildings bring a new contact, such as a church bringing a
clergyman. Each has their own agenda and loyalty.*

Three questions define one, and they are **the same three that define a patron**
(`patrons.md` §2):

| | | The patron's word |
| :--- | :--- | :--- |
| **What he wants** | the asks he brings to the PC | *need* |
| **What he cares about** | what moves his loyalty, and what he writes about unprompted | `cares_about` |
| **What he can do** | the capability his institution gives the colony | *specialty* |

**One model, two ways of filling it in.** A patron rolls his three at random and
leaves within a few years. An institutional contact has his fixed by the building
that produced him, and stays as long as the building stands.

So `patrons.md`'s offer object (§4) works here unchanged: gift, request, barter,
sale and purchase are the same five shapes with the same resolution path.

## 2. He lives in a town, which is most of what he is

An institutional contact is **resident**, and that has two consequences nothing
else in the contact model has.

**He carries prominence.** `rebel-sentiment.md` §4: every contact resident in a
town pushes its sentiment by his loyalty scaled by his prominence. A slighted
clergyman is a mechanical problem, not a flavour one — and a contented one holds
his town down.

**He is lost with his building or his town.** No successor, in keeping with
`contacts.md` §8. A town that falls takes its clergyman with it, and the church
that is rebuilt brings a new man who remembers nothing.

## 3. The four

| Building | Contact | Extended by |
| :--- | :--- | :--- |
| **church** | the **clergy** | cathedral |
| **gunsmith** | the **quartermaster** | armoury |
| **printing press** | the **journalist** | — |
| **library** | the **scholar** | college |

**The theatre brings nobody.** It is the entry-level amusement building and it
stays that way.

An **extension** building does not create a second contact. It widens what the
existing one can do — which is what `buildings.md` means by the cathedral's "more
with the contact", and it is the same relationship in all three cases.

### The clergy

| | |
| :--- | :--- |
| **Wants** | charity — gold or food for the poor, and relief when the town suffers |
| **Cares about** | how the people are actually living. Hunger, sickness, and want |
| **Can do** | he preaches obedience. A contented clergyman is a standing weight against rebellion, and he can be asked to intercede in a town on the brink |

He is the PC's cheapest instrument against sentiment and the one that costs
money rather than force. He also **objects** — to the ale house, to guns, to
whatever his conscience will not carry — which makes him the first contact whose
approval and whose usefulness pull in different directions.

**The cathedral** extends his reach beyond his own town.

### The quartermaster

| | |
| :--- | :--- |
| **Wants** | iron, guns, and gold for the armoury |
| **Cares about** | whether the colony is defended. He reads walls, arms and the strength of what stands in them |
| **Can do** | **companies raised in his town launch better armed** |

That capability lands exactly where `battles.md` §2 leaves a gap: arms are **fixed
at launch** and never resupplied, so *who equipped you* is the whole of what a
company will ever have. A quartermaster is therefore worth more than the guns he
represents — he is the difference between a militia and a company that can
campaign.

**The armoury** extends him to arming companies raised elsewhere in the colony.

### The journalist

| | |
| :--- | :--- |
| **Wants** | to be told things, and to print them. Access, and to be left alone |
| **Cares about** | whether the PC deals honestly with him |
| **Can do** | **he moves prestige.** A contented journalist prints well of the Crown and banks it; a slighted one prints the other thing |

**He cannot touch an optic.** `prestige.md` §4 locks that optics never decay, and
good press is not a pardon — he adds to the prestige tally, he does not erase a
debt. A PC who lost a town stays a man who lost a town, however friendly the
press.

**And he is dangerous to own by design.** `buildings.md` §4 has the printing press
raising rebel sentiment by name, and his prominence is the highest of the four —
he is the most famous man in the town and everyone reads him.

So the PC holds a contact who **prints prestige and breeds sedition at the same
time**, and the obvious response to the second is the thing that destroys the
first. Censoring him lowers sentiment, craters his loyalty, and costs prestige
directly. That decision is the whole point of the building.

He has **no extension**. The press is already the end of its branch.

### The scholar

| | |
| :--- | :--- |
| **Wants** | experts sent to his library, and funds for it |
| **Cares about** | education across the colony, not only in his own town |
| **Can do** | **he moves experts between towns** |

That is the capability `buildings.md` §4 promises when it calls him *a contact who
wants them spread about the colony*, and it fills a real gap: `the-provost.md`
brings experts **into** the colony and nothing else can move one once it has
landed. A fur town that becomes a weaving town cannot currently redeploy the
trapper it no longer needs. The scholar can.

He overlaps the Provost without duplicating him. **The Provost supplies, the
scholar distributes**, and the two of them caring about the same measure means a
PC who builds libraries pleases a Crown officer he has never paid.

**The college** extends him to the experts it already counts from elsewhere.

## 4. What they have in common, and what that buys

All four **want gold or goods, care about something the PC controls only
indirectly, and can do one thing nothing else in the game does.**

The last part is deliberate. An institutional contact whose capability duplicates
an existing system is a letter that never needs answering. Each of these four is
the *only* route to its effect:

- nothing else lowers sentiment by persuasion
- nothing else arms a company at launch
- nothing else adds to prestige on purpose
- nothing else relocates an expert

**A dev adding a fifth should hold it to that test**, and a building that brings a
contact with nothing unique to offer should bring no contact at all — which is
why the theatre does not.

## 5. Tuning targets

- Prominence per role. The journalist is highest and the quartermaster probably
  lowest.
- What each capability is worth, and what each institution's asks cost over a run.
- How far an extension building widens its contact.
- Whether the clergy's intercession is a standing effect, an occasional
  invocation, or both.

## 6. Open items

- **What a contact does at very low loyalty.** `contacts.md` §4 has the general
  answer, but these four each have an obvious betrayal — the journalist who turns
  on the PC in print is not the quartermaster who simply stops caring.
- Whether the journalist's prestige contribution should be **capped**, so a PC
  cannot build a press in every town and print his way to a score.
- Whether the scholar may move an expert **against a governor's wishes**, and if
  so what that does to the governor's loyalty.
- Whether a clergyman's objections are a vice in the `patrons.md` sense — named,
  rolled, and mechanical — or simply part of being the clergy.
- What happens to an institutional contact in a **rebel** town. He is resident,
  the town has repudiated the Crown, and nothing says whether he goes with it.
