#!/bin/sh
# Text rules are context the model may drop. This is enforcement it cannot.
# Glyphs are built with printf so editing this file never trips its own rule.
set -u

EM_DASH=$(printf '\342\200\224')
EN_DASH=$(printf '\342\200\223')
LDQUO=$(printf '\342\200\234')
RDQUO=$(printf '\342\200\235')
LSQUO=$(printf '\342\200\230')
RSQUO=$(printf '\342\200\231')
NBSP=$(printf '\302\240')
ZWSP=$(printf '\342\200\213')

payload=$(cat)

extract_jq() {
  printf '%s' "$payload" | jq -r '
    [.tool_input.content, .tool_input.new_string, .tool_input.command]
    | map(select(type == "string"))
    | join("\n")
  ' 2>/dev/null
}

extract_node() {
  printf '%s' "$payload" | node -e '
    let s = "";
    process.stdin.on("data", d => s += d).on("end", () => {
      try {
        const t = JSON.parse(s).tool_input || {};
        process.stdout.write([t.content, t.new_string, t.command]
          .filter(v => typeof v === "string").join("\n"));
      } catch (e) { process.exit(1); }
    });
  ' 2>/dev/null
}

# The raw fallback also sees old_string, so it blocks edits that remove an
# existing glyph. Install jq or node if the repo already contains any.
if command -v jq >/dev/null 2>&1; then
  text=$(extract_jq) || text=$payload
elif command -v node >/dev/null 2>&1; then
  text=$(extract_node) || text=$payload
else
  text=$payload
fi

deny() {
  printf '%s' "$text" | grep -q -e "$2" || return 0
  printf 'Blocked: %s. %s\n' "$1" "$3" >&2
  exit 2
}

deny "em dash"            "$EM_DASH"   "Use a comma, colon, or period."
deny "spaced en dash"     " $EN_DASH " "Use a comma, colon, or period."
deny "curly double quote" "$LDQUO"     "Use a straight double quote."
deny "curly double quote" "$RDQUO"     "Use a straight double quote."
deny "curly single quote" "$LSQUO"     "Use a straight apostrophe."
deny "curly single quote" "$RSQUO"     "Use a straight apostrophe."
deny "non-breaking space" "$NBSP"      "Use a normal space."
deny "zero-width space"   "$ZWSP"      "Delete it."

exit 0
