class_name Population
extends RefCounted

## 🔒 **Population counts people** (#426, `docs/mechanics/population.md` §1).
##
## A town, an expedition, a company or a village holds whole people — thousands
## of them, where a town of twelve used to be twelve units. **Experts are
## individuals among them**, one person each, and are counted as people for
## everything people are counted for.
##
## **Rates per head are authored per thousand people** (§4), so the figures in
## the data did not change when the count did: *one food per head a month* reads
## as one food per thousand people a month. This is where a rate meets a count,
## and nothing multiplies a rate by a head count anywhere else.

## The people a per-head rate in the data is written for (§4), and the workers
## that fill one worked tile or one worker-slot (§3).
const THOUSAND: int = 1000


## `people` in the thousands a per-head rate is written for.
static func thousands(people: float) -> float:
	return people / float(THOUSAND)


## A rate authored per thousand people, for this many people.
static func of(rate_per_thousand: float, people: float) -> float:
	return rate_per_thousand * thousands(people)


## A rate authored per thousand people, as an amount of `resource`.
##
## **Livestock is counted in head on the people scale** (§2), so a rate that
## yields livestock — horses per man, beasts per settler — is a ratio between two
## counts that both grew a thousandfold and does not shrink. Everything else is
## the rate for the thousands.
static func amount_for(resource: StringName, rate_per_thousand: float, people: float) -> float:
	if ResourceCatalogue.is_livestock(resource):
		return rate_per_thousand * people
	return of(rate_per_thousand, people)


## The tiles — or conversion worker-slots — this many workers fill: **one per
## thousand, floored** (§3). A town of 1,999 workers works one.
static func slots_for(workers: int) -> int:
	return maxi(0, floori(float(workers) / float(THOUSAND)))
