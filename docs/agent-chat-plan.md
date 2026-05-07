# FlowTrace Agent Chat Plan

## Goal

Add an optional in-Neovim chat panel so a developer can ask quick contextual questions while exploring a FlowTrace artifact, without leaving the current code/navigation context.

Example questions:

- "What does this node mean in the context of the whole app?"
- "Why is this branch important?"
- "How does this step relate to the previous node?"
- "What should I inspect next?"

The feature should preserve the core FlowTrace principle: the user builds understanding by walking real source code, with lightweight agent help available on demand.

## Product shape

FlowTrace already provides:

1. agent-authored `.flow.json` artifacts
2. CLI validation/terminal preview
3. Neovim tree navigation

Agent chat adds:

1. current node / whole flow context collection
2. an external configurable agent command
3. a floating markdown chat window
4. a lightweight chat transcript preserved across asks
5. explicit chat clearing when the user wants a fresh conversation

## Non-goals for MVP

- Do not build a full chat client inside Neovim.
- Do not require a specific agent provider.
- Do not implement every agent's native session protocol.
- Do not let the plugin modify files.
- Do not depend on FlowTrace CLI LLM calls; the CLI remains deterministic.
- Do not make the agent responsible for generating the original flow artifact in this feature. This is for questions while exploring an existing artifact.

## Session model

Use FlowTrace-managed chat memory by default.

The plugin stores an in-memory transcript, e.g.:

```lua
state.agent_chat = {
  { role = "user", content = "What does this mean?" },
  { role = "assistant", content = "This node coordinates..." },
}
```

Each new ask sends:

- current flow context
- current node context, when relevant
- nearby source context
- flow outline
- recent chat transcript
- new user question

This gives follow-up continuity even when the external command is stateless, e.g. `pi -p` or `claude -p`.

### Why not native sessions first?

Every coding agent has a different session model:

- Pi supports saved sessions and print mode (`pi -p`).
- Claude Code has its own session behavior.
- Codex/opencode may use different flags or persistence models.
- Some tools are simple stdin/stdout transforms.

A FlowTrace-managed transcript is portable and good enough for MVP. Native agent session support can be added later as an optional mode.

## UX

### Commands

Add these commands:

```vim
:FlowTraceAsk       " ask about current node
:FlowTraceAskFlow   " ask about entire flow
:FlowTraceChat      " reopen/show current chat window
:FlowTraceChatClear " clear transcript
```

### Keymaps inside the FlowTrace tree

Suggested defaults:

```text
a   ask about current node
A   ask about whole flow
C   clear FlowTrace chat
```

Existing keymaps should remain:

```text
<CR> jump
o    expand/collapse
f    next flow
F    previous flow
p    preview
?    details
r    reload
q    close
```

Update the help line in the tree buffer to mention chat succinctly, for example:

```text
<CR> jump • a ask • A ask flow • C clear chat • f/F flows • o toggle • q close
```

## Floating chat window

Use a floating markdown buffer.

Behavior:

1. User presses `a` or `A`.
2. Prompt with `vim.ui.input({ prompt = "Ask FlowTrace: " }, callback)`.
3. Open/reuse a floating markdown chat window.
4. Append the user question and `Thinking...`.
5. Run the configured external agent command.
6. Replace `Thinking...` with the answer.
7. Store both user question and assistant answer in `state.agent_chat`.
8. `q` or `<Esc>` closes the floating window, but transcript remains.
9. `C` / `:FlowTraceChatClear` clears transcript and optionally closes or refreshes chat window.

Suggested window options:

```lua
vim.api.nvim_open_win(buf, true, {
  relative = "editor",
  width = math.min(96, math.floor(vim.o.columns * 0.70)),
  height = math.min(28, math.floor(vim.o.lines * 0.55)),
  row = math.floor(vim.o.lines * 0.15),
  col = math.floor(vim.o.columns * 0.15),
  style = "minimal",
  border = "rounded",
  title = " FlowTrace Chat ",
  title_pos = "center",
})
```

Set:

```lua
vim.bo[buf].filetype = "markdown"
vim.wo[win].wrap = true
vim.wo[win].linebreak = true
```

## Agent command configuration

Add setup config to `require("flowtrace").setup(...)`.

Example public/default shape:

```lua
require("flowtrace").setup({
  agent = {
    command = "pi",
    args = { "-p" },
    prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
    timeout_ms = 60000,
    max_chat_turns = 6,
  },
})
```

For Claude:

```lua
require("flowtrace").setup({
  agent = {
    command = "claude",
    args = { "-p" },
    prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
  },
})
```

For Pi, based on Pi docs:

```bash
pi -p "Summarize this codebase"
cat README.md | pi -p "Summarize this text"
```

So the plugin should execute Pi like:

```lua
vim.system({ "pi", "-p", "Answer the user's FlowTrace question using the context from stdin." }, {
  stdin = prompt_context,
  text = true,
}, callback)
```

Prefer stdin for the large structured context and a short static instruction as the final CLI argument.

### Config fields

Initial fields:

```lua
agent = {
  command = "pi",              -- executable
  args = { "-p" },             -- args before prompt_arg
  prompt_arg = "...",          -- optional final prompt arg
  timeout_ms = 60000,
  max_chat_turns = 6,
}
```

Potential future fields:

```lua
agent = {
  enabled = true,
  cwd = nil,                    -- default vim.loop.cwd()
  env = {},
  input = "stdin",              -- only stdin for MVP
  native_session = false,        -- future
}
```

## Prompt/context construction

Create a new module:

```text
packages/nvim/lua/flowtrace/agent.lua
```

Suggested functions:

