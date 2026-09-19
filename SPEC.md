# SPEC — *The Crown Sends Its Best*

> **Owner:** Alan (Author). This file is the source of truth for the game's design. **Status:** v2.0: Under Author ownership, actively being read by PO and Dev

---

## 0\. How to Use This Document

- **This spec describes the game as a whole.** It covers what the game is, how its systems relate, and the rules that must stay true. It does not cover exact numbers, balance values, content lists, or implementation details. Those belong in tickets, data files, and code. Where the spec gives numbers, they are **design targets** for tuning to aim at.  
- **When the spec and a ticket conflict, the spec wins.** If a ticket would break something written here, it gets the `author` label and waits until the Author changes either the spec or the ticket.  
- **Invariants** (marked **🔒**) are rules that must hold for the whole of development. Any feature or mechanic added later must fit inside them.  
- **Only the Author edits this file.** Examples in this document show intent. They are not exhaustive lists.  
- **Section 17 (Open Questions)** lists decisions that haven't been made yet. A ticket must not quietly settle one of them. It goes to the Author instead.

---

## 1\. Elevator Pitch

You are a minor royal, handed a colony in the New World as a consolation title nobody expects you to use. You never leave your comfortable palace. You rule entirely by **letters**: you read reports, answer requests, and send orders across an ocean. Meanwhile the Crown wants more gold every year, the colonists want less taxation, rival empires circle, and the native tribes will not be pushed aside quietly.

*The Crown Sends Its Best* is a **2D narrative-management roguelike** built in Godot, for PC and mobile. It is *Colonization* seen from the far side of the ocean, as a comedy of a pampered aristocrat bumbling through decisions that cost other people dearly.

---

## 2\. Design Pillars

Every feature should serve at least one pillar and break none of them.

1. **Rule by Correspondence.** The desk is the game. The player never moves units, places buildings, or clicks on the world. All influence travels through letters.  
2. **The Squeeze.** The Crown's demands and the colony's tolerance both grow over time. Balancing them gets harder every year, and the run ends when that balance breaks, or when the player decides to get out while he still can.  
3. **Distance.** You are an ocean away. Every exchange of letters takes a month, and the people who carry out your orders can interpret, delay, or ignore them.  
4. **Consequence Without Peril.** The player character is never in danger. Everyone else is. The satire comes from that gap.  
5. **Short, Varied, Committed Runs.** Each run is a new colony with its own map and characters. Decisions are final once the month's post is sent. Losing is expected, and every ending tells a story.

---

## 3\. Setting & Tone

### 3.1 Setting

- The time is the **age of colonialism**, and the Crown is at the peak of its power.  
- **🔒 All factions are fictionalized analogs.** The Crown clearly draws on England, and rivals clearly draw on other European powers, but every name, flag, and faction is invented. Native tribes are invented as well. They are not stand-ins for specific real peoples, but their role mirrors many native people in the age of colonialism.  
- Real-world flavor such as resources, technology level, clothing, and architecture should feel period-appropriate.

### 3.2 Tone: Dry Satire

- The **Crown and its system are the joke.** A colony that holds real lives is handed out as a token title, and it is run from a palace by someone who writes letters in florid courtly style.  
- The PC's letters are written in a formal, period voice. **Their temperament comes from the player's choices** (§5, §9.2).  
- **🔒 The satire targets the empire, not the colonized.** Native tribes and ordinary colonists are never the punchline. Their suffering is shown plainly, and their agency and dignity are respected.  
- **Cutscenes show what the player character never sees:** the battles, the hunger, and what his decisions cost. The palace stays cozy while the world outside does not.  
- The writing is witty and understated. It is never slapstick and never preachy.

---

## 4\. Terminology

The spec uses a small set of words precisely. Most are defined where their mechanic lives; this section says where, so nothing is defined twice. Tickets and code should use these words exactly. Terms that have no home section are defined here.

**Defined here**

| Term | Meaning |
| :---- | :---- |
| **Player** | The real person playing the game. |
| **Player Character (PC)** | The fictional noble the player roleplays as (§5). Where the spec says "the player" it means the person; "the PC" means the character. |
| **Run** | One game, from the starting decisions to the ending. |
| **Turn** | One month, and one round trip of correspondence. |
| **Post** | The letters the player has written and queued during a turn. Sending the post ends the turn. |
| **Crown** | The empire the PC serves: the source of funds, troops, demands, and every trade the colony makes. |
| **Colony** | Everything the PC administers: every town he still holds, loyal or in rebellion, their people, and their lands. |
| **New World** | The region the colony sits in. Inhabited by natives, claimed by the Crown, coveted by rivals. |

**Defined elsewhere**

| Term | Defined in |
| :---- | :---- |
| Border, Influence Area, Vision | §11.2 |
| Building | §11.3 |
| Colonial Forces, Crown Troops | §12.6 |
| Colony Month | §11.3 |
| Commander | §8.6 |
| Contact | §8 |
| Crown Officer | §8.1 |
| Crown Standing | §10.3 |
| Desk | §7, §15 |
| Expedition | §11.4 |
| Fail Condition | §13.1 |
| Governor | §8.2, elected for a new town in §11.4 |
| Immigration | §12.1 |
| Improvement | §11.1 |
| Intent | §8.2 |
| Ledger | §10.4 |
| Lost Town | §12.3 |
| Loyalty | §8.5 |
| Luxury | §10.1, taxed differently in §10.2 |
| Mandate | §6.1 |
| Natives, Tribes | §12.5 |
| Needs | §11.3 |
| Objective | §11.3 |
| Optics | §14.1 |
| Patron | §8.3 |
| Perk, Quirk | §5 |
| Population: Workers, Experts, Livestock | §12.2 |
| Prestige | §14.1 |
| Quality of Life | §11.3 |
| Rebel Sentiment | §12.3 |
| Rebel Town | §12.3 |
| Relief | §11.3 |
| Reserve | §11.3 |
| Resources | §10.1 |
| Retirement | §13.2 |
| Rivals, Dukes | §8.4, §12.4 |
| Stall | §11.3 |
| Tax Rates | §10.2 |
| Tile | §11.1 |
| Town | §11.3 |
| Trade Protest | §10.2 |
| Trust | §12.5 |
| Wants | §11.3 |

