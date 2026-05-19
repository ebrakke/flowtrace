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
	Goal, Lens, Change string
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
		relevance, tags := classifyRelevance(c.File, text)
		n := FlowNode{ID: id, Label: labelFromMatch(c.File, text), Kind: "step", File: c.File, Line: line, Column: 1, Summary: text, Relevance: relevance, Tags: tags, Evidence: "Matched request terms in repository search.", Anchor: text, Resolution: "search"}
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
	return &Flow{
		SchemaVersion:    SchemaVersion,
		ID:               slug(o.Request) + "-flow",
		Title:            titleFromRequest(o.Request),
		CreatedAt:        time.Now().UTC().Format(time.RFC3339),
		Root:             root,
		Thesis:           inferThesis(o),
		Investigation:    buildInvestigation(o),
		Sections:         inferSections(nodes),
		Concepts:         inferConcepts(cands, nodes),
		Impact:           inferImpact(o),
		TestScenarios:    inferTestScenarios(cands),
		ConfidenceChecks: inferConfidenceChecks(o, root),
		Nodes:            nodes,
	}
}

func inferThesis(o BuildOptions) string {
	lens := inferLens(o.Request, o.Change)
	if o.Lens != "" {
		lens = o.Lens
	}
	switch lens {
	case "change-impact":
		change := strings.TrimSpace(o.Change)
		if change == "" {
			change = o.Request
		}
		return "This trace is organized around the likely blast radius of " + change + ", separating core workflow, domain model, supporting code, and validation scenarios."
	case "bug-investigation":
		return "This trace is organized around the suspected failure path, emphasizing code that can affect the symptom and de-emphasizing generic boilerplate."
	case "test-understanding":
		return "This trace is organized around the behaviors and confidence checks that prove the system works, with implementation nodes as supporting evidence."
	default:
		return "This trace explains the subsystem as a lifecycle of concepts, contracts, producers, and consumers, rather than only as a call graph."
	}
}

func buildInvestigation(o BuildOptions) *FlowInvestigation {
	lens := strings.TrimSpace(o.Lens)
	goal := strings.TrimSpace(o.Goal)
	if lens == "" {
		lens = inferLens(o.Request, o.Change)
	}
	if goal == "" {
		goal = o.Request
	}
	inv := &FlowInvestigation{Goal: goal, Lens: lens, Question: o.Request}
	if o.Change != "" {
		inv.OpenQuestions = append(inv.OpenQuestions,
			"Which domain concepts does this change depend on?",
			"Which schema, cache, job, UI, and test paths should change if this is correct?",
			"What would be surprising if it were not touched?",
		)
	} else {
		inv.OpenQuestions = append(inv.OpenQuestions,
			"Which nodes are core workflow versus supporting boilerplate?",
			"Which domain concepts or persisted fields determine correctness?",
			"Which scenarios would prove this flow works?",
		)
	}
	return inv
}

func inferLens(request, change string) string {
	low := strings.ToLower(request + " " + change)
	switch {
	case strings.Contains(low, "test") || strings.Contains(low, "verify"):
		return "test-understanding"
	case strings.Contains(low, "remove") || strings.Contains(low, "refactor") || strings.Contains(low, "change") || change != "":
		return "change-impact"
	case strings.Contains(low, "bug") || strings.Contains(low, "debug") || strings.Contains(low, "issue") || strings.Contains(low, "fail"):
		return "bug-investigation"
	default:
		return "subsystem-understanding"
	}
}

func classifyRelevance(file, text string) (string, []string) {
	low := strings.ToLower(file + " " + text)
	var tags []string
	add := func(tag string) { tags = append(tags, tag) }
	if strings.Contains(low, "test") || strings.Contains(low, "spec") {
		return "test", []string{"test-relevant"}
	}
	if strings.Contains(low, "schema") || strings.Contains(low, "migration") || strings.Contains(low, "model") || strings.Contains(low, "domain") || strings.Contains(low, "entity") || strings.Contains(low, "table") {
		add("data-model")
		return "domain", tags
	}
	if strings.Contains(low, "service") || strings.Contains(low, "job") || strings.Contains(low, "worker") || strings.Contains(low, "index") || strings.Contains(low, "cache") || strings.Contains(low, "repository") {
		add("core-workflow")
		return "core", tags
	}
	if strings.Contains(low, "controller") || strings.Contains(low, "handler") || strings.Contains(low, "route") || strings.Contains(low, "auth") || strings.Contains(low, "middleware") || strings.Contains(low, "parse") || strings.Contains(low, "crud") {
		add("expand-if-symptom-points-here")
		return "boilerplate", tags
	}
	return "supporting", tags
}

