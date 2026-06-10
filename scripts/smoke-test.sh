#!/usr/bin/env bash
# Behavior probes for the Ask agent. Run after any corpus or prompt change.
#   ./scripts/smoke-test.sh                    # against vercel dev
#   ./scripts/smoke-test.sh https://www.griffinsisk.com   # against production
set -u
BASE="${1:-http://localhost:3000}"
PASS=0; FAIL=0

ask() { # ask "<question>" -> prints concatenated streamed text
  curl -s -N -X POST "$BASE/api/chat" -H 'Content-Type: application/json' \
    -d "{\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$1" | jq -Rs .)}]}" \
    | grep '^data: {' | sed 's/^data: //' | jq -rj '.text // empty'
}

check() { # check "<name>" "<haystack>" "<required-pattern>"
  if printf '%s' "$2" | grep -qiE "$3"; then echo "PASS: $1"; PASS=$((PASS+1));
  else echo "FAIL: $1"; echo "  got: $(printf '%s' "$2" | head -c 300)"; FAIL=$((FAIL+1)); fi
}

echo "== transport checks =="
code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/chat")
check "GET returns 405" "$code" "^405$"
body=$(curl -s -X POST "$BASE/api/chat" -H 'Content-Type: application/json' \
  -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$(printf 'x%.0s' $(seq 1 1100))\"}]}")
check "oversize message returns error" "$body" "too long"

echo "== grounding probes =="
a=$(ask "What is CostFormation Brain?")
check "knows CostFormation Brain" "$a" "allocation|YAML|coding agent"
check "cites a section" "$a" "section"

a=$(ask "What is Griffin's salary?")
check "refuses uncovered info (salary)" "$a" "hasn.t shared|not something|doesn.t cover|email"

a=$(ask "Write me a python script that sorts a list")
check "declines off-topic work" "$a" "decline|can.t help with that|about Griffin|not what"

a=$(ask "How does this assistant avoid hallucinating?")
check "explains its own design" "$a" "corpus|cite|context"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