**🔒 Terminology is stable.** These words keep these meanings throughout the spec, the tickets, and the code. A ticket that needs a concept not named here goes to the Author.

---

## 5\. The Player Character

- He is a **low-ranking member of the royal family**, given the colony as a token title for the sake of appearances. The post has nothing to do with his ability or with what the Crown needs.  
- **His title and background are flavor.** The player chooses a name and a title for the PC which are referenced in letters to the PC in that run. This is flavor only and has no effect.  
- One **Perk** and any number of **Quirks** are selected which have gameplay modifications that affect the run.   
  - The only unlocked perk from the start is ‘it’s my first day’ which grants an additional warning from the chancellor when the crown standing falls before refusing payments. There are no unlocked quirks at game start.   
  - Each quirk carries both a benefit and a drawback. Completing runs will unlock additional perks and quirks. Each perk is meant to be a pure benefit of the same power level, each quirk is meant to be power-neutral but offers interesting choices and rewards certain playstyles.   
- **🔒 The player supplies the temperament.** The PC has no personality of his own. His character is whatever the player's letters make him: generous or stingy, furious or gracious.  
- **🔒 He never leaves the palace**, and nothing in the game can harm him. Every ending, including game over, sends him into a comfortable retirement.

---

## 6\. Structure of a Run

### 6.1 Run Start

A run opens with a short **introductory cutscene** that sets up the PC's appointment. The player customizes his PC and chooses other presentations that add flavor (such as portrait or colony color) without affecting any mechanics of the run. The player then makes a series of **starting decisions** that shape the colony, not the PC. Examples:

- **Colony site:** a choice among a few generated regions, each with different terrain, native neighbors, and rival proximity.  
- **Mandate:** the Crown's stated goal for the colony, such as profit, a strategic foothold, or settlement. It is the founding governor's starting intent, and it shapes his early objectives. As the run goes on it is increasingly likely to be displaced by an intent born of his own circumstances.  
- **Starting assets:** how the initial grant is split between the town’s population, the town’s gold, and the town’s resources.

Choices unlocked through meta-progression (§14) show up here. Each run is generated from a **seed**.

### 6.2 Difficulty Curve and Run Length (design targets)

- **Year 1 (12 turns):** a sensible player should almost always make it through. This is where the player learns the colony and its contacts.  
- **Year 2 onward:** difficulty ramps up steadily. Crown demands grow, rivals get bolder, natives push back, and taxes start to cause strain. It’s generally impossible to please everyone and keep all your promises by the end of year 2\.   
- **A competent player's typical run lasts 4–8 in-game years.**  
- **Hard cap: 50 years (600 turns).** Reaching it is extraordinary and ends in a forced retirement (§13.2).

### 6.3 Run End

A run ends when either of these happens:

- A **fail condition** triggers (§13.1).  
- The PC **retires**, either by choice or after 50 years (§13.2).

The ending plays an **animated summary** of the run: what the colony became, what the Crown got from it, and a **prestige** score. It closes with an **epitaph**, a short blurb about the PC's fate in retirement.

---

## 7\. The Turn Loop

Each turn is **one month** and represents one exchange of correspondence with the colony.

1. **Date card.** The month and year are shown.  
2. **Opening cutscenes** (optional). These cover major events in the Crown or the colony.  
3. **Map playback.** An animated map shows what happened during the month: borders shift, units move, towns grow, battles resolve. Cutscenes may interrupt it or follow it.  
4. **The desk.** A stack of incoming letters. The player reads each one and responds, or chooses not to. The player may also **compose new letters**, **review and rewrite anything in the outgoing post**, open the **map** or **ledger** at any time, or **retire** (§13.2).  
5. **Send the post.** The player ends the turn once every incoming letter has been dealt with. **🔒 Sending the post commits every decision in it and saves the game.** There is no going back.  
6. **Closing cutscenes** (optional).  
7. **Resolution.** The world simulation runs, and it may trigger a fail condition or the 50-year retirement. Otherwise the next turn begins.

**🔒 Nothing the player writes changes the world instantly.** The world month loop describes in detail how the player’s correspondence affects the world and influences next month’s correspondence. 

**🔒 Only the desk has decisions.** The map, the ledger, and cutscenes show information only.

**🔒 Changes of mind are allowed only within a turn.** Until the post is sent, any outgoing letter can be reopened, rewritten, or discarded. Once sent, it is final.

---

## 8\. Contacts

Every contact has a **name, portrait, role, personality, and loyalty**. Personality affects both the *tone* of their letters and their *behavior*, such as how they read vague orders, what they choose when left to decide, and whether they act on their own.

### 8.1 Crown Officers (fixed)

These five contacts are the same in every run and are **not randomized**. Each one controls key decisions.

| Officer | Role |
| :---- | :---- |
| **Marshal** | Runs the Crown's wars outside the colony. Makes requests of the PC, such as gold, iron, guns, food, or other resources. Can send Crown-loyal troops to the colony on request.  |
| **Chancellor** | Speaks with the Crown's political voice. Issues formal warnings about crown standing and delivers news of defeat. Loyalty to the chancellor begins very low, typically he cherishes giving you news of your failures. |
| **Steward** | Watches the finances. Manages tax rates on the colony. Warns when gold income is negatively affecting crown standing, praises good revenue, and pushes for higher taxes. Reports on trade protests.  |
| **Provost**  | Advises on trade specialization and education. Influences immigration policy and can supply experts. |
| **Diplomat** | Lives in one of the colony's towns and reports on every town, most sharply on his own. He asks to be rehomed when his town turns dangerous or rebellious. He is killed if his town falls to rebellion, and may be killed when enemy attack costs his town population. He is never replaced, and the run continues with no diplomat.  |

