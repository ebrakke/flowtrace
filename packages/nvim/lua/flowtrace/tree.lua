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

local function add_highlight(highlights, row, col, text, group)
  if text and text ~= '' then
    table.insert(highlights, { row = row, col = col, end_col = col + #text, group = group })
  end
end

local function display_file(path)
  if not path or path == '' then return '?' end
  return path
end

local function location_text(node)
  return display_file(node.file) .. ':' .. tostring(node.line or '?')
end

local function meta_text(node)
  local parts = {}
  if node.kind then table.insert(parts, 'type: ' .. node.kind) end
  if node.resolution and node.resolution ~= 'manual' then table.insert(parts, 'source: ' .. node.resolution) end
  if node.confidence and node.confidence > 0 and node.confidence < 0.75 then table.insert(parts, 'low confidence') end
  return table.concat(parts, ' • ')
end

local function child_count(node)
  return #(node.children or {}) + #(node.branches or {})
end

local function add_annotation(lines, index, highlights, prefix, id, node, text, group)
  if not text or text == '' then return end
  add_line(lines, index, highlights, prefix .. '   ' .. text, id, node, group)
end

local function add_node(lines, index, highlights, flow, expanded, id, prefix, is_last, branch_label, seen)
  local node = flow.nodes[id]
  if not node then return end

  local is_open = expanded[id] ~= false
  local has_children = child_count(node) > 0
  local connector = is_last and '└─ ' or '├─ '
  local child_prefix = prefix .. (is_last and '   ' or '│  ')
  local marker = has_children and (is_open and '▾ ' or '▸ ') or ''
  local branch = branch_label and ('↳ ' .. branch_label .. ': ') or ''
  local location = location_text(node)

  local row = add_line(lines, index, highlights, prefix .. connector .. marker .. branch .. location, id, node, 'FlowTraceFile')
  add_highlight(highlights, row, #prefix, connector:gsub('%s+$', ''), 'FlowTraceMarker')
  add_highlight(highlights, row, #prefix + #connector, marker:gsub('%s+$', ''), 'FlowTraceMarker')
  if branch_label then
    add_highlight(highlights, row, #prefix + #connector + #marker, branch, 'FlowTraceBranch')
  end

  add_annotation(lines, index, highlights, child_prefix, id, node, node.label or id, 'FlowTraceLabel')

  local meta = meta_text(node)
  add_annotation(lines, index, highlights, child_prefix, id, node, meta, 'FlowTraceMeta')

  local summary = clean(node.summary)
  add_annotation(lines, index, highlights, child_prefix, id, node, summary, 'FlowTraceSummary')

  if seen[id] then
    add_annotation(lines, index, highlights, child_prefix, id, node, 'already shown', 'FlowTraceMeta')
    return
  end
  if not is_open then return end
  seen[id] = true

  local children = {}
  for _, child in ipairs(node.children or {}) do
    table.insert(children, { id = child })
  end
  for _, br in ipairs(node.branches or {}) do
    table.insert(children, { id = br.target, branch_label = br.label })
  end

  for i, child in ipairs(children) do
    add_node(lines, index, highlights, flow, expanded, child.id, child_prefix, i == #children, child.branch_label, seen)
  end
end

function M.render(flow, expanded)
  local lines = {}
  local index = {}
  local highlights = {}
  expanded = expanded or {}

  add_line(lines, index, highlights, 'Flow: ' .. (flow.title or flow.id or 'untitled'), nil, nil, 'FlowTraceTitle')
  add_line(lines, index, highlights, 'Press <CR> jump • a ask • A ask flow • C clear chat • f/F flows • o toggle • q close', nil, nil, 'FlowTraceHelp')
  add_line(lines, index, highlights, '', nil, nil, nil)
  add_node(lines, index, highlights, flow, expanded, flow.root, '', true, nil, {})

  return lines, index, highlights
end

return M
