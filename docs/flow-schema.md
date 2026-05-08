# FlowTrace Artifact Schema

FlowTrace artifacts are JSON files named `.flowtrace/<slug>.flow.json`.

## Top-level object

```json
{
  "schemaVersion": "0.1",
  "id": "running-query-flow",
  "title": "Data flow for running this query",
  "createdAt": "2026-05-07T12:00:00Z",
  "root": "node-1",
  "nodes": {}
}
```

Required fields:

- `schemaVersion`: currently `0.1`
- `id`: stable artifact identifier
- `title`: human-readable title
- `createdAt`: RFC3339 timestamp
- `root`: id of the root node
- `nodes`: object keyed by node id

## Node object

```json
{
  "id": "node-1",
  "label": "API endpoint receives query request",
  "kind": "entrypoint",
  "file": "src/server/routes/query.ts",
  "line": 24,
  "column": 1,
  "summary": "HTTP entrypoint for running a saved query.",
  "symbol": "runQuery",
  "anchor": "function runQuery(query)",
  "resolution": "llm_validated",
  "children": ["node-2"],
  "branches": [{ "label": "cache hit", "target": "node-cache" }]
}
```

Required node fields: `id`, `label`, `kind`, `file`, `line`, and `resolution`.

Optional location stability fields:

- `anchor`: exact source text to search for at jump time, such as a function declaration
- `symbol`: shorter fallback text/symbol to search for if `anchor` is not found

Consumers should prefer `anchor`, then `symbol`, then the stored `line`. This keeps old artifacts useful when nearby edits shift line numbers.

`resolution` must be one of:

- `lsp`
- `ast`
- `search`
- `llm_inferred`
- `llm_validated`
- `manual`

Line numbers are 1-based. Columns are 1-based in artifacts; the Neovim plugin converts them to Neovim's 0-based cursor column.
