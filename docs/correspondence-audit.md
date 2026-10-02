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

Each contact's four-point brief (who he is, what he wants, what loyalty buys,
when he turns) is in [`contact-briefs.md`](contact-briefs.md).

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
| #478 | A new governor writes from his party, then from his town's founding | seasonal report from town month 3; course letters held past arrival; a report from the road and the sea; Crown founding's `setting_out` |

---

## Contact sheets

### 1. Governor

**Status: 🟡 written as far as the engine allows (2026-10-02).** 44 letters from
him, 10 the PC can compose to him, one from the Diplomat about him. Waiting on
#473–#478. Not signed off.

Codes (E, P, D, A, N) are how the session refers to items. E-codes from the
first inventory are kept, and new letters continue from E34.

#### What finishing him takes

| When this lands | Write |
| :--- | :--- |
| #473 the appeal's population-scaled figure | `pc.an_appeal` (A1); the "not forgotten" reply in E26 becomes it (D5) |
| #474 his good word | his offer at high regard; `pc.ask_for_his_good_word` (A6) |
| #475 a seditious governor elsewhere | extend E45 to towns other than the Diplomat's own (A7) |
| #476 six hooks | N9 his town's protest; N11 a project abandoned; N14 pride in a great building; A10 the loyal neighbour; A11 the investment pitch; retarget E43 to a *fall* in regard (A4) |
| #477 rescoring a site on arrival | `governor.the_ground_has_changed`: find a new site, or keep it (A5) |
| #478 town age, party params, the Crown founding's governor | E1 from the town's month 3; E8/E9 held past the arrival; a report from the road and the sea; E30 for a Crown founding |

Then re-run `tools/post_calendar.gd` over three seeds, and sign off.

#### Rulings (Author)

