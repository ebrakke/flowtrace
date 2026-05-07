# FlowTrace

FlowTrace turns natural-language code exploration requests into validated, jumpable code walkthrough artifacts.

Instead of asking an LLM for only a prose summary of a codebase, FlowTrace produces a `.flow.json` map of real source files, functions, branches, and data transformations. The CLI generates and validates the artifact; the Neovim plugin opens it as an interactive tree you can jump through.

Status: early MVP. The CLI is usable today with deterministic search-only output or optional LLM assistance. The Neovim plugin is intentionally small and is installed from a local checkout for now.

## Repository layout

```text
packages/cli/        Go CLI: build, validate, and print FlowTrace artifacts
packages/nvim/       Neovim/LazyVim plugin runtime files
skills/flowtrace/    Agent Skill package compatible with the Agent Skills spec
docs/                schema, install, development, and release notes
examples/            sample app and sample .flow.json artifact
```

## Requirements

- Go 1.22+
- Neovim 0.9+ for the plugin
- Optional: `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` for LLM-assisted traces
- Optional: Node.js/npm only if you install the Agent Skill with `npx skills`

## Quick start from a clone

```bash
git clone https://github.com/flowtrace/flowtrace.git
cd flowtrace

go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
go run ./packages/cli/cmd/flowtrace print examples/simple.flow.json
```

Generate a deterministic search-only walkthrough for this repository:

```bash
go run ./packages/cli/cmd/flowtrace build \
  --root . \
  --provider none \
  --out .flowtrace/flowtrace-build.flow.json \
  "walk through the flowtrace build command"

go run ./packages/cli/cmd/flowtrace validate --root . .flowtrace/flowtrace-build.flow.json
```

Open the artifact in Neovim after installing the plugin:

```vim
:FlowTraceOpen .flowtrace/flowtrace-build.flow.json
```

## Install the CLI

From a checkout:

```bash
go install ./packages/cli/cmd/flowtrace
flowtrace print examples/simple.flow.json
```

From GitHub after the repository is public and tagged:

```bash
go install github.com/flowtrace/flowtrace/packages/cli/cmd/flowtrace@latest
```

CLI commands:

```bash
flowtrace build [--root .] [--out .flowtrace/name.flow.json] [--provider none|auto|anthropic|openai] "request"
flowtrace validate [--root .] FILE.flow.json
flowtrace print FILE.flow.json
```

Provider notes:

- `--provider none` is deterministic and uses repository search results only.
- `--provider auto` uses `ANTHROPIC_API_KEY` first, then `OPENAI_API_KEY`, if available.
- `--provider anthropic` and `--provider openai` require the matching API key.

## Install the Neovim / LazyVim plugin

The MVP plugin lives in `packages/nvim`, so install it from a local clone or symlink that directory into Neovim's runtime path.

With LazyVim/lazy.nvim from a local checkout:

```lua
-- ~/.config/nvim/lua/plugins/flowtrace.lua
return {
  {
    dir = vim.fn.expand('~/src/flowtrace/packages/nvim'),
    name = 'flowtrace.nvim',
    lazy = false,
  },
}
```

With native packages from a local checkout:

```bash
mkdir -p ~/.local/share/nvim/site/pack/flowtrace/start
ln -s "$PWD/packages/nvim" ~/.local/share/nvim/site/pack/flowtrace/start/flowtrace.nvim
```

Commands:

```vim
:FlowTraceOpen path/to/file.flow.json
:FlowTraceLast
:FlowTraceRefresh
:FlowTraceClose
```

Default keys in the FlowTrace tree: `<CR>` jump, `o` expand/collapse, `p` preview, `?` details, `r` refresh, `q` close.

## Install the Agent Skill

The canonical skill package is `skills/flowtrace/SKILL.md`. It follows the Agent Skills spec: the folder name and `name` frontmatter are both `flowtrace`.

Install manually for agents that scan the cross-client convention:

```bash
mkdir -p ~/.agents/skills
cp -R skills/flowtrace ~/.agents/skills/flowtrace
```

Install with the Skills CLI after the GitHub repository is public:

```bash
npx skills add https://github.com/flowtrace/flowtrace --skill flowtrace
```

See [`docs/agent-skill.md`](docs/agent-skill.md) for assumptions and validation notes.

## Documentation

- [`docs/installation.md`](docs/installation.md) - detailed install and usage notes
- [`docs/flow-schema.md`](docs/flow-schema.md) - `.flow.json` schema
- [`docs/agent-skill.md`](docs/agent-skill.md) - Agent Skill packaging notes
- [`docs/development.md`](docs/development.md) - contributor/development workflow
- [`docs/release.md`](docs/release.md) - MVP release checklist
- [`docs/mvp.md`](docs/mvp.md) - original technical MVP plan

## License

MIT. See [`LICENSE`](LICENSE).
