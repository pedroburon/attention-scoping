#!/usr/bin/env sh
# Attention Scoping session-start hook for Claude Code.
# Outputs context when .attention.yml is present in the current repo.
# Silent otherwise — does not suggest adoption.

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

yml="$root/.attention.yml"
state_file="$root/.attention.state"

[ -f "$yml" ] || exit 0

if [ -f "$state_file" ]; then
  scope=$(cat "$state_file")
  printf "Attention Scoping active: scope '%s'. Invoke the attention-scope skill to verify or switch scopes.\n" "$scope"
else
  printf "Attention Scoping configured but no scope active. Invoke the attention-scope skill to activate one.\n"
fi