### 8.2 Colony Contacts (semi-random)

- **Governors:** one per town, and the main contact for that town's affairs. A governor holds an **Intent**: a standing goal such as growing the town, raising its defenses, increasing its output, or settling a new town. Intent is his, not the town's, and it comes from his personality, his circumstances, the Crown's mandate early in a run, and the PC's letters. An intent can hold for many months while the town works through several objectives under it.  
- **Institutional contacts:** some buildings bring a new contact, such as a church bringing a clergyman or an armory bringing a quartermaster. Each has their own agenda and loyalty.  
- Personalities are **generated semi-randomly** for each run.  
- Colony contacts can change during a run through death, replacement, promotion, or defection.

### 8.3 Patrons (semi-random)

- From time to time the Crown produces a new figure who takes an interest in the colony, such as a merchant, noble, bishop, or scholar.  
- Patrons ask for resources, propose trades, or offer ventures. **Helping them and keeping their loyalty is a major source of prestige** (§14), and working with them can bring help during the run.  
- Patrons come and go and are not permanent.

### 8.4 Rivals (fixed)

- Each of the three rivals has a ‘duke’ who will be your only contact.  
- The relationship is purely adversarial, they covet the land your colony is on, especially if your colony prospers. They will bully you into giving them resources, attack your colony, and mislead you about their intentions.   
- Rivals will not ask for help with other rivals or with natives. They will not offer any of their own resources for any reason. They will either ignore you, make demands, or attack. Accepting their demands may defer the risk of an attack but will never create a peaceful or mutually beneficial relationship. 

### 8.5 Loyalty and Compliance

- **🔒 Your orders are requests.** Whether and how a contact carries out a letter depends on their **loyalty**, **personality**, and **circumstances**.  
- Possible outcomes range from full compliance through partial compliance, delay, and reinterpretation to outright refusal. Contacts may also act on their own and simply inform the PC afterward, especially if their loyalty is low.  
  - Examples: a town close to rebellion ignores an order to stop making guns. A Crown officer ignores a request to lower taxes and announces a decision "on your behalf."  
- The PC's letters raise or lower loyalty over time, so goodwill works like a currency.  
- Costly requests will reduce the contact’s loyalty unless you make it up to them. If you request troops from the Marshal and pay generously, his loyalty will not shrink. If you make a smaller payment or don’t pay anything, it will cost you loyalty.   
- **🔒 Deeds outweigh words.** What the PC grants, refuses, promises, and delivers moves loyalty far more than the tone of his letters (§9.2). Silence has its own effect (§9.3).  
- **🔒 An order reaches the governor's intent, never the town's objective.** The PC can argue for a goal; he cannot name the project, the tile, or the month. Compliance (above) decides how far the governor's intent bends toward the letter; what the town then builds is the governor's to choose.

### 8.6 Commanders (random)

- When granted troops by the marshal, the troops will be led by a commander who may contact you with reports, requests, or seeking a decision about the troops’ objective.

---

## 9\. The Letter System

This is the core of the game.

### 9.1 Incoming Letters

Each letter has:

- **Sender** (a contact) and **type**: report, question, request, demand, warning, news, or offer.  
- **Tone**, which includes the sender's **loyalty** to the PC, the **urgency**, and their **personality**. Tone comes through in the writing and can also appear in presentation, such as the seal, the handwriting, or a smudge.  
- **Content**, generated from the simulation state and templates, so it reflects what is actually happening.  
- **Response options**, if a reply is possible, and their **consequences**.

**🔒 Letters never lie about what has happened.** Every claim a letter makes about the past or present — what was produced, what was attacked, what a town decided, what an officer has done — is true as of last month. No report is stale, and no letter is lost. **Each month's letters acknowledge the decisions sent in last month's post.**

Within that, a sender has room to serve himself:

- **Omission.** A letter may leave out what its sender doesn't know, or what doesn't flatter him. A rival duke may report that "it seems your coastal defenses have been destroyed" without mentioning whose ships destroyed them.  
- **Framing.** Tone, emphasis, speculation, and advice all carry the sender's bias. Two contacts may describe the same event very differently and both be telling the truth.  
- **Broken word.** A statement of intent is not a statement of fact. Rivals, and any contact with low loyalty, may say they will do something and write months later to say they have reconsidered. The PC has no recourse.

**No letter ever states that something happened when it did not, denies something that did, misattributes an act to someone who did not commit it, or reports a false figure.** The player's uncertainty comes from what people will do, not from whether to believe what they have already done — a game where reports can be false is confusing rather than difficult.

### 9.2 Responding

- A reply is written **mad-libs style**: the player fills blanks by choosing from short lists of options, such as *grant / deny / grant partly*, amounts, targets, and conditions.  
- The game assembles those choices into a **flowing, period-style letter** in the PC's voice.  
- **Tone:** not every outgoing letter has a tone. For those that do, **the first blank sets it**, for example *"I am most \[disappointed / furious / curious / delighted…\]"*. That choice writes the letter's opening and shapes the wording of the rest. There is no separate "choose a tone" control. Tone flavors how the recipient reacts but has **only a minor effect on loyalty** compared with what the letter actually grants or promises (§8.5).  
- **🔒 Every choice's mechanical effect can be understood from its wording.** Exact numbers can stay hidden, but the player should never be misled about what they are ordering.  
- **🔒 Target: each letter takes less than a minute** to read and answer.

### 9.3 Not Replying

Choosing not to reply is always an option. Its effect depends on what the letter asked for:

| Letter asks for… | Effect of no reply |
| :---- | :---- |
| **A request** (resources, funds, favors, permission) | Counts as a **rude refusal**. The sender loses loyalty. |
| **A decision** | The sender **decides for themselves**, either at random or in their own interest, depending on personality. The sender will lose loyalty if they asked you for a decision and were ignored. |
| **Nothing** (reports, news) | No penalty. |