```lua
local M = {}

function M.ask_node(state) end
function M.ask_flow(state) end
function M.show_chat(state) end
function M.clear_chat(state) end

function M.build_prompt(state, question, scope) end
function M.run(config, prompt, callback) end

return M
```

### Current node context

For `ask_node`, include:

- flow title/id
- current node id
- label
- kind/type
- file and stored line
- anchor
- symbol
- summary
- children labels
- branch labels/targets
- nearby source around resolved location

### Whole flow context

For `ask_flow`, include:

- flow title/id
- full outline of labels/kinds/files
- summaries for all nodes
- current node, if one is selected
- nearby source for current node only, to avoid huge prompts

### Nearby source

Use the same anchor resolution strategy as jump:

1. find `node.anchor` in the file
2. fallback to `node.symbol`
3. fallback to `node.line`

Then include maybe 30-80 lines around the resolved line.

Pseudo:

```lua
local radius = 30
local start = math.max(1, line - radius)
local finish = math.min(#lines, line + radius)
```

Include line numbers in the snippet.

### Flow outline

Render a compact outline from the graph, independent of current expansion state:

```text
- Agent researches the code and writes a FlowTrace artifact (agent) skills/flowtrace/SKILL.md:20
  - Artifact follows the FlowTrace schema (artifact) packages/cli/internal/core/schema.go:10
    - User or agent runs flowtrace validate (cli) packages/cli/cmd/flowtrace/main.go:22
```

Avoid infinite recursion with a `seen` map.

### Chat transcript

Include only the most recent `max_chat_turns` turns to avoid prompt bloat.

Format:

```md
## Previous chat

User: ...
Assistant: ...
```

## Full prompt template

```md
You are helping a developer understand code while they explore a FlowTrace walkthrough.

Rules:
- Be concise and practical.
- Ground your answer in the provided flow/source context.
- Explain how the current node fits into the larger flow.
- If the context is insufficient, say what file/function to inspect next.
- Do not modify files.

## User question

{question}

## Scope

{current-node|whole-flow}

## Flow

Title: {flow.title}
Artifact: {state.path}

## Current node

Label: {node.label}
Type: {node.kind}
File: {node.file}:{node.line}
Anchor: {node.anchor}
Symbol: {node.symbol}
Summary: {node.summary}

Children:
- ...

Branches:
- ...

## Nearby source

```text
{line-numbered snippet}
```

## Flow outline

```text
{outline}
```

## Previous chat

{recent transcript}
```

## Running the external command

Use `vim.system` when available.

Pseudo:

```lua
local cmd = { config.command }
vim.list_extend(cmd, config.args or {})
if config.prompt_arg and config.prompt_arg ~= "" then
  table.insert(cmd, config.prompt_arg)
end

local done = false
local timer = nil
if config.timeout_ms then
  timer = vim.uv.new_timer()
  timer:start(config.timeout_ms, 0, function()
    if not done then
      -- kill process if possible / mark timeout
    end
  end)
end

vim.system(cmd, {
  stdin = prompt,
  text = true,
  cwd = vim.fn.getcwd(),
}, function(result)
  done = true
  if timer then timer:stop(); timer:close() end
  vim.schedule(function()
    if result.code ~= 0 then
      -- show stderr/stdout error in chat window
    else
      -- append result.stdout
    end
  end)
end)
```

MVP can skip hard process killing if that complicates things. It should at least show that the request timed out or failed.

## Error handling

If no agent configured:

```text
FlowTrace agent is not configured. Add require("flowtrace").setup({ agent = { command = "pi", args = { "-p" } } })
```

If command missing:

```text
Could not run agent command: pi
Install/configure it, or update require("flowtrace").setup({ agent = ... })
```

If command exits nonzero, show:

- exit code
- stderr
- first part of stdout if present

## Implementation steps

1. Add `setup(opts)` to `lua/flowtrace/init.lua` and merge defaults.
2. Add `agent.lua` module.
3. Add state fields:

   ```lua
   state.agent_chat = {}
   state.agent_win = nil
   state.agent_buf = nil
   ```

4. Add commands in `plugin/flowtrace.lua`:

   ```lua
   :FlowTraceAsk
   :FlowTraceAskFlow
   :FlowTraceChat
   :FlowTraceChatClear
   ```

5. Add tree keymaps:

   ```lua
   a -> ask_node
   A -> ask_flow
   C -> clear_chat
   ```

6. Build prompt context.
7. Run external command through `vim.system`.
8. Render/update floating markdown chat buffer.
9. Update README install/config examples with Pi and Claude snippets.
10. Validate with:

   ```bash
   luac -p packages/nvim/plugin/flowtrace.lua packages/nvim/lua/flowtrace/*.lua
   go test ./packages/cli/...
   ```

## Suggested README example

```lua
return {
  {
    "ebrakke/flowtrace",
    name = "flowtrace.nvim",
    lazy = false,
    config = function(plugin)
      vim.opt.runtimepath:append(plugin.dir .. "/packages/nvim")
      vim.cmd("runtime plugin/flowtrace.lua")

      require("flowtrace").setup({
        agent = {
          command = "pi",
          args = { "-p" },
          prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
        },
      })
    end,
  },
}
```

Claude alternative:

```lua
require("flowtrace").setup({
  agent = {
    command = "claude",
    args = { "-p" },
    prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
  },
})
```

## Open future improvements

- Native session integration per agent.
- Persist transcript per artifact on disk under `.flowtrace/`.
- Streaming output into the floating window.
- Ask about selected source range in the code window.
- Let answer include suggested next FlowTrace node to jump to.
- Optional repo-inspection mode for agents that can safely run tools.
