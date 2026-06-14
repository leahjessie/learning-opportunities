#!/usr/bin/env bash
set -uo pipefail

# learning-opportunities-auto: PostToolUse hook (matches Bash tool)
#
# Fires after every Bash tool use. Checks whether the command was a
# `git commit` and, if so, suggests that Claude offer a learning exercise.
# The skill itself decides whether the commit's content is worth an
# exercise — this hook just provides the nudge at the right moment.
#
# No external dependencies beyond bash and standard Unix tools.

INPUT=$(cat)

# ---------------------------------------------------------------------------
# Check if this was a git commit. Claude Code sends shell text in a "command"
# field; Codex can send it in a "cmd" field.
#
# Match the COMMAND TEXT ONLY, never the full payload: a PostToolUse payload
# also carries the command's output (tool_response), so grepping the whole blob
# fires on any command whose output merely prints "git" and "commit" (e.g.
# reading a file that mentions them). Extract just the command value first.
# ---------------------------------------------------------------------------

CMD=$(echo "$INPUT" | grep -oE '"(command|cmd)":"([^"\\]|\\.)*"' | head -1 | sed -E 's/^"(command|cmd)":"//; s/"$//')

# Require `git commit` where `commit` is the SUBCOMMAND, not an argument.
# The regex, piece by piece:
#
#   (^|[;&|`(][[:space:]]*|\$\([[:space:]]*|\\[nr][[:space:]]*)
#     Anchor: start of command, right after a shell separator
#     (`;` `&` `|` backtick `(`), a `$(` substitution, or an escaped newline /
#     carriage return. Multi-line commands arrive as a JSON string with their
#     newlines escaped to the literal two chars `\n` (`\r`), so a statement like
#     `git add .\ngit commit -m x` keeps `commit` on one grep line — without
#     treating `\n`/`\r` as a separator, the second statement's `git commit`
#     would go unmatched. Stops `foogit commit` (no separator before `git`).
#
#   git
#     The literal command.
#
#   ([[:space:]]+-[^[:space:]"]+([[:space:]]+[^-[:space:]"][^[:space:]"]*)?)*
#     Zero or more global-flag blocks: `<space>-flag` optionally followed by a
#     non-flag value. Intermediate tokens must be FLAGS, so `git log commit`
#     and `git show commit abc123` (commit as an argument) don't match, while
#     `git -c foo=bar commit` still does.
#
#   [[:space:]]+commit([[:space:]";|&)]|$|\\)
#     The `commit` subcommand, terminated by whitespace / quote / separator /
#     end / backslash — so `git commit-tree` won't match.
if ! printf '%s' "$CMD" | grep -Eq '(^|[;&|`(][[:space:]]*|\$\([[:space:]]*|\\[nr][[:space:]]*)git([[:space:]]+-[^[:space:]"]+([[:space:]]+[^-[:space:]"][^[:space:]"]*)?)*[[:space:]]+commit([[:space:]";|&)]|$|\\)'; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract session_id for rate limiting. It's a top-level UUID — no escaped
# quotes or nesting to worry about, so basic grep/sed is safe.
# ---------------------------------------------------------------------------

SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"$//')

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract cwd so we can query git in the repo the commit was made in,
# and identify the commit by its short SHA for de-duplication below.
# ---------------------------------------------------------------------------

CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | head -1 | sed 's/"cwd":"//;s/"$//')
if [[ -z "$CWD" ]]; then
  CWD="$PWD"
fi

SHA=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null) || exit 0
if [[ -z "$SHA" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Verify the commit actually landed and is THIS commit, not stale work.
#
# We key off the reflog ref-update time, NOT the committer timestamp (%ct).
# %ct is stamped when git assembles the commit metadata — *before* it creates
# the (possibly signed) commit object. With signed commits authorized through
# an interactive prompt (e.g. 1Password / Touch ID), the approval can take
# tens of seconds, so by the time the commit lands %ct is already "old" and a
# naive freshness check bails on a perfectly good commit.
#
# The reflog entry for HEAD@{0} is written when the ref actually updates —
# *after* signing — so its timestamp is genuinely "now" the moment the commit
# lands, regardless of how long approval took. A failed `git commit` writes no
# reflog entry, so HEAD@{0} stays the previous (older) entry and we still skip
# silently. `--date=unix` renders the selector as HEAD@{<unixtime>}.
# ---------------------------------------------------------------------------

REF_TS=$(git -C "$CWD" reflog -1 --date=unix --format='%gd' 2>/dev/null | grep -oE '[0-9]+') || exit 0
NOW=$(date +%s)
if [[ -z "$REF_TS" ]] || (( NOW - REF_TS > 30 )); then
  exit 0
fi

# ---------------------------------------------------------------------------
# Session state:
#   * .state  — count of emitted offers this session (cap at 2)
#   * .seen   — commit SHAs we've already nudged about (de-dupe)
# Both live in $TMPDIR keyed on session id; reset when the session ends.
# The counter increments only when a nudge is actually emitted, and the
# per-SHA de-dupe ensures a single commit can't consume multiple offers
# from the session cap if this hook is invoked more than once for it.
# ---------------------------------------------------------------------------

SAFE_ID="${SESSION_ID//[^a-zA-Z0-9_-]/_}"
STATE_FILE="${TMPDIR:-/tmp}/lo_auto_${SAFE_ID}.state"
SEEN_FILE="${TMPDIR:-/tmp}/lo_auto_${SAFE_ID}.seen"

if [[ -f "$SEEN_FILE" ]] && grep -q "^${SHA}$" "$SEEN_FILE" 2>/dev/null; then
  exit 0
fi

offers=0
if [[ -f "$STATE_FILE" ]]; then
  offers=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi

# Stop after 2 offers per session.
if [[ "$offers" -ge 2 ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Grab the commit subject so the nudge can mention a concrete topic.
# Sanitize to stay safely embeddable in the JSON string below: strip
# newlines, tabs, carriage returns, double-quotes, and backslashes, and
# cap length.
# ---------------------------------------------------------------------------

SUBJECT=$(git -C "$CWD" log -1 --pretty=%s 2>/dev/null | head -c 160 | tr -d '"\r\n\t\\')

# Record that we're emitting a nudge for this commit, then emit.
echo "$SHA" >> "$SEEN_FILE"
echo $(( offers + 1 )) > "$STATE_FILE"

# ---------------------------------------------------------------------------
# Emit suggestion for Claude via structured JSON. PostToolUse hooks must
# output JSON with hookSpecificOutput on exit 0 to inject context.
# ---------------------------------------------------------------------------

cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[learning-opportunities-auto] The user just committed code (${SHA}: ${SUBJECT}). Per the learning-opportunities skill, consider whether this is a good moment to offer a learning exercise. If the committed work involved new files, schema changes, architectural decisions, refactors, or unfamiliar patterns, ask the user (one short sentence) if they'd like a 10-15 minute exercise. Do not start the exercise until they confirm. If they decline, note it — no more offers this session."}}
HOOK_JSON

exit 0
