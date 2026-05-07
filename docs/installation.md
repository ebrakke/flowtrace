# Installation and Usage

This guide shows how to install FlowTrace from the public GitHub repository, generate a walkthrough artifact, view it in Neovim, and install the Agent Skill.

## 1. Install the CLI

Install from GitHub:

```bash
go install github.com/ebrakke/flowtrace/packages/cli/cmd/flowtrace@latest
```

Make sure your Go bin directory is on `PATH`:

```bash
export PATH="$(go env GOPATH)/bin:$PATH"
```

Verify:

```bash
flowtrace --help
```

## 2. Generate a FlowTrace artifact

From any repository you want to explore, search-only mode is best for first use because it does not need network access or API keys:

```bash
flowtrace build \
  --root . \
  --provider none \
  --out .flowtrace/flowtrace-build.flow.json \
  "walk through the main request flow"

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

## 3. Install the Neovim / LazyVim plugin

LazyVim/lazy.nvim install from GitHub:

```lua
-- ~/.config/nvim/lua/plugins/flowtrace.lua
return {
  {
    "ebrakke/flowtrace",
    name = "flowtrace.nvim",
    lazy = false,
    config = function(plugin)
      vim.opt.runtimepath:append(plugin.dir .. "/packages/nvim")
      vim.cmd("runtime plugin/flowtrace.lua")
    end,
  },
}
```

The plugin currently lives in the monorepo subdirectory `packages/nvim`; the `config` block adds that subdirectory to Neovim's runtimepath and sources the plugin file.

Use it from a repository containing a `.flow.json` artifact:

```vim
:FlowTraceOpen .flowtrace/flowtrace-build.flow.json
```

Helpful commands:

- `:FlowTraceOpen <file>` opens a specific artifact.
- `:FlowTraceLast` opens the lexicographically last `.flowtrace/*.flow.json` in the current directory.
- `:FlowTraceRefresh` reloads the current artifact.
- `:FlowTraceClose` closes the FlowTrace window.

## 4. Clone for development or examples

```bash
git clone https://github.com/ebrakke/flowtrace.git
cd flowtrace

go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
go run ./packages/cli/cmd/flowtrace print examples/simple.flow.json
```

If you prefer to use a local checkout of the Neovim plugin while developing it:

```lua
return {
  {
    dir = vim.fn.expand('~/src/flowtrace/packages/nvim'),
    name = 'flowtrace.nvim',
    lazy = false,
  },
}
```

## 5. Install the Agent Skill

Skills CLI install:

```bash
npx skills add https://github.com/ebrakke/flowtrace --skill flowtrace
```

Manual install for agents that scan `~/.agents/skills`:

```bash
git clone https://github.com/ebrakke/flowtrace.git
mkdir -p ~/.agents/skills
cp -R flowtrace/skills/flowtrace ~/.agents/skills/flowtrace
```

The skill instructs compatible agents to use FlowTrace for code walkthrough artifacts: generate a `.flow.json`, validate it, and tell the user how to open it in Neovim.
