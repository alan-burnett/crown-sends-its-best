# Mechanics — Policy

> **Owner:** PO. Living document, expected to be reworked after playtesting.
> Devs implement from this; devs do not edit it. If this doc ever contradicts
> SPEC.md, the spec wins and the ticket gets the `author` label.
>
> **Serves:** SPEC §11.3 ("setting intent and policies"), §9.4, §12.5, §8.3,
> §10.3, and the Squeeze pillar.
>
> **Needs a SPEC §4 entry.** Policy is named in three sections and defined in
> none.

---

## 1. What a policy is

The world runs on people acting in their own interests. Governors serve their
towns, officers serve the Crown, tribes serve themselves, and none of them is
much interested in what suits the PC.

> **A policy is how the Crown puts its thumb on the scale.**

The Crown offers every settler bound for your colony supplies and gold. Nobody's
nature changed; the arithmetic did, and more of them come. That costs somebody
money every month for as long as it runs.

### What separates it from an intent

Both persist, so the line has to be drawn somewhere precise:

> **A policy has an ongoing cost that somebody pays every month.**

Urging a governor's intent changes a standing goal and costs nothing thereafter.
A policy bills you for as long as it stands, and **who bears that bill is the
whole of the mechanic**.

**Tax rates are technically policy and are deliberately kept separate.** They
have their own machinery in SPEC §10.2 and nothing here applies to them.

## 2. The shape

| Part | What it is |
| :--- | :--- |
| **Enactor** | The contact who puts his name to it |
| **Effect** | An ongoing change to how the world behaves |
| **Cost** | A monthly charge, for as long as it stands |
| **Split** | How much of that charge the PC agreed to bear |

## 3. Paying for it

When the PC asks for a policy, he says what he will pay: **all of it, half of
it, or none of it.** The enactor then decides whether he will wear the rest, and
that decision runs through compliance like any other — his loyalty, his
circumstances, his temperament.

### The policy always works at full strength

**Paying less never weakens the effect.** The policy does exactly what it does;
the shortfall is borne by the contact, in loyalty, every month.

That is the important design choice. Underpaying is not a value-for-money
calculation, it is **a decision about a relationship** — the PC is asking a man
to carry something for him, indefinitely, and finding out later what that cost.

### Paying nothing costs three times paying half

Not twice. **Three times.**

| The PC pays | Monthly loyalty drain on the enactor |
| :--- | :--- |
| All of it | none |
| Half | `X` |
| None | `3X` |

The curve is deliberately not linear in the unpaid share. **People want to feel
you are working with them**, and a PC who contributes something — even plainly
not enough — is treated very differently from one who contributes nothing and
expects the thing done anyway.

This is the cheapest lesson in the game: half is far better than nothing, and it
costs half.

## 4. Renegotiation

A policy the PC is not paying for drains its enactor every month, and eventually
he will not carry it further.

**He writes before it ends.** Something to the effect of *we shall have to let
this lapse unless you begin to bear your share.* The PC's reply can raise his
contribution — and it should also be able to attach **a lump sum on top**, to
soothe the thing over. Everybody loves a bribe, and a letter that offers one
reads very differently from a letter that merely concedes a point.

**The warning always comes before the ending.** The same principle as the
Chancellor's deadline in `crown-standing.md`: a cost the player cannot see coming
is a trap, not a decision.

## 5. When the Crown stops paying

Crown Standing reaching `REFUSING` stops the PC's gold. **Every policy he was
funding is then in the same position as if he had written to each enactor saying
he would now pay nothing.**

So it is not a silent collapse. It is a **renegotiation with every one of them at
once**, and each decides for himself:

- **He accepts.** *Your draft was returned unpaid. I shall cover it from here.*
- **He refuses.** *Your draft was returned unpaid. The committee's funds will not
  last past the autumn.* — which ends the policy, on a stated deadline, with time
  to act.

