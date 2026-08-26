# Learning Opportunities

Last verified: 2026-08-26

## What This Is

A Claude Code plugin packaging science-based learning exercises for deliberate skill development during AI-assisted coding. Author: Dr. Cat Hicks. License: CC-BY-4.0.

## Fork status

This checkout is Jessie's maintained repository derivative of `DrCatHicks/learning-opportunities`. Work on branch `fork`, which tracks `origin/fork` on Jessie's GitHub fork. The `upstream` remote is the canonical project and its push URL is set to `DISABLE`.

The fork diverges for two durable reasons. It hardens the `learning-opportunities-auto` post-commit hook so the nudge fires reliably on signed and multi-line commits and only for an actual `git commit`. It adds the coordinated laptop-to-mini delivery entry points owned by `~/Developer/personal/dotfiles`. The hook changes are candidates for contribution back to the canonical project; the delivery entry points are local and are not.

Merge upstream changes from `upstream/main`. GitHub does not synchronize a fork's default branch, so `origin/main` drifts behind the canonical project and is not a comparison ref. Git history records the individual changes; do not restate them here.

The sections below this one originate in the canonical project's `CLAUDE.md`, which this fork reduces to a pointer. A merge that changes `CLAUDE.md` upstream conflicts against that pointer; resolve it by porting the upstream change into this file and restoring the pointer.

## Project Structure

- `.claude-plugin/marketplace.json` - Marketplace catalog (repo root is the marketplace)
- `.agents/plugins/marketplace.json` - Codex marketplace catalog
- `learning-opportunities/` - The skill plugin
  - `.claude-plugin/plugin.json` - Plugin manifest
  - `.codex-plugin/plugin.json` - Codex plugin manifest
  - `skills/learning-opportunities/` - The skill (SKILL.md + resources)
- `learning-opportunities-auto/` - The auto-prompting hook plugin (requires `learning-opportunities`)
  - `.claude-plugin/plugin.json` - Plugin manifest
  - `.codex-plugin/plugin.json` - Codex plugin manifest
  - `hooks/post-tool-use.sh` - PostToolUse hook (bash)
- `orient/` - The orientation generator plugin
  - `.claude-plugin/plugin.json` - Plugin manifest
  - `.codex-plugin/plugin.json` - Codex plugin manifest
  - `skills/orient/` - The skill (SKILL.md)
- `CHANGELOG.md` - Release history

## Releasing a New Version

Each plugin has its own version. When releasing, update the version in four places atomically:

1. `<plugin>/.claude-plugin/plugin.json` — bump `version`
2. `<plugin>/.codex-plugin/plugin.json` — bump `version`
3. `.claude-plugin/marketplace.json` — bump the matching plugin entry's `version`
4. `CHANGELOG.md` — add entry at top, under the `# Changelog` heading

Use semver. All versioned files must show the same version string for the plugin being released. Commit them together.

### Changelog format

```markdown
## <plugin-name> X.Y.Z

Brief description.

**New:**
- Additions

**Changed:**
- Modifications

**Fixed:**
- Bug fixes
```

Only include sections that apply.
