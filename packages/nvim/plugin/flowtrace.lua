if vim.g.loaded_flowtrace == 1 then
  return
end
vim.g.loaded_flowtrace = 1

vim.api.nvim_create_user_command('FlowTraceOpen', function(opts)
  require('flowtrace').open(opts.args)
end, { nargs = 1, complete = 'file' })

vim.api.nvim_create_user_command('FlowTraceLast', function()
  require('flowtrace').last()
end, {})

vim.api.nvim_create_user_command('FlowTraceClose', function()
  require('flowtrace').close()
end, {})

vim.api.nvim_create_user_command('FlowTraceRefresh', function()
  require('flowtrace').refresh()
end, {})
