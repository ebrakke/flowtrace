package core

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type BuildOptions struct {
	Root, Out          string
	MaxFiles, MaxNodes int
	DryRun             bool
	Request            string
}
type candidate struct {
	File    string
	Score   int
	Matches []match
}
type match struct {
	Line int
	Text string
}

func Build(o BuildOptions) error {
	if o.MaxFiles <= 0 {
		o.MaxFiles = 80
	}
	if o.MaxNodes <= 0 {
		o.MaxNodes = 40
	}
	terms := requestTerms(o.Request)
	cands, err := searchRepo(o.Root, terms, o.MaxFiles)
	if err != nil {
		return err
	}
	snips := formatSnippets(o.Root, cands)
	if o.DryRun {
		fmt.Println(snips)
		return nil
	}
	flow := heuristicFlow(o, cands)
	if err := normalizeAndResolve(flow, o.Root, cands); err != nil {
		return err
	}
	if flow.ID == "" {
		flow.ID = slug(o.Request) + "-flow"
	}
	if flow.Title == "" {
		flow.Title = titleFromRequest(o.Request)
	}
	flow.SchemaVersion = SchemaVersion
	if flow.CreatedAt == "" {
		flow.CreatedAt = time.Now().UTC().Format(time.RFC3339)
	}
	out := o.Out
	if out == "" {
		out = filepath.Join(o.Root, ".flowtrace", slug(o.Request)+".flow.json")
	}
	if err := os.MkdirAll(filepath.Dir(out), 0755); err != nil {
		return err
	}
	if err := ValidateFlow(flow, o.Root); err != nil {
		return err
	}
	if err := WriteFlow(out, flow); err != nil {
		return err
	}
	fmt.Println(out)
	return nil
}

func requestTerms(req string) []string {
	stop := map[string]bool{"the": true, "and": true, "for": true, "with": true, "this": true, "that": true, "walk": true, "through": true, "data": true, "flow": true, "me": true, "a": true, "an": true, "to": true, "of": true, "in": true, "on": true, "run": false, "running": false}
	re := regexp.MustCompile(`[A-Za-z0-9_./-]+`)
	raw := re.FindAllString(strings.ToLower(req), -1)
	seen := map[string]bool{}
	var out []string
	for _, t := range raw {
		if len(t) < 3 || stop[t] || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	if len(out) == 0 {
		out = []string{strings.ToLower(req)}
	}
	return out
}

func searchRepo(root string, terms []string, max int) ([]candidate, error) {
	skipDir := map[string]bool{".git": true, ".flowtrace": true, "node_modules": true, "vendor": true, "dist": true, "build": true, "target": true}
	var cands []candidate
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		name := d.Name()
		if d.IsDir() {
			if skipDir[name] {
				return filepath.SkipDir
			}
			return nil
		}
		if !isTextSource(name) {
			return nil
		}
		rel, _ := filepath.Rel(root, path)
		b, err := os.ReadFile(path)
		if err != nil || bytes.IndexByte(b, 0) >= 0 {
			return nil
		}
		lines := strings.Split(string(b), "\n")
		c := candidate{File: filepath.ToSlash(rel)}
		for i, l := range lines {
			low := strings.ToLower(l)
			for _, term := range terms {
				if strings.Contains(low, term) {
					c.Score++
					if len(c.Matches) < 8 {
						c.Matches = append(c.Matches, match{i + 1, strings.TrimSpace(l)})
					}
					break
				}
			}
		}
		lowName := strings.ToLower(rel)
		for _, term := range terms {
			if strings.Contains(lowName, term) {
				c.Score += 3
			}
		}
		if c.Score > 0 {
			cands = append(cands, c)
		}
		return nil
	})
	sort.Slice(cands, func(i, j int) bool {
		if cands[i].Score == cands[j].Score {
			return cands[i].File < cands[j].File
		}
		return cands[i].Score > cands[j].Score
	})
	if len(cands) > max {
		cands = cands[:max]
	}
	return cands, err
}

func isTextSource(name string) bool {
	exts := []string{".go", ".ts", ".tsx", ".js", ".jsx", ".py", ".rb", ".rs", ".java", ".kt", ".lua", ".vim", ".md", ".json", ".yaml", ".yml", ".sql", ".sh"}
	for _, e := range exts {
		if strings.HasSuffix(name, e) {
			return true
		}
	}
	return false
}

func formatSnippets(root string, cands []candidate) string {
	var b strings.Builder
	for _, c := range cands {
		fmt.Fprintf(&b, "\n## %s (score %d)\n", c.File, c.Score)
		for _, m := range c.Matches {
			fmt.Fprintf(&b, "%d: %s\n", m.Line, m.Text)
		}
	}
	return b.String()
}

func heuristicFlow(o BuildOptions, cands []candidate) *Flow {
	nodes := map[string]FlowNode{}
	prev := ""
	root := ""
	limit := o.MaxNodes
	if limit > len(cands) {
		limit = len(cands)
	}
	for i := 0; i < limit; i++ {
		c := cands[i]
		line := 1
		text := "Relevant code location"
		if len(c.Matches) > 0 {
			line = c.Matches[0].Line
			text = c.Matches[0].Text
		}
		id := fmt.Sprintf("node-%d", i+1)
		if i == 0 {
			root = id
		}
		n := FlowNode{ID: id, Label: labelFromMatch(c.File, text), Kind: "step", File: c.File, Line: line, Column: 1, Summary: text, Anchor: text, Resolution: "search"}
		nodes[id] = n
		if prev != "" {
			p := nodes[prev]
			p.Children = append(p.Children, id)
			nodes[prev] = p
		}
		prev = id
	}
	if root == "" {
		root = "node-1"
		nodes[root] = FlowNode{ID: root, Label: "Repository entrypoint not found", Kind: "unknown", File: "README.md", Line: 1, Column: 1, Summary: "No matching source files were found; this placeholder points at README.", Resolution: "search"}
	}
	return &Flow{SchemaVersion: SchemaVersion, ID: slug(o.Request) + "-flow", Title: titleFromRequest(o.Request), CreatedAt: time.Now().UTC().Format(time.RFC3339), Root: root, Nodes: nodes}
}

func normalizeAndResolve(f *Flow, root string, cands []candidate) error {
	if f.Nodes == nil {
		f.Nodes = map[string]FlowNode{}
	}
	for id, n := range f.Nodes {
		n.ID = id
		n.File = filepath.ToSlash(filepath.Clean(n.File))
		if n.Column < 1 {
			n.Column = 1
		}
		if n.Resolution == "" {
			n.Resolution = "llm_inferred"
		}
		if _, err := os.Stat(filepath.Join(root, n.File)); err != nil { // map basename to candidate
			for _, c := range cands {
				if filepath.Base(c.File) == filepath.Base(n.File) {
					n.File = c.File
					break
				}
			}
		}
		if n.Line < 1 {
			n.Line = 1
		}
		f.Nodes[id] = n
	}
	return nil
}

func slug(s string) string {
	s = strings.ToLower(s)
	re := regexp.MustCompile(`[^a-z0-9]+`)
	s = strings.Trim(re.ReplaceAllString(s, "-"), "-")
	if len(s) > 48 {
		s = strings.Trim(s[:48], "-")
	}
	if s == "" {
		return "flow"
	}
	return s
}
func titleFromRequest(s string) string {
	if s == "" {
		return "FlowTrace"
	}
	return strings.ToUpper(s[:1]) + s[1:]
}
func labelFromMatch(file, text string) string {
	if text != "" {
		if len(text) > 70 {
			return text[:67] + "..."
		}
		return text
	}
	return file
}
