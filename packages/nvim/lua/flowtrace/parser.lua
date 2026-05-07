local M = {}

function M.load(path)
  local text = table.concat(vim.fn.readfile(path), '\n')
  local ok, flow = pcall(vim.json.decode, text)
  if not ok then
    error('FlowTrace: invalid JSON in ' .. path .. ': ' .. tostring(flow))
  end
  if type(flow) ~= 'table' or type(flow.nodes) ~= 'table' or not flow.root then
    error('FlowTrace: artifact requires root and nodes')
  end
  return flow
end

return M
