package core

import (
	"fmt"
	"io"
	"strings"
)

func PrintFlow(w io.Writer, f *Flow) {
	fmt.Fprintf(w, "Flow: %s\n", f.Title)
	seen := map[string]bool{}
	printNode(w, f, f.Root, "", true, seen)
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
	conf := ""
	if n.Confidence > 0 {
		conf = fmt.Sprintf(" %.0f%%", n.Confidence*100)
	}
	fmt.Fprintf(w, "%s%s%s%s [%s] %s:%d\n", prefix, connector, n.Label, conf, n.Kind, n.File, n.Line)
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
