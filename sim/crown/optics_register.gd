class_name OpticsRegister
extends RefCounted

## What made the Crown look foolish, and what each embarrassment is worth
## (#76, `docs/mechanics/prestige.md` §4).
##
## ## 🔒 A mechanic emits the event. It never prices it
##
## **No mechanic decides whether it affects prestige.** Trade protests,
## rebellion, tribute, battles and lost towns each emit an event saying what
## happened, and this one table decides which of those events are optics and what
## each is worth.
##
## The same split the content pipeline uses, where a trigger decides *whether* a
## letter is sent and the letter file decides *how it reads*, and for the same
## reason: **a price is only meaningful against every other price**, so pricing
## cannot be distributed across the mechanics that generate the events.
##
## It also means a new optic is **a row in this table, not a change to the
## mechanic that causes it**. A dev adding rival tribute in M5 emits
## `tribute_paid` and stops there; whether the court minds, and how much, is not
## his to decide and not his ticket's.
##
## ## 🔒 Optics never decay
##
## Something that made the Crown look bad in year one counts against the PC in
## year forty, undiminished. No forgetting, no half-life, no rehabilitation —
## which is what makes §8's retirement decision real: the reason to leave is
## never that waiting heals anything, it is that waiting accrues new damage.
##
## ## 🔒 The money is not counted twice
##
## A protest costs the Crown its tax income on that resource, and a rebel town
## stops trading with it altogether. **Both of those already land in
## `net_position`**, which prestige reads directly. Every figure here is for the
## **embarrassment alone**; charging the gold again would double-count the event
## and make protests and rebellions read far worse than the design intends.
##
## ## Fixed debts, not proportional ones
##
## An optic is an absolute figure, not a share of anything, so **one rebellion
## destroys a small-time governor and merely embarrasses a great one** — the
## great one's net gold dwarfs it. That is the court forgiving a man who made
## them rich, and it is not to be tuned away.
##
## ## 🔒 The reckoning happened, and it is a table of multiples
##
## §11 held the table open until M7, when every optic exists and all of it could
## be priced in one sitting with the answers visible. That is #187, and it is
## done: **every price below is a stated multiple of one reference optic**, so
## the table says what each embarrassment is worth against the others rather than
## carrying figures each set in whichever ticket introduced it.
##
## Two rows were added by the reckoning itself — the Crown's Resident dead and a
## founding party annihilated. Both events had been emitted for milestones by
## mechanics that had never heard of prestige, and neither had ever been charged
## anything. **That is the emit-not-price rule working and then being collected
## on**, which is what the pass is for.
##
## What M7 did **not** settle, because it cannot: the reference figure itself,
## and §14.3's unlock thresholds. Both want the range a real run reaches, which
## is the harness's answer and M8's decision. **M7 decided what the numbers are
## for; M8 decides what they are.**

## 🔒 **A desperate letter** (#264, `tone.md` §4, §6).
##
## > **The Crown does not care whether the PC flatters or abuses his subjects.
## > It minds very much that he looked weak in front of them.**
##
## The sharpest expression in the game of §14.1's lock that prestige measures
## **only how the Crown benefits**: cruelty is free and desperation is not.
## **Hateful carries no prestige cost at all**, and should not.
const EVENT_DESPERATE_LETTER: StringName = &"desperate_letter"

## Named here before anything emitted them, so that the milestone which adds
## them is a mechanic and not a negotiation about what the court thinks of it.
##
## **Two of them came alive in M6** and the mechanics that emit them still do not
## know that: a company wiped out is `Company._remove` reaching zero, a town
## taken is `Colony.lost`, and neither file has ever mentioned prestige. That is
## §4's rule working — *a mechanic emits the event, it never prices it.*
##
## 🔒 **And there is still no such thing as losing a battle.** `battles.md` §6
## has no rout and no surrender, so a month of heavy casualties is not an optic
## and cannot become one: the court hears about **annihilation, not about a bad
## month**. `company_dwindled` is deliberately absent from this list.
const EVENT_TRIBUTE_PAID: StringName = &"tribute_paid"
const EVENT_COMPANY_DESTROYED: StringName = &"company_destroyed"
const EVENT_TOWN_LOST: StringName = &"town_lost"
const EVENT_RUN_FAILED: StringName = &"run_failed"

## Added by the reckoning (#187), from events already emitted and never priced.
##
## **The Crown's own Resident dead in the colony** (SPEC §8.1), and **a founding
## party annihilated** (`founding-towns.md` §7). Both were emitted by mechanics
## that had never heard of prestige, which is §4 working — and both went to the
## court and were charged nothing, which is what a reckoning is for.
const EVENT_DIPLOMAT_DIED: StringName = &"diplomat_died"
const EVENT_EXPEDITION_DESTROYED: StringName = &"expedition_destroyed"


