#!/usr/bin/env python3
from pathlib import Path
import html

OUT = Path(__file__).parent / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1280, 760
COLORS = {
    "bg": "#1e1e2e",
    "panel": "#181825",
    "panel2": "#11111b",
    "border": "#313244",
    "muted": "#6c7086",
    "text": "#cdd6f4",
    "subtle": "#9399b2",
    "title": "#cba6f7",
    "file": "#a6e3a1",
    "marker": "#f5c2e7",
    "branch": "#fab387",
    "blue": "#89b4fa",
    "red": "#f38ba8",
    "yellow": "#f9e2af",
    "green": "#a6e3a1",
    "cursor": "#45475a",
}

def esc(s):
    return html.escape(s, quote=True)

def text(x, y, s, color="text", size=14, weight="400", opacity=1):
    return f'<text x="{x}" y="{y}" fill="{COLORS.get(color,color)}" font-family="JetBrains Mono, SFMono-Regular, Consolas, monospace" font-size="{size}" font-weight="{weight}" opacity="{opacity}">{esc(s)}</text>'

def rect(x,y,w,h,color,opacity=1,rx=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{COLORS.get(color,color)}" opacity="{opacity}"/>'

def shell(title, body, left_title="FlowTrace tree", right_title="packages/nvim/lua/flowtrace/tree.lua"):
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
        '<defs><clipPath id="leftClip"><rect x="0" y="34" width="604" height="726"/></clipPath><clipPath id="rightClip"><rect x="628" y="34" width="628" height="726"/></clipPath></defs>',
        rect(0,0,W,H,"bg"), rect(0,0,610,H,"panel"), rect(610,0,2,H,"border"), rect(0,0,W,34,"panel2"),
        text(18,23,left_title,"subtle",13), text(636,23,right_title,"subtle",13),
        rect(628,300,628,32,"border",0.55),
        text(638,76," 35  local function add_node(lines, index, highlights, flow, expanded, id, prefix, is_last, branch_label, seen)","text",13),
        text(638,104," 36    local node = flow.nodes[id]","text",13),
        text(638,132," 37    if not node then return end","text",13),
        text(638,160," 38","text",13),
        text(638,188," 39    local is_open = expanded[id] ~= false","text",13),
        text(638,216," 40    local has_children = child_count(node) > 0","text",13),
        text(638,244," 41    local connector = is_last and '└─ ' or '├─ '","text",13),
        text(638,272," 42    local child_prefix = prefix .. (is_last and '   ' or '│  ')","text",13),
        text(638,328," 43    local marker = has_children and (is_open and '▾ ' or '▸ ') or ''","red",13),
        text(638,356," 44    local branch = branch_label and ('↳ ' .. branch_label .. ': ') or ''","text",13),
        text(638,384," 45    local location = location_text(node)","text",13),
        text(638,412," 46","text",13),
        text(638,440," 47    local row = add_line(lines, index, highlights, prefix .. connector .. marker .. branch .. location, id, node, 'FlowTraceFile')","text",13),
        text(638,468," 48    add_highlight(highlights, row, #prefix, connector:gsub('%s+$', ''), 'FlowTraceMarker')","text",13),
        f'<g clip-path="url(#leftClip)">{body}</g>',
        '</svg>'
    ]
    return "\n".join(parts)

baseline_lines = [
("Flow: Lua plugin tree build", "title"),
("Press <CR> jump • a ask • A ask flow • C clear chat • f/F flows • o toggle • q close", "muted"),
("", "text"),
("└─ ▾ packages/nvim/lua/flowtrace/init.lua:42", "file"),
("   setup creates commands and calls tree renderer", "text"),
("   type: entrypoint", "blue"),
("   The plugin opens a nofile buffer, parses the .flow.json, and renders jumpable rows.", "subtle"),
("   └─ ▾ packages/nvim/lua/flowtrace/parser.lua:18", "file"),
("      decode and normalize flow JSON", "text"),
("      type: parser", "blue"),
("      Parser maps nodes by id and preserves children and branch targets.", "subtle"),
("      ├─ packages/nvim/lua/flowtrace/window.lua:3", "file"),
("      │  open a persistent side buffer", "text"),
("      │  type: ui", "blue"),
("      │  Window opts enable wrap, cursorline, and nofile buffer state.", "subtle"),
("      ├─ packages/nvim/lua/flowtrace/tree.lua:35", "file"),
("      │  recursively add node lines", "text"),
("      │  type: renderer", "blue"),
("      │  add_node writes file, label, metadata, summary, children, and branches.", "subtle"),
("      └─ ↳ repeated node: packages/nvim/lua/flowtrace/tree.lua:71", "branch"),
("         prevent infinite recursion", "text"),
]

