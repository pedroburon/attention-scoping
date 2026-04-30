# Attention Scoping

> Control what an LLM sees by controlling what's on disk.

Your coding assistant reads every file in your checkout. The payment service, the analytics pipeline, the three deprecated modules, the migration from 2021. All of it. Even when you're only changing one auth middleware.

That's not context. That's noise. And it costs you.

Attention Scoping fixes this at the filesystem layer — no prompts to rewrite, no wrappers to install, no model fine-tuning. It uses `git sparse-checkout` to hide the files the model doesn't need for the current task, leaving only what matters on disk.

**Less context. Better answers. No overhead.**

---

## Why it works

LLMs distribute attention across every token they receive. Irrelevant files consume that attention even when the model "ignores" them. The _lost-in-the-middle_ effect (Liu et al., 2023) shows retrieval accuracy dropping up to ~40% for information buried in long contexts, regardless of model family.

The implication: a checkout containing 200 files when the task needs 12 is a checkout that systematically dilutes your model's focus. It still answers. It answers worse.

Attention Scoping removes the noise before it reaches the model — at the filesystem layer, not the prompt layer. Because it operates through `git sparse-checkout`, it's transparent to everything:

- **Claude Code and other coding agents** — they just see fewer files
- **Your IDE** — nothing to configure
- **Test runners, linters, type checkers** — unaffected
- **`grep`, `find`, ripgrep** — the files simply aren't there

Nothing in your toolchain needs to know about Attention Scoping. The irrelevant files just aren't there.

---

## How it works

You define named **scopes** in `.attention.yml` at the repo root. Each scope is a unit of work: a name, a description, and the paths needed to do that work.

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

Then:

```sh
attention use payments      # working tree shrinks to payments scope
# ...do the work...
attention off               # restore full checkout
```

---

## Install

### CLI

Requires: POSIX `sh`, `awk`, `git` 2.25+.

```sh
git clone https://github.com/pedroburon/attention-scoping
sudo cp attention-scoping/bin/attention /usr/local/bin/attention
```

Or without sudo:

```sh
mkdir -p ~/.local/bin
cp attention-scoping/bin/attention ~/.local/bin/attention
# ensure ~/.local/bin is on PATH
```

### Claude Code Skill

The `attention-scope` skill gives Claude Code a first-class interface to Attention Scoping:

- **Adoption wizard** — Claude analyzes your repo structure, proposes scopes, and generates `.attention.yml` with your input
- **Runtime enforcement** — Claude activates the right scope before touching code, and stays within it
- **Session-start hook** — Claude knows your active scope from the moment a session opens

**Install the skill:**

```sh
# 1. Clone the repo (if you haven't)
git clone https://github.com/pedroburon/attention-scoping

# 2. Copy the skill to your Claude Code skills directory
mkdir -p ~/.claude/skills
cp -r attention-scoping/skills/attention-scope ~/.claude/skills/
```

**Use it:**

```
/attention-scope
```

On first run in a repo without `.attention.yml`, the skill walks you through setup. In a repo that's already configured, it reads your scopes and activates the right one for the task.

**Optional: session-start hook**

The skill can install a hook that tells Claude your active scope at the start of every session. During the adoption flow, it will ask. Or add it manually:

```json
// ~/.claude/settings.json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"~/.claude/skills/attention-scope/hooks/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

---

## CLI usage

```
attention list           List available scopes
attention use <scope>    Activate a scope
attention status         Show the active scope
attention off            Restore full checkout
```

`attention use <scope>` calls `git sparse-checkout init` if needed, then `git sparse-checkout set <paths>`. The active scope is recorded in `.attention.state` — add this to `.gitignore`.

---

## Adopting it in a repo

1. Add `.attention.yml` to the repo root — see [the spec](docs/attention-yml-spec.md) or use the [examples](examples/) as templates
2. Add `.attention.state` to `.gitignore`
3. Run `attention list` to confirm scopes parse
4. Drop in [`templates/CLAUDE.md`](templates/CLAUDE.md) if you use Claude Code without the skill

---

## Choosing scopes

Good scopes match the way work actually arrives — by feature, by surface, by subsystem. Bad scopes mirror the directory tree mechanically.

Heuristics:

- A scope should contain the files you'd open in your IDE for that task. Not more.
- Cross-cutting code (shared utils, types) belongs in any scope that needs it. Duplicating a path across scopes is expected.
- If a scope's path list exceeds ~10 entries, it's probably two scopes.
- If two scopes share more than half their paths, they're probably one.

---

## When not to use it

- **Small repos.** If the full checkout fits comfortably in context, don't bother.
- **Whole-codebase tasks.** Large refactors, dependency upgrades. Use `attention off`.
- **Tooling that breaks with sparse-checkout.** Rare, but verify your build.

---

## Repo contents

| Path | What it is |
|------|-----------|
| `bin/attention` | The CLI — POSIX sh, no dependencies |
| `skills/attention-scope/` | Claude Code skill (adoption wizard + runtime enforcement) |
| `docs/attention-yml-spec.md` | `.attention.yml` schema reference |
| `examples/` | `.attention.yml` templates for common project shapes |
| `templates/CLAUDE.md` | Drop-in instructions for Claude Code adopters |
| `tests/` | CLI and hook test suite |

---

## Background

- Liu et al., _Lost in the Middle: How Language Models Use Long Contexts_ (2023)
- Anthropic, _Long context prompting tips_

The core finding: retrieval accuracy is U-shaped over position — strong at the start and end, weakest in the middle. Doubling context length without doubling signal makes things worse.

---

## License

MIT.