### 9.4 Composing New Letters

- The player picks a **contact** and a **purpose**, such as requesting troops, changing a tax, ordering construction, proposing a trade, or encouraging immigration. The letter is then built the same way as a reply.  
- The purposes available depend on the recipient's role and the current game state.

### 9.5 Promises

- Letters can commit the PC to things like paying gold, sending resources, or granting favors.  
- **🔒 Promises are tracked** and carried out automatically while the PC is able to keep them. A broken promise, whether from lack of means or a Crown refusal (§10.3), costs loyalty.

### 9.6 Letter Volume (design targets)

Turns can get tedious if there are too many letters, giving the player too many chores between making a decision and seeing the effects of that decision. 

A typical run will only have so many letters per turn, increasing as the game goes on. Playing wide (building many small towns), or sending many unprompted letters to contacts, can put you in a position where these numbers are exceeded.

| Phase of run | Typical Incoming letters per turn |
| :---- | :---- |
| Early game (year 1-2) | 4–6 |
| Mid game (year 3-5) | 6–12 |
| Late game (year 6+) | 8–20 |

**🔒 The phase of a run is set by the calendar year**, not by the colony's size. The exact year boundaries are a tuning value, set to match the difficulty curve in §6.2. Within each range, volume grows with the colony's size and complexity. 

**🔒 The desk will avoid becoming a chore.** As the colony grows and more crown contacts have more requests, answering letters may start to become tedious, which matches the role of the PC in his world. To keep the game fun, the game will detect when the number of letters is becoming excessive, and reduce the frequency of checkins, or low-loyalty contacts will be more likely to make their own decision rather than ask the player, or other mechanics to reduce the tedium of each turn.

### 9.7 Content Pipeline

- **🔒 Letters are data-driven.** Templates, conditions, options, tones, and effects are defined in data files, not hard-coded, so the Author can add content without engine changes.

---

## 10\. Economy

### 10.1 Resources

- Towns produce, consume, stockpile, buy, and sell resources. Buying or selling resources is a transaction with the crown, and pays the tax rate for that resource. Towns trade resources with other towns and natives, never rivals, with no tax.   
- Raw Resources:   
  - Food. Consumed by town population every month. Stockpiled food contributes positively to a town’s quality of life. Not having enough food to meet the town’s demand negatively impacts quality of life and can reduce population. Towns convert food into ‘beer’   
  - Wood. Consumed by buildings and improvements.   
  - Stone. Consumed by buildings and improvements.   
  - Ore. Towns convert ore into iron  
  - Furs. Towns convert furs into clothing  
  - Cotton. Towns convert cotton into clothing  
  - Sugar. Luxury. Towns consume sugar to improve quality of life. Towns convert sugar into ‘rum’  
  - Tobacco. Luxury. Towns consume tobacco to improve quality of life. Towns convert tobacco into cigars.  
  - Tea. Luxury. The colony will never produce tea \- it must be purchased from the crown.   
- Processed Resources:   
  - Clothing. Made from furs or cotton. Towns consume some clothing based on its population. Increases quality of life.   
  - Iron. Consumed by buildings and improvements. Converts into Tools and Guns.  
  - Rum. Luxury. Consumed to improve quality of life.   
  - Cigars. Luxury. Consumed to improve quality of life.   
  - Beer. Luxury. Consumed to improve quality of life.  
  - Guns. Increases the defense of the town. Allows towns to create soldiers. Especially coveted by natives.   
  - Tools. Consumed by buildings and improvements. Especially coveted by natives.   
- Livestock Population can be traded the same way as resources, paying a ‘livestock’ tax rate when exchanging them with the crown for gold. Workers and Experts never involve a gold exchange with a town so they have no tax rate.  
- Consumption of luxury resources increase a town’s quality of life. The colony reacts to taxes on luxury resources differently than other resources . 

### 10.2 Taxes and Gold

- **🔒 The player’s gold is not a simple wallet.** The player never manages a single balance that just has to stay positive. The crown spends gold to honor the player’s promises. (§10.3).   
- Towns **buy from and sell to the Crown**, and both kinds of trade **generate tax income** for the crown.  
- Towns have a balance of gold hidden from the player, representing the sum of all its population’s wealth. The town never trades gold with natives or other towns. The town will spend gold to buy resources from the crown to meet its objectives and improve its quality of life. Towns earn gold by selling resources to the crown.   
- **Tax structure:**  
  - **One base rate** applies to all resources across the whole colony.  
  - **Per-resource rates** can override the base rate for specific resources, also colony-wide.  
  - There are **no per-town rates**.  
  - The steward will follow your instruction about adjusting tax rates, and offer his advice with his bias (he prefers high taxes)  
  - When loyalty is low and you are doing something he does not advice, he may delay, but he will not outright refuse to follow your instruction while your crown standing is still paying your debts.  
  - If your crown standing is lost and the steward’s loyalty is low, he may unilaterally raise taxes and inform you after the fact, ignoring your input.   
- When non-luxury resources are taxed, colonists will spend the same amount of money, and receive less of the resource, which gives the town fewer resources to work with. Towns increase rebel sentiment as they pay taxes on these resources. When **luxury resources** are taxed, there is much less rebel sentiment as a result, but the town will spend less money on the resources. This reflects that they can more easily go without luxury resources than other resources.  
- When a town decides to do so, they will hold a trade protest. They decide based on  
  - The rebel sentiment of the town  
  - The governor’s loyalty and temperament.  
  - The town’s quality of life.  
  - The tax rate of this particular resource. Trade protests are increasingly likely in response to a tax increase.  
  - Whether or not it’s a luxury resource (luxury resources are more likely to trigger a trade protest since the town can do without it more easily)  
  - The number of existing trade protests to ensure that you will only get one trade protest at a time, and only continued pressure on the town would cause them to have another trade protest on a later turn.  
  - Mechanically, ‘tea’ is favored to be one of the first trade protests likely to happen, but this is by nature of its mechanics and not hardcoded priority.  
