class_name LetterKind
extends RefCounted

## The three kinds of outgoing letter (#261, `docs/mechanics/tone.md` §3).
##
## | | |
## | :--- | :--- |
## | **Answering** | you meet or deny what was asked of you |
## | **Directing** | you tell a contact what you want him doing |
## | **Asking** | you want something from him |
##
## Which knobs are even available differs by kind:
##
## | | Answering | Directing | Asking |
## | :--- | :--- | :--- | :--- |
## | Loyalty | ✅ | ✅ | ✅ |
## | The six compliance outcomes | — | ✅ | ✅ |
## | Partial magnitude | — | — | ✅ |
## | Urging weight and duration | — | ✅ | — |
##
## ## 🔒 Answering is deliberately the thinnest
##
## **There is no compliance step** — *you* are the one complying — and the
## decision that matters is whether you gave him what he asked for. The deed
## dominates and tone must not rival it (SPEC §8.5, locked).
##
## ## Why this is a table and not a guess
##
## The rule was already half here: `fund_policy` and `end_policy` were forced to
## comply with the comment *being paid is not a request*, which is §3's answering
## row without the name. Half a rule in a comment is a rule the next order kind
## will not get, so this names all of them.
##
## **A kind not listed is directing**, which is the safe reading: it deliberates
## like an order, which is what everything did before this table existed.

const ANSWERING: StringName = &"answering"
const DIRECTING: StringName = &"directing"
const ASKING: StringName = &"asking"

const ALL: Array[StringName] = [ANSWERING, DIRECTING, ASKING]

## **You meet or deny what he asked of you.** His own letter put the question and
## your reply is the whole of it, so there is nothing left for him to decide.
const ANSWERS: Array[StringName] = [
	M1Registrations.ORDER_PROMISE_GOLD,
	M1Registrations.ORDER_PROMISE_RESOURCE,
	M1Registrations.ORDER_PROMISE_REVENUE,
	M1Registrations.ORDER_PROMISE_SHIPMENT,
	M1Registrations.ORDER_DECLINE_DEMAND,
	M1Registrations.ORDER_FUND_POLICY,
	M1Registrations.ORDER_END_POLICY,
	M1Registrations.ORDER_REFUSE,
	M1Registrations.ORDER_GRANT_FAVOR,
	M1Registrations.ORDER_PAY_TRIBUTE,
	M1Registrations.ORDER_FUND_FOUNDING,
	M1Registrations.ORDER_ADJUST_LOYALTY,
]

## **You want something from him**, and how much of it he does is a question with
## a number in it. Partial magnitude belongs to exactly these.
const ASKS: Array[StringName] = [
	M1Registrations.ORDER_SHIP_RESOURCE,
	M1Registrations.ORDER_REQUEST_TROOPS,
]


## Which kind of letter this order came from.
static func of(order_kind: StringName) -> StringName:
	if ANSWERS.has(order_kind):
		return ANSWERING
	if ASKS.has(order_kind):
		return ASKING
	return DIRECTING


## Whether the man reading it has anything left to decide.
##
## 🔒 **Answering has no compliance step.** Not a heavy push toward complying —
## none at all. A man who asked for gold and was sent it does not then deliberate
## about whether to accept it, and a man who was refused has not been given
## anything to refuse in turn.
static func deliberates(order_kind: StringName) -> bool:
	return of(order_kind) != ANSWERING


## Whether tone may move how much of a partial gets done.
##
## §4's annoyed pushes hard toward a partial answer, and that push **is worth
## less if the partial is a tenth of what was asked.** So the two move together,
## and only where there is an amount to move.
static func has_a_magnitude(order_kind: StringName) -> bool:
	return of(order_kind) == ASKING


## Whether a letter may be written harshly (#263, `tone.md` §9).
##
## 🔒 **Not when answering.** There is nothing to lean on — *you* are the one
## deciding, and *do it or else* has no object. On every other letter it is a
## second axis beside the tone: five tones times harsh-or-not is **ten
## registers.**
##
## Offered when **any** option in the letter would order something. A reply that
## mixes an answer with an instruction is still an instruction, and the clause
## has something to attach to.
static func may_be_harsh(letter: Letter) -> bool:
	if letter == null:
		return false
	for step in letter.steps():
		for option in step.get(LetterSchema.KEY_OPTIONS, []):
			for effect_id in option.get(LetterSchema.KEY_EFFECT, {}):
				var kind := ContentRegistry.order_kind_of(String(effect_id))
				if String(kind).is_empty():
					continue
				if of(kind) != ANSWERING:
					return true
	return false
