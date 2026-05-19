package core

import (
	"fmt"
	"io"
	"strings"
)

func PrintFlow(w io.Writer, f *Flow) {
	fmt.Fprintf(w, "Flow: %s\n", f.Title)
	printInvestigation(w, f)
	seen := map[string]bool{}
	printNode(w, f, f.Root, "", true, seen)
}

func printInvestigation(w io.Writer, f *Flow) {
	if f.Thesis != "" {
		fmt.Fprintf(w, "Thesis: %s\n", f.Thesis)
	}
	if f.Investigation != nil {
		if f.Investigation.Lens != "" || f.Investigation.Goal != "" {
			fmt.Fprintf(w, "Lens: %s", f.Investigation.Lens)
			if f.Investigation.Goal != "" {
				fmt.Fprintf(w, " • Goal: %s", f.Investigation.Goal)
			}
			fmt.Fprintln(w)
		}
		if len(f.Investigation.OpenQuestions) > 0 {
			fmt.Fprintln(w, "Open questions:")
			for _, q := range f.Investigation.OpenQuestions {
				fmt.Fprintf(w, "  - %s\n", q)
			}
		}
	}
	if len(f.Sections) > 0 {
		fmt.Fprintln(w, "Sections:")
		for _, s := range f.Sections {
			count := ""
			if len(s.Nodes) > 0 {
				count = fmt.Sprintf(" (%d nodes)", len(s.Nodes))
			}
			fmt.Fprintf(w, "  - %s%s", s.Title, count)
			if s.Summary != "" {
				fmt.Fprintf(w, ": %s", s.Summary)
			}
			fmt.Fprintln(w)
		}
	}
	if len(f.Concepts) > 0 {
		fmt.Fprintln(w, "Concepts:")
		for _, c := range f.Concepts {
			fmt.Fprintf(w, "  - %s", c.Name)
			if c.Summary != "" {
				fmt.Fprintf(w, ": %s", c.Summary)
			}
			fmt.Fprintln(w)
		}
	}
	if f.Impact != nil && f.Impact.Change != "" {
		fmt.Fprintf(w, "Impact: %s\n", f.Impact.Change)
	}
	if len(f.TestScenarios) > 0 {
		fmt.Fprintln(w, "Test scenarios:")
		for _, s := range f.TestScenarios {
			fmt.Fprintf(w, "  - %s", s.Name)
			if s.Summary != "" {
				fmt.Fprintf(w, ": %s", s.Summary)
			}
			fmt.Fprintln(w)
		}
	}
	if len(f.ConfidenceChecks) > 0 {
		fmt.Fprintln(w, "Confidence checks:")
		for _, c := range f.ConfidenceChecks {
			fmt.Fprintf(w, "  - %s", c.Name)
			if c.Prompt != "" {
				fmt.Fprintf(w, ": %s", c.Prompt)
			}
			fmt.Fprintln(w)
		}
	}
}

func printNode(w io.Writer, f *Flow, id, prefix string, last bool, seen map[string]bool) {
	n, ok := f.Nodes[id]
	if !ok {
		return
	}
	connector := "└─ "
	nextPrefix := prefix + "   "
	if !last {
		connector = "├─ "
		nextPrefix = prefix + "│  "
	}
	relevance := ""
	if n.Relevance != "" {
		relevance = " • " + n.Relevance
	}
	fmt.Fprintf(w, "%s%s%s [%s%s] %s:%d\n", prefix, connector, n.Label, n.Kind, relevance, n.File, n.Line)
	if seen[id] {
		fmt.Fprintf(w, "%s   ↳ already shown\n", prefix)
		return
	}
	seen[id] = true
	items := append([]string{}, n.Children...)
	for i, child := range items {
		printNode(w, f, child, nextPrefix, i == len(items)-1 && len(n.Branches) == 0, seen)
	}
	for i, br := range n.Branches {
		branchLast := i == len(n.Branches)-1
		bconn := "├─ "
		bprefix := nextPrefix + "│  "
		if branchLast {
			bconn = "└─ "
			bprefix = nextPrefix + "   "
		}
		fmt.Fprintf(w, "%s%sbranch: %s\n", nextPrefix, bconn, br.Label)
		printNode(w, f, br.Target, bprefix, true, seen)
	}
}

func indentLines(s, prefix string) string { return prefix + strings.ReplaceAll(s, "\n", "\n"+prefix) }
