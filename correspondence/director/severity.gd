class_name Severity
extends RefCounted

## How hard a letter says a thing (#257, `docs/mechanics/the-director.md` §7).
##
## A topic usually has several letters. *Give us a break* and *they cannot bear
## it* are **the same concern said at two different strengths**, and each letter
## declares the pressure it speaks to. The director sends the strongest whose bar
## the pressure clears, among those whose conditions hold.
##
## ## 🔒 This needs a field of its own. `urgency` is taken
##
## SPEC §9.1 makes urgency one of **tone's** three inputs, alongside loyalty and
## personality, and the director already feeds it straight into `tone_for`. It
## cannot also select severity.
##
## ## 🔒 Severity is not tone
##
## | | Comes from | Decides |
## | :--- | :--- | :--- |
## | **Severity** | pressure | **which letter** he sends |
## | **Tone** | loyalty, personality, urgency | **how it reads** |
##
## A clergyman at the end of his patience but fond of the PC sends the **severe**
## letter in a **dutiful** register. A trivial complaint from a man who despises
## him is the **mild** letter, **hatefully**.
##
## **Collapse the two and every serious letter is also an angry one**, which
## costs the game its most useful character note: the people who like the PC are
## the ones who tell him how bad it is.
##
## ## Why conditions alone cannot do this
##
## **Conditions describe the world. Pressure describes the man.** Two clergymen
## facing an identical duty — one patient, one not — must be able to write
## different letters, and conditions cannot tell them apart because the duty is
## the same for both.

## The key a letter declares it under.
const KEY: String = "speaks_to"

## What a letter that says nothing about its strength speaks to.
##
## **Nought, so it is always within reach.** A letter nobody has given a strength
## is a letter that can always be sent, which is what every letter authored
## before this field existed was — and it keeps the field an addition rather than
## a migration.
const MILDEST: float = 0.0


## The pressure this letter speaks to.
static func of(letter: Dictionary) -> float:
	return maxf(0.0, float(letter.get(KEY, MILDEST)))


## Whether a man feeling this much would reach for this letter at all.
static func within_reach(letter: Dictionary, pressure: float) -> bool:
	return of(letter) <= pressure


## The strongest of several letters that is still within reach, or -1.
##
## Ties break on the letter id, so which one wins is the content's business
## rather than the iteration order's.
static func strongest(letters: Array, pressure: float) -> int:
	var best := -1
	var loudest := -1.0
	for index in letters.size():
		var letter: Dictionary = letters[index]
		if not within_reach(letter, pressure):
			continue
		var speaks_to := of(letter)
		if best < 0 or speaks_to > loudest + 0.0001 \
				or (absf(speaks_to - loudest) <= 0.0001
					and String(letter.get("id", "")) < String(letters[best].get("id", ""))):
			best = index
			loudest = speaks_to
	return best
