local M = {}

local non_code_filetypes = {
  flowtrace = true,
  ['neo-tree'] = true,
  ['NvimTree'] = true,
  ['oil'] = true,
  ['snacks_picker'] = true,
  ['snacks_explorer'] = true,
  ['TelescopePrompt'] = true,
  ['TelescopeResults'] = true,
  ['lazy'] = true,
  ['mason'] = true,
  ['help'] = true,
  ['qf'] = true,
}

local function current_item(state)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
  return state.index[vim.api.nvim_win_get_cursor(state.win)[1]]
end

local function is_code_window(win, state)
  if not win or not vim.api.nvim_win_is_valid(win) or win == state.win then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= '' then return false end
  if non_code_filetypes[vim.bo[buf].filetype] then return false end
  return true
end

local function code_window(state)
  if is_code_window(state.source_win, state) then
    return state.source_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_code_window(win, state) then
      state.source_win = win
      return win
    end
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  end
  vim.cmd('rightbelow vertical new')
  state.source_win = vim.api.nvim_get_current_win()
  return state.source_win
end

local function escape_pattern(text)
  return text:gsub('([^%w])', '%%%1')
end

local function find_in_buffer(buf, needle)
  if not needle or needle == '' then return nil end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Plain substring match first. This makes anchors robust and avoids Vim/regex escaping surprises.
  for i, line in ipairs(lines) do
    local col = line:find(needle, 1, true)
    if col then return i, col end
  end

  -- Then a whitespace-tolerant match for anchors copied from code but reformatted slightly.
  local pattern = escape_pattern(needle):gsub('%%s%+', '%%s+')
  for i, line in ipairs(lines) do
    local col = line:find(pattern)
    if col then return i, col end
  end

  return nil
end

local function resolve_location(buf, node)
  local line, col = find_in_buffer(buf, node.anchor)
  if line then return line, col, 'anchor' end

  line, col = find_in_buffer(buf, node.symbol)
  if line then return line, col, 'symbol' end

  return node.line or 1, node.column or 1, 'line'
end

function M.jump(state)
  local item = current_item(state)
  if not item then return end
  local node = item.node
  local tree_win = state.win
  local target_win = code_window(state)
  vim.api.nvim_set_current_win(target_win)
  vim.cmd('edit ' .. vim.fn.fnameescape(node.file))
  local buf = vim.api.nvim_win_get_buf(target_win)
  local line, col = resolve_location(buf, node)
  vim.api.nvim_win_set_cursor(target_win, { line, math.max(col - 1, 0) })
  vim.cmd('normal! zz')
  if tree_win and vim.api.nvim_win_is_valid(tree_win) then
    state.win = tree_win
  end
end

function M.preview(state)
  local item = current_item(state)
  if not item then return end
  local node = item.node
  local target_win = code_window(state)
  vim.api.nvim_set_current_win(target_win)
  vim.cmd('edit ' .. vim.fn.fnameescape(node.file))
  local buf = vim.api.nvim_win_get_buf(target_win)
  local line = resolve_location(buf, node)
  vim.cmd('pedit +' .. tostring(line) .. ' ' .. vim.fn.fnameescape(node.file))
end

function M.details(state)
  local item = current_item(state)
  if not item then return end
  local n = item.node
  local lines = {
    '# ' .. (n.label or item.id),
    '',
    '- type: ' .. tostring(n.kind),
    '- file: `' .. tostring(n.file) .. ':' .. tostring(n.line) .. '`',
    '- jump anchor: `' .. tostring(n.anchor or n.symbol or '') .. '`',
  }
  if n.resolution and n.resolution ~= 'manual' then
    table.insert(lines, '- source: ' .. tostring(n.resolution))
  end
  if n.confidence and n.confidence > 0 and n.confidence < 0.75 then
    table.insert(lines, '- confidence: ' .. tostring(n.confidence))
  end
  table.insert(lines, '')
  table.insert(lines, n.summary or '')

  local width = math.min(84, math.max(50, math.floor(vim.o.columns * 0.55)))
  local height = math.min(#lines + 2, math.max(10, math.floor(vim.o.lines * 0.35)))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' FlowTrace node ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', function() vim.api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
end

return M
