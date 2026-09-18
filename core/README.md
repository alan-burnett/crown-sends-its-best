# core/ — shared infrastructure

What belongs to none of the three layers and is used by all of them: content
loading and the asset indirection layer, plus the autoload singletons that
expose them.

**Why this is not one of the six directories in #1.** Autoloads are Nodes, so
they cannot live in `sim/`; and the loader is needed by `correspondence/`, by
`presentation/`, and by the `tools/` CLIs, so it belongs to none of them. The
alternative was putting a filesystem reader inside the pure, headless sim. This
is recorded as an assumption on #1.

| Path | Autoload | What it is |
| :--- | :--- | :--- |
| `content/json_loader.gd` | — | Reads a directory tree into memory, keyed by id |
| `content/json_types.gd` | — | Typed reads, because JSON gives every number back as a float |
| `content/content_db.gd` | `Content` | The loaded `data/` tree, by collection |
| `assets/asset_registry.gd` | `Assets` | `id` -> `res://` path, with a placeholder fallback |
