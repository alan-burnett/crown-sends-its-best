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
| 2 | Commander | ⬜ | Carries A15 "defend us or let us defend ourselves" from the governor |
| 3 | Journalist | ⬜ | 0 letters |
| 4 | Quartermaster | ⬜ | 0 letters |
| 5 | Scholar | ⬜ | 0 letters |
| 6 | Clergyman | ⬜ | |
| 7 | Provost | ⬜ | |
| 8 | Patron | ⬜ | |
| 9 | Dukes (×3) | ⬜ | |
| 10 | Diplomat | ⬜ | |
| 11 | Marshal | ⬜ | |
| 12 | Steward | ⬜ | Owes a thank-you letter for donations (#472) |
| 13 | Chancellor | ⬜ | #399 built: five reliefs to place |
| — | Tribes | — | Speak only through others (SPEC §12.5), by PO recommendation |

## Author asks in #368 — each must land somewhere

| Ask | Contact | Status |
| :--- | :--- | :--- |
| Relaxing the Crown squeeze | Chancellor (+ whoever pulls each relief) | ⬜ #399 ruled and built: five reliefs, content is ours |
| Possibly affecting the Marshal's war | Marshal | ⬜ needs ruling vs the-marshal.md §8 lock |
| Winning back a disloyal governor with a CTJ moment | Governor / Diplomat | 🔧 #473 |
| Commanders restocking troops and supplies | Commander | ⬜ |
| Patrons scaring off rivals for a while | Patron | ⬜ |
| Colony contacts doing something special at high and low loyalty | all colony contacts | 🟡 governor ruled (#474, #475); others at their turn |
| Provost's library bribe at low loyalty, and the governor's letter after | Provost + Governor | ⬜ |
| "Remember when I did you a favour — can I have 100 gold" | all | ⬜ |
| Duke declares the Crown's timber reserves in jeopardy (price policy) | Dukes | ⬜ |
| Unique policies per contact, some needing high loyalty | all | ⬜ |
| Governor: tension is rising with the natives, what should we do | Governor | ✅ `they_grow_cold` (#476 to sharpen) |
| Commander: we need resupply — gold, guns, horses, tools, people | Commander | ⬜ |
| Expedition: we've reached the destination but things have changed | Governor (of expedition) | 🔧 #477 |
| Ways to cancel existing policies | PC compose + all policy holders | ✅ `pc.end_a_policy` |

## PO suggestions in #368 (comment 2026-09-23) — by contact

Carried so none is forgotten; the Author accepts or cuts each at that contact's turn.

- **Governor:** tribe war aid (built, #471); proposes a daughter town; the rebel's terms;
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
| PC can cancel a policy at will | ✅ `pc.end_a_policy` — check each policy holder's sheet uses it |
| High-regard special per contact | ⬜ |
| Low-regard unilateral per contact | ⬜ |
| Remember when — both halves, per contact | ⬜ |
| Two-voice month (#404 built) | ⬜ |
| Consequence letters | ⬜ |

## Rulings pending with the Author

- ~~#399~~ ruled and built (`crown-demands.md` §10): the five reliefs are content now.
- the-marshal.md §8 — whether any letter may move the Marshal's war.

## Issues opened by this audit

| Issue | What | Content waiting on it |
| :--- | :--- | :--- |
| #472 | A shipment nobody asked for is a donation; the Crown books what it paid | Steward's thank-you letter (Steward sheet) |
| #473 | The appeal: a gold figure scaled by the town's population | `pc.an_appeal`; D5 |
| #474 | A governor's good word | the offer and `pc.ask_for_his_good_word` |
| #475 | The Diplomat hears of a seditious governor in another town | extend `diplomat.his_governor_means_to_leave` |
| #476 | Governor letters: six things the sim knows and no letter can read | N9, N11, N14, A10, A11, A4 retarget |
| #477 | An expedition rescores its site on arrival | `governor.the_ground_has_changed` (A5) |

---

## Contact sheets

### 1. Governor

Status: 🟡 content written 2026-09-29; waiting on #473–#476 and the A5 ruling.

**To finish the governor:** after #473 write `pc.an_appeal` and the D5 option;
after #474 write his good-word offer and `pc.ask_for_his_good_word`; after #475
extend the Diplomat's sedition letter to other towns; after #476 write N9, N11,
N14, A10, A11 and retarget A4; after #477 write A5.
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
| E31 | `a_tribe_asks_for_help` | loyal: a tribe asks for goods for its troubles abroad (#471) | gift / refuse |
| E32–33 | `i_answered_their_ask_gift` / `_refuse` | disloyal: tells after (#471) | none |

#### What exists — the PC writes to him

| Code | Letter | Offered | Effect |
| :--- | :--- | :--- | :--- |
| P1 | `request_shipment` | any governor | `ship_resource`, double / fair / nothing (harsh) |
| P2 | `lay_an_embargo` | any governor | `embargo` lay / lift |
| P3 | `ask_for_a_policy` | ~~any governor~~ the Provost only since #451 | `encourage_immigration` |
| P4 | `send_the_diplomat` | where the Diplomat could go | `move_diplomat` + 240 gold |
| P5 | `urge_a_course` | any governor with a town (#454) | `urge_intent` ×4 |
| P6 | `encourage_settlers` | any governor with a town | (landed on main; to review) |
| P7 | `state_a_preference` | the governor of a marching party (#454) | `prefer_site` ×4 |
| P8 | `demand_the_stores` | any governor (#454) | `ship_resource` |
| P9 | `order_the_quota` | any governor (#454) | `ship_resource` |

The PC **cannot** send gold to a town, appeal to a governor, or cancel a policy
by composing. (Urging unprompted landed in #454.)

#### Defects found

| Code | Defect |
| :--- | :--- |
| D1 | ✅ fixed by #454. **`pc.state_a_preference` was unreachable in play.** Not composable, no sender, gated on sedition. The expedition preference (SPEC §11.4 lock, founding-towns §5) cannot be sent, and E30 has no reply to carry it. |
| D2 | ✅ fixed by #454. `pc.demand_the_stores` and `pc.order_the_quota` have no trigger — orphaned. |
| D3 | ✅ `asking_again` can say yes: gold to the town, sized as E25 sizes its ask. |
| D4 | ✅ #451 removed the three no-op options from E29. |
| D5 | 🟡 `nothing_to_report`: dead "say nothing" option removed. "Not forgotten" becomes the appeal once #473 lands. |
| D6 | ✅ `a_neighbour_declared` replies: the duty down (to the Steward), comfort, or walls. |
| D7 | 🔧 #474: his good word (Author's ruling, `policy.md` §7). |
| D8 | ⬜ `idle_building` param declares `field`, reads `fallback` (dev nit; not yet ticketed). |

#### #368 asks for the governor

| Code | Ask | Today |
| :--- | :--- | :--- |
| A1 | Win back a disloyal governor, CTJ (Author) | 🔧 #473: the appeal, gold ∝ population (`contacts.md` §9) |
| A2 | Provost library push — governor's side (Author) | ✅ E11 exists; the 100 gold not paid |
| A3 | "Remember when I did you a favour, can I have gold" (Author) | ✅ E25; sour half ✅ N4 |
| A4 | Tension rising with the natives, what should we do (Author) | ✅ `they_grow_cold` (reads a level); 🔧 #476 row 5 for a true fall |
| A5 | Expedition reached the site and things have changed (Author) | 🔧 #477: ruled — rescored below 80% on arrival; find a new site or keep it |
| A6 | High-loyalty special / unique policy (Author) | 🔧 #474 his good word |
| A7 | Low-loyalty unilateral (Author) | ✅ ruled: his turn to sedition. Diplomat's letter for his own town ✅; for another town 🔧 #475 |
| A8 | Proposes a daughter town (PO) | ✅ covered by E8/E9 (an intent change to go wide) and N6 |
| A9 | Rebel governor states terms (PO) | ✅ `our_terms` |
| A10 | Loyal neighbour: "they ask us for grain, do we send it" (PO) | 🔧 #476 row 4 |
| A11 | Investment pitch / fund a building he cannot (PO) | 🔧 #476 row 6 |
| A12 | "The good ground is theirs" (PO) | ✅ E16 covers it |
| A13 | Expedition mid-course (PO) | ✅ E30 `setting_out` now carries the preference; P7 for a later word |
| A14 | Tall's pride (PO) | 🔧 #476 row 3 (N14) |
| A15 | "Defend us, or let us defend ourselves" (PO) | ➡ moved to the Commander sheet |
| A16 | Spread made audible (PO) | ✅ E28, now with replies (D6) |
| A17 | Two-voice month vs the Steward (PO) | ✅ E7 |
| A18 | Tribe war aid (PO) | ✅ built after all in #471 — E31–33 |

#### Rulings made (2026-09-29)

- **Shipments that arrive** settle an open demand for that resource, or are a
  donation: the Steward thanks the colony, and standing rises by the goods' Crown
  value. Written into `crown-demands.md` §5; engine is #472. Carried to the
  Steward sheet: ⬜ **the thank-you letter**.
- **Resources only** — no town ships gold (`crown-demands.md` §5).
- **A1** — the appeal costs gold in proportion to the town's population
  (`contacts.md` §9, #473).
- **High-loyalty special** — his good word: a policy lifting every other
  contact in his town (`policy.md` §7, #474).
- **Low-loyalty** — only his turn to *prepare for rebellion*; the Diplomat
  writes, the PC answers with `cultivate_governor` (#475 for other towns).

#### Written 2026-09-29

| Letter | Covers |
| :--- | :--- |
| `governor.you_refused_me` | N4, sour memory: a refusal. Apologise, or stand by it |
| `governor.you_gave_your_word` | N4, sour memory: a broken promise. Apologise |
| `governor.our_people_were_struck` | N5, his expedition attacked |
| `governor.they_have_turned_back` | N5, his expedition came home |
| `governor.we_have_arrived` | N6, the new town's first letter, with the four courses |
| `governor.the_tribe_brought_us_food` | N7 |
| `governor.they_have_joined_us` | N7 |
| `governor.they_have_stopped_trading` | N7 |
| `governor.a_duke_is_in_the_rebel_town` | N8, loyal governors only |
| `governor.they_grow_cold` | A4, the tribe's regard below 35 |
| `governor.our_terms` | A9, the rebel hall's terms; the answer goes to the Steward |
| `governor.asking_again` (fix) | D3, a yes |
| `governor.a_neighbour_declared` (fix) | D6, A16 |
| `governor.nothing_to_report` (fix) | D5, dead option removed |
| `governor.setting_out` (fix) | A13: the site preference rides his first letter (`founding-towns.md` §5) |
| `pc.send_the_town_gold` | N2: 100, 250 or 500, placeholders |
| `pc.end_a_policy` | N3, to anyone holding a policy |
| `diplomat.his_governor_means_to_leave` | A7: the governor of his own town turns seditious, and he offers `cultivate_governor` |

#### New ideas (Claude)

| Code | Idea | Plumbing |
| :--- | :--- | :--- |
| N1 | PC composes **an urging** at will: "see to your defences" | ✅ already built, `pc.urge_a_course` (#454) |
| N2 | PC composes **gold to a town** | ✅ `pc.send_the_town_gold` |
| N3 | PC composes **cancel a policy** (all holders) | ✅ `pc.end_a_policy` |
| N4 | "You will remember you refused me" / "you promised us grain" | ✅ `you_refused_me`, `you_gave_your_word` |
| N5 | Expedition struck / turned back — the governor's account | ✅ `our_people_were_struck`, `they_have_turned_back` |
| N6 | "We have arrived" — the new town's first letter | ✅ `we_have_arrived` |
| N7 | The tribe brought corn / sent men to join us / stopped trading | ✅ three letters |
| N8 | A duke's men are in the rebel town next door | ✅ `a_duke_is_in_the_rebel_town` |
| N9 | His town began a trade protest — the governor explains | 🔧 #476 row 2 |
| N10 | A successor governor introduces himself | ✖ `contacts.md` §8: there are no successors |
| N11 | "We cannot finish it" — an objective stalled | 🔧 #476 row 1 |
| N12 | Low-loyalty unilateral: short-weights the customs | ✖ superseded by the Author's ruling (A7) |
| N13 | High-loyalty policy: a standing contribution | ✖ superseded by the Author's ruling (his good word) |
| N14 | Tall's pride keyed to a great building | 🔧 #476 row 3 |
