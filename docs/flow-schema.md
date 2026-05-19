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
  "thesis": "Indexing correctness depends on a job-produced search document, persisted version fields, and cache lookup keys staying in sync.",
  "investigation": {
    "goal": "Understand indexing before removing versioning",
    "lens": "change-impact",
    "question": "What would it mean to remove versioning?",
    "openQuestions": ["Which cache keys depend on version?"]
  },
  "sections": [
    {
      "title": "Core indexing lifecycle",
      "summary": "The shortest path through the behavior under investigation.",
      "nodes": ["node-1", "node-2"]
    }
  ],
  "concepts": [],
  "impact": null,
  "testScenarios": [],
  "confidenceChecks": [],
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

Optional decision-oriented fields:

- `thesis`: one-sentence system model that frames the trace. Broad “understand deeply” traces should be organized around this, not merely around the lowest-level entrypoint.
- `investigation`: records the user's goal, selected lens, original question, and open questions to pursue.
- `sections`: optional conceptual groupings of node ids, such as “Core workflow”, “Domain model”, or “Confidence checks”. Sections let a trace be consumed by lifecycle/concept instead of only by parent-child call order.
- `concepts`: domain concepts detected or authored for the flow, including locations, node ids, users, risks, and confidence.
- `impact`: structured blast-radius notes for a contemplated change.
- `testScenarios`: behavioral scenarios that would prove the flow or change is correct.
- `confidenceChecks`: prompts a reader can use to verify their mental model, such as predicting a validation failure or explaining why a layer would need to change.

## Section object

```json
{
  "title": "Domain model and contracts",
  "summary": "Persisted entities, fields, schemas, cache keys, indexes, or external resources that determine correctness.",
  "nodes": ["schema-node", "cache-key-node"]
}
```

Each `nodes` entry must reference an existing node id.

## Confidence check object

```json
{
  "name": "predict the blast radius",
  "prompt": "If versioning is removed, which service/domain/schema/cache/test areas should change?",
  "success": "The answer separates directly observed dependencies from inferred ones.",
  "node": "version-service"
}
```

`node` is optional, but if present it must reference an existing node id.

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
  "relevance": "boilerplate",
  "evidence": "Request enters here, but the bug likely lives downstream.",
  "tags": ["expand-if-symptom-points-here"],
  "symbol": "runQuery",
  "anchor": "function runQuery(query)",
  "resolution": "llm_validated",
  "children": ["node-2"],
  "branches": [{ "label": "cache hit", "target": "node-cache" }]
}
```

Required node fields: `id`, `label`, `kind`, `file`, `line`, and `resolution`.

Optional decision fields:

- `relevance`: one of `core`, `domain`, `supporting`, `boilerplate`, `test`, or `unclear`. Consumers can use this to collapse low-signal sections and emphasize the user's investigation goal.
- `evidence`: short explanation of why the node was included or how confident the author is.
- `tags`: free-form labels such as `core-workflow`, `data-model`, or `expand-if-symptom-points-here`.

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