def render_lines(lines, x=24, y=62, dy=22, cursor=None, dim_from=None, badges=False):
    out=[]
    for i,(s,c) in enumerate(lines):
        yy=y+i*dy
        if cursor == i:
            out.append(rect(10, yy-16, 590, 24, "cursor", .8, 4))
        op=.45 if dim_from is not None and i in dim_from else 1
        out.append(text(x, yy, s, c, 13, opacity=op))
    return "\n".join(out)

# 1 baseline
(Path(OUT)/"01-current-tree.svg").write_text(shell("Current baseline", render_lines(baseline_lines)), encoding="utf-8")

# 2 breadcrumb + active lineage
lines2 = [
("Flow: Lua plugin tree build", "title"),
("Path: init.setup → parser.normalize → tree.add_node → branch rendering", "yellow"),
("Keys: <CR> jump • o toggle • b breadcrumbs • l lineage highlight", "muted"),
("", "text"),
("└─ ▾ packages/nvim/lua/flowtrace/init.lua:42", "green"),
("   setup creates commands and calls tree renderer", "text"),
("   └─ ▾ packages/nvim/lua/flowtrace/parser.lua:18", "green"),
("      decode and normalize flow JSON", "text"),
("      ├─ packages/nvim/lua/flowtrace/window.lua:3", "file"),
("      │  open a persistent side buffer", "subtle"),
("      ├─ packages/nvim/lua/flowtrace/actions.lua:88", "file"),
("      │  jump and preview source locations", "subtle"),
("      └─ ▾ packages/nvim/lua/flowtrace/tree.lua:35", "green"),
("         recursively add node lines", "text"),
("         ├─ packages/nvim/lua/flowtrace/tree.lua:47", "green"),
("         │  add the jumpable row for the node", "text"),
("         └─ ↳ repeated node: packages/nvim/lua/flowtrace/tree.lua:71", "branch"),
("            prevent infinite recursion", "subtle"),
]
body2 = rect(12,40,586,34,"border",0.45,6) + render_lines(lines2, cursor=14, dim_from={8,9,10,11,16,17})
(Path(OUT)/"02-breadcrumb-lineage.svg").write_text(shell("Sticky breadcrumb + active lineage", body2), encoding="utf-8")

# 3 compact rows + details pane
lines3 = [
("Flow: Lua plugin tree build                                      compact", "title"),
("└─ ▾ init.lua:42        setup creates commands and opens trace        [entry]", "file"),
("   └─ ▾ parser.lua:18   decode and normalize flow JSON                [parser]", "file"),
("      ├─ window.lua:3   open persistent side buffer                   [ui]", "subtle"),
("      ├─ actions.lua:88 jump / preview source locations               [nav]", "subtle"),
("      └─ ▾ tree.lua:35  recursively add node lines                    [renderer]", "green"),
("         ├─ tree.lua:47 add jumpable node row                         [render]", "green"),
("         ├─ tree.lua:51 annotate label/meta/summary                   [detail]", "file"),
("         └─ tree.lua:71 render branches after children                [branch]", "branch"),
]
body3 = render_lines(lines3, y=62, cursor=5)
body3 += rect(18,300,574,168,"panel2",0.95,8)
body3 += rect(18,300,574,1,"border",1)
body3 += text(36,330,"Selected node", "yellow", 13, "700")
body3 += text(36,360,"tree.lua:35  add_node(lines, index, highlights, flow, expanded, id, ...)", "file", 13)
body3 += text(36,390,"type: renderer • children: 4 • branches: 1 • depth: 3", "blue", 13)
body3 += text(36,420,"Summary: writes one compact row in the tree; details move here so", "text", 13)
body3 += text(36,444,"lineage stays visible instead of being separated by metadata blocks.", "text", 13)
(Path(OUT)/"03-compact-detail-pane.svg").write_text(shell("Compact rows + selected detail pane", body3), encoding="utf-8")

