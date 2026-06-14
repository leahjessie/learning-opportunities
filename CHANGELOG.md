# Changelog

## learning-opportunities-auto 1.0.4

Fixes two cases where a real `git commit` failed to trigger the nudge.

**Fixed:**
- The "did the commit just land?" check now keys off the reflog ref-update time of `HEAD@{0}` instead of the committer timestamp (`%ct`). `%ct` is stamped before the commit object is created, so a signed commit whose approval prompt takes longer than the 30s window left `%ct` stale and the hook silently bailed on a perfectly good commit. The reflog entry is written after signing, so the check is now immune to approval latency while still skipping genuinely failed commits (which write no reflog entry).
- Multi-line commands now match. The Bash tool sends a multi-line command as a JSON string with newlines escaped to the literal chars `\n`, so a statement like `git add .\ngit commit -m x` kept `commit` on a single grep line preceded by `\n` — which the subcommand matcher didn't treat as a statement separator, so the nudge never fired. The anchor now recognizes escaped `\n`/`\r` as separators (alongside `;`, `&`, `|`, backtick, `(`, and `$(`). `&&`-joined and single-line commits were unaffected.

## learning-opportunities-auto 1.0.3

Hardens the commit-detection trigger so the nudge fires only on real commits.

**Fixed:**
- Scoped commit detection to the command text instead of the whole hook payload, so a command whose *output* merely printed "git" and "commit" (e.g. reading a file that mentions them) no longer fires a spurious nudge.
- Tightened the matcher to require `commit` as the git *subcommand*: intermediate tokens must be flags, so common agent commands like `git log <sha>` and `git show <sha>` (where `commit`/a SHA is an argument) no longer match. Anchored to the start of the command or a shell separator so prefixes like `foogit commit` don't match.

**Changed:**
- The offer counter now increments only when a nudge is actually emitted, de-duped per commit SHA, so non-committing calls and repeated hook invocations can't silently burn the per-session offer quota.
- Failed commits (e.g. rejected by a pre-commit hook) are now skipped by checking HEAD's commit timestamp, avoiding nudges about stale work.
- The nudge now includes the short SHA and commit subject so the skill has a concrete topic handle.

## learning-opportunities-auto 1.0.2

**Fixed:**
- Fixed Codex hook execution from repository working directories by resolving the hook script from Codex's plugin cache instead of using a repo-relative path

## orient 1.0.0

Added orient plugin to the learning-opportunities marketplace.

**New:**
- `orient` skill for generating repo-specific orientation files using program comprehension research
- Showboat mode for detailed linear code walkthroughs

## learning-opportunities-auto 1.0.1

**Fixed:**
- Moved hook declaration from inline `plugin.json` format to `hooks/hooks.json`, which is the format Claude Code actually reads at runtime
- Moved `scripts/post-tool-use.sh` to `hooks/post-tool-use.sh` to colocate with hook configuration

## learning-opportunities-auto 1.0.0

Initial release of the automatic hook companion plugin.

**New:**
- `PostToolUse` hook that triggers after `git commit` and nudges Claude to offer a learning exercise when appropriate
- Bash implementation — works on Linux and macOS out of the box; Windows users need to configure `CLAUDE_CODE_GIT_BASH_PATH` (see README)
- Session state tracking: respects the learning-opportunities skill's two-exercise-per-session limit and declined-offer flag

## learning-opportunities 1.0.0

Initial release as a Claude Code plugin.

**New:**
- `learning-opportunities` skill for science-based deliberate practice during AI-assisted coding
- Exercise types: Prediction/Observation/Reflection, Generation/Comparison, Trace the Path, Debug This, Teach It Back, Retrieval Check-in
- Supporting resources: PRINCIPLES.md (learning science foundations), MEASURE-THIS.md (team experiment playbook)