func inferSections(nodes map[string]FlowNode) []FlowSection {
	groups := []struct {
		title     string
		relevance string
		summary   string
	}{
		{"Core workflow", "core", "Nodes that directly drive the behavior under investigation."},
		{"Domain model and contracts", "domain", "Nodes that define persisted shape, artifact schema, or correctness contracts."},
		{"Tests and confidence", "test", "Nodes that validate behavior or describe test coverage."},
		{"Supporting context", "supporting", "Useful context that is not the center of gravity."},
		{"Boilerplate", "boilerplate", "Generic entrypoint, parsing, auth, or adapter code to expand only when relevant."},
		{"Unclear relevance", "unclear", "Nodes included because they may matter but need validation."},
	}
	var sections []FlowSection
	for _, group := range groups {
		var ids []string
		for id, node := range nodes {
			if node.Relevance == group.relevance {
				ids = append(ids, id)
			}
		}
		sort.Strings(ids)
		if len(ids) > 0 {
			sections = append(sections, FlowSection{Title: group.title, Summary: group.summary, Nodes: ids})
		}
	}
	return sections
}

func inferConcepts(cands []candidate, nodes map[string]FlowNode) []FlowConcept {
	conceptTerms := []string{"version", "snapshot", "schema", "cache", "index", "embedding", "job", "model", "migration"}
	seen := map[string]*FlowConcept{}
	for _, c := range cands {
		lowFile := strings.ToLower(c.File)
		for _, term := range conceptTerms {
			matched := strings.Contains(lowFile, term)
			for _, m := range c.Matches {
				if strings.Contains(strings.ToLower(m.Text), term) {
					matched = true
					break
				}
			}
			if !matched {
				continue
			}
			name := titleWord(term)
			fc := seen[name]
			if fc == nil {
				seen[name] = &FlowConcept{Name: name, Summary: "Detected from file names or matched lines; review linked locations to confirm semantics.", Confidence: "inferred"}
				fc = seen[name]
			}
			if len(fc.Locations) < 6 {
				fc.Locations = append(fc.Locations, c.File)
			}
			for id, node := range nodes {
				if len(fc.Nodes) >= 6 {
					break
				}
				if node.File == c.File && !containsString(fc.Nodes, id) {
					fc.Nodes = append(fc.Nodes, id)
				}
			}
		}
	}
	var out []FlowConcept
	for _, term := range conceptTerms {
		name := titleWord(term)
		if fc := seen[name]; fc != nil {
			out = append(out, *fc)
		}
	}
	return out
}

func inferImpact(o BuildOptions) *FlowImpact {
	if strings.TrimSpace(o.Change) == "" && inferLens(o.Request, "") != "change-impact" {
		return nil
	}
	change := strings.TrimSpace(o.Change)
	if change == "" {
		change = o.Request
	}
	return &FlowImpact{
		Change: change,
		LikelyAffected: []string{
			"core service logic",
			"domain model and persisted fields",
			"database schema or migrations",
			"background jobs/workers",
			"cache keys or invalidation",
			"API/UI exposure",
			"integration tests and fixtures",
		},
		InspectIfUntouched: []string{
			"cache key construction",
			"schema/index definitions",
			"read paths and rebuild flows",
			"test fixtures that encode old assumptions",
		},
		Unknowns: []string{"Static search cannot prove runtime reachability; validate against tests or logs."},
	}
}

func inferTestScenarios(cands []candidate) []FlowTestScenario {
	hasTests := false
	for _, c := range cands {
		low := strings.ToLower(c.File)
		if strings.Contains(low, "test") || strings.Contains(low, "spec") {
			hasTests = true
			break
		}
	}
	existing := "unknown"
	if hasTests {
		existing = "candidate tests found in trace"
	}
	return []FlowTestScenario{
		{Name: "happy path", Summary: "The core workflow completes and produces the expected externally visible result.", Existing: existing, Confidence: "inferred"},
		{Name: "stale or mismatched state", Summary: "A cache/index/model mismatch follows the expected fallback, miss, or rebuild behavior.", Existing: existing, Confidence: "inferred"},
		{Name: "partial failure", Summary: "A downstream write or indexing failure does not leave corrupt state behind.", Existing: existing, Confidence: "inferred"},
	}
}

func inferConfidenceChecks(o BuildOptions, root string) []FlowConfidenceCheck {
	lens := inferLens(o.Request, o.Change)
	if o.Lens != "" {
		lens = o.Lens
	}
	checks := []FlowConfidenceCheck{
		{Name: "explain the core path", Prompt: "Can you explain the shortest path from the user/system trigger to the behavior being investigated?", Success: "The explanation names the core nodes and avoids generic boilerplate unless it affects the behavior.", Node: root},
		{Name: "predict an omitted touchpoint", Prompt: "If the central concept changed, what file or layer would be suspicious if it were not touched?", Success: "The answer cites a concrete service/domain/schema/cache/test touchpoint from the trace."},
	}
	if lens == "change-impact" {
		checks = append(checks, FlowConfidenceCheck{Name: "validate the blast radius", Prompt: "Can you enumerate the service, domain, schema, job, cache, UI/API, and test areas that need inspection?", Success: "The answer separates directly observed dependencies from inferred or unknown dependencies."})
	}
	if lens == "subsystem-understanding" {
		checks = append(checks, FlowConfidenceCheck{Name: "state the system model", Prompt: "Can you summarize the subsystem as concepts, contracts, producers, and consumers rather than a list of functions?", Success: "The answer includes the top-level thesis and maps it to concrete nodes."})
	}
	return checks
}

func containsString(items []string, target string) bool {
	for _, item := range items {
		if item == target {
			return true
		}
	}
	return false
}

func titleWord(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
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
