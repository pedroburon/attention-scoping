#!/usr/bin/env sh
# Tests for the attention-scope session-start hook.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
HOOK="$REPO_ROOT/skills/attention-scope/hooks/session-start.sh"

PASS=0; FAIL=0; FAILED_NAMES=""

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }

assert_eq() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf "  %s %s\n" "$(green ✓)" "$1"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $1"
    printf "  %s %s\n" "$(red ✗)" "$1"
    printf "    %s\n" "$(dim "expected: [$2]")"
    printf "    %s\n" "$(dim "actual:   [$3]")"
  fi
}

assert_contains() {
  case "$3" in
    *"$2"*)
      PASS=$((PASS+1)); printf "  %s %s\n" "$(green ✓)" "$1"
      ;;
    *)
      FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $1"
      printf "  %s %s\n" "$(red ✗)" "$1"
      printf "    %s\n" "$(dim "expected to contain: [$2]")"
      printf "    %s\n" "$(dim "actual: [$3]")"
      ;;
  esac
}

section() { printf "\n%s\n" "$1"; }

new_repo() {
  d=$(mktemp -d); cd "$d" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  printf "x\n" > README.md
  git add -A; git commit -q -m "init"
  printf "%s" "$d"
}

section "hook: outside any git repo — silent"
d=$(mktemp -d); cd "$d" || exit 1
out=$(bash "$HOOK" 2>/dev/null)
assert_eq "no output outside git repo" "" "$out"

section "hook: git repo, no .attention.yml — silent"
new_repo > /dev/null
out=$(bash "$HOOK" 2>/dev/null)
assert_eq "no output when .attention.yml absent" "" "$out"

section "hook: .attention.yml present, no .attention.state"
new_repo > /dev/null
printf "version: 1\nscopes:\n  api:\n    paths:\n      - src\n" > .attention.yml
out=$(bash "$HOOK" 2>/dev/null)
assert_contains "mentions 'configured'" "configured" "$out"
assert_contains "mentions 'attention-scope' skill" "attention-scope" "$out"

section "hook: .attention.yml + .attention.state present"
new_repo > /dev/null
printf "version: 1\nscopes:\n  api:\n    paths:\n      - src\n" > .attention.yml
printf "api" > .attention.state
out=$(bash "$HOOK" 2>/dev/null)
assert_contains "shows active scope name" "api" "$out"
assert_contains "says 'active'" "active" "$out"
assert_contains "mentions 'attention-scope' skill" "attention-scope" "$out"

section "hook: .attention.state with trailing newline"
new_repo > /dev/null
printf "version: 1\nscopes:\n  workers:\n    paths:\n      - src\n" > .attention.yml
printf "workers\n" > .attention.state
out=$(bash "$HOOK" 2>/dev/null)
assert_contains "scope name read correctly despite newline" "workers" "$out"

printf "\n"
TOTAL=$((PASS+FAIL))
if [ "$FAIL" -eq 0 ]; then
  printf "%s %d/%d passed\n\n" "$(green ✓)" "$PASS" "$TOTAL"
  exit 0
else
  printf "%s %d/%d failed:%s\n\n" "$(red ✗)" "$FAIL" "$TOTAL" "$FAILED_NAMES"
  exit 1
fi
