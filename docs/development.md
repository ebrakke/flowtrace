# Development

## Prerequisites

- Go 1.22+
- Neovim 0.9+ for plugin smoke testing

## Common commands

```bash
go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . .flowtrace/cli-and-nvim-paths.flow.json
go run ./packages/cli/cmd/flowtrace print .flowtrace/cli-and-nvim-paths.flow.json
go run ./packages/cli/cmd/flowtrace context --root . "walk through flowtrace validation"
go run ./packages/cli/cmd/flowtrace build --root . "walk through flowtrace validation"
```

## Repository conventions

- Curated repository walkthroughs live in `.flowtrace/*.flow.json`; avoid committing one-off scratch traces unless they are useful demos.
- Use the project skill at `.pi/skills/update-flowtraces/SKILL.md` when code/docs changes may make checked-in walkthroughs stale.
- Keep the CLI dependency-light; it currently uses the Go standard library.
- The CLI should stay deterministic and should not call LLM providers; coding agents do the research/reasoning.
- The Agent Skill package is canonical at `skills/flowtrace`.
- Plugin UX is still MVP; avoid broad plugin rewrites unless they are the task at hand.

## Manual plugin smoke test

Install `packages/nvim` as a local runtime plugin, open Neovim from the repository root, then run:

```vim
:FlowTraceOpen .flowtrace/cli-and-nvim-paths.flow.json
```

Confirm the tree renders and `<CR>` jumps to files in this repository, such as `packages/cli/cmd/flowtrace/main.go`.