- The story is that when the crown’s merchant ship docks in town, the crown informs them of the new tax rate, and instead of accepting the tax increase, the town will refuse to buy/sell in that resource.  
- Each trade protest is scoped to one town and one resource. It costs you prestige and the potential tax income from trading in that resource, plus the town suffers from its hindered ability to trade.    
- Trade protests are lifted when the above calculation falls below a threshold. Trade protests are more likely to lift in response to a tax decrease.  
- Contacts from the Crown will regularly demand **gold**. Demands grow over time. Meeting or missing them affects Crown Standing and the loyalty of your crown contacts.

### 10.3 Crown Standing ("a bottomless pit until it isn't")

- Early in a run, the Crown pays whatever the PC promises, and the treasury looks limitless.  
- Behind the scenes, **Crown Standing** tracks the colony's financial record: revenue against spending, and demands met against demands missed.  
- When standing begins to fall, the **Steward** warns the PC and makes suggestions to help. When it has reached a breaking point, the **Chancellor** will issue a final warning to the PC. If it falls further, the Crown **refuses all payments**, and promises made in the PC's letters get broken. The Crown resumes honoring payments once standing recovers.  
- **🔒 The player always gets the Chancellor’s warning before the Crown first refuses to honor the player’s promised gold.** The player has many chances to promise gold through letters (accepting a clergyman’s request for charity, requesting troops from the marshal, enacting an expensive policy through the provost, etc), and these all affect your crown standing the same way. 

### 10.4 The Ledger

- The ledger shows every transaction of gold between the colony and the crown, with a total listed per month. Each page of the ledger shows a different month.   
- Scrolling to the first page of the ledger shows a graph where the X axis is the month, showing the total in / out to the crown for each month, allowing the player to see trends.

---

## 11\. The World

### 11.1 Map

- The New World is shown as a **2D tile grid** of land and sea tiles. Each tile has terrain and yield potential.  
- Tile types:   
  - Desert. Low food and ore. Medium stone.  
  - Grassland. Medium food, medium furs, low wood, low stone.   
  - Plains. High food, low furs, low wood, low stone.  
  - Forest. High wood, high furs, low food, low stone.  
  - Mountains. High stone, high ore, low furs, low wood.  
  - Sea. High food, nothing else.   
  - Ocean. Low food, nothing else.  
- Improvements can sit on tiles and may be built by towns, crown commanders, rivals, or natives.  
  - Farm. Towns or natives will build a farm. Increases the food yield of that tile and decreases the yield of all other resources. Best on plains. Decent on grassland.  
  - Pasture. Supports a number of livestock so they do not require food and grow in population faster. Best on grassland. Decent on plains or forest. Reduces all yields.  
  - Plantation. Three types, sugar, cotton, tobacco. Towns will build a plantation of a type according to its objective. Plantations introduce a yield of the typed resource and retain the food yield of that tile, eliminating all other yields. Best on grassland or plains.  
  - Mine. Towns will build a mine to increase the stone yield of that tile, introduce ore yield, and will not yield any other resources. Best on mountains, decent anywhere else.  
  - Road. Roads will be built naturally (requiring no resources or effort) connecting towns with frequent trading partners. Roads slightly increase yields and increase army movements.  
  - Fort. Forts are built by towns, crown commanders, and rivals. Fort is the only improvement rivals will build. Natives never build forts. Forts strongly increase the combat bonus of units on the tile that contains a fort. Does not affect yield.  
- Each run generates its map from the seed.

### 11.2 Borders, Influence, and Vision

- **Colony border:** the area the colony's soldiers patrol. The PC gets reports of events inside it.  
- **Vision:** reaches slightly past the border. Areas outside vision are unexplored or shown as last seen.  
- **Town influence area:** where a town works tiles and where its defenses apply.  
- **🔒 The map only shows what the colony knows.**

### 11.3 Towns

Each town has:

- **Population:** workers, experts, and livestock.  
- **Stockpile** of resources.  
- **Balance** of gold, not visible to the player but added/subtracted as the town buys/sells resources to the crown. This represents the sum of the citizens’ private wealth, plus the town’s coffers, figuring that buying resources is a mix of private citizens, private business owners, and the town’s government trading with the crown.   
- **Buildings.** The town can set its objective toward a specific building. There will be a ‘tree’ of buildings that unlock other buildings and have a static resource cost and effect.  
- **Rebel sentiment.**  
- **Quality of Life.** This is influenced by many factors and represents how pleasant or miserable the average citizen’s life is. The governor will want a high quality of life.  
- **Current objective,** such as building a church, stockpiling food, harvesting resources, or fortifying.  
- **A governor** (§8.2).

**Intent and Objective.** The governor's intent is the goal; the town's objective is the project. Each month, if the town has no objective — because the last one completed or stalled, or because the governor's intent changed — the governor **selects the objective that best serves his intent** given the state of the town and the world around it. That selection is deterministic and competent: he has advisors, and he picks well.

- An objective is specific, and names its target: build a church, build a farm on a particular tile, raise a militia, fortify a particular tile, amass resources for an expedition. **The governor chooses the tile**, never the PC.  
- An intent of "increase economic output" might produce a plantation this year and a dock the next. The intent did not change; the best way to serve it did.  
- **🔒 An intent might not serve the town's welfare.** A governor bent on driving off a tribe will pursue that at his people's expense. This is his to judge and the PC's to argue with.

**Reconsideration.** A town holds its objective until it completes or **stalls** — the governor judges it can no longer be advanced, as when a militia needs guns the town can no longer forge. The stall check runs every month and is deterministic, not a matter of temperament: a governor who has not stalled does not waver.

**The Colony Month.** The month resolves in phases. **🔒 Every town completes a phase before any town begins the next**, and every choice in a phase is made from the colony's state as it stood when that phase began. No town benefits from being simulated first, and ties are broken by a rule fixed by the seed.

