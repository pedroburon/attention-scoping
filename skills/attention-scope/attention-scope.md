---
name: attention-scope
description: Adopt and use Attention Scoping — manage LLM context via git sparse-checkout
---

# Attention Scope

Attention Scoping limits which files appear in the working tree using git sparse-checkout.
Fewer files = less noise = better LLM answers on large repos.

This skill handles two scenarios:
- **Adoption**: no `.attention.yml` in the repo yet → set it up
- **Use**: `.attention.yml` exists → activate the right scope for the current task

## Setup

When this skill is invoked, the `Skill` tool outputs the base directory of the skill file.
Note that path — it is `$SKILL_DIR` throughout these instructions.

All CLI calls use `$SKILL_DIR/bin/attention`.

---

## Step 1: Detect repo state

```sh
git rev-parse --show-toplevel 2>/dev/null
```

If not inside a git repo, stop and tell the user.

Check whether `.attention.yml` exists at the repo root:
- **Not found** → run **Adoption Flow** below
- **Found** → run **Use Flow** below

---

## Adoption Flow

Run when the repo has no `.attention.yml`.

### A1. Analyze directory structure

```sh
find . -maxdepth 3 -type d | grep -v '^\./\.' | sort
```

Identify:
- Source dirs: `src/`, `lib/`, `app/`, `packages/`, named service directories
- Test dirs: `tests/`, `test/`, `spec/`, `__tests__/`, `*_test/`
- Shared/utility dirs: `shared/`, `utils/`, `common/`, `types/`
- Config/infra dirs: `config/`, `infra/`, `deploy/`, `.github/`

### A2. Propose scopes

Propose 2–5 scopes. For each scope:
- Use a snake_case name that matches a unit of work (e.g., `auth`, `payments`, `api`)
- Write a one-line description of what work happens there
- Include the source directory AND its matching test directory in `paths`
- Include cross-cutting dirs (shared, utils, types) in any scope that needs them

Present proposals:

```
Proposed scopes:

  auth — Authentication and session management
    paths: src/auth, tests/auth, src/shared

  payments — Payment processing and invoice generation
    paths: src/payments, tests/payments, src/shared

  api — HTTP API layer and routing
    paths: src/api, tests/api, src/middleware
```

Ask:
> "Do you want to rename, add/remove paths, split, or merge any scope before I write the file?"

Wait for response. Apply changes. Re-present if changes are substantial.

### A3. Write `.attention.yml`

Write to the repo root using this exact format (spaces only, no tabs):

```yaml
version: 1

scopes:
  <name>:
    description: "<description>"
    paths:
      - <path>

default: <first-scope-name>
```

Indentation rules:
- `version`, `scopes`, `default` at column 0
- Scope names at 2-space indent, ending with `:`
- `description` and `paths` at 4-space indent
- Path items at 6-space indent, prefixed with `- `

### A4. Update `.gitignore`

Read `.gitignore` (treat as empty if absent). If `.attention.state` is not present,
append it. Create the file if it doesn't exist.

### A5. Validate

```sh
$SKILL_DIR/bin/attention list
```

Every proposed scope must appear in the output. If a scope is missing:
- Check indentation (tabs will break the parser — spaces only)
- Check scope name ends with `:` at 2-space indent
- Fix and re-run

### A6. Offer hook installation

Ask:
> "Install a session-start hook so Claude detects Attention Scoping automatically at the start of each session? (Recommended)"

If yes: invoke the `update-config` skill. Instruct it to add a `SessionStart` hook
with command: `bash "<SKILL_DIR>/hooks/session-start.sh"` where `<SKILL_DIR>` is the
actual resolved path from setup.

---

## Use Flow

Run when `.attention.yml` exists. Triggered by explicit invocation or a hook message
at session start.

### U1. Read available scopes

```sh
$SKILL_DIR/bin/attention list
```

### U2. Pick the right scope

Choose the scope whose paths cover the files needed for the current task.
When in doubt, prefer the narrower scope.

If the task spans multiple scopes: work one scope at a time — complete the first
scope's changes, then switch.

If no scope covers the task: say so explicitly before proceeding.
Never use full checkout silently.

### U3. Activate

```sh
$SKILL_DIR/bin/attention use <scope>
```

### U4. Enforce throughout the session

- Do not read or edit files outside the active scope's paths without flagging it
- To switch: `$SKILL_DIR/bin/attention use <new-scope>`
- Do not run `$SKILL_DIR/bin/attention off` unless the user explicitly asks

---

## Reference

```sh
$SKILL_DIR/bin/attention list              # see all scopes and their paths
$SKILL_DIR/bin/attention use <scope>       # activate a scope
$SKILL_DIR/bin/attention status            # show the active scope
$SKILL_DIR/bin/attention off               # restore full checkout
```
