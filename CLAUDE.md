# Working on this repo

This is the source repo for Attention Scoping itself. It's small enough that
**no `.attention.yml` is needed** — work with the full checkout.

The drop-in `CLAUDE.md` for repos that *adopt* attention scoping lives at
[`templates/CLAUDE.md`](templates/CLAUDE.md). Don't confuse the two.

## Layout

- `bin/attention` — the CLI (POSIX sh + awk, no dependencies)
- `docs/attention-yml-spec.md` — the `.attention.yml` schema
- `examples/` — sample `.attention.yml` files for common project shapes
- `templates/CLAUDE.md` — drop-in for adopters
- `tests/` — tests for the CLI and parser

## Conventions for `.attention.yml` examples

The CLI parser is awk, not a full YAML parser. Examples must follow this
exact indentation:

```yaml
version: 1

scopes:
  scope_name:
    description: "short description"
    paths:
      - relative/path
      - another/path

default: scope_name
```

Rules:

- Scope names: 2-space indent, ends with `:`
- `description` and `paths`: 4-space indent
- Path items: 6-space indent, `- ` prefix
- Spaces only, no tabs

When adding a new example, run `bin/attention list` against it (from a repo
root containing the file) to confirm it parses.

## Testing

```sh
tests/run.sh
```

The script runs in a temp directory and does not touch your working tree.
