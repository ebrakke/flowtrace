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
  return table.concat(parts, ' • ')
end

local function child_count(node)
  return #(node.children or {}) + #(node.branches or {})
end

local function child_summary(node)
  local steps = #(node.children or {})
  local branches = #(node.branches or {})
  local parts = {}
  if steps > 0 then table.insert(parts, tostring(steps) .. (steps == 1 and ' step' or ' steps')) end
  if branches > 0 then table.insert(parts, tostring(branches) .. (branches == 1 and ' branch' or ' branches')) end
  if #parts == 0 then return nil end
  return table.concat(parts, ', ')
end

local function kind_badge(node)
  if not node.kind or node.kind == '' then return '' end
  return ' [' .. node.kind .. ']'
end

local function add_annotation(lines, index, highlights, prefix, id, node, text, group)
  if not text or text == '' then return end
  add_line(lines, index, highlights, prefix .. '   ' .. text, id, node, group)
end

local function children_for(node)
  local children = {}
  for _, child in ipairs(node.children or {}) do
    table.insert(children, { id = child })
  end
  for _, br in ipairs(node.branches or {}) do
    table.insert(children, { id = br.target, branch_label = br.label })
  end
  return children
end

local function add_compact_node(lines, index, highlights, flow, expanded, id, prefix, is_last, branch_label, seen)
  local node = flow.nodes[id]
  if not node then return end

  local is_open = expanded[id] ~= false
  local has_children = child_count(node) > 0
  local connector = is_last and '└─ ' or '├─ '
  local child_prefix = prefix .. (is_last and '   ' or '│  ')
  local marker = has_children and (is_open and '▾ ' or '▸ ') or ''
  local branch = branch_label and ('↳ ' .. branch_label .. ': ') or ''
  local location = location_text(node)
  local label = clean(node.label or id)
  local badge = kind_badge(node)
  local collapsed = (has_children and not is_open) and ('  {' .. child_summary(node) .. '}') or ''
  local repeat_note = seen[id] and '  {already shown}' or ''
  local text = prefix .. connector .. marker .. branch .. location .. '  ' .. label .. badge .. collapsed .. repeat_note

  local row = add_line(lines, index, highlights, text, id, node, nil)
  local col = #prefix
  add_highlight(highlights, row, col, connector:gsub('%s+$', ''), 'FlowTraceMarker')
  col = col + #connector
  add_highlight(highlights, row, col, marker:gsub('%s+$', ''), 'FlowTraceMarker')
  col = col + #marker
  if branch_label then
    add_highlight(highlights, row, col, branch, 'FlowTraceBranch')
    col = col + #branch
  end
  add_highlight(highlights, row, col, location, 'FlowTraceFile')
  col = col + #location + 2
  add_highlight(highlights, row, col, label, 'FlowTraceLabel')
  col = col + #label
  add_highlight(highlights, row, col, badge, 'FlowTraceMeta')
  col = col + #badge
  add_highlight(highlights, row, col, collapsed .. repeat_note, 'FlowTraceSummary')

  if seen[id] or not is_open then return end
  seen[id] = true

  local children = children_for(node)
  for i, child in ipairs(children) do
    add_compact_node(lines, index, highlights, flow, expanded, child.id, child_prefix, i == #children, child.branch_label, seen)
  end
end

local function add_verbose_node(lines, index, highlights, flow, expanded, id, prefix, is_last, branch_label, seen)
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

  local children = children_for(node)
  for i, child in ipairs(children) do
    add_verbose_node(lines, index, highlights, flow, expanded, child.id, child_prefix, i == #children, child.branch_label, seen)
  end
end

local function add_detail_lines(lines, index, highlights, id, node)
  if not node then return end
  add_line(lines, index, highlights, 'Selected: ' .. (node.label or id), nil, nil, 'FlowTraceDetailTitle')

  local context = { location_text(node) }
  local counts = child_summary(node)
  if counts then table.insert(context, counts) end
  add_line(lines, index, highlights, table.concat(context, '  •  '), nil, nil, 'FlowTraceSummary')

  local summary = clean(node.summary)
  if summary ~= '' then
    add_line(lines, index, highlights, '', nil, nil, nil)
    add_line(lines, index, highlights, 'Summary', nil, nil, 'FlowTraceDetailSummaryTitle')
    add_line(lines, index, highlights, summary, nil, nil, 'FlowTraceDetailSummary')
  end
end

local function add_detail_panel(lines, index, highlights, id, node)
  if not node then return end
  add_line(lines, index, highlights, '', nil, nil, nil)
  add_line(lines, index, highlights, '──────────────── selected node ────────────────', nil, nil, 'FlowTraceDetailBorder')
  add_detail_lines(lines, index, highlights, id, node)
end

function M.render_detail(flow, id)
  local lines = {}
  local highlights = {}
  if flow and id then
    add_detail_lines(lines, {}, highlights, id, flow.nodes[id])
  end
  if #lines == 0 then
    add_line(lines, {}, highlights, 'No FlowTrace node selected', nil, nil, 'FlowTraceSummary')
  end
  return lines, highlights
end

function M.render(flow, expanded, opts)
  local lines = {}
  local index = {}
  local highlights = {}
  expanded = expanded or {}
  opts = opts or {}

  local compact = opts.compact == true
  local selected_id = opts.selected_id or flow.root

  add_line(lines, index, highlights, 'Flow: ' .. (flow.title or flow.id or 'untitled'), nil, nil, 'FlowTraceTitle')
  if compact then
    add_line(lines, index, highlights, 'Compact view: one row per node • selected details below • <CR> jump • p preview • ? popup • D panel • o toggle • q close', nil, nil, 'FlowTraceHelp')
  else
    add_line(lines, index, highlights, 'Press <CR> jump • a ask • A ask flow • C clear chat • f/F flows • o toggle • q close', nil, nil, 'FlowTraceHelp')
  end
  add_line(lines, index, highlights, '', nil, nil, nil)

  if compact then
    add_compact_node(lines, index, highlights, flow, expanded, flow.root, '', true, nil, {})
    if opts.detail_panel ~= false then
      add_detail_panel(lines, index, highlights, selected_id, flow.nodes[selected_id])
    end
  else
    add_verbose_node(lines, index, highlights, flow, expanded, flow.root, '', true, nil, {})
  end

  return lines, index, highlights
end

return M
