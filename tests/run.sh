#!/usr/bin/env sh
# Test runner for the `attention` CLI.
#
# Sets up a throwaway git repo per test in $TMPDIR, runs the CLI against it,
# and asserts behaviour. Does not touch the working tree.
#
# Usage:  tests/run.sh

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
ATTN="$REPO_ROOT/bin/attention"

PASS=0
FAIL=0
FAILED_NAMES=""

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }

# -- helpers -----------------------------------------------------------------

# new_repo: create an empty git repo in a fresh temp dir, cd into it, echo path.
new_repo() {
  d=$(mktemp -d)
  cd "$d" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  printf "%s" "$d"
}

# Write a file and commit, so sparse-checkout has something to act on.
seed() {
  mkdir -p "$(dirname "$1")"
  printf "%s\n" "$2" > "$1"
}

commit_all() {
  git add -A
  git commit -q -m "seed"
}

# assert_eq <name> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
    printf "  %s %s\n" "$(green ✓)" "$1"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES="$FAILED_NAMES $1"
    printf "  %s %s\n" "$(red ✗)" "$1"
    printf "    %s\n" "$(dim "expected: $2")"
    printf "    %s\n" "$(dim "actual:   $3")"
  fi
}

# assert_contains <name> <needle> <haystack>
assert_contains() {
  case "$3" in
    *"$2"*)
      PASS=$((PASS + 1))
      printf "  %s %s\n" "$(green ✓)" "$1"
      ;;
    *)
      FAIL=$((FAIL + 1))
      FAILED_NAMES="$FAILED_NAMES $1"
      printf "  %s %s\n" "$(red ✗)" "$1"
      printf "    %s\n" "$(dim "expected to contain: $2")"
      printf "    %s\n" "$(dim "actual: $3")"
      ;;
  esac
}

# assert_fails <name> <command...>
assert_fails() {
  name=$1; shift
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILED_NAMES="$FAILED_NAMES $name"
    printf "  %s %s\n" "$(red ✗)" "$name"
    printf "    %s\n" "$(dim "expected non-zero exit, got success")"
  else
    PASS=$((PASS + 1))
    printf "  %s %s\n" "$(green ✓)" "$name"
  fi
}

# A standard fixture: api / workers / shared, default api.
write_fixture() {
  cat > .attention.yml <<'YAML'
version: 1

# leading comment
scopes:
  api:
    description: "HTTP API"
    paths:
      - src/api
      - src/shared

  workers:
    description: "Background jobs"
    paths:
      - src/workers
      - src/shared

  shared:
    paths:
      - src/shared

default: api
YAML
  seed src/api/app.py        "api"
  seed src/workers/queue.py  "worker"
  seed src/shared/util.py    "shared"
  seed README.md             "readme"
  commit_all
}

section() { printf "\n%s\n" "$1"; }

# -- tests -------------------------------------------------------------------

section "parser: get_scopes / get_paths / get_description"
new_repo > /dev/null
write_fixture
scopes=$("$ATTN" list 2>/dev/null | awk 'NF && /^  [^ ·]/ {print $1}' | tr '\n' ',' )
assert_eq "list shows three scopes in order" "api,workers,shared," "$scopes"

list_out=$("$ATTN" list)
assert_contains "list marks default scope" "(default)" "$list_out"
assert_contains "list shows description"   "HTTP API"  "$list_out"
assert_contains "list shows path bullet"   "· src/api" "$list_out"

section "use: activates sparse-checkout for the scope"
"$ATTN" use api > /dev/null
assert_eq "sparse-checkout enabled" "true" "$(git config core.sparseCheckout)"
assert_eq "state file records active scope" "api" "$(cat .attention.state)"
[ -f src/api/app.py ]      && api_present=yes      || api_present=no
[ -f src/workers/queue.py ] && workers_present=yes || workers_present=no
[ -f src/shared/util.py ]  && shared_present=yes   || shared_present=no
[ -f README.md ]           && readme_present=yes   || readme_present=no
assert_eq "api files present"     yes "$api_present"
assert_eq "workers files hidden"  no  "$workers_present"
assert_eq "shared files present"  yes "$shared_present"
assert_eq "root files always present" yes "$readme_present"

