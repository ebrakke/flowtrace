# FlowTrace Technical MVP

## Goal

Build a tool that turns a natural-language code exploration request into a jumpable Neovim walkthrough.

Example request:

```text
Walk me through the data flow for running this query.
```

The tool should produce:

```text
.flowtrace/running-query.flow.json
```

Then Neovim should open an interactive tree where every node jumps to real code.

The core product principle:

> AI prepares an interactive code walkthrough; the developer builds understanding by walking the actual source code.

---

## Architecture

```text
┌────────────────────┐
│ LLM / Agent / CLI  │
│ "trace this flow"  │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ flowtrace build    │
│ repo analysis      │
└─────────┬──────────┘
          │ writes
          ▼
┌────────────────────┐
│ .flow.json artifact│
└─────────┬──────────┘
          │ opened by
          ▼
┌────────────────────┐
│ Neovim plugin      │
│ interactive tree   │
└────────────────────┘
```

MVP components:

1. **`flowtrace` CLI**
   - accepts a natural-language request
   - searches the repository for candidate context
   - emits deterministic scaffold `.flow.json` artifacts
   - validates file paths, symbols, references, and line numbers
   - prints artifacts for terminal debugging

FlowTrace intentionally leaves LLM reasoning to the calling coding agent (Claude Code, Codex, Cursor, etc.). The CLI is an artifact/context/validation tool, not an LLM client.

2. **Neovim plugin**
   - opens a `.flow.json` artifact
   - renders an interactive tree view
   - allows jump-to-code
   - supports expand/collapse
   - shows confidence and resolution metadata

---

## MVP Scope

### In scope

#### CLI

```bash
flowtrace build "walk through the data flow for running this query"
```

Outputs:

```bash
.flowtrace/running-this-query.flow.json
```

The CLI should:

- collect repository context
- emit candidate snippets with `flowtrace context`
- create a deterministic search scaffold with `flowtrace build`
- validate every file path exists
- validate child/branch references
- support stable anchors/symbols for jump-time resolution
- emit structured JSON

#### Neovim

Commands:

```vim
:FlowTraceOpen .flowtrace/running-this-query.flow.json
:FlowTraceLast
```

Tree panel supports:

- expand/collapse nodes
- jump to node location with `<CR>`
- preview node with `p`
- show node details with `?`

### Out of scope for first MVP

- full static data-flow analysis
- perfect TypeScript type resolution
- live bidirectional LLM chat inside Neovim
- automatic runtime tracing
- graph rendering
- editing flow maps inside Neovim
- multi-language perfection

---

## Initial Technology Choices

### CLI

MVP language: **Go**

Reasons:

- simple distribution as a single CLI binary
- strong standard-library support for JSON, validation, and filesystem walking
- works well as a repository-agnostic tool across language ecosystems
- can still shell out to `ripgrep`, LSP servers, or language-specific analyzers later

Initial implementation uses only the Go standard library. Potential later additions:

```text
cobra or urfave/cli       # richer CLI UX
ripgrep integration       # faster search
tree-sitter bindings      # multi-language AST anchors
LSP client integration    # symbol resolution
```

### Neovim plugin

Recommended language: **Lua**

Initial structure:

```text
packages/nvim/
  plugin/flowtrace.lua
  lua/flowtrace/
    init.lua
    parser.lua
    tree.lua
    window.lua
    actions.lua
```

Use plain Neovim APIs first. Avoid heavy dependencies for the MVP.

---

## Flow Artifact Schema

Artifacts live at:

```text
.flowtrace/<slug>.flow.json
```

Example:

```json
{
  "schemaVersion": "0.1",
  "id": "running-query-flow",
  "title": "Data flow for running this query",
  "createdAt": "2026-05-07T12:00:00Z",
  "root": "node-1",
  "nodes": {
    "node-1": {
      "id": "node-1",
      "label": "API endpoint receives query request",
      "kind": "entrypoint",
      "file": "src/server/routes/query.ts",
      "line": 24,
      "column": 1,
      "summary": "HTTP entrypoint for running a saved query.",
      "confidence": 0.91,
      "resolution": "llm_validated",
      "children": ["node-2"]
    },
    "node-2": {
      "id": "node-2",
      "label": "queryService.runQuery",
      "kind": "service",
      "file": "src/server/query/queryService.ts",
      "line": 88,
      "column": 3,
      "summary": "Coordinates query validation, SQL generation, execution, and formatting.",
      "confidence": 0.86,
      "resolution": "llm_inferred",
      "children": ["node-3", "node-4"],
      "branches": [
        {
          "label": "if cached result exists",
          "target": "node-cache"
        },
        {
          "label": "if query must execute",
          "target": "node-3"
        }
      ]
    }
  }
}
```

Required node shape:

```ts
type FlowNode = {
  id: string
  label: string
  kind: string
  file: string
  line: number
  column?: number
  summary?: string
  confidence?: number
  resolution: "lsp" | "ast" | "search" | "llm_inferred" | "llm_validated" | "manual"
  children?: string[]
  branches?: FlowBranch[]
  alternatives?: FlowAlternative[]
}
```

---

## CLI MVP Design

### Commands

#### `flowtrace build`

```bash
flowtrace build "walk through the data flow for running this query"
```

Options:

```bash
--root .
--out .flowtrace/query.flow.json
--max-files 80
--max-nodes 40
--dry-run
```

#### `flowtrace context`

