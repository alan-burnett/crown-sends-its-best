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
## ## These prices have never been weighed against one another
##
## §11: prestige is not whole until M7, when every optic exists and the whole
## table is priced in one sitting with all the answers visible. Until then each
## figure is a placeholder set in the ticket that introduced it, which is exactly
## the situation the emit-not-price rule exists to make survivable.

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


## The whole table, in gold. Every price is a placeholder until M7 (§11).
##
## **There is no such thing as losing a battle** (`battles.md` §6 has no rout and
## no surrender), so an optic priced on a battle lost could never fire. The
## discrete defeat the court actually hears about is a company wiped out, and
## that is what is priced.
static func prices() -> Dictionary:
	return {
		# Available now.
		#
		# 🔒 **The figure that decides whether desperate is a tool or the
		# answer to everything** (#264). Small enough to be worth paying once;
		# large enough that a run of them tells at retirement. The ticket says
		# plainly that it wants the harness rather than an argument, so this is a
		# starting point with its reasoning attached rather than a judgement: a
		# fifth of a trade protest, so one plea is a small thing beside a resource
		# the colony stopped selling — and about thirty of them come to a
		# rebellion, which is the shape the sentence *a run of them tells* has.
		String(EVENT_DESPERATE_LETTER): 45.0,
		String(TradeProtest.EVENT_DECLARED): 220.0,
		String(Rebellion.EVENT_DECLARED): 1_400.0,
		# Hooks. M5 brings rivals and lost towns, M6 brings companies, and #78
		# brings the run's own ending.
		String(EVENT_TRIBUTE_PAID): 500.0,
		String(EVENT_COMPANY_DESTROYED): 700.0,
		String(EVENT_TOWN_LOST): 3_000.0,
		String(EVENT_RUN_FAILED): 6_000.0,
	}


## What one event costs the Crown's face. Zero for everything not an optic.
static func price_of(type: StringName) -> float:
	return float(prices().get(String(type), 0.0))


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
	var table := prices()
	for type in table:
		owed += float(table[type]) * float(log.of_type(StringName(type)).size())
	return owed


## What the court heard about in one month, for the letters that mention it.
static func debt_for_month(log: EventLog, month: int) -> float:
	if log == null:
		return 0.0
	var owed := 0.0
	for event in log.for_month(month):
		owed += price_of(event.type)
	return owed
