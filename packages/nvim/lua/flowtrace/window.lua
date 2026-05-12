local M = {}

local function configure_buffer(buf, filetype)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype
end

local function configure_window(win, cursorline)
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].cursorline = cursorline
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
end

function M.open_buffer()
  local width = math.max(50, math.floor(vim.o.columns * 0.42))
  vim.cmd('topleft vertical ' .. width .. 'new')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  configure_buffer(buf, 'flowtrace')
  configure_window(win, true)
  return buf, win
end

function M.open_detail_buffer(tree_win)
  if tree_win and vim.api.nvim_win_is_valid(tree_win) then
    vim.api.nvim_set_current_win(tree_win)
  end
  local height = math.max(7, math.min(12, math.floor(vim.o.lines * 0.22)))
  vim.cmd('belowright ' .. height .. 'new')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  configure_buffer(buf, 'flowtrace-detail')
  configure_window(win, false)
  vim.api.nvim_win_set_height(win, height)
  if tree_win and vim.api.nvim_win_is_valid(tree_win) then
    vim.api.nvim_set_current_win(tree_win)
  end
  return buf, win
end

return M
