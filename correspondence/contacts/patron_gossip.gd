class_name PatronGossip
extends RefCounted

## A well-connected patron's displeasure reaches the court (#282,
## `docs/mechanics/patrons.md` §6).
##
## ## 🔒 The first time one contact's opinion moves another's
##
## *Lord Ashby gives us to understand that Your Grace has been difficult.*
##
## Everything else in the game moves a man by what the PC did or by what the
## world did. This moves him by **what another man thinks**, which is new, and
## the doc is emphatic about how far it may go:
##
## > **Keep it one-directional and shallow.** A patron reaches the Crown
## > officers; the officers reach nobody.
##
## Three things enforce that, and they are worth naming because a later reader
## will be tempted by each:
##
## | | |
## | :--- | :--- |
## | **Only a patron speaks** | the source must hold the `well_connected` vice |
## | **Only an officer hears** | `ROLE_CROWN_OFFICER`, never a governor, never another patron |
## | **Hearing is not speaking** | the officers' own movement emits nothing anyone listens to |
##
## Contagion between contacts generally is a spiral nobody has designed, and it
## must not arrive by accident.
##
## ## 🔒 Only a fall travels
##
## A man complains about the PC at court; he does not go round improving the
## PC's name because he has been paid. The asymmetry is the point of the vice —
## it is a *vice* — and it is also what stops the well-connected patron becoming
## the cheapest way to raise five loyalties at once.
##
## ## 🔒 And the victim writes
##
## `contacts.md` §6: a contact writes about what he cares about. A silent
## contagion would be a number moving behind the curtain; a letter from the
## Steward repeating gossip is the PC discovering that a man he brushed off has a
## voice at court. The event is what the trigger reads, so the letter cannot fire
## without the movement having happened.

const KNOB: String = "displeasure_spreads"

const EVENT_SPREAD: StringName = &"patron_spoke_ill"


## How much of a patron's fall reaches the court, nought if he is nobody.
##
## **Clamped below one**, which is the shallowness rule in arithmetic: a share of
## one would have the whole court fall as far as the patron did, and there would
## be no difference between offending one man and offending five.
static func share_of(contact: Contact) -> float:
	if not Patron.is_patron(contact):
		return 0.0
	return clampf(float(PatronVices.knob_of(contact, KNOB).get("share", 0.0)), 0.0, 0.9)


## Carry this month's falls to the Crown's officers.
##
## Reads **the movement, not the level** — a patron who is merely low is a patron
## the court has already heard about, and he must not go on costing the PC every
## month for the same slight. `PatronBook` holds where each man stood when the
## court last heard, which is why this needs no threshold and never repeats
## itself.
##
## 🔒 **Ordered, and summed before anything moves.** Two well-connected patrons
## falling in one month must land the same way however the roster was iterated,
## so the whole month's gossip is totalled first and applied once.
static func spread(run: RunState, log: EventLog, month: int) -> void:
	if run == null or log == null or run.patrons == null:
		return

	var speakers := PackedStringArray()
	var carried := 0.0
	var patrons := Patron.all_in(run)
	for entry in patrons:
		var patron: Contact = entry
		var share := share_of(patron)
		var fell := run.patrons.fall_of(patron)
		if share > 0.0 and fell > 0.0:
			carried += fell * share
			speakers.append(String(patron.id))
		# **Noted whatever his vice**, so a book restored from a save knows where
		# every patron stood rather than only the ones who talk.
		run.patrons.note(patron)

	if carried <= 0.0:
		return

	for officer in ContactRoster.crown_officers(run):
		if officer.relationship == null:
			continue
		# 🔒 **The officers hear and do not speak.** Their own movement is an
		# ordinary drift with nothing listening for it, which is the whole of
		# "one-directional and shallow" — there is no second pass, and a dev who
		# wanted one would have to write it and argue with `test_patrons`.
		officer.relationship.drift(-carried)

	# **Seam A: the movement and the event are one act.** The trigger that makes
	# an officer write reads this, so there is no state in which the court has
	# cooled and nobody mentions it.
	log.emit(EVENT_SPREAD, &"crown", month, {
		"patrons": speakers,
		"amount": carried,
	}, WorldPhase.RECKONING)
