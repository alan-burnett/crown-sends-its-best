# data/

Game content. **Adding content is adding a file** — no engine code changes
(SPEC §9.7, §16.1).

Every top-level directory here is a **collection**, named after the directory,
loaded by the `Content` autoload and reachable as `Content.collection("name")`.

## Language suffixes

A directory ending in a two-letter language code is localised, and only the one
matching the selected language loads:

```
data/letters_en/<sender>/<letter>.json   prose + reply structure  -> collection "letters"
```

A second language is a **copied folder where only `text` fields change**. Prose
lives inline with its mechanics, so nothing has to be kept in sync across two
files (`CLAUDE.md`, Content pipeline).

## File shape

A file holds either one record with an `id`, or an array of them. Ids must be
unique across the **whole** tree — a duplicate is an error, not a silent
overwrite, because otherwise which one won would depend on directory order.

```jsonc
{ "id": "marshal.request_supplies", "sender": "marshal", ... }
```

## Numbers

Godot's JSON parser returns every number as a float, so `200` arrives as
`200.0`. Read numbers through `JsonTypes`, against the type the schema
declares. Rendering `{param:amount}` as "200.0" in a letter is the mistake the
content validator exists to prevent.

## Collections

| Directory | Collection | Owner |
| :--- | :--- | :--- |
| `assets/` | `assets` | Asset indirection, `id` -> `res://` path (SPEC §16.3) |
| `letters_en/` | `letters` | Letter prose and reply structure (#8) |
| `triggers/` | `triggers` | When a letter fires. **No prose** (#14) |
