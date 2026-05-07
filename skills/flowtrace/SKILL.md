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

Use this skill when the user wants a source-level code walkthrough that they can navigate, not just a prose explanation. FlowTrace creates `.flow.json` artifacts containing real repository file paths, line numbers, labels, anchors, branches, confidence, and resolution metadata.

Do not treat FlowTrace as runtime tracing, instrumentation, log analysis, distributed tracing, profiling, or observability telemetry. The output is a static code walkthrough artifact for developer exploration.

## Important model boundary

You, the coding agent, do the research and reasoning. Do not expect the FlowTrace CLI to call an LLM or infer the final flow for you. The CLI is a deterministic artifact helper: it gathers candidate context, creates rough search scaffolds, validates artifacts, and prints trees.

## Workflow

1. Confirm the repository root and the flow to trace. Ask a brief clarification only if the request is ambiguous.
2. Gather candidate context from the repository root:

   ```bash
   flowtrace context --root . "walk me through the data flow for running this query"
   ```

3. Inspect the relevant files yourself with your normal code-reading tools. Decide the real flow nodes, labels, child order, branches, summaries, and anchors.
4. Write `.flowtrace/<slug>.flow.json` yourself. Prefer nodes with stable jump metadata:

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

5. Validate the artifact:

   ```bash
   flowtrace validate --root . .flowtrace/<slug>.flow.json
   ```

6. Optionally inspect the walkthrough in the terminal:

   ```bash
   flowtrace print .flowtrace/<slug>.flow.json
   ```

7. Tell the user how to open it in Neovim:

   ```vim
   :FlowTraceOpen .flowtrace/<slug>.flow.json
   ```

## Scaffold option

If you want a rough starting artifact, run:

```bash
flowtrace build --root . --out .flowtrace/<slug>.flow.json "walk me through the data flow for running this query"
```

Treat this as a search-based scaffold only. Review and edit it before presenting it as the final walkthrough.

## Output expectations

Return a concise summary with:

- artifact path
- validation command and result
- Neovim open command
- caveats for nodes marked `search` or low confidence

If validation fails, report the validation error and do not present the artifact as ready to use.
