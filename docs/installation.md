# Installation and Usage

This guide shows how to install FlowTrace from a clone, generate a walkthrough artifact, view it in Neovim, and install the Agent Skill.

## 1. Clone and verify

```bash
git clone https://github.com/flowtrace/flowtrace.git
cd flowtrace

go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
```

## 2. Install or run the CLI

Run without installing:

```bash
go run ./packages/cli/cmd/flowtrace print examples/simple.flow.json
```

Install from the checkout:

```bash
go install ./packages/cli/cmd/flowtrace
flowtrace print examples/simple.flow.json
```

Install from GitHub after the project is public and tagged:

```bash
go install github.com/flowtrace/flowtrace/packages/cli/cmd/flowtrace@latest
```

## 3. Generate a FlowTrace artifact

Search-only mode is best for first use because it does not need network access or API keys:

```bash
flowtrace build \
  --root . \
  --provider none \
  --out .flowtrace/flowtrace-build.flow.json \
  "walk through the flowtrace build command"

flowtrace validate --root . .flowtrace/flowtrace-build.flow.json
flowtrace print .flowtrace/flowtrace-build.flow.json
```

LLM-assisted mode can produce better labels and ordering:

```bash
export ANTHROPIC_API_KEY=...
flowtrace build --root . --provider anthropic "walk through the CLI validation path"
```

or:

```bash
export OPENAI_API_KEY=...
flowtrace build --root . --provider openai "walk through the CLI validation path"
```

Generated artifacts default to `.flowtrace/<slug>.flow.json`. They are ignored by git so local traces do not pollute commits.

## 4. Install the Neovim / LazyVim plugin

The plugin currently lives in `packages/nvim`; install that directory as a runtime plugin.

LazyVim/lazy.nvim local checkout example:

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

Native package symlink example from the repository root:

```bash
mkdir -p ~/.local/share/nvim/site/pack/flowtrace/start
ln -s "$PWD/packages/nvim" ~/.local/share/nvim/site/pack/flowtrace/start/flowtrace.nvim
```

Use it from a repository containing a `.flow.json` artifact:

```vim
:FlowTraceOpen .flowtrace/flowtrace-build.flow.json
```

Helpful commands:

- `:FlowTraceOpen <file>` opens a specific artifact.
- `:FlowTraceLast` opens the lexicographically last `.flowtrace/*.flow.json` in the current directory.
- `:FlowTraceRefresh` reloads the current artifact.
- `:FlowTraceClose` closes the FlowTrace window.

## 5. Install the Agent Skill

Manual install for agents that scan `~/.agents/skills`:

```bash
mkdir -p ~/.agents/skills
cp -R skills/flowtrace ~/.agents/skills/flowtrace
```

Skills CLI install after the repository is public:

```bash
npx skills add https://github.com/flowtrace/flowtrace --skill flowtrace
```

The skill instructs compatible agents to use FlowTrace for code walkthrough artifacts: generate a `.flow.json`, validate it, and tell the user how to open it in Neovim.
