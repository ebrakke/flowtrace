local M = {}

local function clean(text)
  return (text or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function add_line(lines, index, highlights, text, id, node, group)
  table.insert(lines, text)
  local row = #lines - 1
  if id then index[#lines] = { id = id, node = node } end
  if group and text ~= '' then
    table.insert(highlights, { row = row, col = 0, end_col = #text, group = group })
  end
  return row
end

local function add_node(lines, index, highlights, flow, expanded, id, depth, branch_label, seen)
  local node = flow.nodes[id]
  if not node then return end

  local is_open = expanded[id] ~= false
  local has_children = #(node.children or {}) > 0 or #(node.branches or {}) > 0
  local marker = has_children and (is_open and '▾ ' or '▸ ') or '  '
  local prefix = string.rep('  ', depth)
  local branch = branch_label and ('↳ ' .. branch_label .. ': ') or ''
  local label = branch .. (node.label or id)

  local label_row = add_line(lines, index, highlights, prefix .. marker .. label, id, node, 'FlowTraceLabel')
  table.insert(highlights, { row = label_row, col = #prefix, end_col = #prefix + #marker, group = 'FlowTraceMarker' })
  if branch_label then
    table.insert(highlights, { row = label_row, col = #prefix + #marker, end_col = #prefix + #marker + #branch, group = 'FlowTraceBranch' })
  end

  local meta_parts = {}
  if node.kind then table.insert(meta_parts, 'type: ' .. node.kind) end
  if node.resolution and node.resolution ~= 'manual' then table.insert(meta_parts, 'source: ' .. node.resolution) end
  if node.confidence and node.confidence > 0 and node.confidence < 0.75 then table.insert(meta_parts, 'low confidence') end
  if #meta_parts > 0 then
    add_line(lines, index, highlights, prefix .. '  ' .. table.concat(meta_parts, ' • '), id, node, 'FlowTraceMeta')
  end
  add_line(lines, index, highlights, prefix .. '  file: ' .. (node.file or '?') .. ':' .. tostring(node.line or '?'), id, node, 'FlowTraceFile')

  local summary = clean(node.summary)
  if summary ~= '' then
    add_line(lines, index, highlights, prefix .. '  ' .. summary, id, node, 'FlowTraceSummary')
  end

  if seen[id] then
    add_line(lines, index, highlights, prefix .. '  ↳ already shown', id, node, 'FlowTraceMeta')
    return
  end
  if not is_open then return end
  seen[id] = true

  for _, child in ipairs(node.children or {}) do
    add_node(lines, index, highlights, flow, expanded, child, depth + 1, nil, seen)
  end
  for _, br in ipairs(node.branches or {}) do
    add_node(lines, index, highlights, flow, expanded, br.target, depth + 1, br.label, seen)
  end
end

function M.render(flow, expanded)
  local lines = {}
  local index = {}
  local highlights = {}
  add_line(lines, index, highlights, 'Flow: ' .. (flow.title or flow.id or 'untitled'), nil, nil, 'FlowTraceTitle')
  add_line(lines, index, highlights, 'Press <CR> jump • o toggle • p preview • ? details • r reload • q close', nil, nil, 'FlowTraceHelp')
  add_line(lines, index, highlights, '', nil, nil, nil)
  add_node(lines, index, highlights, flow, expanded, flow.root, 0, nil, {})
  return lines, index, highlights
end

return M
