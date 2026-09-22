class_name Letterhead
extends RefCounted

## How a letter says who it is from (#304, `docs/mechanics/names.md` §2).
##
## **`<Role> <name>` and then a qualifier.**
##
## > **Governor Don Johnson of Morrisville**
## > **Commander Ames Harker of the town of Ashmere**
## > **Patron Mingle Welkington**
##
## ## 🔒 The first word is always the role
##
## Not an honorific. No *Captain*, no *Lord*, no *Father*.
##
## **It is there to be scanned, not to be flavour.** An experienced player should
## look at the stack and know what came in without opening anything, and a desk
## of *Lord*, *Sir* and *Captain* tells him nothing about who wants what. A desk
## of **Governor. Commander. Patron. Journalist.** tells him the whole month.
##
## It costs a little colour and buys a real thing — the same trade
## `the-director.md` makes when it refuses to sort the stack by importance: the
## player does the judging, so the interface owes him legible inputs.
##
## **The role word comes from the role, not from `title`.** That field holds
## flavour like *Steward of the Revenue*, no letter uses it, and the letterhead
## must not.
##
## ## 🔒 A rival is the one exception, and it is a principled one
##
## **His name is the whole letterhead.** *Le Duc de Montargis*. No role word,
## because *Rival* is a game term and no man was ever called one.
##
## The rule survives it because of **why** the rule exists. The role word is a
## crutch for a name the player has never seen: a generated *Ames Harker* means
## nothing until *Commander* is in front of it. Rivals are a hardcoded cast of
## three whose names carry their own titles — *Le Duc*, *Grevé*, *Don* — so the
## fiction has already done the job the role word was hired for.
##
## It does not extend to the Crown officers, who are equally fixed and equally
## learned. *Master Corvyn Thrale* does not say **Steward**, so he keeps his
## word. **The test is whether the name itself announces the man.**

## The word each role puts first.
##
## A role absent here gets none, which is how a rival ends up with his name
## alone — an absence rather than a branch on who he is.
const ROLE_WORD: Dictionary = {
	Contact.ROLE_GOVERNOR: "Governor",
	Contact.ROLE_COMMANDER: "Commander",
	Contact.ROLE_PATRON: "Patron",
	Contact.ROLE_INSTITUTIONAL: "",
	Contact.ROLE_DIPLOMAT: "Diplomat",
	Contact.ROLE_CROWN_OFFICER: "",
}

## 🔒 **The qualifier a role starts with** (§2), which the contact then carries.
##
## Defaulted from the role and **settled when the contact is created**, because a
## commander is one role with three allegiances (`commanders.md` §1) and each
## names a different master. A qualifier derived from the role would have to be
## recomputed by something that knew what a rebellion was; one he carries is
## simply rewritten by the thing that turned him, and nothing else in the game
## needs to know.
const DEFAULT_QUALIFIER: Dictionary = {
	Contact.ROLE_GOVERNOR: " of {town}",
	Contact.ROLE_INSTITUTIONAL: " of {town}",
	Contact.ROLE_DIPLOMAT: " of {town}",
	Contact.ROLE_COMMANDER: " of the town of {town}",
	Contact.ROLE_PATRON: "",
	Contact.ROLE_CROWN_OFFICER: "",
	Contact.ROLE_RIVAL: "",
}

## The two a commander is given instead, by who raised him.
##
## **The patron's went empty when the title became his role.** It read *, patron
## to the crown*, which said what *Lord* could not — *Patron* says it in the first
## word, and saying it twice is worse than saying it once.
const CROWN_COMMANDER: String = " of the Crown's service"

## 🔒 **And it changes when he turns** (§2). A town commander whose town revolts
## stops being *of the town of Ashmere* and becomes this. Same contact, same
## company, different master.
##
## It says the right thing, too. A rebel commander is not a local difficulty in
## Ashmere — **he serves a nation now**, which is what SPEC §13.1 means when it
## says the colony becomes one.
const REBEL_COMMANDER: String = " of the independent nation"


## What a role's qualifier starts as.
static func qualifier_for(role: StringName) -> String:
	return String(DEFAULT_QUALIFIER.get(role, ""))


## The word this contact puts before his name, or empty.
##
## 🔒 **Four offices share one role**, so a Crown officer's word cannot come
## from his role alone: the Steward, the Chancellor, the Marshal and the Provost
## are all `crown_officer` and §2 wants *Steward Corvyn Thrale*. His word is a
## field on the contact, defaulted from the role — the same shape the qualifier
## has, and for the same reason.
##
## It is still not the `title` field. That holds flavour like *Steward of the
## Revenue*; this holds the one word that goes first.
static func of_contact(contact: Contact) -> String:
	if contact == null:
		return ""
	if not contact.role_word.is_empty():
		return contact.role_word
	return String(ROLE_WORD.get(contact.role, ""))


## What a role's word defaults to, for a contact who says nothing.
static func role_word(role: StringName) -> String:
	return String(ROLE_WORD.get(role, ""))


## The whole letterhead: role, name, qualifier.
##
## **The town fills the slot from the contact**, so the Diplomat's letterhead
## moves when he is rehomed without anybody special-casing him (SPEC §8.1). A
## player who notices *of Ashmere* become *of Kettleburn* has been told something
## real before he reads a word.
##
## A qualifier whose town is unknown is dropped rather than rendered with a hole
## in it: *Governor Silas Pike of* is worse than *Governor Silas Pike*.
static func of(contact: Contact) -> String:
	if contact == null:
		return ""

	var out := contact.display_name
	var word := of_contact(contact)
	if not word.is_empty():
		out = "%s %s" % [word, out]

	var qualifier := contact.qualifier
	if qualifier.contains(TOWN_SLOT):
		var town := contact.town
		if town.is_empty():
			return out
		qualifier = qualifier.replace(TOWN_SLOT, town)
	return out + qualifier


## The one slot a qualifier may carry.
const TOWN_SLOT: String = "{town}"
