# Correspondence audit — #368 checklist

The standing checklist for the author-led audit in #368. **Nothing on this list
is dropped without the Author saying so.** An item leaves only as ✅ done,
🔧 issue opened (named), or ✖ cut by the Author.

Legend: ⬜ not started · 🟡 in discussion · 🔧 waiting on an engine issue ·
✅ done · ✖ cut by the Author

Tone-sensitive prose is **out of scope** for this pass (Author, 2026-09-26):
each letter gets default prose; the tone pass comes after.

---

## Per-contact audit — every contact gets the same sheet

For each contact, before sign-off:

1. Every letter he can **send** — trigger, content, replies, effects.
2. Every letter the PC can **send him** (composed).
3. What investing in him **unlocks** — a high-loyalty special (policy or act).
4. What he does **unilaterally at low loyalty**.
5. **Remember when** — a kindness he did the PC, and the sour half.
6. Gaps, each marked authorable-now or issue-needed.

## Contacts

| # | Contact | Status | Notes |
| --: | :--- | :--- | :--- |
| 1 | Governor | 🟡 | Started 2026-09-26 |
| 2 | Commander | ⬜ | |
| 3 | Journalist | ⬜ | 0 letters |
| 4 | Quartermaster | ⬜ | 0 letters |
| 5 | Scholar | ⬜ | 0 letters |
| 6 | Clergyman | ⬜ | |
| 7 | Provost | ⬜ | |
| 8 | Patron | ⬜ | |
| 9 | Dukes (×3) | ⬜ | |
| 10 | Diplomat | ⬜ | |
| 11 | Marshal | ⬜ | |
| 12 | Steward | ⬜ | |
| 13 | Chancellor | ⬜ | Last — needs #399 ruling |
| — | Tribes | — | Speak only through others (SPEC §12.5), by PO recommendation |

## Author asks in #368 — each must land somewhere

| Ask | Contact | Status |
| :--- | :--- | :--- |
| Relaxing the Crown squeeze | Chancellor | ⬜ needs #399 ruling |
| Possibly affecting the Marshal's war | Marshal | ⬜ needs ruling vs the-marshal.md §8 lock |
| Winning back a disloyal governor with a CTJ moment | Governor / Diplomat | ⬜ |
| Commanders restocking troops and supplies | Commander | ⬜ |
| Patrons scaring off rivals for a while | Patron | ⬜ |
| Colony contacts doing something special at high and low loyalty | all colony contacts | ⬜ |
| Provost's library bribe at low loyalty, and the governor's letter after | Provost + Governor | ⬜ |
| "Remember when I did you a favour — can I have 100 gold" | all | ⬜ |
| Duke declares the Crown's timber reserves in jeopardy (price policy) | Dukes | ⬜ |
| Unique policies per contact, some needing high loyalty | all | ⬜ |
| Governor: tension is rising with the natives, what should we do | Governor | ⬜ |
| Commander: we need resupply — gold, guns, horses, tools, people | Commander | ⬜ |
| Expedition: we've reached the destination but things have changed | Governor (of expedition) | ⬜ |
| Ways to cancel existing policies | PC compose + all policy holders | ⬜ |

## PO suggestions in #368 (comment 2026-09-23) — by contact

Carried so none is forgotten; the Author accepts or cuts each at that contact's turn.

