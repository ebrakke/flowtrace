---
name: flowtrace
description: Creates validated FlowTrace .flow.json code walkthrough artifacts from natural-language code exploration requests. Use when a user asks to map, trace, explain, or walk through code paths, data flow, request flow, feature implementation, branches, pull requests, changesets, diffs, or source-level architecture in a repository.
license: MIT
compatibility: Requires the flowtrace CLI on PATH, installable with go install github.com/ebrakke/flowtrace/packages/cli/cmd/flowtrace@latest. Neovim viewing requires the FlowTrace Lua plugin.
metadata:
  version: "0.1.0"
  project: FlowTrace
---

# FlowTrace

Use this skill when the user wants a source-level code walkthrough that they can navigate, not just a prose explanation. FlowTrace artifacts are `.flow.json` files containing real repository file paths, line numbers, labels, anchors, branches, and resolution metadata.

Do not treat FlowTrace as runtime tracing, instrumentation, log analysis, distributed tracing, profiling, or observability telemetry. The output is a static code walkthrough artifact for developer exploration.

## Core principle

You, the coding agent, build the understanding. FlowTrace is only the artifact format, validator, terminal previewer, and Neovim viewer.

Do **not** start by asking the FlowTrace CLI to explore a natural-language request. First use your normal code-reading tools to inspect the repository: search, read files, follow imports/callers/callees, inspect tests, and reason about the lifecycle. Only after you understand the flow should you write and validate the `.flow.json` artifact.

## Before you start: ensure the CLI is available

Check whether `flowtrace` is installed:

```bash
command -v flowtrace
flowtrace --help
```

If it is not installed and Go is available, install it from GitHub:

```bash
go install github.com/ebrakke/flowtrace/packages/cli/cmd/flowtrace@latest
```

If `flowtrace` still is not found, the Go bin directory may not be on `PATH`. Check it with:

```bash
go env GOPATH
```

Then either call the binary directly:

```bash
$(go env GOPATH)/bin/flowtrace --help
```

or tell the user to add this to their shell profile:

```bash
export PATH="$(go env GOPATH)/bin:$PATH"
```

If Go is unavailable or installation fails, continue researching and writing the artifact, but tell the user validation could not be run and include the install error.

## Workflow

1. Confirm the repository root and the flow to trace. Ask a brief clarification only if the request is ambiguous.
2. Ensure the `flowtrace` CLI is available using the check above.
3. Research the codebase yourself. Use your own tools to find entrypoints, handlers, services, data transformations, branches, downstream calls, response formatting, and important alternatives. Follow real code references; do not rely on FlowTrace to infer them.
4. If the request is for a PR, branch, diff, or changeset, use the changeset workflow below before deciding the final tree.
5. Decide the walkthrough structure: root node, important child order, branch targets, labels, summaries, and resolution values.
6. Write `.flowtrace/<slug>.flow.json` yourself. Create the directory if needed. Prefer stable jump metadata on every node:

   ```json
   {
     "id": "node-1",
     "label": "runQuery coordinates execution",
     "kind": "service",
     "file": "src/query.ts",
     "line": 42,
     "column": 1,
     "symbol": "runQuery",
     "anchor": "function runQuery(",
     "summary": "Validates, executes, and formats the query.",
     "resolution": "manual",
     "children": ["node-2"]
   }
   ```

7. Validate the finished artifact:

   ```bash
   flowtrace validate --root . .flowtrace/<slug>.flow.json
   ```

8. Preview the tree in the terminal:

   ```bash
   flowtrace print .flowtrace/<slug>.flow.json
   ```

9. Fix any validation/preview issues by editing the JSON. Repeat validation until clean.
10. Tell the user how to open it in Neovim:

   ```vim
   :FlowTraceOpen .flowtrace/<slug>.flow.json
   ```

## Changeset / PR workflow

Use this mode when the user asks for a FlowTrace of a pull request, branch, patch, diff, or changeset. The goal is not to mirror the implementation chronology or list every changed hunk. The goal is to explain how data now moves through the changed behavior, while making changed code easy to jump to during review.

1. Determine the comparison base. Prefer an explicit base from the user. Otherwise inspect remotes and branches and choose the likely mainline in this order: `origin/main`, `main`, `origin/master`, `master`. If uncertain, ask briefly.
2. Inspect the changed file list and hunks, for example:

   ```bash
   git status --short
   git diff --stat <base>...HEAD
   git diff --name-only <base>...HEAD
   git diff --find-renames <base>...HEAD
   ```

3. Identify the changed symbols, data structures, configuration, schemas, validation rules, IO boundaries, and tests. Then read the surrounding unchanged code needed to understand how data reaches and leaves those changed points.
4. Build the flow from the user's/reviewer's perspective:
   - Start at the external trigger, public API, command, handler, scheduled job, or other data entrypoint that exercises the change.
   - Follow the data through parsing, validation, enrichment, persistence, side effects, downstream calls, and response/output formatting.
   - Include unchanged context nodes when they are necessary to connect changed nodes into a coherent data flow.
   - Prefer nodes that correspond to changed code, changed callers/callees, changed tests, and changed behavior boundaries.
   - Use branches for behavior alternatives introduced or affected by the changeset.
5. Label changed nodes clearly. Start summaries for changed nodes with `Changed:` when the node's referenced lines are part of the diff. Start context-only summaries with `Context:` when the node is unchanged but needed to understand the flow.
6. Do not create a file-by-file diff tour. Skip cosmetic-only edits unless they affect the reviewed data path. If a changed file is intentionally omitted, mention it in the final caveats.
7. Name the artifact after the branch or PR when possible, for example `.flowtrace/pr-123.flow.json` or `.flowtrace/<branch>-changes.flow.json`.

## Optional CLI helpers

These are optional helpers, not the primary workflow:

- `flowtrace context --root . "request"` prints candidate search snippets if you want a quick hint list.
- `flowtrace build --root . --out .flowtrace/<slug>.flow.json "request"` creates a rough search-based scaffold.

Treat CLI-generated scaffolds as disposable drafts. Review and rewrite them before presenting a final walkthrough.

## Output expectations

Return a concise summary with:

- artifact path
- validation command and result
- terminal preview command used
- Neovim open command
- caveats for nodes marked `search` or `llm_inferred`

If validation fails, report the validation error and do not present the artifact as ready to use.
