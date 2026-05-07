local parser = require('flowtrace.parser')
local tree = require('flowtrace.tree')
local window = require('flowtrace.window')
local actions = require('flowtrace.actions')

local M = {}
local state = { expanded = {} }
local ns = vim.api.nvim_create_namespace('flowtrace')

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
  map('p', function() actions.preview(state) end)
  map('?', function() actions.details(state) end)
  map('q', function() M.close() end)
  map('r', function() M.refresh() end)
  map('o', function()
    local item = state.index[vim.api.nvim_win_get_cursor(state.win)[1]]
    if item then state.expanded[item.id] = state.expanded[item.id] == false and true or false; redraw() end
  end)
end

function M.open(path)
  setup_highlights()
  state.source_win = vim.api.nvim_get_current_win()
  state.path = path
  state.flow = parser.load(path)
  state.expanded = state.expanded or {}
  state.buf, state.win = window.open_buffer()
  setup_keys()
  redraw()
end

function M.last()
  local files = vim.fn.glob('.flowtrace/*.flow.json', false, true)
  table.sort(files)
  local path = files[#files]
  if not path then error('FlowTrace: no .flowtrace/*.flow.json found') end
  M.open(path)
end

function M.refresh()
  if not state.path then return end
  state.flow = parser.load(state.path)
  redraw()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
end

return M
