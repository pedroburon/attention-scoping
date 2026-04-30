# `.attention.yml` Specification

Version 1.

`.attention.yml` lives at the root of a git repo and declares the **scopes**
available to `attention use`. The file is parsed by `awk`, not a full YAML
parser — the format is a strict subset of YAML and indentation matters.

## File location

The repo root, alongside `.gitignore`. Discovered via `git rev-parse --show-toplevel`.

## Top-level fields

| Field      | Type            | Required | Description                                           |
|------------|-----------------|----------|-------------------------------------------------------|
| `version`  | integer         | yes      | Schema version. Currently `1`.                        |
| `scopes`   | map of scopes   | yes      | Named scopes. At least one entry.                     |
| `default`  | string          | no       | Name of the scope to mark as default in `list` output.|

## Scope fields

Each entry under `scopes` is a named scope:

| Field         | Type             | Required | Description                                  |
|---------------|------------------|----------|----------------------------------------------|
| `description` | string           | no       | One-line summary of the scope's intent.      |
| `paths`       | list of strings  | yes      | Repo-relative paths included in the scope.   |

## Indentation rules

The parser is line-based and looks for exact indent levels. Use **spaces only**,
no tabs.

```yaml
version: 1                       # column 0

scopes:                          # column 0
  payments:                      # column 2  — scope name
    description: "Payment flow"  # column 4  — scope field
    paths:                       # column 4  — scope field
      - src/payments             # column 6  — path item
      - tests/payments           # column 6  — path item

default: payments                # column 0
```

Rules:

- Scope names: indent 2 spaces, end with `:`.
- `description` and `paths` keys: indent 4 spaces.
- Path items: indent 6 spaces, prefix `- `.
- One scope per block. Blank lines between scopes are allowed.
- Comments (`# ...`) are allowed on their own lines.

## Path semantics

Paths are passed verbatim to `git sparse-checkout set`. They follow git's
sparse-checkout pattern rules:

- A bare path like `src/payments` includes that directory and everything
  beneath it.
- The repo root (`.attention.yml`, `README.md`, etc.) and `.git/` are always
  present regardless of scope.
- Patterns with leading `/` or trailing `/*` are valid but rarely needed for
  scope definitions.

## Example: minimal valid file

```yaml
version: 1

scopes:
  core:
    paths:
      - src
```

## Example: multi-scope with default

```yaml
version: 1

scopes:
  api:
    description: "HTTP API and routing"
    paths:
      - src/api
      - src/middleware
      - tests/api

  workers:
    description: "Background job workers"
    paths:
      - src/workers
      - src/queue
      - tests/workers

  shared:
    description: "Shared types and utilities — pull in alongside another scope"
    paths:
      - src/shared
      - src/types

default: api
```

## What the parser does *not* support

The awk parser is intentionally minimal. The following are **not** supported:

- Tabs for indentation.
- Inline (flow-style) lists or maps: `paths: [a, b]`, `{key: value}`.
- Multi-line strings (`|`, `>`).
- Anchors and aliases (`&`, `*`).
- Quoted keys.
- Nested scopes or scope inheritance.

If you need any of these, the parser will silently skip lines it doesn't
recognize. Keep the format flat.

## Validating your file

```sh
attention list
```

If a scope is missing from the output, check its indentation. If a scope shows
no paths, the items under `paths:` are likely indented wrong.

## State file

When a scope is active, `attention` writes its name to `.attention.state` at
the repo root. This file is **not** part of the spec — it's an implementation
detail of the CLI, and should be added to `.gitignore`.
