# Mechanics — Institutional Contacts

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §8.2, §12.3, §14.1, and `buildings.md`.

---

## 1. Four questions, answered against the base contact

SPEC §8.2: *some buildings bring a new contact, such as a church bringing a
clergyman. Each has their own agenda and loyalty.*

**Each of these men extends the ordinary contact model. They do not share a
second one.** Everything below is the base mechanic of `contacts.md` with its
blanks filled in — there is no institutional-contact machinery, and there must not
be, or a change made for one of them silently moves the others.

**Nor are they patrons.** `patrons.md` is deliberately simple and should stay
that way; binding the two models together would handcuff each to the other's
future.

Four questions define a contact, and answering them is the whole of adding one:

| Question | Where the answer lives |
| :--- | :--- |
| **What does his loyalty do?** | `contacts.md` §2 — one knob, read differently by role |
| **How does he get loyalty?** | `cares_about` (§5), which also decides what he writes about (§6) |
| **What will he ask of the PC?** | his letters |
| **What is his bias?** | perception leans (`perception.md`) |

The fourth is not decoration. Every fixed contact in the game skews one way and
the player learns to discount it — the Steward wants higher duties, the Provost
thinks the colony under-schooled, the Marshal minimises every threat. **These four
each need their own slant**, or they read as instruments rather than people.

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

**What his loyalty does.** Two things, and he is the only contact so far who gets
a second.

He is **very influential** — among the highest prominence in the game — so his
regard moves his town's rebel sentiment hard in whichever direction it points. And
**his loyalty scales the church's own effect**: the building gives perceived
safety (`buildings.md` §4), and a contented clergyman gives more of it. A church
with a slighted priest in it is a building the town has stopped believing in.

**How he gets loyalty.** He cares about **his people, and most about the poorest**.
A town that is not a miserable place to live earns his regard; one that is loses
it, whatever the PC sends him personally.

Mechanically that is quality of life read **from the bottom**: heavy on health and
means, and **blind to pleasure**. A town with a theatre, a cellar of rum and
hungry people does not please him at all, which is precisely the trap
`quality-of-life.md` §8 warns the player about — and the clergy is the one voice
that will not be fooled by it.

**What he asks for.**

- **Gold**, for charity.
- **A tax holiday**, in one of two shapes — below.
- **An expedition of pilgrims** — below.

#### The tax holiday, two shapes

Both are **time-limited rate changes**, which nothing in §10.2 can currently
express: rates today are standing, a base plus per-resource overrides, with
nothing that expires. Both are also necessarily **colony-wide**, because §10.2
locks that there are no per-town rates — so a priest asking relief for his own poor
is asking the whole colony to go without the duty.

| | The ask | Scope | Length |
| :--- | :--- | :--- | :--- |
| **A festival** | *the people are holding a festival to celebrate {resource}; waive the duty on it* | **one resource** | about three months |
| **A holy day** | *a holiday is upon us; waive all duties so we may keep it properly* | **everything** | the one month |

Narrow and long, or broad and brief.

**Best-selling means the most gold sold this month.** Author's ruling, and it is
the liveliest of the readings on purpose: the priest asks about whatever had a
good harvest, so the ask swings with the colony's fortunes rather than settling
on one staple. **The better the colony trades, the more he asks the Crown to give
up.** Prosperity draws the cost, exactly as it does with the dukes.

**🔒 The waiver begins the month the PC agrees.** Not announced in advance and
not scheduled — the priest writes, the PC answers, and it starts.

There is no scheduled-future-event path in the game, and this deliberately does
not build one. A general scheduler standing up for a single caller is a system
nobody asked for; **the second thing that genuinely needs one can generalise from
it.**

A month of no duty is a month of cheap goods for every town — quality of life up,
sentiment down — paid for out of Crown revenue, which is `net_position` and
therefore standing *and* prestige.

**🔒 A resource under trade protest is exempt from either waiver.**

A protest is a town refusing the Crown's duty (`trade-protests.md`), so there is
no duty flowing to waive — the exemption is nearly definitional rather than a
special case. It matters most for the holy day, which waives everything else:
**a colony in protest does not get a holiday from the thing it is protesting.**

