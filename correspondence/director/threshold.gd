class_name Threshold
extends RefCounted

## How much a man has to mind before he writes (#255,
## `docs/mechanics/the-director.md` §4, §5).
##
## **Pressure is about the world. The threshold is about the man.** Three things
## set it: a base per role, redundancy, and his own temperament.
##
## An **importunate** patron (`patrons.md` §6) is exactly a very low threshold
## and needs no mechanism of its own.
##
## ## 🔒 Redundancy is the only volume control that scales
##
## **The threshold rises with how many contacts share a role.** Your first
## church's man writes freely; the third church's clergyman needs a substantially
## bigger problem before he will trouble the Crown, because he knows perfectly
## well that the Crown hears from clergy already.
##
## It is diegetic, it is one rule rather than per-contact bookkeeping, and **it
## is what stops a wide colony producing a desk that grows with its towns.**
##
## That matters more than it looks after M5 and M6. A developed colony can hold
## five Crown officers, a governor per town, up to four institutional contacts
## per town, three patrons, three dukes and every commander in the field — and
## without this each of them writes as freely as the first did.
##
## ## 🔒 Ranked by when he arrived, not by his id
##
## The man who was already writing keeps his low bar. Ranking by id would let a
## governor founded in year six, whose name happens to sort early, quietly raise
## the threshold of the man who has been writing since month one — which is the
## opposite of what redundancy means.

const COLLECTION: String = "director"
const RECORD: String = "thresholds"

static var _base: Dictionary = {}
static var _default: float = 30.0
static var _redundancy_step: float = 0.45
static var _redundancy_ceiling: float = 2.6
static var _personality_spread: float = 0.35
static var _redundant_roles: PackedStringArray = PackedStringArray()


## Every magnitude is data (`data/director/thresholds.json`), because what counts
## as *enough to write about* is a harness sweep rather than a judgement anyone
## can make at a keyboard.
static func load_from(record: Dictionary) -> void:
	_base = record.get("base", {}).duplicate()
	_default = float(record.get("default", _default))
	_redundancy_step = float(record.get("redundancy_step", _redundancy_step))
	_redundancy_ceiling = float(record.get("redundancy_ceiling", _redundancy_ceiling))
	_personality_spread = float(record.get("personality_spread", _personality_spread))
	_redundant_roles = PackedStringArray(record.get("redundant_roles", []))


static func reset() -> void:
	_base = {}
	_default = 30.0
	_redundancy_step = 0.45
	_redundancy_ceiling = 2.6
	_personality_spread = 0.35
	_redundant_roles = PackedStringArray()


## 🔒 Whether more men of this role means each of them is quieter.
##
## **Only roles a colony accumulates.** A second church, a tenth town, a fourth
## commander in the field — each of those is one more voice saying the sort of
## thing the Crown already hears, which is what §5 means by the third clergyman.
##
## **The Crown's officers are not that.** They share a role and they are four
## distinct offices doing different work: the Steward's returns are not the
## Marshal's supplies, and a fourth of them is not a third clergyman. Ranking
## them against one another quieted three of the four on the arbitrary grounds of
## how their names sort — and the Marshal, whose whole function is to ask, was
## the one it silenced.
static func crowds(role: StringName) -> bool:
	return _redundant_roles.has(String(role))


## What a man of this role starts at, before anything about him.
static func base_for(role: StringName) -> float:
	return float(_base.get(String(role), _default))


## What the nth man of a role has to clear, as a multiple of the first's.
##
## 🔒 **The first is unaffected**, which is the whole of the rule: he was here
## and writing before anybody else shared his work.
static func redundancy_at(rank: int) -> float:
	return minf(1.0 + _redundancy_step * float(maxi(0, rank)), _redundancy_ceiling)


## This man's threshold.
##
## `rank` is how many contacts of his role were already here when he arrived.
static func for_contact(contact: Contact, rank: int) -> float:
	if contact == null:
		return _default
	# **Readier men have lower bars.** A contact who is apt to write is not one
	# who feels more strongly — pressure is the world's business — he is one who
	# reaches for the pen sooner.
	var temperament := 1.0 - _personality_spread * (contact.writes_readily - 1.0)
	# 🔒 **And how the PC has written to him** (#264, `tone.md` §4). A man
	# treated kindly reaches for the pen sooner and a man treated with contempt
	# stops reaching for it at all — so a kind PC pays in desk and a cruel one
	# pays by not being consulted.
	#
	# A divisor, because eagerness is the mirror of a threshold: more of one is
	# less of the other, and the same figure then reads the same way whichever end
	# a tuning pass looks at it from.
	var eager := 1.0 if contact.relationship == null else maxf(0.0001, contact.relationship.eagerness)
	return maxf(1.0, base_for(contact.role) * redundancy_at(rank) * temperament / eager)


## How many contacts of each role were already here when each one arrived.
##
## Contact id -> rank. Returned whole rather than asked per contact, because the
## answer is about the roster and computing it once a month is cheaper than
## walking it for every man in it.
static func ranks_in(contacts: Dictionary) -> Dictionary:
	var by_role: Dictionary = {}
	var ids: Array = contacts.keys()
	ids.sort()
	for id in ids:
		var contact: Contact = contacts[id]
		if contact == null:
			continue
		by_role[String(contact.role)] = by_role.get(String(contact.role), [])
		(by_role[String(contact.role)] as Array).append(contact)

	var out: Dictionary = {}
	for role in by_role:
		var peers: Array = by_role[role]
		if not crowds(StringName(role)):
			# Distinct offices. Each of them is the first of his kind.
			for peer in peers:
				out[String((peer as Contact).id)] = 0
			continue
		# Earliest first, ties broken on the id so the same roster always ranks
		# the same way.
		peers.sort_custom(func(a: Contact, b: Contact) -> bool:
			if a.known_since != b.known_since:
				return a.known_since < b.known_since
			return String(a.id) < String(b.id))
		for rank in peers.size():
			out[String((peers[rank] as Contact).id)] = rank
	return out