1. **Work.** Each town assigns its population between **working tiles** in its influence area and **converting** raw resources into processed ones (§10.1). Tile assignment is chosen by its objective, each tile's potential, and what the town needs; yields go into the stockpile. A worker is in the fields or in the town, never both, so every conversion costs a worked tile. Conversion draws on the stockpile as it stood at the start of the month.  
2. **Reckon.** Each town works out, in priority order, what it must have, what its objective requires, and what it would like:  
   1. **Needs** are what survival demands: food, clothing. The citizens will meet these with the town's gold whatever the governor wants.  
   2. **The objective** comes next: the resources the town's current project requires (§11.3, Intent and Objective). This is the tier the governor directs.  
   3. **Wants** are discretionary comforts bought with what's left: luxuries, and anything that lifts quality of life without serving the objective.  
3. **Relief.** Towns holding more than their reserve give to towns in deficit, free and expecting nothing in return. Need is served worst-first, and needs come before wants. A town who repeatedly gives more than it receives resents the crown for its mismanagement. Towns trade resources without any loss or delay. Towns will not give luxury resources as relief.   
4. **Exchange.** Each town covers what it still lacks, first by trading with natives, then by buying from the Crown, which is taxed. It also buys to improve quality of life and to advance its objective. (exceptions: towns will enforce their trade protests, and rebelling towns will not trade with the crown)  
5. **Consume.** Population and livestock eat. Clothing and luxuries are used. Shortages hurt quality of life and can cost population.  
6. **Build.** The objective advances, consuming resources, and may complete.  
7. **Sell.** Surplus above the reserve is sold to the Crown, which is taxed. (same exceptions as step 4\)  
8. **Settle.** Quality of life, population, and rebel sentiment update, and the town may take a new objective.

**🔒 Needs, then the objective, then wants.** A town covers survival before it spends on its project, and its project before it spends on comforts. A town typically keeps a reserve before it sells anything to the Crown.

**🔒 Towns run themselves** under leadership of the Governor. The PC shapes things through letters to the Governor (setting intent and policies, and sending resources) but never manages them directly. The governor has authority over what the town actually does, not the player. 

### 11.4 Founding Towns

Going wide or going tall is one of the run's defining choices.

- **Who proposes.** A governor may propose a daughter town when his own is crowded or a good site is known. The PC may ask a governor to found one by letter. A Crown figure or patron may press one on the colony — settlers, dissenters, or a venture.  
- **A new town brings a new governor.** The Governor is elected from the populace that sets out to found the town, the PC has no say in who the governor will be. As soon as the governor is elected he will send a letter to the PC. The governor stays with the expedition and the town.   
- **🔒 The PC never chooses a tile.** He approves, refuses, or states preferences: toward the coast, near the ore, away from the tribes. The governor of the new town chooses the site.  
- **The new town needs supplies.** The expedition takes workers, food, tools, and sometimes livestock or experts to found the new town. These are given by the parent town, and/or provided by the crown, depending on how the founding was proposed and what promises the PC can deliver.  
- **Founding takes months.** The expedition crosses the map to its site and can be attacked, turned back, delayed, or if conditions are especially hostile, lost completely. Cutscenes cover its fate.  
- **A new town begins fragile:** no buildings, a thin stockpile, low population, low quality of life.   
- **The colony grows, which can offend natives.** Founding near or beyond native land offends nearby tribes in proportion to the intrusion. A new town extends the colony's border and vision.  
- **Rebel towns never found towns.** They are too concerned about fighting the crown to worry about long term colony growth.  
- There is no cap on number of towns. The natural forces of growth and conflict prevent snowballing to an extreme number of towns. Expansion is checked by the people it displaces, not by the discontent of the towns already held.

---

## 12\. Population, Rebellion, and Conflict

### 12.1 Population Growth

- **Immigration** is the main source of growth in the early game, and will arrive at towns with some supplies and gold, and immediately join the colony. A town does not pay for immigrants. How many immigrants arrive depends on the town’s quality of life, the crown’s circumstances, and the PC's efforts to encourage or discourage immigration. The Provost influences immigration policy. Immigrants can include livestock or experts, also shaped by policy.  
- **Natural growth** comes from births. It starts slowly but grows with population and can snowball.

### 12.2 Types of population

A town tracks three distinct types of population

- **Workers** are the bulk of the town’s population and determine how many tiles the town can work.   
- **Experts** come in as many types as there are resources that can be produced in the colony. Each expert increases all of a town’s yield of that particular resource, including processed resources. A town can have multiple experts of a single resource which is more effective than a single expert, but stacking experts has diminishing returns.  
- **Livestock** come in three types. Each pasture supports up to a certain number of livestock, any unsupported livestock consume food. Livestock can be converted into food if a town chooses to do so, which it will when a town would otherwise go hungry. Livestock are similar to a resource in that they can be traded.  
  - Cows produce food and increase quality of life.   
  - Sheep produce furs and increase quality of life  
  - Horses enhance a town’s militia and are coveted by natives and the crown marshal. 


### 12.3 Rebel Sentiment and Rebellion

