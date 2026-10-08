#!/bin/sh
# Run: sh .claude/hooks/no-ai-glyphs.test.sh
# Glyphs are built with printf so this file never trips the rule it tests.
set -u

HOOK="$(dirname "$0")/no-ai-glyphs.sh"
pass=0
fail=0

check() {
  printf '%s' "$2" | sh "$HOOK" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL  %-28s exit=%s want=%s\n' "$1" "$got" "$3"
  fi
}

wrap() { printf '{"tool_input":{"content":"a %s b"}}' "$1"; }

check "em dash"              "$(wrap "$(printf '\342\200\224')")" 2
check "curly dquote left"    "$(wrap "$(printf '\342\200\234')")" 2
check "curly dquote right"   "$(wrap "$(printf '\342\200\235')")" 2
check "curly squote left"    "$(wrap "$(printf '\342\200\230')")" 2
check "curly squote right"   "$(wrap "$(printf '\342\200\231')")" 2
check "non-breaking space"   "$(wrap "$(printf '\302\240')")" 2
check "zero-width space"     "$(wrap "$(printf '\342\200\213')")" 2
check "spaced en dash"       "$(wrap "$(printf '\342\200\223')")" 2

check "en dash in range" \
  "$(printf '{"tool_input":{"content":"pages 10%s20"}}' "$(printf '\342\200\223')")" 0
check "straight quotes" \
  '{"tool_input":{"content":"const s = \"hi\";"}}' 0
check "edit removing a glyph" \
  "$(printf '{"tool_input":{"old_string":"a %s b","new_string":"a, b"}}' "$(printf '\342\200\224')")" 0
check "edit adding a glyph" \
  "$(printf '{"tool_input":{"old_string":"dont","new_string":"don%st"}}' "$(printf '\342\200\231')")" 2
check "commit message" \
  "$(printf '{"tool_input":{"command":"git commit -m \\"a %s b\\""}}' "$(printf '\342\200\224')")" 2

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
