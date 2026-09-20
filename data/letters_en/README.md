# data/letters_en/

Letter prose and reply structure, in English. Schema owned by #8.

Organised by sender: `data/letters_en/<sender>/<letter>.json`.

Prose lives **inline with its mechanics**, and the folder carries the language
suffix. A second language is a copy of this folder where only `text` fields
change.

Conditions and effects are **ids into a code-side registry** with typed params
(#11). There is never logic in one of these files.

## Reply options

An option in a `reply.steps[].options[]` carries its `label`, its `text`, and
the `effect` that becomes an Order. One further key changes what the order
*does* rather than how it reads:

| Key | Meaning |
| :--- | :--- |
| `harsh` | The PC wrote this rung as a **command rather than a request** |

A harsh order is the surest way to actually be obeyed, and it costs the governor
his regard and the town its patience for the privilege (#71,
`docs/mechanics/rebel-sentiment.md` §4). It is declared here rather than
inferred from the effect's params, because which rung is a command is a thing
the prose says — the player chose it.

**Harsh orders come from the PC only.** The flag is read where his outgoing post
becomes Orders and nowhere else, so an NPC's Intent can never arrive carrying it
however a letter is authored.

The validator rejects a `harsh` that is not `true`/`false`, and one on an option
with no effect — an option that orders nothing cannot be a command.