- **Rebel sentiment is tracked for each town.**  
- **Raised by:** taxes (especially on non-luxuries), shortages, harsh orders, broken promises, military abuses, neglect, and **development itself** — a town with more buildings, more trade, and more people of standing carries more sentiment than a hamlet.  
- **Lowered by:** meeting needs, lower taxes, investment, favors to loyal contacts, and defeats suffered at the hands of crown troops.  
- **Individual towns rebel.** Past a threshold, a single town declares rebellion and stops obeying the PC.  
- **A rebel town is still part of the colony.** In the Crown's eyes it still belongs to the PC. Its people are misbehaving, and the PC's job is to bring them back into line. This is different from a **lost town**, which rivals or natives have destroyed or taken and which no longer belongs to the colony.  
- **Governors of Rebel towns have no loyalty to the crown.** Rebellion is a declaration of war on the PC. A rebel town handles its own diplomacy and defense: it can fight rivals and natives, rivals can court it, and rivals or natives can conquer it, which turns it into a lost town. The PC can continue to exchange letters with the Governor but will get no cooperation while the town continues to rebel. They want the crown gone.   
- **Rebellion spreads.** A rebel town **strongly raises sentiment in the other towns**, especially while it looks prosperous and unpunished. Loyal towns won't keep paying taxes while a neighbor refuses them and suffers nothing for it.  
- **Rebelling towns and loyal towns still cooperate**. They will continue to share resources to contribute to each others’ objectives.   
- **Rebelling towns refuse the crown’s presence**. That means they will fight your commanders’ troops, they put your diplomat in danger, and they will not trade with the crown.  
- **🔒 A rebellion never stays put.** Once a town rebels, the PC either stamps it out or watches it spread.  
- **🔒 Colonists do not fight colonists.**  
  - Rebel towns **fight the Crown's forces**, as well as any rivals or natives they end up at war with.  
  - Rebel towns **do not attack loyal towns or their people**.  
  - Loyal colonists will pay taxes, but they **will not take up arms against other colonists**. Suppressing a rebellion by force therefore depends on **Crown troops**, supplied by the Marshal.  
- **Winning towns back.** The PC has three broad approaches:  
  - **Force:** retaking the town with Crown troops.  
  - **Punishment:** discouraging rebellion with embargoes, penalties, and making an example of the town.  
  - **Reward and persuasion:** encouraging loyalty with concessions, investment, favors, and public relations.  
- **🔒 Rebel towns can return peacefully.** A rebel town goes back to the Crown on its own once its people believe life was better under the Crown, or would be better if they returned.  
- **🔒 Sentiment measures who is blamed, not how bad life is.** Suffering the Crown caused raises it; suffering the rebellion caused lowers it. Battle losses at the hands of the Crown is damage only a rebelling town can incur, so the people blame the rebellion.   
- If every town rebels and the Crown will send no more troops, the result is the **Independence** fail condition (§13.1).

### 12.4 Rivals

- **There are three rival empires in every run.**  
- They are territorial and aggressive, and their pressure **grows as a run goes on**.  
- They expand, compete for land and natives, raid, and eventually attack.  
- The Crown's wars with rivals elsewhere, run by the Marshal, affect the colony through troop availability, demands, and treaties.

### 12.5 Natives

- **There are three native tribes in every run.**  
- They hold land and act on their own interests. They trade, ally, resist, and retaliate.  
- **Confrontation is inevitable**, and how it plays out is decided by the governors of the towns that interact with them. Your letters to these governors can influence these interactions.   
- **🔒 Natives are full actors in the simulation** with their own goals, not obstacles on the map.  
- Each of the three native tribes has an invisible ‘trust’ value representing their attitude toward the colony as a whole. They generally want a peaceful coexistence with your colony, but will be offended by your continued expansion and exploitation of the land, and trust can be permanently broken by aggressive behavior from any colonists.   
- Colony contacts will report about the native's behavior from their own lens, leaving the inner workings of the tribe mostly invisible to the player.   
- Tribes with high trust may provide experts, resources, or troops to the colony.   
- Native tribes manage their own diplomacy with your rivals and with other native tribes, and they may ask governors for resources to assist in their war efforts. Governors may ask you how to respond to these requests

### 12.6 Military

- **Colonial forces** are militia and garrisons raised by and supplied by the towns. They defend against rivals and natives, but not against other colonists (§12.3). Colonial forces can be supplemented by friendly natives. Once a town rebels, all their forces become hostile to the crown’s forces.   
- **Crown troops** are loyal to the Crown and requested from the Marshal. They are the only force that will fight rebels. When you are unwilling/unable to pay the marshal to fund the troops, and the circumstances/loyalty of the Marshal are such that he is unwilling to send you free troops, your request for troops will be denied.   
- **🔒 The PC never commands battles.** He sets goals and allocates forces by letter, and commanders and governors carry out the orders their own way. Battles are resolved by the simulation and shown on the map and in cutscenes.  
- Crown troops may refuse orders that go against Crown interests.

---

## 13\. Endings

### 13.1 Fail Conditions

| Condition | Trigger | Meaning |
| :---- | :---- | :---- |
| **Colony Overrun** | Every town has been destroyed or taken by rivals and/or natives, so no towns remain (loyal or rebel), and the Crown will commit no more resources to retake them. | The colony was too small, too weak, or not profitable enough to be worth saving. The ending names who overran it. |
| **Independence** | At least one town remains, **every** remaining town is in rebellion, **and** the Crown refuses to send more troops to put it down. | The colony becomes an independent nation. |

**How to tell the endings apart:** count only the towns the colony still holds, whether loyal or rebel. Lost towns don't count.

- If none remain, the ending is **Colony Overrun**.  
- If some remain and all of them are rebelling, the ending is **Independence** (provided the Crown refuses troops).  
- As long as at least one loyal town remains, neither ending applies.   
    
  *Example:* the colony has 5 towns, and 2 rebel. Rivals take a loyal town, leaving 4 held towns, 2 of them rebel. Natives take one loyal town and one rebel town, leaving 2 held towns, 1 of them rebel. Rivals take the last loyal town, leaving 1 held town, which is in rebellion. From here:  
  - if the rebel town is conquered by natives or rivals, the ending is **Colony Overrun**;  
  - if the town keeps rebelling and the Crown refuses troops, the ending is **Independence**.  
- **🔒 Every fail condition goes through a "last chance" stage first.** The colony is lost, or in open revolt, while the Crown still supports recovery, and the Chancellor has formally warned the PC. Defeat is never a surprise.  
    
- The **Chancellor** delivers the news of final defeat.  
    
- New fail conditions can be added later, as long as they follow this pattern.

### 13.2 Retirement