```bash
flowtrace context "walk through the data flow for running this query"
```

Prints candidate files/snippets for a coding agent to use while authoring a high-quality `.flow.json` artifact.

#### `flowtrace validate`

```bash
flowtrace validate .flowtrace/query.flow.json
```

Checks:

- JSON schema is valid
- all files exist
- all line numbers are in range
- each node has label, kind, file, and line
- children and branches point to real node IDs

#### `flowtrace print`

```bash
flowtrace print .flowtrace/query.flow.json
```

Renders the tree in the terminal for debugging.

---

## Build Pipeline

### Step 1: Gather repository context

Given a request like:

```text
walk through the data flow for running this query
```

Run search queries derived from the request.

For MVP:

- split meaningful terms
- search exact phrases
- search likely symbols/routes
- search filenames

Example:

```bash
rg -n "runQuery|run query|queryService|executeQuery|saved query|query"
```

Collect candidate files.

### Step 2: Extract snippets

For each candidate file:

- include relevant matching lines
- include surrounding context
- include the whole file if it is small enough

Limit total tokens.

### Step 3: Agent authors the flow

The calling coding agent uses the candidate snippets plus its own code-reading tools to author strict `.flow.json`. Each node should reference a real file and preferably include a stable `anchor` and/or `symbol` for jump-time resolution.

Agent-authored nodes include:

- label
- file
- line
- symbol and/or text anchor
- summary
- children
- branches

`flowtrace build` can emit a deterministic search scaffold, but this is intentionally not treated as the final intelligent flow.

### Step 4: Validate locations

For each draft node:

1. ensure file exists
2. resolve line by:
   - exact symbol search
   - text anchor search
   - fallback to first relevant match
3. reject or mark unresolved nodes
4. normalize paths

### Step 5: Emit artifact

Write:

```text
.flowtrace/<slug>.flow.json
```

Optionally also write debug output:

```text
.flowtrace/<slug>.debug.md
```

---

## Neovim Plugin MVP

### Commands

```vim
:FlowTraceOpen {file}
:FlowTraceLast
:FlowTraceClose
:FlowTraceRefresh
```

### Tree rendering

Example buffer:

```text
Flow: Data flow for running this query

▾ API endpoint receives query request                     91%  entrypoint
  ▾ queryService.runQuery                                86%  service
    ├─ branch: if cached result exists
    └─ branch: if query must execute
       ▸ buildSqlFromQuery
       ▸ warehouseClient.execute
       ▸ formatQueryResults
```

### Keymaps in tree buffer

```text
<CR>  jump to file:line
o     expand/collapse
p     preview location
?     show details
r     reload flow file
q     close
```

### Jump behavior

When user presses `<CR>`:

```lua
vim.cmd("edit " .. node.file)
vim.api.nvim_win_set_cursor(0, { node.line, node.column or 0 })
```

Optionally keep the tree open in a side split.

---

## Repository Layout

```text
flowtrace/
  README.md
  docs/
    mvp.md
    flow-schema.md
  packages/
    cli/
      go.mod
      cmd/flowtrace/main.go
      internal/core/
        build.go
        llm.go
        print.go
        schema.go
        validate.go
    nvim/
      plugin/flowtrace.lua
      lua/flowtrace/
        init.lua
        window.lua
        tree.lua
        parser.lua
        actions.lua
  examples/
    simple-ts-app/
```

---

## Implementation Milestones

### Milestone 1: Static artifact + Neovim viewer

No LLM yet.

Tasks:

- define schema
- create sample `.flow.json`
- build Neovim tree viewer
- jump to files/lines

Success criteria:

```vim
:FlowTraceOpen examples/simple.flow.json
```

opens a navigable tree and jumps correctly.

### Milestone 2: CLI validation and print

Tasks:

- implement `flowtrace validate`
- implement `flowtrace print`
- schema checking in Go

Success criteria:

```bash
flowtrace validate .flowtrace/foo.flow.json
flowtrace print .flowtrace/foo.flow.json
```

works.

### Milestone 3: Agent-authored draft flow

Tasks:

- implement `flowtrace context "request"`
- implement deterministic `flowtrace build "request"` scaffolds
- add repository search
- add snippet collection
- document the Agent Skill workflow where the calling coding agent authors the final JSON
- add artifact emission

Success criteria:

A coding agent can use FlowTrace CLI context/validation to produce a usable flow for a small repository.

### Milestone 4: Better resolution

Tasks:

- validate file paths
- resolve symbols to exact lines
- mark confidence and resolution source
- include alternatives for ambiguous calls

### Milestone 5: Branch support in UI

Tasks:

- render branches separately
- jump to branch targets
- collapse branches by default

---

## Recommended First Build Order

1. Create `flowtrace.nvim` viewer against hand-written JSON.
2. Create schema and sample flow file.
3. Add `flowtrace validate`.
4. Add `flowtrace context` and deterministic `flowtrace build` scaffolding.
5. Iterate on real repository examples.

This avoids getting stuck on analysis before proving the editor UX.

---

## MVP Definition of Done

We have an MVP when this works:

```bash
flowtrace build "walk me through the data flow for running this query"
```

Then:

```vim
:FlowTraceOpen .flowtrace/running-query.flow.json
```

And the user can:

- see a meaningful flow tree
- jump to real code files
- walk the main path
- inspect branches
- distinguish inferred vs validated nodes
- build understanding through source navigation, not prose summaries
