# Development

## Prerequisites

- Go 1.22+
- Neovim 0.9+ for plugin smoke testing
- Optional API key for LLM-assisted CLI builds

## Common commands

```bash
go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
go run ./packages/cli/cmd/flowtrace print examples/simple.flow.json
go run ./packages/cli/cmd/flowtrace build --root . --provider none "walk through flowtrace validation"
```

## Repository conventions

- Generated local artifacts belong in `.flowtrace/*.flow.json` and are gitignored.
- Keep the CLI dependency-light; it currently uses the Go standard library.
- Avoid committing secrets. LLM providers read API keys from environment variables.
- The Agent Skill package is canonical at `skills/flowtrace`.
- Plugin UX is still MVP; avoid broad plugin rewrites unless they are the task at hand.

## Manual plugin smoke test

Install `packages/nvim` as a local runtime plugin, open Neovim from the repository root, then run:

```vim
:FlowTraceOpen examples/simple.flow.json
```

Confirm the tree renders and `<CR>` jumps to `examples/simple-go-app/main.go`.
