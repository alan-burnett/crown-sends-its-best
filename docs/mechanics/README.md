# Mechanics

The numbers and formulas `SPEC.md` deliberately leaves out.

**The PO owns these. Devs read them; devs do not edit them.** If a mechanics doc
contradicts the spec, **the spec wins** and the ticket gets the `author` label.

They are living documents. Expect them to be reworked after playtesting — that is
the point of keeping them out of the spec, so the spec can stay true without
being rewritten every iteration.

## Written

| Doc | What it covers | First needed |
| :--- | :--- | :--- |
| [perception.md](perception.md) | How a truthful number becomes a biased word | M1 |
| [deliberation.md](deliberation.md) | One kernel for every decision an actor makes | M1 |
| [world-month.md](world-month.md) | The nine phases, and the timing rule | M1 |
| [quality-of-life.md](quality-of-life.md) | How pleasant or miserable a town's life is | M2 |
| [governor-objectives.md](governor-objectives.md) | Intent, objectives, and who decides which | M2 |
| [town-economy.md](town-economy.md) | Prices, reserve, buying, and working the tiles | M2 |
| [crown-standing.md](crown-standing.md) | The bottomless pit, and when it stops being one | M3 |

## Still to write

In roughly the order they are needed.

| Mechanic | Why it is not written | First needed |
| :--- | :--- | :--- |
| **Production and conversion** | Deferred by the Author as a larger mechanic: tiles, improvements, building bonuses, experts, and the split of labour between fields and town. **M2 needs a minimal version regardless, because clothing is a need.** Conversion competing with tile work is settled. | M2 |
| **Policy** | A third category of order, alongside intent and objectives — a standing instruction about how a town or an officer conducts itself. "Stop producing rum." "Treat the tribe gently." Named in SPEC §11.3 and §9.4, defined nowhere, absent from §4. **Stub as a no-op until defined.** | M3 |
| **Rebel sentiment** | The colony-side jaw of the Squeeze, opposite crown standing. Inputs are listed in §12.3; there is no model. Carries a threshold, a spread mechanism, a last-chance stage, and a peaceful-return condition. | M3 |
| **Trade protests** | §10.2 lists six inputs, unusually complete. Mostly a formula rather than a design conversation. | M3 |
| **Crown demand growth** | §10.2 says demands grow over time and nothing else. One curve, but it is what makes year five harder than year two. | M3 |
| **Immigration** | §12.1 names the inputs. Reads quality of life, which is written. | M4 |
| **Founding and expeditions** | §11.4 is detailed on intent, silent on numbers. | M4 |
| **Native trust** | §12.5 gives tribes an invisible trust value and their own diplomacy. | M5 |
| **Rival pressure** | §12.4 says pressure grows as a run goes on. | M5 |
| **Battles** | Deferred by the Author. §12.6 says the simulation resolves them and nothing more. | M6 |
| **Prestige** | Gated on SPEC §17 and on crown standing stabilising in playtest. | M3+ |