# 4 focus mode
lines4 = [
("Flow: Lua plugin tree build                         FOCUS: current path", "title"),
("Showing ancestors, selected node, siblings, and immediate children. 12 hidden nodes.", "yellow"),
("", "text"),
("└─ ▾ init.lua:42  setup creates commands", "green"),
("   └─ ▾ parser.lua:18  normalize flow JSON", "green"),
("      ├─ window.lua:3  open side buffer", "subtle"),
("      ├─ actions.lua:88  jump / preview source", "subtle"),
("      └─ ▾ tree.lua:35  recursively add node lines", "green"),
("         ├─ tree.lua:47  add jumpable row", "file"),
("         ├─ tree.lua:51  annotate selected node", "file"),
("         ├─ tree.lua:65  append children", "file"),
("         └─ ↳ branch target  tree.lua:71  prevent recursion", "branch"),
("", "text"),
("… collapsed: cli validate flow, terminal print flow, chat provider flow", "muted"),
]
body4 = render_lines(lines4, cursor=7)
body4 += rect(390,52,190,26,"yellow",0.18,13) + text(410,70,"press F to restore all", "yellow", 12)
(Path(OUT)/"04-focus-path-mode.svg").write_text(shell("Focus / show-my-path mode", body4), encoding="utf-8")

# 5 scope rails and branch badges
lines5 = [
("Flow: Lua plugin tree build                         rails + branch badges", "title"),
("▌ init.lua:42        setup creates commands", "green"),
("▌  ▌ parser.lua:18   decode and normalize flow JSON", "green"),
("▌  ▌  ▌ window.lua:3 open persistent side buffer", "subtle"),
("▌  ▌  ▌ actions.lua:88 jump / preview source", "subtle"),
("▌  ▌  ▌ tree.lua:35 recursively add node lines", "green"),
("▌  ▌  ▌  ▌ tree.lua:47 add jumpable row", "file"),
("▌  ▌  ▌  ▌ tree.lua:51 annotate label/meta/summary", "file"),
("▌  ▌  ▌  ▌ [repeat guard] tree.lua:71 already shown", "branch"),
("▌  ▌  ▌  ▌ [branch] error path → actions.lua:112 show notification", "branch"),
]
body5 = render_lines(lines5, cursor=5)
for x,c in [(24,"#a6e3a1"),(45,"#89b4fa"),(66,"#f9e2af"),(87,"#fab387")]:
    body5 += f'<line x1="{x}" y1="84" x2="{x}" y2="274" stroke="{c}" stroke-width="2" opacity="0.55"/>'
(Path(OUT)/"05-scope-rails-badges.svg").write_text(shell("Scope rails + branch badges", body5), encoding="utf-8")

# 6 minimap
lines6 = [
("Flow: Lua plugin tree build                         tree + minimap", "title"),
("01 └─ ▾ init.lua:42        setup", "green"),
("02    └─ ▾ parser.lua:18   normalize JSON", "green"),
("03       ├─ window.lua:3   side buffer", "subtle"),
("03       ├─ actions.lua:88 source preview", "subtle"),
("03       └─ ▾ tree.lua:35  add node lines", "green"),
("04          ├─ tree.lua:47 node row", "green"),
("04          ├─ tree.lua:51 metadata", "file"),
("04          ├─ tree.lua:57 summary", "file"),
("04          └─ tree.lua:71 branch / recursion guard", "branch"),
("03       └─ agent.lua:20 chat context", "subtle"),
]
body6 = render_lines(lines6, cursor=6)
body6 += rect(520,58,64,260,"panel2",0.9,8) + text(533,82,"map","muted",12)
for i in range(18):
    y=100+i*10
    color="green" if i in [0,1,4,5,6] else "muted"
    w=[14,24,34,44,34][i%5]
    body6 += rect(535,y,w,6,color,0.9 if color=="green" else .35,2)
body6 += rect(530,148,48,42,"yellow",0.18,5)
body6 += text(430,350,"Mini map shows viewport, depth changes, and active lineage.", "yellow", 12)
(Path(OUT)/"06-minimap-depth-gutter.svg").write_text(shell("Depth gutter + minimap", body6), encoding="utf-8")

print(f"wrote svg mockups to {OUT}")
