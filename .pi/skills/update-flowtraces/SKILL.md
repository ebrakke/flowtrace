---
name: update-flowtraces
description: "Maintains this repository's checked-in .flowtrace/*.flow.json walkthroughs. Use whenever FlowTrace code, docs, schema, CLI behavior, Neovim plugin behavior, agent skill instructions, or screenshots change and the demo traces may be stale. Also use when the user asks to update example flowtraces, refresh repository walkthroughs, validate traces, or keep demos in sync with code. Prefer a cost-aware workflow: high-capability exploration first, cheaper/mechanical JSON editing second."
license: MIT
compatibility: Requires the flowtrace CLI via go run ./packages/cli/cmd/flowtrace or an installed flowtrace binary. Optional: pi subagents with model overrides for cost-aware delegation.
metadata:
  project: FlowTrace
  version: "0.1.0"
---

# Update FlowTrace Repository Walkthroughs

This repository uses checked-in `.flowtrace/*.flow.json` files as live demos. They should showcase FlowTrace on FlowTrace itself, so keep them accurate when code or docs move.

## Goal

Update only the traces that are affected by the current change. A good trace is:

- navigable: every node points to a real file and line in this repo
- useful: the tree teaches a reader how FlowTrace works, not just where strings appear
- stable: nodes include `anchor` or `symbol` when possible so jumps survive line drift
- current: summaries describe the code as it exists now
- focused: no obsolete concepts such as `confidence`

## Current curated traces

- `.flowtrace/cli-and-nvim-paths.flow.json` — broad walkthrough of the CLI and Neovim paths.
- `.flowtrace/lua-plugin-tree-build.flow.json` — focused walkthrough of Lua tree rendering/plugin behavior.
- `.flowtrace/agentic-plugin-system.flow.json` — deeper walkthrough of the agentic FlowTrace system and plugin interactions.

If you add a new curated trace, make it about this repository's real code and add it to this list.

## Cost-aware workflow

Separate semantic exploration from mechanical JSON editing.

1. **Cheap triage in the parent session.** Inspect the diff and changed files:

   ```bash
   git status --short
   git diff --name-only
   git diff -- . ':(exclude).flowtrace/*.flow.json'
   ```

   Decide which existing traces mention changed files, symbols, anchors, or concepts:

   ```bash
   rg -n "packages/cli|packages/nvim|skills/flowtrace|docs/" .flowtrace
   rg -n "old symbol or concept" .flowtrace
   ```

2. **Use a capable model for exploration when semantics changed.** If the code path, lifecycle, behavior, or architecture changed, have the strongest available model inspect source files and produce a concise update brief. The brief should include:

   - affected trace files and node ids
   - source file/line evidence for each changed claim
   - removed/obsolete concepts
   - recommended new children/branches/summaries
   - validation risks

   If using `pi-subagents`, this is the expensive step. Use `context-builder`, `scout`, or `oracle` with a capable model. Ask for a brief only, not JSON.

3. **Delegate mechanical JSON edits cheaply.** Once the update brief is precise, JSON generation/editing is mostly structural. Use a cheaper model or lightweight `delegate`/`worker` when available. Give it:

   - the exact trace file(s)
   - the update brief
   - the FlowTrace schema expectations
   - the instruction to preserve valid JSON, node ids where practical, and stable anchors

   Do not let the cheaper step invent unexplored code paths. If it finds ambiguity, it should stop and ask for a stronger exploration pass.

4. **Parent reviews and validates.** The parent session owns final quality. Read the diff, run validation, and preview at least one changed trace.

## Inline workflow when not using subagents

1. Read changed code and affected traces yourself.
2. Update only stale nodes/summaries/anchors/branches.
3. Preserve node ids unless a structural rewrite makes new ids clearer.
4. Avoid adding `confidence`; the schema intentionally does not use it.
5. Validate all curated traces.

## Editing guidelines

- Prefer updating existing nodes over rewriting whole files.
- Keep `resolution: "manual"` for human/agent-authored curated nodes.
- Use `resolution: "search"` only for rough scaffold nodes that have not been semantically reviewed.
- Every node needs `id`, `label`, `kind`, `file`, `line`, and `resolution`.
- Add `anchor` for distinctive code text such as `func runBuild(args []string) error` or `function M.render(flow, expanded)`.
- Add `symbol` for shorter fallback jumps such as `runBuild` or `M.render`.
- Branches should explain real alternatives in the code, not arbitrary categories.
- Summaries should be durable explanations, not implementation trivia that will churn every edit.

## Suggested subagent pattern

Use this shape when the update is non-trivial and subagents are available. Override model names to match the local environment and budget.

```text
1. High-capability explorer/context-builder:
   Goal: inspect changed FlowTrace code and affected .flowtrace artifacts; produce an update brief with node ids and evidence. No edits.

2. Cheaper delegate/worker:
   Goal: apply the brief to JSON only. Preserve schema and anchors. Run validation if allowed.

3. Parent:
   Review the JSON diff, run validation and print previews, then fix any issues.
```

Good explorer prompt:

```text
Inspect the current diff and checked-in .flowtrace artifacts. Identify which walkthrough nodes are stale. Return a concise update brief with affected artifact path, node id, current stale text, source evidence with file:line, and the exact replacement intent. Do not edit files.
```

Good cheap editor prompt:

```text
Apply this update brief to the listed .flowtrace/*.flow.json files. Only edit JSON fields mentioned by the brief unless validation requires a small related fix. Preserve valid JSON and existing node ids. Do not invent new code-path claims. Run flowtrace validation and report results.
```

## Validation

Run the bundled helper from the repository root:

```bash
.pi/skills/update-flowtraces/scripts/validate-flowtraces.sh
```

Or run manually:

```bash
go test ./packages/cli/...
for f in .flowtrace/*.flow.json; do
  go run ./packages/cli/cmd/flowtrace validate --root . "$f"
done
```

Preview changed traces:

```bash
go run ./packages/cli/cmd/flowtrace print .flowtrace/cli-and-nvim-paths.flow.json
```

## Final response

Summarize:

- which trace files changed
- what code/docs changes they now reflect
- validation commands and results
- any trace intentionally left unchanged and why
