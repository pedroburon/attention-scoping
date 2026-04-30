# Attention Scoping

> Control what an LLM sees by controlling what's on disk.

Attention Scoping is a technique for improving LLM coding assistant quality in
large codebases by structurally limiting which files reach the model's context.
It uses `git sparse-checkout` to hide files the model doesn't need for the
current task, without deleting them.

This repo contains:

- The technique's specification
- `attention`, a dependency-free shell CLI
- The `.attention.yml` schema
- Examples for common project layouts
- A `CLAUDE.md` you can drop into any repo that adopts the technique

---

## The premise to drop

> "More context = better answers"

This is wrong. What produces better answers is **relevant context**. A model
given 5k tokens of what matters will outperform the same model given 80k
tokens with noise.

## Why it works

LLMs distribute attention across every token they receive. Irrelevant files
consume that attention even when the model "ignores" them. This is measured:
the *lost-in-the-middle* effect shows accuracy dropping by up to ~40% for
information sitting in the middle of a long context, regardless of model
family.

The implication for coding assistants: a checkout containing 200 files when
the task only needs 12 is a checkout that systematically dilutes the model's
attention. The model still answers. It answers worse.

Attention Scoping addresses this at the filesystem layer rather than at the
prompt layer. Instead of asking the model (or a wrapper) to filter, it removes
the files from the working tree entirely, using a tool every git repo already
supports: sparse-checkout.

Because the operation is at the filesystem layer, it is transparent to:

- Claude Code and other coding agents
- Your IDE
- Test runners, linters, type checkers
- Shell tools (`grep`, `find`, ripgrep)

Nothing needs to know about Attention Scoping. The files just aren't there.

## How it works

You declare named **scopes** — units of work — in `.attention.yml` at the repo
root. Each scope lists the paths needed to do that work.

```yaml
version: 1

scopes:
  payments:
    description: "Full payment flow"
    paths:
      - src/payments
      - src/shared/currency
      - tests/payments

  auth:
    description: "Authentication and middleware"
    paths:
      - src/auth
      - src/middleware

default: payments
```

A scope is a unit of work with a name, description, and intent — not just a
path list. The description is what helps the model (and you) pick the right
one.

Then:

```sh
attention use payments      # working tree shrinks to payments scope
# ...do the work...
attention off               # restore full checkout
```

## Install

```sh
git clone https://github.com/pedroburon/attention-scoping
cd attention-scoping
sudo cp bin/attention /usr/local/bin/attention
```

Or, without sudo:

```sh
mkdir -p ~/.local/bin
cp bin/attention ~/.local/bin/attention
# ensure ~/.local/bin is on PATH
```

Requirements: POSIX `sh`, `awk`, `git` 2.25 or newer.

## Usage

```
attention list           List available scopes
attention use <scope>    Activate a scope
attention status         Show the active scope
attention off            Restore full checkout
```

`attention list` shows scopes with their descriptions and paths, marks the
active one, and marks the default if no scope is active.

`attention use <scope>` calls `git sparse-checkout init` if needed, then
`git sparse-checkout set <paths>`. The active scope is recorded in
`.attention.state` (add this to `.gitignore`).

`attention off` runs `git sparse-checkout disable` and clears state.

## Adopting it in a repo

1. Add `.attention.yml` to the repo root (see [the spec](docs/attention-yml-spec.md)).
2. Add `.attention.state` to `.gitignore`.
3. Drop in [`templates/CLAUDE.md`](templates/CLAUDE.md) if you use Claude Code.
4. Run `attention list` to confirm scopes parse.

See [`examples/`](examples/) for `.attention.yml` templates by project shape.

## Choosing scopes

Good scopes match the way work actually arrives — by feature, by surface, by
subsystem. Bad scopes match the directory tree mechanically.

Heuristics:

- A scope should hold the files you'd open if you were doing the task in your
  IDE without help. Not more.
- Cross-cutting code (shared utilities, types) belongs in any scope that
  needs it. Duplicating a path across scopes is fine and expected.
- If a scope's path list grows past ~10 entries, it's probably two scopes.
- If two scopes share more than half their paths, they're probably one.

## When not to use it

- Tiny repos. If the full checkout fits comfortably in context, don't bother.
- Tasks that genuinely span the whole codebase (large refactors, dependency
  upgrades). Use `attention off` and accept the cost.
- Repos where sparse-checkout breaks tooling (rare, but check your build).

## Theoretical background

- Liu et al., *Lost in the Middle: How Language Models Use Long Contexts* (2023)
- Anthropic, *Long context prompting tips*

The core finding across studies: retrieval accuracy is U-shaped over position,
strong at the start and end of the context, weakest in the middle. Doubling
context length without doubling signal makes things worse, not better.

## Status

v0. Shell CLI, awk-based parser, no dependencies. The parser is intentionally
strict about indentation — see [the spec](docs/attention-yml-spec.md) for the
exact format.

## License

MIT.
