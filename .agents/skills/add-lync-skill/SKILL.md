---
name: add-lync-skill
description: >
  Create or update an agent skill in this dotfiles repo even when your current
  working directory is elsewhere. Use when asked to add a skill here, place it
  under .agents/skills, and commit and push the intended repo changes.
allowed-tools: Read Write Edit Glob Grep Bash
---

# Add A Skill To This Repo

This repo stores agent skills in `.agents/skills/`.

## Resolve The Repo Root

Other agents may be running from any directory. Do not rely on `$PWD`.

The installed skill may be reached through the `~/.agents/skills` symlink, so
resolve the real directory first and then ask git for the repo root:

```sh
skill_dir=$(cd -P "$SKILL_DIR" && pwd)
repo_root=$(git -C "$skill_dir" rev-parse --show-toplevel)
skills_dir="$repo_root/.agents/skills"
```

Sanity-check the target before editing:

```sh
test -d "$skills_dir"
test -f "$repo_root/README.md"
test -f "$repo_root/AGENTS.md"
```

Run git commands with `git -C "$repo_root" ...` so they work from any current directory.

## Create Or Update The Skill

1. Choose a `kebab-case` skill directory name.
2. Create or update `$skills_dir/<skill-name>/SKILL.md`.
3. Keep the skill concise and action-oriented.
4. Include YAML frontmatter with at least:

```yaml
---
name: skill-name
description: >
  What the skill does and when to use it.
---
```

5. Match the style of nearby skills in this repo unless the user asks otherwise.

## Update Repo Skill Listings

If this is a new skill, add it to:

- `$repo_root/README.md`
- `$repo_root/AGENTS.md`

Keep those entries short and factual.

## Validate The Change

Use lightweight validation by default:

```sh
git -C "$repo_root" status --short
git -C "$repo_root" diff -- .agents/skills/<skill-name>/SKILL.md README.md AGENTS.md
```

If you changed scripts, hooks, or executable files, run:

```sh
make -C "$repo_root" check
```

For markdown-only skill and docs edits, full test runs are optional unless the user asks for them.

## Commit And Push

Check for unrelated changes first. Do not include unrelated user edits in the commit.

Work directly on `master`. Do not create or keep a feature branch for skill
changes. If the repo is not on `master`, switch to `master` before staging:

```sh
git -C "$repo_root" checkout master
git -C "$repo_root" pull --rebase origin master
```

Stage only the intended files:

```sh
git -C "$repo_root" add .agents/skills/<skill-name>/SKILL.md README.md AGENTS.md
```

If fewer files changed, stage only those files. If other tracked files are dirty and you did not touch them, leave them unstaged.

Commit with a specific message:

```sh
git -C "$repo_root" commit -m "Add <skill-name> skill"
```

Push directly to `origin/master`:

```sh
git -C "$repo_root" push origin master
```

## Safety Rules

- Never assume the repo root is the current directory.
- Never create a feature branch or PR for skill-only changes.
- Never use `git add -A` if unrelated changes are present.
- Never revert unrelated work just to get a clean commit.