- **Governor:** ~~tribe war aid~~ (✖ Author deferred past M8 in #402); proposes a daughter town; the rebel's terms;
  loyal neighbour of a rebel; investment pitch; "the good ground is theirs";
  expedition mid-course; tall's pride; asks the Crown to fund a building;
  "defend us or let us defend ourselves"; spread made audible; two-voice month
  against the Steward.
- **Commander:** the decision letter (where do I go); resupply; after a battle;
  veteran without a command; before the walls of a rebel town.
- **Journalist:** "I have had letters from Kettleburn"; programme asks; PR and
  Crown Sentiment at high regard; headline after a battle or protest; the new
  hamlet.
- **Quartermaster:** the contract; guns shortage; war profiteering noticed.
- **Scholar:** library; peace against the Marshal; studies the natives;
  luxuries.
- **Clergyman:** festival, holy day, pilgrims, charity (exist); sermons at low
  regard; rebellion mediator; missionary zeal; clergy vs scholar on natives.
- **Provost:** library bribe; experts report; education bearing fruit;
  high-regard policy.
- **Patron:** specialty offers; scaring off a duke; pressing a founding;
  reacting to the court warming or cooling; the gift that is not free.
- **Dukes:** timber reserves; courting a rebel town; latch at minimum; paid and
  satisfied for now.
- **Diplomat:** envoy to a rebel town; conscience on the natives; his town about
  to fall.
- **Marshal:** cheap troops while the war is quiet; recalling his men; wants an
  example made of rebels.
- **Chancellor:** relief from the Squeeze at a price; spread too thin; an
  example made.
- **Steward:** two-voice month against a governor.

## Cross-cutting

| Item | Status |
| :--- | :--- |
| PC can cancel a policy at will (today only as a reply to a lapsing letter) | ⬜ |
| High-regard special per contact | ⬜ |
| Low-regard unilateral per contact | ⬜ |
| Remember when — both halves, per contact | ⬜ |
| Two-voice month (#404 built) | ⬜ |
| Consequence letters | ⬜ |

## Rulings pending with the Author

- #399 — what relief from the Squeeze is, and what it costs.
- the-marshal.md §8 — whether any letter may move the Marshal's war.

## Issues opened by this audit

_(none yet)_

---

## Contact sheets

### 1. Governor

Status: 🟡 inventory presented 2026-09-26, awaiting the Author's rulings.
Codes below (E, D, A, N) are how we refer to items in the session.

#### What exists — inbound, 30 letters

| Code | Letter | Fires when | Replies |
| :--- | :--- | :--- | :--- |
| **Town reports** | | | |
| E1 | `report_month` | always (cd 3) | urge ×4 |
| E2 | `announce_objective` | new objective that can finish | urge ×4 |
| E3 | `report_completed` | town finished something | urge ×4 |
| E4 | `report_shortage` | stores < 0.34, after month 1 | urge ×4 |
| E5 | `report_idle_building` | a building dark for upkeep | urge get_rich / go_tall |
| E6 | `question_duty` | base tax > 0.12 | none |
| E7 | `a_rise_would_be_felt` | two-voice companion to the Steward's tax-rise letter | none |
| **His intent** | | | |
| E8 | `i_have_settled_on_a_course` | intent changed, regard high | carry on / urge ×3 |
| E9 | `the_course_i_must_take` | intent changed, regard medium | none |
| E10 | `report_disagreement` | PC's urging ≠ his intent | urge ×4 |
| E11 | `i_have_been_pressed` | Provost urged his town, intent now education | none |
| E12–15 | `ack_complied` / `ack_delayed` / `ack_refused` / `ack_acted_alone` | answering a PC urging | none |
| **Natives** | | | |
| E16 | `the_people_next_door` | native pressure ≥ 0.12 (cd 12) | urge ×3 + "be rid of them" |
| E17 | `a_tribe_has_written` | loyal: asks how to answer a tribe | yield / gift / refuse / threaten |
| E18–21 | `i_answered_the_tribe_*` ×4 | disloyal: tells after | none |
| E22 | `i_have_made_a_bargain` | native trade agreement struck | urge ×3 |
| **Enemies** | | | |
| E23 | `they_are_on_my_fields` | foreign men on his tiles | urge get_rich / military |
| **Remember when** | | | |
| E24 | `asking_again` | remembers the PC's kindness, stores < 0.5 | refuse only |
| E25 | `remember_what_i_sent` | remembers **his** kindness (cd 24) | send gold to town / refuse |
| **Rebellion** | | | |
| E26 | `nothing_to_report` | his intent is sedition | urge get_rich / 2 no-ops |
| E27 | `town_has_declared` | his town declared | none |
| E28 | `a_neighbour_declared` | another town declared | none |
| E29 | `we_are_coming_back` | his town returned | 3 no-ops |
| **Founding** | | | |
| E30 | `setting_out` | newly elected expedition governor | none |

#### What exists — the PC writes to him

| Code | Letter | Offered | Effect |
| :--- | :--- | :--- | :--- |
| P1 | `request_shipment` | any governor | `ship_resource`, double / fair / nothing (harsh) |
| P2 | `lay_an_embargo` | any governor | `embargo` lay / lift |
| P3 | `ask_for_a_policy` | any governor or Crown officer | `encourage_immigration` only |
| P4 | `send_the_diplomat` | where the Diplomat could go | `move_diplomat` + 240 gold |

The PC **cannot** urge an intent unprompted, send gold to a town, appeal to a
governor, or cancel a policy by composing. Urging exists only as a reply.

#### Defects found

| Code | Defect |
| :--- | :--- |
| D1 | **`pc.state_a_preference` is unreachable in play.** Not composable, no sender, gated on sedition. The expedition preference (SPEC §11.4 lock, founding-towns §5) cannot be sent, and E30 has no reply to carry it. |
| D2 | `pc.demand_the_stores` and `pc.order_the_quota` have no trigger — orphaned. |
| D3 | E24 `asking_again` can only refuse. `promise_gold_to_town` / `promise_resource` now exist to say yes. |
| D4 | E29 `we_are_coming_back` — three options, none does anything. |
| D5 | E26 `nothing_to_report` — two of three options do nothing. |
| D6 | E28 `a_neighbour_declared` asks for "something to tell them" and offers no reply. |
| D7 | The governor holds **no policy of his own**; policy.md §7 says he can ("how his own town conducts itself"). |
| D8 | `idle_building` param source declares `field`, reads `fallback` (dev nit). |

#### #368 asks for the governor

| Code | Ask | Today |
| :--- | :--- | :--- |
| A1 | Win back a disloyal governor, CTJ (Author) | ⬜ no appeal letter; `adjust_loyalty` exists |
| A2 | Provost library push — governor's side (Author) | ✅ E11 exists; the 100 gold not paid |
| A3 | "Remember when I did you a favour, can I have gold" (Author) | ✅ E25; sour half ⬜ (`remembers_a_slight`, `remembers_a_broken_word` unused by governors) |
| A4 | Tension rising with the natives, what should we do (Author) | ⬜ E16 is static pressure; nothing fires on regard *falling* |
| A5 | Expedition reached the site and things have changed (Author) | ⬜ nothing; blocked by D1 as well |
| A6 | High-loyalty special / unique policy (Author) | ⬜ D7 |
| A7 | Low-loyalty unilateral (Author) | ⬜ none for governors (E18–21 is the closest) |
| A8 | Proposes a daughter town (PO) | ⬜ |
| A9 | Rebel governor states terms (PO) | ⬜ |
| A10 | Loyal neighbour: "they ask us for grain, do we send it" (PO) | ⬜ |
| A11 | Investment pitch / fund a building he cannot (PO) | ⬜ `promise_gold_to_town` exists |
| A12 | "The good ground is theirs" (PO) | 🟡 E16 half-covers |
| A13 | Expedition mid-course (PO) | ⬜ |
| A14 | Tall's pride (PO) | 🟡 E3 is generic |
| A15 | "Defend us, or let us defend ourselves" (PO) | ⬜ — overlaps Commander |
| A16 | Spread made audible (PO) | 🟡 E28 |
| A17 | Two-voice month vs the Steward (PO) | ✅ E7 |
| A18 | Tribe war aid (PO) | ✖ Author deferred past M8 (#402) |

#### New ideas (Claude)

| Code | Idea | Plumbing |
| :--- | :--- | :--- |
| N1 | PC composes **an urging** at will: "see to your defences" | authorable |
| N2 | PC composes **gold to a town** | authorable |
| N3 | PC composes **cancel a policy** (all holders) | authorable (`he_holds_a_policy`, `end_policy`) |
| N4 | "You will remember you refused me" / "you promised us grain" | authorable |
| N5 | Expedition struck / turned back — the governor's account | authorable (events exist) |
| N6 | "We have arrived" — the new town's first letter | authorable (`town_founded`) |
| N7 | The tribe brought corn / sent men to join us / stopped trading | authorable (events exist) |
| N8 | A duke's men are in the rebel town next door | authorable (`rebellion_backed`) |
| N9 | His town began a trade protest — the governor explains | authorable |
| N10 | A successor governor introduces himself | issue (no arrival condition for governors) |
| N11 | "We cannot finish it" — an objective stalled | issue (no stall condition) |
| N12 | Low-loyalty unilateral: the town short-weights the Crown's customs | issue (driver) |
| N13 | High-loyalty policy: a standing contribution to the Crown | issue (new policy effect) |
| N14 | Tall's pride keyed to a great building (college, cathedral) | issue (filter on what finished) |