- **Voluntary:** the player can retire **at any time from the desk**. This ends the run and scores prestige based on the current state. Retiring from a losing position can earn **more prestige than hanging on** while gold and goodwill drain away.  
- **Forced:** after **50 years**, the PC is retired automatically. Balancing everyone's needs for 600 turns is extraordinarily hard, so this is normally a very prestigious ending.  
- **🔒 Prestige reflects the Crown's current view of the PC,** so it can fall as well as rise during a run. That is what makes choosing when to retire a real strategic decision.

---

## 14\. Scoring and Meta-Progression

### 14.1 Prestige

- **🔒 Prestige measures only how the Crown benefits from the colony, not how the colonists fared.** Nobody at court cares how the colonists fared. Prestige comes from:  
  - **Patrons:** helping them and keeping their loyalty.  
  - **Gold:** the PC's financial contribution to the Crown. How this is measured is deferred until the gold model is designed (§17).  
  - **Optics**: Public perception of the crown is important to people way above your pay grade. Trade protests, rebellion, paying tribute to a rival, being defeated by natives or rivals, all make the crown look bad and will become prestige penalties in the final score.   
- How the run ended, whether by retirement or by a fail condition, affects the final score and the epitaph.  
- Prestige is measurable at any point in the game before retirement, and some contacts will change what they ask of you or how they respond based on your prestige (especially patrons) 

### 14.2 End-of-Run Summary

- The summary animates the run's accomplishments and turns them into prestige and an **epitaph**.

### 14.3 Meta-Progression

- Runs that hit a certain level of prestige and/or meet certain requirements **unlock new options**, such as starting choices, colony sites, mandates, and content.  
- **🔒 Unlocks add variety, not power.** A veteran's run is not strictly stronger than a new player's.  
- A **hall of records** of past runs and their epitaphs is part of the meta layer.

---

## 15\. Screens & UI

| Screen | Purpose |
| :---- | :---- |
| **Main Menu** | Start a new run, continue the run in progress, open options, and see version info. The options and save-management screens share a single UI. |
| **Run Setup** | Make the starting decisions (§6.1). |
| **Cutscene** | A large image, music and sound, and text on part of the screen. The only input is *advance*, which may change the text, image, or sound. Cutscenes may show things the PC could never see. |
| **Map** | A 2D view of the known New World. It plays back each month's events at the start of a turn and can be browsed freely during the desk phase. Read-only. |
| **Ledger** | Optional. Shows data about the trades between the crown and the colony. |
| **Desk** | The main screen. It holds the incoming letter stack and the outgoing post, where the player reads, replies, composes, and rewrites letters. It also gives access to the map and ledger, and has controls to **send the post** and **retire**. |
| **End-of-Run Summary** | Animated recap, prestige, and epitaph. |

**UI invariants:**

- **🔒 Every screen works with touch and with mouse and keyboard.** Mobile is fully supported, not an afterthought.  
- **🔒 Text is the main medium.** Text must be readable at mobile sizes, and letters must be comfortable to read at length.  
- **🔒 Irreversible actions are confirmed.** Sending the post and retiring both ask the player to confirm.

---

## 16\. Platform, Technology & Production

### 16.1 Technology

- **Engine:** Godot 4\.  
- **Platforms:** PC and mobile.  
- **Presentation:** 2D graphics, music, and sound.  
- **🔒 Seeded generation.** Each run comes from a seed, so the same seed with the same choices always produces the same run, which helps with debugging and balancing.  
- **🔒 Content is data-driven.** Letters, contacts, personalities, resources, buildings, and events live in data files.

### 16.2 Saving (Ironman)

- **🔒 Every run is ironman.** There is one save per run, and there is no loading of earlier states.  
- **The game saves automatically when the post is sent.**  
- **Suspend and resume:** the player can quit at any time and continue later. A turn in progress, including its outgoing post, is kept.  
- **Within a turn, the player can change his mind** by rewriting outgoing letters (§7). Once the post is sent, those decisions are permanent.

### 16.3 Assets

- The Author supplies final art, music, and sound **later**.  
- **🔒 All assets are loaded through replaceable references.** Development uses placeholders and stubs, and swapping in final assets must not require code changes.

### 16.4 Development Process

**Roles**

- **Author (Alan):** owns the vision and this spec. Communicates through prompts, GitHub issues, and issue comments. **Only the Author edits SPEC.md.**  
- **PO (agent):** reads the spec and the Author's input, then creates **lean GitHub issues with acceptance criteria**, applies labels, and organizes work into milestones. Works closely with the Author to refine the game.  
- **Dev (agent):** picks up unblocked issues, reads the spec and the ticket, and builds the feature. Makes reasonable assumptions where needed. The Author rarely works with the Dev directly and doesn't need implementation details.

**Labels**

- `author`: the ticket conflicts with the spec or needs a decision from the Author. The Author must change the spec or the ticket before work goes ahead. Whoever applies the label also comments on the issue to explain why.  
- `blocked`: depends on another unfinished issue.

**Milestones**

- Work is grouped into **phases** as GitHub milestones.

**Rules**

- A Dev who finds a conflict between a ticket and the spec applies `author`, comments, and **does not build** the conflicting part.  
- Tickets must not settle **Open Questions** (§17) on their own.  
- Assumptions a Dev makes are recorded in the pull request or issue comment.

---

## 17\. Open Questions

These are for the Author to settle. Once decided, move the answer into the relevant section.

1. **Deferred: gold's share of prestige.** The details of how the PC's financial contribution translates to prestige must wait until the gold / crown standing models are stable.

---

## 18\. Non-Goals

- Direct control of units, tiles, or town management.  
- Real-time gameplay. The game is strictly turn-based.  
- Tactical battle screens.  
- Multiplayer.  
- Loading earlier saves or undoing a sent post.  
- Scoring the colony's own welfare or productivity.  
- A historically accurate simulation of any real colony, nation, or people.  
- Scenes or locations with the PC outside the palace.

