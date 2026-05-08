# Contributing

FlowTrace is an early MVP. Small, focused issues and pull requests are easiest to review.

Before opening a PR, run:

```bash
go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . .flowtrace/cli-and-nvim-paths.flow.json
```

Please commit `.flowtrace/*.flow.json` files only when they are useful repository walkthroughs, not one-off scratch traces. See `docs/development.md` for local setup notes.
