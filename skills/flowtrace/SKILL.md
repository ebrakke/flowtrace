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

Use this skill when the user wants a source-level code walkthrough that they can navigate, not just a prose explanation. FlowTrace creates `.flow.json` artifacts containing real repository file paths, line numbers, labels, branches, confidence, and resolution metadata.

Do not treat FlowTrace as runtime tracing, instrumentation, log analysis, distributed tracing, profiling, or observability telemetry. The output is a static code walkthrough artifact for developer exploration.

## Workflow

1. Confirm the repository root and the flow to trace. Ask a brief clarification only if the request is ambiguous.
2. Build a FlowTrace artifact from the repository root:

   ```bash
   flowtrace build --root . "walk me through the data flow for running this query"
   ```

   If `flowtrace` is not installed but the FlowTrace repository is checked out at the current root, run:

   ```bash
   go run ./packages/cli/cmd/flowtrace build --root . "walk me through the data flow for running this query"
   ```

3. Prefer deterministic search-only output when API keys are unavailable or reproducibility matters:

   ```bash
   flowtrace build --root . --provider none --out .flowtrace/query-flow.flow.json "walk me through the data flow for running this query"
   ```

4. Use LLM-assisted output only when the user/environment provides credentials:

   ```bash
   export ANTHROPIC_API_KEY=...
   flowtrace build --root . --provider anthropic "walk through the request flow"
   ```

   or:

   ```bash
   export OPENAI_API_KEY=...
   flowtrace build --root . --provider openai "walk through the request flow"
   ```

5. Validate the artifact path printed by `build`:

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

## Output expectations

Return a concise summary with:

- artifact path
- validation command and result
- Neovim open command
- caveats for nodes marked `search` or `llm_inferred`

If validation fails, report the validation error and do not present the artifact as ready to use.
