# Contributing

FlowTrace is an early MVP. Small, focused issues and pull requests are easiest to review.

Before opening a PR, run:

```bash
go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
```

Please keep generated `.flowtrace/*.flow.json` files out of commits unless they are intentional examples. See `docs/development.md` for local setup notes.