For the festival it rarely arises at all, and that falls out of the ruling above:
a resource nobody is trading cannot be the one that sold the most gold this
month.

So both are the same bargain in different clothes: **buy the colony's goodwill
with the Crown's money.** That is the clergy's whole character in one instrument.

#### The pilgrim expedition

**He creates the population.** He gathers devout people from outside the colony
entirely — they are not shed by any town, and nobody already here is displaced.

**But he has no supplies, and the PC must buy them.** Gold, or the expedition
never materialises at all.

That makes it a **third founding route**, Crown-launched in shape
(`founding-towns.md` §3): it arrives by ship with no ground travel and none of
§7's dangers, and it is paid for in gold rather than in a parent town's people.

It is also **a way to buy population that bypasses immigration entirely.**
`immigration.md`'s arrivals answer to appeal and to the Crown's circumstances;
pilgrims answer to the PC's purse. Which is the Provost's bargain in another
coat — growth for gold — and it carries the Provost's consequence too, since
`immigration.md` §9 makes growth the engine of rebellion. **A pilgrim town is
future sentiment, bought.**

**🔒 A pilgrim town does not arrive with a church.** It arrives devout and
unbuilt, like any other founding, and must raise one for itself if it wants one.
The priest gathers people, not institutions — and he does not get to seed a second
clergyman on the PC's money.

**His bias.** He talks to the poorest of the poor, the ones with nowhere else to
go, **so he believes the colony is far worse off than it is.** Every welfare
measure he reports leans dark.

Which sets up the thing that makes him difficult: **a PC who believes him
overspends, and a PC who discounts him entirely misses the famine.** He is never
lying — §9.1 holds — he simply sees the part of the town nobody else writes about.

He also **objects**: to the ale house, to the guns, to whatever his conscience
will not carry. So he is the first contact whose approval and whose usefulness
pull in different directions.

**The cathedral** widens what he can do.

### The quartermaster

> **Placeholder.** What guns are *for* is a larger question than this contact —
> §10.1 has them arming the militia and coveted by the natives, `battles.md` makes
> them a supply ratio fixed at launch, and `buildings.md` gates them behind the
> only locked conversion in the tree. This is enough to build him; expect the
> particulars to move when that settles.

**What his loyalty does.** At high regard he grants **contracts to make guns and
ship them to the Crown**, which cannot happen without him at all.

They are **very lucrative**. They are also the single most unpopular thing the PC
can do to his own colony, and half the residents will write to say so.

**It needs no new authority over the towns.** SPEC §11.3 locks that towns run
themselves and the PC never manages them directly — so a contract is **a price**,
not an order. It raises what the Crown pays for guns; town valuation does the
rest, and towns turn to muskets because muskets are suddenly worth making. The
sim needs no override and the PC issues no instruction.

**Who complains, and why they are right.** Guns raise a town's defence (§10.1),
so a contract is the colony **manufacturing its own safety and selling it
abroad**. The clergy objects on conscience, the scholar on principle, the
journalist on both and loudly. Governors watch plantations turn into forges.

#### 🔒 The contract unmakes the man who grants it

**He gains loyalty from the colony being well armed** — guns in the stockpiles,
guns in the companies' hands.

Shipping them to the Crown is the precise opposite of that. **So the harder the PC
works the contract, the faster he loses the only man who can grant it**, and the
instrument closes itself. No cap is needed and none should be added.

It is the quartermaster's mirror of the journalist: one man's cooperation loosens
the colony, the other's enriches the Crown by disarming it. **Both are traps, and
they point opposite ways.**

**What he asks for.** Iron, gold to buy iron, help moving guns where they are
needed — and money, of course. And **lower duty on iron**.

That makes three residents asking for relief on three different things: the
**clergy** wants the duty off what the poor cannot do without, the **scholar**
wants it off luxuries, and the **quartermaster** wants it off iron. One
instrument, three claimants, and a PC who can afford to please one of them.

**His bias.** The stockpiles are **always dangerously low** and the duty on iron
is **always too high** — at every level of supply and every rate, exactly as the
Provost is permanently certain the colony is under-schooled.

