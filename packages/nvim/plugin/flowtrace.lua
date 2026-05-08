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

vim.api.nvim_create_user_command('FlowTraceNext', function()
  require('flowtrace').next()
end, {})

vim.api.nvim_create_user_command('FlowTracePrev', function()
  require('flowtrace').prev()
end, {})

vim.api.nvim_create_user_command('FlowTraceClose', function()
  require('flowtrace').close()
end, {})

vim.api.nvim_create_user_command('FlowTraceRefresh', function()
  require('flowtrace').refresh()
end, {})

vim.api.nvim_create_user_command('FlowTraceAsk', function()
  require('flowtrace').ask()
end, {})

vim.api.nvim_create_user_command('FlowTraceAskFlow', function()
  require('flowtrace').ask_flow()
end, {})

vim.api.nvim_create_user_command('FlowTraceChat', function()
  require('flowtrace').chat()
end, {})

vim.api.nvim_create_user_command('FlowTraceChatClear', function()
  require('flowtrace').chat_clear()
end, {})

vim.api.nvim_create_user_command('FlowTraceAgentProvider', function(opts)
  require('flowtrace').agent_provider(opts.args)
end, {
  nargs = '?',
  complete = function(arg_lead)
    local out = {}
    for _, name in ipairs(require('flowtrace').agent_provider_names()) do
      if name:sub(1, #arg_lead) == arg_lead then table.insert(out, name) end
    end
    return out
  end,
})