## 🔒 **The reference optic: one resource the colony stopped selling.**
##
## Every other price below is **a stated multiple of this one** (#187), so the
## table says what each embarrassment is worth *against the others* rather than
## carrying eight free-floating numbers each set in whichever ticket happened to
## introduce it. Move this and the whole table moves with its relations intact;
## move a multiple and you have made a design statement out loud.
##
## The same arrangement `QualityOfLife.live_weight` uses, and for the same
## reason: **a retune should not have to be made twice.**
##
## 🔒 **A trade protest is the reference because it is the one the player
## meets most and understands soonest** — a market shuts, and he can see exactly
## why. An optic priced against it is priced against something he has felt.
##
## M8 owns this figure. M7 owns the multiples.
const A_PROTEST: float = 220.0

## The whole table, as multiples of `A_PROTEST` (#187, `prestige.md` §11).
##
## | Optic | × | Reads as |
## | :--- | --: | :--- |
## | A desperate letter | 0.2 | a fifth of a shut market |
## | An expedition annihilated | 0.75 | less than a protest, and deliberately |
## | A trade protest | 1 | **the reference** |
## | The Resident dead | 1.5 | the Crown's own man, and nobody replaces him |
## | Tribute to a duke | 2.3 | buying off a foreigner, in public |
## | A company wiped out | 3.2 | the Crown's soldiers, annihilated |
## | A town in rebellion | 6.4 | a town that stopped answering |
## | A town lost | 13.6 | a town that is *gone* |
## | The run failed | 27.3 | the colony itself |
##
## ## Where each multiple comes from
##
## **A desperate letter at a fifth** (#264): small enough to be worth paying
## once, large enough that a run of them tells at retirement. Thirty of them come
## to a rebellion, which is the shape the sentence *a run of them tells* has.
##
## **An expedition below a protest, which looks wrong and is not.** A party lost
## in the woods is a colonial misadventure, and the Crown's stake in it already
## left through `net_position` with its stores — §3 forbids charging that twice.
## What is priced here is the embarrassment alone, and a failed settlement
## embarrasses the court less than a market that visibly shut.
##
## **The Resident above a protest and well below a company.** He is the Crown's
## own officer, dead on the PC's watch, and SPEC §8.1 says nobody will take the
## post — so the court hears about it and the PC loses his sight. One man,
## though, against a company of soldiers.
##
## **Tribute below a company wiped out, and that is deliberate.** Paying a duke
## is humiliating and *voluntary*; a company annihilated is a defeat. The court
## minds losing more than it minds paying, which is the whole of why the PC pays.
##
## 🔒 **A lost town at more than twice a rebellion.** The ticket asks this
## question directly and it is the sharpest one in the table. A rebellion is a
## town that stopped answering and **might yet be brought back**; a lost town is
## gone to a foreign power or destroyed, and never comes back. Two towns in
## revolt should frighten a PC less than one town taken, and this says so.
##
## 🔒 **And the run's own failure at twice a lost town, not ten times it.**
## §3's fixed-debt rule means one rebellion destroys a small-time governor and
## merely embarrasses a great one. The failure debt has to sting without making
## every other optic irrelevant — a figure so large that nothing else could
## matter would collapse the whole table into one question. **Weighing it against
## a typical run's accumulated net gold is the harness's job**, and this ratio is
## what the harness should be asked to check.
static func prices() -> Dictionary:
	return {
		String(EVENT_DESPERATE_LETTER): A_PROTEST * 0.2,
		String(EVENT_EXPEDITION_DESTROYED): A_PROTEST * 0.75,
		String(TradeProtest.EVENT_DECLARED): A_PROTEST,
		String(EVENT_DIPLOMAT_DIED): A_PROTEST * 1.5,
		String(EVENT_TRIBUTE_PAID): A_PROTEST * 2.3,
		String(EVENT_COMPANY_DESTROYED): A_PROTEST * 3.2,
		String(Rebellion.EVENT_DECLARED): A_PROTEST * 6.4,
		String(EVENT_TOWN_LOST): A_PROTEST * 13.6,
		String(EVENT_RUN_FAILED): A_PROTEST * 27.3,
	}


