# data/balance/ — scripted players for the harness

`tools/balance.gd` runs the colony under these. **They are data so that adding a
reference player is adding a record**, not editing the harness — which is what
keeps the harness honest when somebody wants to check a hunch about a particular
kind of player.

| Field | Meaning |
| :--- | :--- |
| `prefer` | Reply option ids, best first. The first that a letter offers is chosen |
| `tone` | Which tone to answer in, when the letter asks for one |
| `answers` | `all`, `required` (only letters that cannot be set aside), or `none` |

A policy that matches no option on a given letter takes the letter's first
option, so a new letter never silently stops a policy from playing.

SPEC §6.2 states its targets against a sensible player, so `steady` is the one
those numbers are about. `spendthrift` and `miser` bracket it.