section "status: reflects active scope"
status_out=$("$ATTN" status)
assert_contains "status shows active scope name" "Active scope: api" "$status_out"
assert_contains "status shows description"       "HTTP API"          "$status_out"

section "list: marks active scope with arrow, not (default)"
list_out=$("$ATTN" list)
assert_contains "list marks active scope" "← active" "$list_out"
case "$list_out" in
  *"(default)"*) marker_clean=no ;;
  *)             marker_clean=yes ;;
esac
assert_eq "active scope hides (default) marker" yes "$marker_clean"

section "use: switching scopes updates checkout"
"$ATTN" use workers > /dev/null
assert_eq "state file updated" "workers" "$(cat .attention.state)"
[ -f src/workers/queue.py ] && workers_present=yes || workers_present=no
[ -f src/api/app.py ]       && api_present=yes     || api_present=no
assert_eq "workers files present after switch" yes "$workers_present"
assert_eq "api files hidden after switch"      no  "$api_present"

section "off: restores full checkout and clears state"
"$ATTN" off > /dev/null
assert_eq "state file removed" "" "$( [ -f .attention.state ] && echo present || echo '' )"
[ -f src/api/app.py ] && api_present=yes || api_present=no
assert_eq "api files restored" yes "$api_present"
status_out=$("$ATTN" status)
assert_contains "status shows full checkout" "Full checkout active" "$status_out"

section "use: scope without description still works"
"$ATTN" use shared > /dev/null
assert_eq "state file records 'shared'" "shared" "$(cat .attention.state)"
status_out=$("$ATTN" status)
assert_contains "status shows scope name" "Active scope: shared" "$status_out"
"$ATTN" off > /dev/null

section "errors: invalid input"
assert_fails "use unknown scope fails"      "$ATTN" use no_such_scope
assert_fails "use without scope name fails" "$ATTN" use
assert_fails "unknown command fails"        "$ATTN" frobnicate

section "errors: missing .attention.yml"
d=$(mktemp -d); cd "$d" || exit 1
git init -q
git config user.email t@e.com; git config user.name t
git config commit.gpgsign false
seed README.md "x"; commit_all
assert_fails "list fails without .attention.yml" "$ATTN" list
assert_fails "use fails without .attention.yml"  "$ATTN" use api

section "errors: outside a git repo"
d=$(mktemp -d); cd "$d" || exit 1
assert_fails "list fails outside git repo" "$ATTN" list

section "parser: tolerates blank lines and comments between scopes"
new_repo > /dev/null
cat > .attention.yml <<'YAML'
version: 1

scopes:

  # a comment between scopes
  one:
    paths:
      - a

  two:
    description: "second"
    paths:
      - b

YAML
seed a/x ""; seed b/x ""; commit_all
out=$("$ATTN" list)
assert_contains "scope 'one' visible" "  one" "$out"
assert_contains "scope 'two' visible" "  two" "$out"
assert_contains "description on 'two' shown" "second" "$out"

# -- hook tests --------------------------------------------------------------
printf "\n=== session-start hook ===\n"
sh "$SCRIPT_DIR/test-hook.sh"; HOOK_EXIT=$?

# -- summary -----------------------------------------------------------------

printf "\n"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ] && [ "${HOOK_EXIT:-0}" -eq 0 ]; then
  printf "%s %d/%d passed\n\n" "$(green ✓)" "$PASS" "$TOTAL"
  exit 0
else
  printf "%s %d/%d failed:%s\n\n" "$(red ✗)" "$FAIL" "$TOTAL" "$FAILED_NAMES"
  exit 1
fi
