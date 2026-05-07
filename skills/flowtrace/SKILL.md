---
name: flowtrace
description: Creates validated FlowTrace .flow.json code walkthrough artifacts from natural-language code exploration requests. Use when a user asks to map, trace, explain, or walk through code paths, data flow, request flow, feature implementation, branches, or source-level architecture in a repository.
license: MIT
compatibility: Requires the flowtrace CLI on PATH, installable with go install github.com/ebrakke/flowtrace/packages/cli/cmd/flowtrace@latest. Neovim viewing requires the FlowTrace Lua plugin.
metadata:
  version: "0.1.0"
  project: FlowTrace
---

# FlowTrace

Use this skill when the user wants a source-level code walkthrough that they can navigate, not just a prose explanation. FlowTrace artifacts are `.flow.json` files containing real repository file paths, line numbers, labels, anchors, branches, confidence, and resolution metadata.

Do not treat FlowTrace as runtime tracing, instrumentation, log analysis, distributed tracing, profiling, or observability telemetry. The output is a static code walkthrough artifact for developer exploration.

## Core principle

You, the coding agent, build the understanding. FlowTrace is only the artifact format, validator, terminal previewer, and Neovim viewer.

Do **not** start by asking the FlowTrace CLI to explore a natural-language request. First use your normal code-reading tools to inspect the repository: search, read files, follow imports/callers/callees, inspect tests, and reason about the lifecycle. Only after you understand the flow should you write and validate the `.flow.json` artifact.

## Workflow

1. Confirm the repository root and the flow to trace. Ask a brief clarification only if the request is ambiguous.
2. Research the codebase yourself. Use your own tools to find entrypoints, handlers, services, data transformations, branches, downstream calls, response formatting, and important alternatives. Follow real code references; do not rely on FlowTrace to infer them.
3. Decide the walkthrough structure: root node, important child order, branch targets, labels, summaries, confidence, and resolution values.
4. Write `.flowtrace/<slug>.flow.json` yourself. Create the directory if needed. Prefer stable jump metadata on every node:

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
     "confidence": 0.9,
     "resolution": "manual",
     "children": ["node-2"]
   }
   ```

5. Validate the finished artifact:

   ```bash
   flowtrace validate --root . .flowtrace/<slug>.flow.json
   ```

6. Preview the tree in the terminal:

   ```bash
   flowtrace print .flowtrace/<slug>.flow.json
   ```

7. Fix any validation/preview issues by editing the JSON. Repeat validation until clean.
8. Tell the user how to open it in Neovim:

   ```vim
   :FlowTraceOpen .flowtrace/<slug>.flow.json
   ```

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
- caveats for nodes marked `search`, `llm_inferred`, or low confidence

If validation fails, report the validation error and do not present the artifact as ready to use.
