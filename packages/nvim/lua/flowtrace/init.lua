local parser = require('flowtrace.parser')
local tree = require('flowtrace.tree')
local window = require('flowtrace.window')
local actions = require('flowtrace.actions')
local agent = require('flowtrace.agent')

local M = {}
local state = { expanded = {}, agent_chat = {}, config = { agent = nil } }
local ns = vim.api.nvim_create_namespace('flowtrace')

local function flow_files()
  local files = vim.fn.glob('.flowtrace/*.flow.json', false, true)
  table.sort(files, function(a, b)
    local uv = vim.uv or vim.loop
    local astat = uv.fs_stat(a)
    local bstat = uv.fs_stat(b)
    local atime = astat and astat.mtime and astat.mtime.sec or 0
    local btime = bstat and bstat.mtime and bstat.mtime.sec or 0
    if atime == btime then return a < b end
    return atime < btime
  end)
  return files
end

local function current_flow_index(files)
  local current = state.path and vim.fn.fnamemodify(state.path, ':p') or nil
  for i, file in ipairs(files) do
    if vim.fn.fnamemodify(file, ':p') == current then return i end
  end
  return nil
end

local function setup_highlights()
  -- Explicit colors instead of only linking to theme groups. Some themes make
  -- Directory/Type/Comment very close to Normal, which made FlowTrace look flat.
  vim.api.nvim_set_hl(0, 'FlowTraceTitle', { fg = '#cba6f7', bold = true })
  vim.api.nvim_set_hl(0, 'FlowTraceHelp', { fg = '#6c7086' })
  vim.api.nvim_set_hl(0, 'FlowTraceLabel', { fg = '#cdd6f4' })
  vim.api.nvim_set_hl(0, 'FlowTraceMarker', { fg = '#f5c2e7', bold = true })
  vim.api.nvim_set_hl(0, 'FlowTraceBranch', { fg = '#fab387', italic = true })
  vim.api.nvim_set_hl(0, 'FlowTraceMeta', { fg = '#89b4fa' })
  vim.api.nvim_set_hl(0, 'FlowTraceFile', { fg = '#a6e3a1' })
  vim.api.nvim_set_hl(0, 'FlowTraceSummary', { fg = '#9399b2' })
end

local function redraw()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local lines, index, highlights = tree.render(state.flow, state.expanded)
  state.index = index
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, hl in ipairs(highlights or {}) do
    vim.api.nvim_buf_set_extmark(state.buf, ns, hl.row, hl.col, {
      end_col = hl.end_col,
      hl_group = hl.group,
      priority = 100,
    })
  end
  vim.bo[state.buf].modifiable = false
end

local function map(lhs, rhs)
  vim.keymap.set('n', lhs, rhs, { buffer = state.buf, silent = true })
end

local function setup_keys()
  map('<CR>', function() actions.jump(state) end)
  map('a', function() agent.ask_node(state) end)
  map('A', function() agent.ask_flow(state) end)
  map('C', function() agent.clear_chat(state) end)
  map('p', function() actions.preview(state) end)
  map('f', function() M.next() end)
  map('F', function() M.prev() end)
  map(']f', function() M.next() end)
  map('[f', function() M.prev() end)
  map('?', function() actions.details(state) end)
  map('q', function() M.close() end)
  map('r', function() M.refresh() end)
  map('o', function()
    local item = state.index[vim.api.nvim_win_get_cursor(state.win)[1]]
    if item then state.expanded[item.id] = state.expanded[item.id] == false and true or false; redraw() end
  end)
end

function M.setup(opts)
  opts = opts or {}
  if opts.agent == false then
    state.config.agent = nil
  elseif opts.agent then
    state.config.agent = vim.tbl_deep_extend('force', agent.defaults(), opts.agent)
  end
end

function M.open(path)
  setup_highlights()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_win_get_buf(current_win)
  if vim.bo[current_buf].filetype ~= 'flowtrace' then
    state.source_win = current_win
  end
  state.path = path
  state.flow = parser.load(path)
  state.expanded = state.expanded or {}
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.win and vim.api.nvim_win_is_valid(state.win) then
    redraw()
    return
  end
  state.buf, state.win = window.open_buffer()
  setup_keys()
  redraw()
end

function M.last()
  local files = flow_files()
  if #files == 0 then error('FlowTrace: no .flowtrace/*.flow.json found') end
  M.open(files[#files])
end

function M.next()
  local files = flow_files()
  if #files == 0 then error('FlowTrace: no .flowtrace/*.flow.json found') end
  local idx = current_flow_index(files) or 0
  M.open(files[(idx % #files) + 1])
end

function M.prev()
  local files = flow_files()
  if #files == 0 then error('FlowTrace: no .flowtrace/*.flow.json found') end
  local idx = current_flow_index(files) or (#files + 1)
  M.open(files[((idx - 2) % #files) + 1])
end

function M.refresh()
  if not state.path then return end
  state.flow = parser.load(state.path)
  redraw()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
end

function M.ask()
  agent.ask_node(state)
end

function M.ask_flow()
  agent.ask_flow(state)
end

function M.chat()
  agent.show_chat(state)
end

function M.chat_clear()
  agent.clear_chat(state)
end

return M