- **Shipments** settle an open demand for that resource first. The rest is a
  donation, credited at the Crown's price, and the Steward thanks the colony.
  Resources only, never gold (`crown-demands.md` §5, #472). The Steward sheet
  owes ⬜ the thank-you letter.
- **The appeal (A1)** costs gold in proportion to the town's population, paid
  into its purse (`contacts.md` §9, #473).
- **High loyalty (A6): his good word.** A policy that lifts every other contact
  in his town by a flat amount, and ends when the policy ends
  (`policy.md` §7, #474).
- **Low loyalty (A7)** is only his turn to *prepare for rebellion*. The
  Diplomat writes, and the PC answers with `cultivate_governor`. There is no
  other low-loyalty letter (#475).
- **A5: the site is rescored on arrival.** Below 80% of its setting-out score,
  he asks whether to find a new site or keep it (`founding-towns.md` §5, #477).
- **What a new governor writes, and when** (`founding-towns.md` §4, #478):
  - while travelling, only about his party;
  - one arrival letter, which is also his first course;
  - then as any governor, with more than one letter a month if more than one
    thing happens to him;
  - his **seasonal report** every 3 months, from the town's third month.

  A Crown founding elects its governor when it sails and writes the same way.
- **Tuning, not content:** a letter for every finished project stays. How often
  projects finish and shortages bite is the economy's tuning (#373). The
  Steward's tax-rise letter and its governor companion (E7) are timed on the
  Steward's sheet.

#### 1. He writes to the PC — 44 letters

✱ marks a letter added or changed in this audit.

| Code | Letter | Fires when | Replies |
| :--- | :--- | :--- | :--- |
| **His party, before there is a town** | | | |
| E30 ✱ | `setting_out` (must answer) | elected as his party sets out | where to settle: best ground / coast / ore / away from the tribes |
| E34 ✱ | `our_people_were_struck` | his town's expedition was attacked | defences / keep the people home |
| E35 ✱ | `they_have_turned_back` | his town's expedition came home | send them out again / keep them home |
| E36 ✱ | `we_have_arrived` (must answer) | his town was founded; names the intent he has chosen | the four courses |
| **The town's reports** | | | |
| E1 ✱ | `report_month`, the seasonal report | every 3 months, governor with a town | the four courses |
| E2 | `announce_objective` | a new project | the four courses |
| E3 | `report_completed` | a project finished | the four courses |
| E4 | `report_shortage` | stores below a third | the four courses |
| E5 | `report_idle_building` | a building shut for upkeep | profit / grow |
| E6 ✱ | `question_duty` | base duty above 12%, governor with a town | — |
| E7 | `a_rise_would_be_felt` | rides with the Steward's tax-rise letter | — |
| **His intent** | | | |
| E8 | `i_have_settled_on_a_course` (must answer) | intent changed, regard high | carry on / three courses |
| E9 | `the_course_i_must_take` (must answer) | intent changed, regard medium | — |
| E10 | `report_disagreement` | the PC's urging ≠ his intent | the four courses |
| E11 | `i_have_been_pressed` | the Provost pushed his town to education | — |
| E12–15 | `ack_complied` / `_delayed` / `_refused` / `_acted_alone` | answering a PC urging | — |
| **The tribes** | | | |
| E16 | `the_people_next_door` | native pressure on his fields | profit / defences / settle further off / be rid of them |
| E43 ✱ | `they_grow_cold` | the tribe's regard below 35 of 100 | be ready / trade with them / keep to your ground |
| E17 | `a_tribe_has_written` (must answer) | loyal: asks how to answer a tribe's grievance | yield / gift / refuse / threaten |
| E18–21 | `i_answered_the_tribe_*` | disloyal: answered it himself | — |
| E31 | `a_tribe_asks_for_help` (must answer) | loyal: a tribe asks for goods for its troubles abroad | give / refuse |
| E32–33 | `i_answered_their_ask_*` | disloyal: answered it himself | — |
| E22 | `i_have_made_a_bargain` | a trade agreement with a tribe | three courses |
| E37 ✱ | `the_tribe_brought_us_food` | a tribe gave his town food | — |
| E38 ✱ | `they_have_joined_us` | tribesfolk settled in his town | — |
| E39 ✱ | `they_have_stopped_trading` | a tribe ended its trade | defences / find the trade elsewhere |
| **Enemies** | | | |
| E23 | `they_are_on_my_fields` (must answer) | foreign men on his tiles | profit / defences |
| E40 ✱ | `a_duke_is_in_the_rebel_town` | a duke backed a rebel town, regard high | defences / give your people no cause |
| **Remember when** | | | |
| E24 ✱ | `asking_again` | remembers the PC's kindness, stores below half | **send the price of it** / refuse |
| E25 ✱ | `remember_what_i_sent` | remembers **his** kindness to the PC | send gold to the town / refuse |
| E41 ✱ | `you_refused_me` | remembers a refusal, loyalty below 50 | apologise / the answer stands |
| E42 ✱ | `you_gave_your_word` | remembers a broken promise | apologise |
| **Rebellion** | | | |
| E26 ✱ | `nothing_to_report` | his intent is sedition | profit / "not forgotten" (becomes the appeal, #473) |
| E27 | `town_has_declared` (must answer) | his town declared | — |
| E44 ✱ | `our_terms` | his town is in rebellion: the hall's terms | the duty down (to the Steward) / no terms |
| E28 ✱ | `a_neighbour_declared` | another town declared | the duty down (to the Steward) / comfort / walls |
| E29 | `we_are_coming_back` (must answer) | his town returned | — |

#### 2. The PC writes to him — 10 letters

| Code | Letter | Offered to | Does |
| :--- | :--- | :--- | :--- |
| P5 | `urge_a_course` | any governor with a town | the four courses |
| P6 | `encourage_settlers` | any governor with a town | urges go tall |
| P10 ✱ | `send_the_town_gold` | any governor with a town | 100 / 250 / 500 to the town's purse (placeholders) |
| P11 ✱ | `end_a_policy` | anyone holding a policy | ends it, at the cost of his loyalty |
| P1 | `request_shipment` | any governor | goods to the Crown: double / fair / nothing |
| P8 | `demand_the_stores` | any governor | goods to the Crown, buy / part-pay / take |
| P9 | `order_the_quota` | any governor | goods to the Crown, ask / expect / command |
| P2 | `lay_an_embargo` | any governor | the colony stops relieving a rebel town, or lifts it |
| P4 | `send_the_diplomat` | where the Diplomat could go | moves the Diplomat there, 240 gold |
| P7 | `state_a_preference` | the governor of a party on the march | where to settle |
| — | `an_appeal` | — | 🔧 #473 |
| — | `ask_for_his_good_word` | — | 🔧 #474 |

#### 3. What investing in him unlocks

- **Compliance** with urgings and shipments, through regard (`contacts.md` §3).
- **He asks before he acts.** A loyal governor asks how to answer a tribe
  (E17, E31). A disloyal one tells the PC afterwards (E18–21, E32–33).
- **He warns.** A duke in the rebel town next door comes only from a governor
  who thinks well of the PC (E40). He tells the PC his course rather than just
  taking it (E8 against E9).
- **His good word**, the high-loyalty policy: 🔧 #474.

#### 4. What he does at low loyalty

He turns to *prepare for rebellion* (E26). Then:

- his own town's Diplomat writes, `diplomat.his_governor_means_to_leave` (E45 ✱),
  and the PC can answer with `cultivate_governor`;
- for a governor in a town the Diplomat does not live in: 🔧 #475;
- the appeal: 🔧 #473.

#### 5. Remember when

- **His kindness to the PC:** E25 asks a share of it back.
- **The PC's kindness to him:** E24 asks again, and can now be answered yes.
- **The sour half:** a refusal (E41) and a broken word (E42).

#### 6. Defects found

| Code | Defect | |
| :--- | :--- | :--- |
| D1 | The site preference could never be sent | ✅ #454; it also rides E30 now |
| D2 | Two PC shipment letters were never offered | ✅ #454 |
| D3 | E24 could only refuse | ✅ |
| D4 | E29 offered three replies that did nothing | ✅ #451 |
| D5 | E26 had two replies that did nothing | 🟡 one removed; the other becomes the appeal (#473) |
| D6 | E28 asked for "something to tell them" and had no reply | ✅ |
| D7 | A governor could hold no policy | 🔧 #474 |
| D8 | `idle_building` param declares `field`, reads `fallback` | ⬜ dev nit, not ticketed |
| D9 | A governor on the march sent his town's seasonal report | ✅ five triggers need a town |
| D10 | A new town's arrival and its first intent arrived together, both must-answer | 🔧 #478 |
| D11 | A Crown-founded town's governor never introduced himself | 🔧 #478 |
| D12 | The Crown's books never showed what it paid for a shipment | 🔧 #472 |

#### 7. Every idea, and where it went

| Code | Idea | Outcome |
| :--- | :--- | :--- |
| A1 | Win back a disloyal governor, CTJ (Author) | 🔧 #473 |
| A2 | The Provost's library push, the governor's side (Author) | ✅ E11 |
| A3 | "Remember when I did you a favour" (Author) | ✅ E25; sour half E41–42 |
| A4 | Tension rising with the natives (Author) | ✅ E43; 🔧 #476 to fire on a fall |
| A5 | The expedition has arrived and things have changed (Author) | 🔧 #477 |
| A6 | High-loyalty special (Author) | 🔧 #474 his good word |
| A7 | Low-loyalty act (Author) | ✅ ruled; E45 for his own town; 🔧 #475 elsewhere |
| A8 | He proposes a daughter town (PO) | ✅ E8/E9 on a change to go wide |
| A9 | The rebel governor's terms (PO) | ✅ E44 |
| A10 | The loyal neighbour: "do we send them grain?" (PO) | 🔧 #476 |
| A11 | The investment pitch (PO) | 🔧 #476 |
| A12 | "The good ground is theirs" (PO) | ✅ E16 |
| A13 | The expedition mid-course (PO) | ✅ E30 reply and P7; the road report 🔧 #478 |
| A14 | Tall's pride (PO) | 🔧 #476 |
| A15 | "Defend us, or let us defend ourselves" (PO) | ➡ Commander sheet |
| A16 | Unrest spreading from a rebel town, made audible (PO) | ✅ E28 |
| A17 | The two-voice month against the Steward (PO) | ✅ E7 |
| A18 | Tribe war aid (PO) | ✅ #471, E31–33 |
| N1 | The PC urges unprompted | ✅ P5 (#454) |
| N2 | The PC sends a town gold | ✅ P10 |
| N3 | The PC cancels a policy | ✅ P11 |
| N4 | The sour memories | ✅ E41, E42 |
| N5 | His expedition struck or turned back | ✅ E34, E35 |
| N6 | We have arrived | ✅ E36 |
| N7 | The tribe gives, joins, stops trading | ✅ E37–39 |
| N8 | A duke in the rebel town next door | ✅ E40 |
| N9 | His town's trade protest | 🔧 #476 |
| N10 | A successor introduces himself | ✖ `contacts.md` §8: no successors |
| N11 | We cannot finish it | 🔧 #476 |
| N12 | Short-weighting the customs | ✖ superseded by A7 |
| N13 | A standing contribution | ✖ superseded by A6 |
| N14 | Pride in a great building | 🔧 #476 |

#### 8. Simulated post (2026-10-02, `tools/post_calendar.gd`)

Three seeds × 36 months, run once replying to every letter with its first option
and once replying to nothing.

- **Whole colony:** about 3–5 letters a month in years 1–2, and 6–11 in year 3,
  which is inside SPEC §9.6.
- **Months 2–4 are the crowded ones:** 5, 5 and 6 letters, with up to three that
  must be answered. Most come from the Crown officers, and those are timed on
  their own sheets.
- **From the governor:**
  - **month 1:** the seasonal report, from month 3 of the town once #478 lands;
  - **month 2:** a new project;
  - **month 3:** a shortage, plus his companion to the Steward's tax-rise letter;
  - **after that:** roughly one or two a month while there is one town, and more
    as towns are founded.
