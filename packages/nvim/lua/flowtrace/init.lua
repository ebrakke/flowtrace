local parser = require('flowtrace.parser')
local tree = require('flowtrace.tree')
local window = require('flowtrace.window')
local actions = require('flowtrace.actions')
local agent = require('flowtrace.agent')

local M = {}
local state = {
  expanded = {},
  agent_chat = {},
  config = {
    agent = nil,
    agent_providers = {},
    agent_provider = nil,
    view = { compact = true, detail_panel = true },
  },
}
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
  vim.api.nvim_set_hl(0, 'FlowTraceDetailBorder', { fg = '#45475a' })
  vim.api.nvim_set_hl(0, 'FlowTraceDetailTitle', { fg = '#f9e2af', bold = true })
  vim.api.nvim_set_hl(0, 'FlowTraceDetailSummaryTitle', { fg = '#cba6f7', bold = true })
  vim.api.nvim_set_hl(0, 'FlowTraceDetailSummary', { fg = '#cdd6f4' })
end

local function current_tree_item()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
  return state.index and state.index[vim.api.nvim_win_get_cursor(state.win)[1]] or nil
end

local function selected_id()
  local item = current_tree_item()
  if item then
    state.selected_id = item.id
    return item.id
  end
  return state.selected_id or (state.flow and state.flow.root) or nil
end

local function apply_lines(buf, lines, highlights)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, hl in ipairs(highlights or {}) do
    vim.api.nvim_buf_set_extmark(buf, ns, hl.row, hl.col, {
      end_col = hl.end_col,
      hl_group = hl.group,
      priority = 100,
    })
  end
  vim.bo[buf].modifiable = false
end

local function ensure_detail_window()
  if not state.config.view.detail_panel then return false end
  if state.detail_buf and vim.api.nvim_buf_is_valid(state.detail_buf) and state.detail_win and vim.api.nvim_win_is_valid(state.detail_win) then
    return true
  end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return false end
  state.detail_buf, state.detail_win = window.open_detail_buffer(state.win)
  return true
end

local function redraw_detail()
  if not ensure_detail_window() then return end
  local lines, highlights = tree.render_detail(state.flow, selected_id())
  apply_lines(state.detail_buf, lines, highlights)
end

local function redraw(preserve_cursor)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local cursor = nil
  if preserve_cursor and state.win and vim.api.nvim_win_is_valid(state.win) then
    cursor = vim.api.nvim_win_get_cursor(state.win)
  end
  local lines, index, highlights = tree.render(state.flow, state.expanded, {
    compact = state.config.view.compact,
    detail_panel = false,
    selected_id = selected_id(),
  })
  state.index = index
  apply_lines(state.buf, lines, highlights)
  if cursor and state.win and vim.api.nvim_win_is_valid(state.win) then
    local row = math.min(cursor[1], #lines)
    if row > 0 then vim.api.nvim_win_set_cursor(state.win, { row, cursor[2] }) end
  end
  redraw_detail()
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
    if item then state.expanded[item.id] = state.expanded[item.id] == false and true or false; redraw(true) end
  end)
  map('D', function()
    state.config.view.detail_panel = not state.config.view.detail_panel
    if not state.config.view.detail_panel and state.detail_win and vim.api.nvim_win_is_valid(state.detail_win) then
      vim.api.nvim_win_close(state.detail_win, true)
    end
    redraw(true)
  end)
end

local function sorted_provider_names()
  local names = {}
  for name, _ in pairs(state.config.agent_providers or {}) do table.insert(names, name) end
  table.sort(names)
  return names
end

local function set_agent_provider(name)
  local provider = state.config.agent_providers and state.config.agent_providers[name]
  if not provider then return false end
  state.config.agent_provider = name
  state.config.agent = provider
  return true
end

function M.setup(opts)
  opts = opts or {}
  if opts.view then
    state.config.view = vim.tbl_deep_extend('force', state.config.view, opts.view)
  end
  if opts.agent == false then
    state.config.agent = nil
    state.config.agent_providers = {}
    state.config.agent_provider = nil
    return
  end

  if not opts.agent then return end

  if opts.agent.providers then
    state.config.agent_providers = {}
    for name, provider in pairs(opts.agent.providers) do
      state.config.agent_providers[name] = vim.tbl_deep_extend('force', agent.defaults(), provider)
    end
    local selected = opts.agent.provider or state.config.agent_provider or sorted_provider_names()[1]
    if selected and not set_agent_provider(selected) then
      vim.notify('FlowTrace: unknown agent provider: ' .. tostring(selected), vim.log.levels.WARN)
      selected = sorted_provider_names()[1]
      if selected then set_agent_provider(selected) end
    end
  else
    state.config.agent = vim.tbl_deep_extend('force', agent.defaults(), opts.agent)
    state.config.agent_providers = {}
    state.config.agent_provider = opts.agent.provider
  end
end

function M.agent_provider(name)
  if not name or name == '' then
    local current = state.config.agent_provider or (state.config.agent and state.config.agent.command) or 'none'
    local names = sorted_provider_names()
    local suffix = #names > 0 and (' Available: ' .. table.concat(names, ', ')) or ''
    vim.notify('FlowTrace agent provider: ' .. current .. suffix, vim.log.levels.INFO)
    return current
  end
  if not set_agent_provider(name) then
    error('FlowTrace: unknown agent provider "' .. name .. '"')
  end
  vim.notify('FlowTrace agent provider: ' .. name, vim.log.levels.INFO)
  return name
end

function M.agent_provider_names()
  return sorted_provider_names()
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
  state.selected_id = state.flow.root
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.win and vim.api.nvim_win_is_valid(state.win) then
    redraw()
    return
  end
  state.buf, state.win = window.open_buffer()
  setup_keys()
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = state.buf,
    callback = function()
      local item = current_tree_item()
      if item and item.id ~= state.selected_id then
        state.selected_id = item.id
        redraw_detail()
      end
    end,
  })
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
  if state.detail_win and vim.api.nvim_win_is_valid(state.detail_win) then vim.api.nvim_win_close(state.detail_win, true) end
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