Either way **he writes**, and either way the PC learns his cheque bounced.

The consequence is worth stating plainly, because it is one of the best things
loyalty does:

> **Your policies survive in proportion to how well you have treated people.**

A PC who has been generous for years finds half his apparatus carried by men
willing to cover for him. A PC who has squeezed everyone finds it all unwinds in
a season, at the exact moment he can least afford it.

## 6. Cancelling

The PC may end a policy he asked for. **It costs loyalty.**

The enactor put his name to the thing. Men are appointed and dismissed over
these, and calling it off makes him look like a fool in front of people whose
opinion he minds a great deal more than he minds the PC's.

## 7. Who can hold one, and who proposes it

**Any contact**, within whatever his position lets him reach.

| Contact | The kind of thing he can put his thumb on |
| :--- | :--- |
| A Crown officer | Military presence in the colony, immigration, education |
| A patron | Whatever his **specialty** is (§8) |
| A governor | How his own town conducts itself — what it makes, how it treats a tribe |
| A rival duke | **Never.** See below |

### Rivals never

**A rival duke enacts no policy, and cannot be hired to.** Paying one to attack a
tribe or a rebelling town is an appealing idea, and SPEC §8.4 forbids it: rivals
"will either ignore you, make demands, or attack," and accepting their demands
"will never create a peaceful or mutually beneficial relationship." Hiring a man
is mutual benefit. The spec wins.

A rival may still end up **allied with a rebelling town** — SPEC §12.3 has rebel
towns handling their own diplomacy and says plainly that "rivals can court it."
That is not a policy and it is not a favour to the PC. It is two of his problems
finding each other, and it is still an alliance **against him**.

**Either party may propose.** The PC writes asking for a policy, or a contact
writes offering one — SPEC §8.3 already has patrons proposing trades and offering
ventures, and this is what that looks like when it persists.

Those are two very different letters. **A request the PC composes is a plan. An
offer arriving on the desk is an opportunity**, and it comes with somebody else's
reasons attached.

## 8. Policies move the world, including its prices

A patron is generated with a **specialty**. One whose specialty is horses can be
persuaded to have his Barony stop buying from its neighbour and buy from your
colony instead.

The game expresses that as **the Crown's price for horses going up.**

Which is why `town-economy.md` §1 makes every faction's valuations a *function*
rather than a constant table. That shape was built for harvest failures; **policy
turns out to be its other driver**, and the more interesting one, because the
player chose it.

A policy's effect is therefore not limited to a rate or a flag. It can reach into
the economy, the population, the military, or the Crown's own opinion of what
things are worth.

## 9. Tuning targets

- The monthly cost of a policy, and whether it grows over a run as demands do.
- `X`, the loyalty drain at half payment — and the 3× multiplier at none, which
  is design rather than tuning and should survive rebalancing.
- How long a contact carries an unfunded policy before warning, and the length of
  the grace he then gives.
- What a lump-sum bribe is worth against accumulated drain.
- The loyalty cost of the PC cancelling.
- How many policies a run can support before letter volume (§9.6) suffers.

## 10. Open items

- **A rebel town allying with a rival is already permitted and unexercised.**
  SPEC §12.3 says a rebel town handles its own diplomacy and that "rivals can
  court it," so the historical parallel needs no spec change to exist — only
  building. When it is built, it is an alliance **against** the PC, not a
  negotiation he is party to.
- Whether a policy's cost scales with the colony — a military presence in a
  colony of two towns cannot cost what it costs in a colony of nine.
- Whether a contact who has carried an unfunded policy for a long time remembers
  it. `contacts.md` §7 wants the Relationship to be a history; **a man who
  covered the PC's debts for two years has earned the right to mention it.**
- Whether the PC can see what a policy is costing him. The Ledger shows gold
  between colony and Crown (§10.4); a recurring charge belongs there, and that
  may be the clearest picture the player ever gets of his own commitments.