Unlike education, though, **the player can check**. The stockpile is a number the
letters quote, so his alarm is verifiable and therefore learnable, which makes him
the easiest of the four to discount correctly.

**The armoury** extends him.

### The journalist

**🔒 His prominence equals the governor's.** No other resident comes close, and
nothing else in the game gives one building a second voice as loud as the man who
runs the town. **This is the sharpest sword in the tree**, and everything below
follows from holding it by the blade.

**What his loyalty does.** At high regard he unlocks **policies** — ordinary ones
in `policy.md`'s sense, recurring monthly cost, carried by him, renegotiated
rather than cancelled, with the 3x asymmetry on non-payment.

**It is a deep unlock**: a press requires a college and a stockade, and the
policies require the man who comes with it to think well of the PC on top. A
colony reaches this late or not at all.

**There are two, and both are plain benefits.** Author's ruling, and the
distinction matters more than either policy does:

| | What it does |
| :--- | :--- |
| **Public Relations** | every governor's loyalty to the PC rises each month. He is printing well of the Crown, governors read it, and their regard reaches their own towns through §4's prominence term |
| **Crown Sentiment** | he prints the Crown's difficulties as readily as he prints a hamlet's, so the colony bears the burden better. **Rebel sentiment reads every tax rate a quarter lower than it is** — 10 per cent counted as 7.5, 40 per cent as 30 |

**The Crown still collects the real rate.** Only sentiment reads it lower, and
the reduction is a quarter *of* the rate rather than twenty-five points off it.

### 🔒 Neither policy is the trap

**What the PC must do to keep him loyal is the trap. What he gets for it is not.**

Both of these are things a player should reach for. He earns them by holding the
colony to the journalist's standard — the worst town, not the average — and by
pursuing a programme that quietly raises the stakes everywhere. **The cost is
paid before the benefit arrives**, and the benefit being genuinely good is what
makes the bargain worth taking and therefore worth regretting.

A policy that was itself a hidden cost would turn the whole man into a trick.
He is not a trick; he is sincere, and he is dangerous because of it.

**They cost like any policy** — full, half or nothing, with `policy.md`'s 3x
asymmetry testing his loyalty when the PC underpays.

### He does not move prestige

**Nobody at court reads the colony's papers.** Author's ruling, and it removes
what was a second prestige bank with nobody behind it.

**How he gets loyalty.** Beyond his own dealings with the PC, he reads **the
quality of life of the worst town in the colony** — not the average.

People write to him and he prints what they send, so he holds the PC to account
for the bleakest headline available. **One neglected hamlet poisons him no matter
how well the capital lives.** And that gets harder as the colony spreads: the
wider the PC goes, the likelier he is to own somewhere wretched, so the most
influential man in the colony becomes harder to please the more of it there is.

**What he asks for.** Not gold. He asks the PC to move **every standing
arrangement with the Crown** in one direction:

- duties lower
- Crown troops sent home
- immigration well funded, and arriving equipped rather than destitute

Each of these is a kindness, and each is easy to grant.

#### 🔒 Granting them builds the thing that leaves

**This is the point of the contact and it should not be tuned away.**

His programme is not misery. It is a colony **lightly taxed, ungarrisoned, well
peopled and well built** — and `rebel-sentiment.md` §6 makes development a
multiplier on the stakes while `immigration.md` §9 makes growth the engine of
rebellion. A prosperous, populous, unpoliced colony is precisely a colony that
does not need the Crown.

So the trap closes from both ends at once:

| | |
| :--- | :--- |
| **His regard** | pushes **his own town's** sentiment down, hard, at a governor's weight |
| **His programme** | raises the stakes **everywhere else**, over years |

**A PC who keeps him happy is buying local quiet with colony-wide loosening**, and
the ledger never shows it. He is sincerely trying to help, he is the most
respected voice the PC has, and he is connecting the colony to itself in a way
that ends in independence.

Insidious is the word, and it is the only contact in the game whose *cooperation*
is the danger.

**His bias.** He thinks every problem is equally important, so **small troubles
move him nearly as far as large ones.**

