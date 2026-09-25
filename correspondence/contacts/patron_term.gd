class_name PatronTerm
extends RefCounted

## How long a patron stays, and the six months that close (#283,
## `docs/mechanics/patrons.md` §8, `docs/mechanics/prestige.md` §5).
##
## ## 🔒 The roll is hidden until it fires
##
## **Every patron stays at least two years.** At that mark he privately settles
## on how much longer he wants — anything from nothing to two further years — and
## **the PC is told none of it.**
##
## So at two years the PC cannot tell whether this man has a month left or
## another two. There is no planning for it. There is only the six months, once
## they start.
##
## ## 🔒 And that is where prestige settles
##
## `prestige.md` §5: his regard is a **live term while he is present**, and on
## departure his **final loyalty banks permanently** — he goes back to court and
## speaks well or ill of the PC for ever, at whatever regard he left with.
##
## Which makes those six months the last chance to move it, **and the PC knows it
## to the month.** Same shape as the Chancellor's warning: a deadline stated in
## fiction, actionable, with the business still open while it runs. A patron
## cultivated for three years and neglected in his last spring banks that neglect
## and takes it home.
##
## ## 🔒 Business continues as normal
##
## He still offers, still asks, still trades. Nothing in his letters' gates knows he
## is leaving, and there is no branch anywhere that quiets a man on his way out —
## a patron who stopped dealing the month he gave notice would make the window
## worthless, which is the opposite of the point.

const EVENT_LEAVING: StringName = &"patron_leaving"
const EVENT_DEPARTED: StringName = &"patron_departed"

## Placeholders; §11 lists all three as tuning.
const STAYS_AT_LEAST: int = 24
const AT_MOST_LONGER: int = 24
const NOTICE_MONTHS: int = 6

## What a patron's regard is worth to the PC's name at full loyalty.
##
## Placeholder. It is the one figure that is both the live term and the final
## bank, so a patron who leaves at the regard he held is worth exactly what he
## was worth the month before — which is what makes the last six months a
## continuation of the game rather than a separate scoring event.
const REGARD_WORTH: float = 400.0


## Move every patron's term on a month (Seam A).
static func advance(run: RunState, log: EventLog, month: int) -> void:
	if run == null:
		return
	for entry in Patron.all_in(run):
		var patron: Contact = entry
		_settle_term(patron, run, log, month)
		_give_notice(patron, log, month)
		_depart(patron, run, log, month)


## 🔒 **Drawn once, at the two-year mark, and hidden** (§8).
##
## From his own stream (`hash(run_seed, contact_id)`), so the same seed gives the
## same man the same term however much else has happened — and a second patron
## settling in the same month does not shift the first one's number.
static func _settle_term(
	patron: Contact, run: RunState, log: EventLog, month: int
) -> void:
	if patron.leaves_month >= 0 or patron.is_dead:
		return
	if month - patron.known_since < STAYS_AT_LEAST:
		return
	var rng := run.streams.contact_stream(String(patron.id))
	# 🔒 **The extra term runs out, and *then* the six months begin** (§8).
	#
	# Not six months carved out of the term — six months after it. A man who
	# settled on three further months would otherwise be gone before he could
	# give notice, and the window that is the entire point of this mechanic would
	# simply not happen to him.
	#
	# So the shortest stay is two years, nothing more, and six months of warning.
	patron.leaves_month = month \
		+ rng.randi_range(0, AT_MOST_LONGER) \
		+ NOTICE_MONTHS
	# 🔒 **Not emitted.** Seam A says the sim emits what happened, and what
	# happened is that a man made up his mind privately. An event here would put
	# the date in the log, and the log is what letters read.


## 🔒 **He writes, and every letter from here names the date** (§8).
##
## Fired once, when the notice period opens. What a letter reads is this event
## and the date on it.
static func _give_notice(patron: Contact, log: EventLog, month: int) -> void:
	if not is_leaving(patron, month) or patron.is_dead:
		return
	if month != patron.leaves_month - NOTICE_MONTHS:
		return
	log.emit(EVENT_LEAVING, patron.id, month, {
		"patron": String(patron.id),
		"name": patron.display_name,
		"leaves_month": patron.leaves_month,
		"months_left": NOTICE_MONTHS,
	}, WorldPhase.RECKONING)


## 🔒 **Whatever he had made up his mind about the PC is locked in** (§8).
##
## The live term stops the month he goes and the bank replaces it for ever, at
## the regard he left with. `Prestige` reads the latest live figure and sums
## every bank, so the handover needs no arithmetic of its own.
static func _depart(
	patron: Contact, run: RunState, log: EventLog, month: int
) -> void:
	if patron.leaves_month < 0 or month < patron.leaves_month or patron.is_dead:
		return

	var banked := patron.loyalty() / Relationship.MAX_LOYALTY * REGARD_WORTH
	log.emit(PatronCredit.EVENT_BANKED, patron.id, month, {
		"contact": String(patron.id),
		"deed": String(EVENT_DEPARTED),
		"amount": banked,
	}, WorldPhase.RECKONING)

	log.emit(EVENT_DEPARTED, patron.id, month, {
		"patron": String(patron.id),
		"name": patron.display_name,
		"months_here": month - patron.known_since,
		# 🔒 **No loyalty figure** (SPEC §8.5 keeps it off the player's screens).
		# What is banked is on the credit event, which is the Crown's book.
	}, WorldPhase.RECKONING)

	# 🔒 **What he put his name to stays** (#440, §4). A policy of his still
	# standing is the colony's for good, with no charge and no one to drain; one
	# that ended while he was here has already gone, and nothing brings it back.
	if run.policies != null:
		run.policies.outlive(patron.id, log, month)

	# 🔒 **He is gone from the correspondence, and he counts for ever.**
	# `Prestige` sums the banks out of the log, so nothing has to keep a record of
	# a man who is no longer here.
	run.contacts.erase(String(patron.id))


## Whether the six months have opened.
static func is_leaving(patron: Contact, month: int) -> bool:
	return patron != null and patron.leaves_month >= 0 \
		and month >= patron.leaves_month - NOTICE_MONTHS


## How many months he has left, or `-1` while he is not leaving.
static func months_left(patron: Contact, month: int) -> int:
	if not is_leaving(patron, month):
		return -1
	return maxi(0, patron.leaves_month - month)


# --- 🔒 The live term -------------------------------------------------------

## What the patrons presently here are worth to the PC's name, this month.
##
## 🔒 **Replaced every month, never accumulated.** §5 has a present patron's
## regard *rising and falling month to month like anything else* — so `Prestige`
## reads the latest of these and only the latest, and the sum of the banks
## separately. A patron who leaves simply stops appearing in it.
static func live_regard(run: RunState) -> float:
	var total := 0.0
	for entry in Patron.all_in(run):
		var patron: Contact = entry
		if patron.is_dead:
			continue
		total += patron.loyalty() / Relationship.MAX_LOYALTY * REGARD_WORTH
	return total
