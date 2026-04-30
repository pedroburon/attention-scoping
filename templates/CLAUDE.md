# Attention Scoping

This repo uses attention scoping to manage LLM context via git sparse-checkout.
Scopes are defined in `.attention.yml` at the repo root.

## Before starting any task

1. Read `.attention.yml`
2. Identify which scope covers the files needed for this task
3. Run `attention use <scope>` before touching any code
4. If no scope fits, run `attention list` and pick the closest one
   or ask before proceeding with full checkout

## Rules

- Never work with full checkout if a relevant scope exists
- If a task spans multiple scopes, activate them one at a time
  and complete each part before switching
- After finishing, leave the scope active — don't run `attention off`
  unless explicitly asked
- If you create new files, check whether they belong to the active scope's
  paths; if not, flag it

## Reference

```bash
attention list              # see available scopes and their paths
attention use <scope>       # activate a scope
attention status            # confirm active scope
attention off               # restore full checkout
```
