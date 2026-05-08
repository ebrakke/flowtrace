# Agent Skill Package

The FlowTrace Agent Skill lives at:

```text
skills/flowtrace/SKILL.md
```

## Spec compliance

Based on the primary Agent Skills specification at <https://agentskills.io/specification.md>:

- A skill is a directory containing `SKILL.md`.
- The directory name must match the required `name` frontmatter.
- `name` must use lowercase letters, numbers, and hyphens only, with no leading/trailing hyphen or consecutive hyphens.
- `description` is required and should explain what the skill does and when to use it.
- Optional `license`, `compatibility`, and `metadata` fields are supported.

FlowTrace uses:

```yaml
name: flowtrace
license: MIT
```

The skill instructions are FlowTrace-specific: they tell an agent to create validated `.flow.json` code walkthrough artifacts and explain how to open those artifacts in Neovim. They are not instructions for runtime tracing, instrumentation, or observability telemetry.

The same skill also includes a changeset / PR mode. When the user asks for a flow of a pull request, branch, patch, diff, or changeset, the agent should compare against the likely mainline branch, inspect the changed hunks, then build a reviewer-oriented data-flow walkthrough that emphasizes changed behavior instead of presenting a file-by-file diff tour.

Agent Skills do not currently define a portable slash-command format, so FlowTrace keeps PR / changeset behavior inside the portable `skills/flowtrace/SKILL.md` instructions instead of shipping client-specific command wrappers. Users can invoke the mode naturally by asking for a FlowTrace of a PR, branch, diff, or changeset.

## Install locations

The Agent Skills implementation guide documents `.agents/skills/` as a cross-client convention for local skill discovery. Manual install:

```bash
mkdir -p ~/.agents/skills
cp -R skills/flowtrace ~/.agents/skills/flowtrace
```

Project-local install for a repository that should carry the skill with it:

```bash
mkdir -p .agents/skills
cp -R /path/to/flowtrace/skills/flowtrace .agents/skills/flowtrace
```

## skills.sh / Skills CLI assumptions

The public pages on <https://skills.sh/> show install commands in this form:

```bash
npx skills add https://github.com/<owner>/<repo> --skill <skill-name>
```

Examples published there store skills under a top-level `skills/<skill-name>/SKILL.md` path. This repository follows that layout with `skills/flowtrace/SKILL.md` so the expected publish command is:

```bash
npx skills add https://github.com/ebrakke/flowtrace --skill flowtrace
```

The GitHub repository is public at `https://github.com/ebrakke/flowtrace`. If skills.sh indexing is required, submit or wait for indexing according to the current skills.sh process.

## Validation

If the reference validator is available, run:

```bash
skills-ref validate ./skills/flowtrace
```

Without `skills-ref`, the minimal manual checks are:

```bash
test -f skills/flowtrace/SKILL.md
grep -q '^name: flowtrace$' skills/flowtrace/SKILL.md
```