Code it as the **shape** of his lean rather than its size: steep near zero and
flattening out, where most contacts are the reverse. A minor shortage in a hamlet
reads to him almost as loudly as a famine in the capital, because in his
newspaper it gets the same headline.

That makes him the mirror of the Marshal, whose leans **minimise every threat**
(`the-marshal.md` §6) — flat near zero where the journalist is steep. The same
machinery, opposite curves, and the player has to learn two different discounts.

**`perception.md`'s one-rung cap bounds him**, which is what keeps this readable:
he is reliably one notch more alarmed than the truth, not hysterical. And the
player who learns to discount him is the player who will miss the real famine.

He has **no extension**. The press is already the end of its branch.

### The scholar

**What his loyalty does.** **Medium prominence** — a learned man looms reasonably
large in a colonial town, but he is respected rather than popular, so less than
the priest and far less than the journalist.

And **his regard scales the library's own effect.** `buildings.md` §4 has the
library turning resident experts into education; a slighted scholar teaches badly.
The building still stands and the learning stops.

**How he gets loyalty.** Two things, and the second is the interesting one.

**Education across the colony**, not only in his own town. Which means the
Provost's **curriculum** policy — the cheapest instrument in the game — now pleases
*two* contacts at once, and a PC who funds it keeps a Crown officer and a resident
contented for almost nothing.

**And peace.** He wants quiet, cooperation, low duties and schooling, because he
believes everyone is as reasonable as he is and ought simply to get along. So
**aggression with the natives or the rivals costs his regard** — and he blames the
PC for it.

#### He does not ask who started it

**He blames the PC when a rival attacks an expedition.** That is not the PC's
aggression by any reading, and the scholar does not care.

This is a deliberate inversion of `rebel-sentiment.md` §2, whose entire organizing
principle is **attribution** — sentiment measures who is blamed, not how bad life
is. The scholar is the opposite: he measures how bad it is and blames whoever is
in charge. **He is attribution-blind on purpose**, and that is the whole of what it
means to be a man who has never had to make a hard decision.

**What he asks for.**

- **Gold** for the library.
- **An expert sent to him**, specifically.
- **Lower duties on luxuries** — which makes a neat pairing with the clergy, who
  wants the duty off what the poor cannot do without. **The priest wants bread
  cheap and the scholar wants wine cheap**, and they will never ask for the same
  thing.
- **That the PC press the Provost on curriculum.** The first contact who asks the
  PC to lobby another contact, and it needs nothing new — it is a letter that
  suggests a letter.

**His bias: academia for its own sake.**

`buildings.md` calls him *a contact who wants experts spread about the colony*,
and that is what he sincerely believes about himself. **What he actually does is
gather them.**

Left to his own judgement he pulls expertise toward his own library, because that
is where it can be properly used, where it will compound, where the real work is
done. The frontier town that needs a farmer is not his concern; it has no library
to receive one.

**So his bias corrupts his own capability**, which is the sharpest kind. A PC who
follows the scholar's advice on placement ends with one brilliant town and a
colony of hamlets, and the scholar will be sincerely delighted about it.

The capability itself stays genuine and stays the PC's instrument: **asked** to
send a weaver to a struggling town, he does it, exactly as the Steward follows an
instruction he disagrees with. It is his **unprompted** judgement that has the
thumb on it.

It also fills a real gap. `the-provost.md` brings experts **into** the colony and
nothing else could move one afterwards — a fur town that became a weaving town was
stuck with its trapper. **The Provost supplies, the scholar distributes**, when he
can be persuaded to.

**The college** extends him to the experts it already counts from elsewhere.

## 4. What they have in common, and what that buys

All four **want gold or goods, care about something the PC controls only
indirectly, carry a bias the player has to learn to discount, and can do one
thing nothing else in the game does.**

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

- **Whether a contact's loyalty scaling his building's effect is the general
  rule.** The clergy does it — his regard buys more of the church's perceived
  safety. If that holds for all four it is an elegant pattern: the building gives
  the effect, the man decides how much of it the town actually gets. If it holds
  only for the clergy it should be said plainly, or a dev will infer the rule.
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