## 🔒 **Everything the court hears about and deliberately does not charge
## for**, and why (#187).
##
## The other half of the acceptance: *every optic emitted is either priced or
## explicitly listed as ignored*. Without this, an event nobody priced and an
## event somebody decided not to price look identical — and the second turns into
## the first the moment the man who decided leaves.
##
## **Most of these are §3 refusing to charge twice.** A protest costs the Crown
## its tax income and a convoy at the bottom of the sea costs it the cargo; both
## already land in `net_position`, which prestige reads directly.
const IGNORED: Dictionary = {
	# 🔒 **The pillar, stated as an absence.** SPEC §14.1 locks that prestige
	# measures only how the Crown benefits, and §18 makes scoring the colony's
	# welfare a non-goal. A famine is the clearest case there is: people the PC was
	# responsible for starved, and **the court does not care.** A PC can leave
	# behind a wretched, half-starved colony and retire in glory, and the game must
	# let him.
	"famine_deaths": "the court does not care how the colonists fared (SPEC 14.1)",

	# 🔒 **Harassment, not war** (#418, `tiles-and-improvements.md` §7): no town
	# changes hands and no company is lost, so nothing the court counts has
	# happened. That is the whole point of the mechanic.
	"improvement_razed": "harassment, not war: no town changes hands and no company is lost",

	# 🔒 **There is still no such thing as losing a battle.** `battles.md` §6
	# has no rout and no surrender, so the discrete defeat the court hears about is
	# annihilation — not a bad month.
	"company_dwindled": "a month of casualties is not a defeat; the optic is annihilation",

	# Already in `net_position`, every one of them.
	"convoy_lost": "the cargo is already gone from the Crown's books",
	"crown_refusing": "the Crown closing its purse is standing, which prestige reads",
	"town_went_short": "a shortage is the colony's, and its cost is the trade it lost",

	# A town taken emits both, and the court hears about one disaster once.
	"town_stormed": "the same disaster as town_lost, which is what is priced",

	# 🔒 **A patron's displeasure is already a term in prestige.** §5 makes his
	# regard a live figure the PC is scored on, so gossip carrying that displeasure
	# to court is the same fall reaching the same account by a second road. It costs
	# the PC his officers' goodwill, which is quite enough.
	"patron_spoke_ill": "his regard is already a term in prestige",

	# 🔒 **A situation, not an event.** §4 scores an optic once, when it
	# happens, and never lets it decay — so charging for a duke sitting on colony
	# ground would leave a permanent debt for a thing the PC ends by paying. The
	# tribute that ends it is the priced optic, and it is priced dearly.
	"rival_parked_on_our_ground": "a standing situation; the tribute that ends it is priced",
	"rival_reached_minimum": "a duke's regard is not a discrete embarrassment",

	# 🔒 **Recovering a town does not refund the rebellion.** §4: optics never
	# decay, no forgetting and no rehabilitation. The court remembers that a town of
	# the PC's went over, and a table with a refund in it would be a table that
	# forgives — which is the one thing this one does not do.
	"town_returned_to_the_crown": "optics never decay, so nothing here refunds one",
}


## Whether this event was looked at and deliberately left unpriced.
static func is_ignored(type: StringName) -> bool:
	return IGNORED.has(String(type))


## What one event costs the Crown's face. Zero for everything not an optic.
static func price_of(type: StringName) -> float:
	return float(prices().get(String(type), 0.0)) * _favour


# --- 🔒 The knob: how loudly each optic rings -------------------------------

## What the court makes of the PC's optics, as a scale on every price (#287,
## *Good PR*).
##
## **One in every run without the perk.** Below one, good ones ring harder and
## bad ones ring quieter — because an optic's price *is* its debt, and there is
## one register for all of them.
##
## 🔒 **It does not make an optic decay. Nothing does.** A run with two
## rebellions in it is still a run with two rebellions in it, and merely less
## ruinous — which is the difference between a perk and a pardon.
static var _favour: float = 1.0


static func favour() -> float:
	return _favour


static func set_favour(scale: float) -> void:
	_favour = maxf(0.0, scale)


static func reset() -> void:
	_favour = 1.0


## Whether the court would hear about this at all.
static func is_an_optic(type: StringName) -> bool:
	return prices().has(String(type))


## Everything embarrassing that has ever happened, totalled.
##
## **Read from the log rather than accumulated into a field**, the same reduction
## `CrownAccounts` makes over the same log. Since §4 locks that an optic is
## scored once when it happens and never decays, the sum over the whole log *is*
## the standing debt — and a figure derived from the record cannot drift away
## from the record.
static func debt_in(log: EventLog) -> float:
	if log == null:
		return 0.0
	var owed := 0.0
	# 🔒 **Through `price_of`, like every other reader.** This read the table
	# directly and so was a second place a price was decided — which went wrong
	# the moment there was anything to apply on top of the authored figure: *Good
	# PR* scaled `price_of` and the tally the court actually keeps did not move.
	#
	# One function answers what an optic costs, and the register has two readers
	# of it rather than two answers.
	for type in prices():
		owed += price_of(StringName(type)) * float(log.of_type(StringName(type)).size())
	return owed


## What the court heard about in one month, for the letters that mention it.
static func debt_for_month(log: EventLog, month: int) -> float:
	if log == null:
		return 0.0
	var owed := 0.0
	for event in log.for_month(month):
		owed += price_of(event.type)
	return owed
