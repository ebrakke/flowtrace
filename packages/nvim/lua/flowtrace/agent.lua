local M = {}

local agent_defaults = {
  command = 'pi',
  args = { '-p' },
  prompt_arg = "Answer the user's FlowTrace question using the context from stdin.",
  timeout_ms = 60000,
  max_chat_turns = 6,
}

function M.defaults()
  return vim.deepcopy(agent_defaults)
end

local function current_item(state)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
  if not state.index then return nil end
  return state.index[vim.api.nvim_win_get_cursor(state.win)[1]]
end

local function clean(text)
  return (text or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function node_id(state, node)
  if not node then return nil end
  if node.id then return node.id end
  for id, candidate in pairs(state.flow.nodes or {}) do
    if candidate == node then return id end
  end
  return nil
end

local function branch_lines(state, node)
  local lines = {}
  for _, br in ipairs(node and node.branches or {}) do
    local target = state.flow.nodes[br.target] or {}
    table.insert(lines, '- ' .. tostring(br.label or '?') .. ' -> ' .. tostring(br.target or '?') .. ' (' .. tostring(target.label or '') .. ')')
  end
  if #lines == 0 then return 'None' end
  return table.concat(lines, '\n')
end

local function child_lines(state, node)
  local lines = {}
  for _, child in ipairs(node and node.children or {}) do
    local target = state.flow.nodes[child] or {}
    table.insert(lines, '- ' .. tostring(child) .. ': ' .. tostring(target.label or ''))
  end
  if #lines == 0 then return 'None' end
  return table.concat(lines, '\n')
end

local function read_source_lines(file)
  if not file or file == '' or vim.fn.filereadable(file) ~= 1 then return nil end
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then return nil end
  return lines
end

local function escape_pattern(text)
  return text:gsub('([^%w])', '%%%1')
end

local function find_in_lines(lines, needle)
  if not needle or needle == '' then return nil end
  for i, line in ipairs(lines) do
    if line:find(needle, 1, true) then return i end
  end
  local pattern = escape_pattern(needle):gsub('%%s%+', '%%s+')
  for i, line in ipairs(lines) do
    if line:find(pattern) then return i end
  end
  return nil
end

local function resolve_line(lines, node)
  if not lines or not node then return nil end
  return find_in_lines(lines, node.anchor) or find_in_lines(lines, node.symbol) or node.line or 1
end

local function nearby_source(node, radius)
  if not node then return 'No current node.' end
  local lines = read_source_lines(node.file)
  if not lines then return 'Could not read source file: ' .. tostring(node.file or '') end
  local line = resolve_line(lines, node)
  if not line then return 'Could not resolve source location.' end
  radius = radius or 30
  local start_line = math.max(1, line - radius)
  local finish_line = math.min(#lines, line + radius)
  local out = {}
  for i = start_line, finish_line do
    table.insert(out, string.format('%5d  %s', i, lines[i]))
  end
  return table.concat(out, '\n')
end

local function outline_node(flow, id, depth, branch_label, seen, out)
  local node = flow.nodes[id]
  if not node then return end
  local prefix = string.rep('  ', depth) .. '- '
  local branch = branch_label and ('[' .. branch_label .. '] ') or ''
  table.insert(out, prefix .. branch .. tostring(node.label or id) .. ' (' .. tostring(node.kind or '?') .. ') ' .. tostring(node.file or '?') .. ':' .. tostring(node.line or '?'))
  local summary = clean(node.summary)
  if summary ~= '' then table.insert(out, string.rep('  ', depth + 1) .. summary) end
  if seen[id] then
    table.insert(out, string.rep('  ', depth + 1) .. '(already shown)')
    return
  end
  seen[id] = true
  for _, child in ipairs(node.children or {}) do
    outline_node(flow, child, depth + 1, nil, seen, out)
  end
  for _, br in ipairs(node.branches or {}) do
    outline_node(flow, br.target, depth + 1, br.label, seen, out)
  end
end

local function flow_outline(flow)
  local out = {}
  if flow and flow.root then outline_node(flow, flow.root, 0, nil, {}, out) end
  return table.concat(out, '\n')
end

local function recent_transcript(state, max_turns)
  local chat = state.agent_chat or {}
  if #chat == 0 then return 'None' end
  local max_messages = math.max(0, (max_turns or 6) * 2)
  local start = math.max(1, #chat - max_messages + 1)
  local lines = {}
  for i = start, #chat do
    local msg = chat[i]
    local role = msg.role == 'assistant' and 'Assistant' or 'User'
    table.insert(lines, role .. ': ' .. tostring(msg.content or ''))
  end
  return table.concat(lines, '\n\n')
end

local function node_section(state, node)
  if not node then return 'No current node selected.' end
  return table.concat({
    'ID: ' .. tostring(node_id(state, node) or ''),
    'Label: ' .. tostring(node.label or ''),
    'Type: ' .. tostring(node.kind or ''),
    'File: ' .. tostring(node.file or '') .. ':' .. tostring(node.line or ''),
    'Anchor: ' .. tostring(node.anchor or ''),
    'Symbol: ' .. tostring(node.symbol or ''),
    'Summary: ' .. tostring(node.summary or ''),
    '',
    'Children:',
    child_lines(state, node),
    '',
    'Branches:',
    branch_lines(state, node),
  }, '\n')
end

function M.build_prompt(state, question, scope)
  local item = current_item(state)
  local node = item and item.node or nil
  local config = (state.config and state.config.agent) or {}
  local flow = state.flow or {}
  return table.concat({
    'You are helping a developer understand code while they explore a FlowTrace walkthrough.',
    '',
    'Rules:',
    '- Be concise and practical.',
    '- Ground your answer in the provided flow/source context.',
    '- Explain how the current node fits into the larger flow.',
    '- If the context is insufficient, say what file/function to inspect next.',
    '- Do not modify files.',
    '',
    '## User question',
    question,
    '',
    '## Scope',
    scope,
    '',
    '## Flow',
    'Title: ' .. tostring(flow.title or flow.id or 'untitled'),
    'ID: ' .. tostring(flow.id or ''),
    'Artifact: ' .. tostring(state.path or ''),
    '',
    '## Current node',
    node_section(state, node),
    '',
    '## Nearby source',
    '```text',
    nearby_source(node, 30),
    '```',
    '',
    '## Flow outline',
    '```text',
    flow_outline(flow),
    '```',
    '',
    '## Previous chat',
    recent_transcript(state, config.max_chat_turns or agent_defaults.max_chat_turns),
  }, '\n')
end

local submit_question

local function chat_scope(state)
  return state.agent_scope == 'whole-flow' and 'whole-flow' or 'current-node'
end

local function chat_lines(state)
  local lines = { '# FlowTrace Chat', '' }
  table.insert(lines, '_Scope: ' .. chat_scope(state) .. ' • type on the `> ` line and press <CR> to send • q closes_')
  table.insert(lines, '')

  if not state.agent_chat or #state.agent_chat == 0 then
    table.insert(lines, '_No chat yet._')
    table.insert(lines, '')
  else
    for _, msg in ipairs(state.agent_chat) do
      if msg.role == 'user' then
        table.insert(lines, '## You')
      else
        table.insert(lines, '## FlowTrace Agent')
      end
      table.insert(lines, '')
      for line in tostring(msg.content or ''):gmatch('([^\n]*)\n?') do
        if line == '' then
          table.insert(lines, '')
        else
          table.insert(lines, line)
        end
      end
      table.insert(lines, '')
    end
  end

  table.insert(lines, '---')
  table.insert(lines, '## Ask')
  table.insert(lines, state.agent_busy and '> Thinking...' or '> ')
  return lines
end

local function focus_input(state, start_insert)
  if not state.agent_buf or not vim.api.nvim_buf_is_valid(state.agent_buf) then return end
  if not state.agent_win or not vim.api.nvim_win_is_valid(state.agent_win) then return end
  local line_count = vim.api.nvim_buf_line_count(state.agent_buf)
  local line = vim.api.nvim_buf_get_lines(state.agent_buf, line_count - 1, line_count, false)[1] or '> '
  local col = math.max(#line, 2)
  vim.api.nvim_win_set_cursor(state.agent_win, { line_count, col })
  if start_insert then vim.cmd('startinsert!') end
end

local function render_chat(state, keep_cursor)
  if not state.agent_buf or not vim.api.nvim_buf_is_valid(state.agent_buf) then return end
  vim.bo[state.agent_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.agent_buf, 0, -1, false, chat_lines(state))
  vim.bo[state.agent_buf].modifiable = true
  if state.agent_win and vim.api.nvim_win_is_valid(state.agent_win) and not keep_cursor then
    focus_input(state, false)
  end
end

function M.show_chat(state, scope)
  if scope then state.agent_scope = scope end
  state.agent_scope = state.agent_scope or 'current-node'
  if not state.agent_chat then state.agent_chat = {} end
  if not state.agent_buf or not vim.api.nvim_buf_is_valid(state.agent_buf) then
    state.agent_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.agent_buf].buftype = 'nofile'
    vim.bo[state.agent_buf].bufhidden = 'hide'
    vim.bo[state.agent_buf].swapfile = false
    vim.bo[state.agent_buf].filetype = 'markdown'
    vim.bo[state.agent_buf].modifiable = true
    vim.keymap.set('n', 'q', function()
      if state.agent_win and vim.api.nvim_win_is_valid(state.agent_win) then vim.api.nvim_win_close(state.agent_win, true) end
    end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('n', '<Esc>', function()
      if state.agent_win and vim.api.nvim_win_is_valid(state.agent_win) then vim.api.nvim_win_close(state.agent_win, true) end
    end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('n', '<CR>', function() submit_question(state) end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('n', 'i', function() focus_input(state, true) end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('n', 'a', function() focus_input(state, true) end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('n', 'o', function() focus_input(state, true) end, { buffer = state.agent_buf, silent = true })
    vim.keymap.set('i', '<CR>', function()
      vim.cmd('stopinsert')
      vim.schedule(function() submit_question(state) end)
    end, { buffer = state.agent_buf, silent = true })
  end
  if not state.agent_win or not vim.api.nvim_win_is_valid(state.agent_win) then
    local width = math.min(96, math.floor(vim.o.columns * 0.70))
    local height = math.min(28, math.floor(vim.o.lines * 0.55))
    state.agent_win = vim.api.nvim_open_win(state.agent_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = math.floor(vim.o.lines * 0.15),
      col = math.floor(vim.o.columns * 0.15),
      style = 'minimal',
      border = 'rounded',
      title = ' FlowTrace Chat ',
      title_pos = 'center',
    })
    vim.wo[state.agent_win].wrap = true
    vim.wo[state.agent_win].linebreak = true
  else
    vim.api.nvim_set_current_win(state.agent_win)
  end
  render_chat(state)
  focus_input(state, true)
end

function M.clear_chat(state)
  state.agent_chat = {}
  render_chat(state)
  vim.notify('FlowTrace chat cleared', vim.log.levels.INFO)
end

function M.run(config, prompt, callback)
  if not config or not config.command or config.command == '' then
    callback(false, 'FlowTrace agent is not configured. Add require("flowtrace").setup({ agent = { command = "pi", args = { "-p" } } })')
    return
  end
  if vim.fn.executable(config.command) ~= 1 then
    callback(false, 'Could not run agent command: ' .. config.command .. '\nInstall/configure it, or update require("flowtrace").setup({ agent = ... })')
    return
  end
  local cmd = { config.command }
  vim.list_extend(cmd, config.args or {})
  if config.prompt_arg and config.prompt_arg ~= '' then table.insert(cmd, config.prompt_arg) end

  local done = false
  local timed_out = false
  local timer = nil
  local proc = nil
  if config.timeout_ms and config.timeout_ms > 0 then
    local uv = vim.uv or vim.loop
    timer = uv.new_timer()
    timer:start(config.timeout_ms, 0, function()
      if done then return end
      timed_out = true
      if proc and proc.kill then
        pcall(function() proc:kill(15) end)
      elseif type(proc) == 'number' then
        pcall(vim.fn.jobstop, proc)
      end
    end)
  end

  if vim.system then
    proc = vim.system(cmd, {
      stdin = prompt,
      text = true,
      cwd = config.cwd or vim.fn.getcwd(),
      env = config.env,
    }, function(result)
      done = true
      if timer then timer:stop(); timer:close() end
      vim.schedule(function()
        if timed_out then
          callback(false, 'Agent request timed out after ' .. tostring(config.timeout_ms) .. 'ms.')
        elseif result.code ~= 0 then
          local err = 'Agent command exited with code ' .. tostring(result.code) .. '.'
          if result.stderr and result.stderr ~= '' then err = err .. '\n\nstderr:\n' .. result.stderr end
          if result.stdout and result.stdout ~= '' then err = err .. '\n\nstdout:\n' .. result.stdout:sub(1, 2000) end
          callback(false, err)
        else
          callback(true, result.stdout or '')
        end
      end)
    end)
  else
    local stdout = {}
    local stderr = {}
    proc = vim.fn.jobstart(cmd, {
      cwd = config.cwd or vim.fn.getcwd(),
      env = config.env,
      stdin = 'pipe',
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then stdout = data end
      end,
      on_stderr = function(_, data)
        if data then stderr = data end
      end,
      on_exit = function(_, code)
        done = true
        if timer then timer:stop(); timer:close() end
        vim.schedule(function()
          local out = table.concat(stdout or {}, '\n')
          local errout = table.concat(stderr or {}, '\n')
          if timed_out then
            callback(false, 'Agent request timed out after ' .. tostring(config.timeout_ms) .. 'ms.')
          elseif code ~= 0 then
            local err = 'Agent command exited with code ' .. tostring(code) .. '.'
            if errout ~= '' then err = err .. '\n\nstderr:\n' .. errout end
            if out ~= '' then err = err .. '\n\nstdout:\n' .. out:sub(1, 2000) end
            callback(false, err)
          else
            callback(true, out)
          end
        end)
      end,
    })
    if proc <= 0 then
      done = true
      if timer then timer:stop(); timer:close() end
      callback(false, 'Could not run agent command: ' .. config.command)
      return
    end
    vim.fn.chansend(proc, prompt)
    vim.fn.chanclose(proc, 'stdin')
  end
end

submit_question = function(state)
  if not state.flow then
    vim.notify('FlowTrace: open a flow first', vim.log.levels.WARN)
    return
  end
  if state.agent_busy then
    vim.notify('FlowTrace: agent is still thinking', vim.log.levels.WARN)
    return
  end
  if not state.agent_buf or not vim.api.nvim_buf_is_valid(state.agent_buf) then return end

  local line_count = vim.api.nvim_buf_line_count(state.agent_buf)
  local line = vim.api.nvim_buf_get_lines(state.agent_buf, line_count - 1, line_count, false)[1] or ''
  local question = line:gsub('^>%s?', ''):gsub('^%s+', ''):gsub('%s+$', '')
  if question == '' or question == 'Thinking...' then
    focus_input(state, true)
    return
  end

  local scope = chat_scope(state)
  local prompt = M.build_prompt(state, question, scope)
  state.agent_chat = state.agent_chat or {}
  table.insert(state.agent_chat, { role = 'user', content = question })
  table.insert(state.agent_chat, { role = 'assistant', content = 'Thinking...' })
  local assistant_index = #state.agent_chat
  state.agent_busy = true
  render_chat(state)
  M.run(state.config and state.config.agent or nil, prompt, function(ok, answer)
    local content = answer or ''
    if ok then content = content:gsub('^%s+', ''):gsub('%s+$', '') end
    state.agent_chat[assistant_index] = { role = 'assistant', content = content }
    state.agent_busy = false
    render_chat(state)
  end)
end

local function ask(state, scope)
  if not state.flow then
    vim.notify('FlowTrace: open a flow first', vim.log.levels.WARN)
    return
  end
  M.show_chat(state, scope)
end

function M.ask_node(state)
  ask(state, 'current-node')
end

function M.ask_flow(state)
  ask(state, 'whole-flow')
end

return M
