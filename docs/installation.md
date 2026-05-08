# Installation and Usage

This guide shows how to install FlowTrace from the public GitHub repository, generate or validate a walkthrough artifact, view it in Neovim, and install the Agent Skill.

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

FlowTrace is designed for coding agents. The CLI does not call LLM APIs or infer the final flow from a natural-language request. Your coding agent should first inspect the repository with its normal tools, follow the real code lifecycle, and write `.flowtrace/<slug>.flow.json` itself.

After the agent writes the artifact, use the CLI to validate and preview it:

```bash
flowtrace validate --root . .flowtrace/main-request-flow.flow.json
flowtrace print .flowtrace/main-request-flow.flow.json
```

For a quick deterministic scaffold or hint list, use `build` or `context` as optional helpers:

```bash
flowtrace build \
  --root . \
  --out .flowtrace/flowtrace-build.flow.json \
  "walk through the main request flow"

flowtrace validate --root . .flowtrace/flowtrace-build.flow.json
flowtrace print .flowtrace/flowtrace-build.flow.json
```

Generated artifacts default to `.flowtrace/<slug>.flow.json`. This repository checks in a few curated `.flowtrace/*.flow.json` walkthroughs as demos; local scratch traces can be deleted or kept out of commits as needed.

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

      -- Optional: enable contextual chat with Pi.
      require("flowtrace").setup({
        agent = {
          provider = "pi",
          providers = {
            pi = {
              command = "pi",
              args = { "-p" },
              prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
            },
            claude = {
              command = "claude",
              args = { "-p" },
              prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
            },
          },
        },
      })
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
- `:FlowTraceAsk` opens chat scoped to the current node.
- `:FlowTraceAskFlow` opens chat scoped to the whole flow.
- `:FlowTraceChat` reopens the current chat transcript.
- `:FlowTraceChatClear` clears the in-memory chat transcript.
- `:FlowTraceAgentProvider [name]` shows or switches the chat provider, with completion for configured providers.

In the FlowTrace tree, press `a` to chat about the current node or `A` to chat about the whole flow. The floating chat window keeps its transcript after you close it with `q` or `<Esc>`. Type questions on the bottom `> ` input line and press `<CR>` to send. Switch providers mid-session with commands like `:FlowTraceAgentProvider pi` or `:FlowTraceAgentProvider claude`.

![FlowTrace chat window with inline prompt](assets/flowtrace-chat.png)

## 4. Clone for development and repository walkthroughs

```bash
git clone https://github.com/ebrakke/flowtrace.git
cd flowtrace

go test ./packages/cli/...
go run ./packages/cli/cmd/flowtrace validate --root . .flowtrace/cli-and-nvim-paths.flow.json
go run ./packages/cli/cmd/flowtrace print .flowtrace/cli-and-nvim-paths.flow.json
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

The skill instructs compatible agents to use their own reasoning/code-reading abilities to create a `.flow.json`, then validate and preview it with the FlowTrace CLI.
