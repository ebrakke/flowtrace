package core

import (
	"fmt"
	"os"
	"path/filepath"
)

func ValidateFlow(f *Flow, root string) error {
	if f.SchemaVersion == "" {
		return fmt.Errorf("schemaVersion is required")
	}
	if f.ID == "" || f.Title == "" || f.Root == "" {
		return fmt.Errorf("id, title, and root are required")
	}
	if len(f.Nodes) == 0 {
		return fmt.Errorf("nodes must not be empty")
	}
	if _, ok := f.Nodes[f.Root]; !ok {
		return fmt.Errorf("root node %q not found", f.Root)
	}
	for _, section := range f.Sections {
		if section.Title == "" {
			return fmt.Errorf("section title is required")
		}
		for _, nodeID := range section.Nodes {
			if _, ok := f.Nodes[nodeID]; !ok {
				return fmt.Errorf("section %q node %q not found", section.Title, nodeID)
			}
		}
	}
	for _, concept := range f.Concepts {
		if concept.Name == "" {
			return fmt.Errorf("concept name is required")
		}
		for _, nodeID := range concept.Nodes {
			if _, ok := f.Nodes[nodeID]; !ok {
				return fmt.Errorf("concept %q node %q not found", concept.Name, nodeID)
			}
		}
	}
	for _, check := range f.ConfidenceChecks {
		if check.Name == "" {
			return fmt.Errorf("confidence check name is required")
		}
		if check.Node != "" {
			if _, ok := f.Nodes[check.Node]; !ok {
				return fmt.Errorf("confidence check %q node %q not found", check.Name, check.Node)
			}
		}
	}
	for id, n := range f.Nodes {
		if n.ID != id {
			return fmt.Errorf("node map key %q does not match node id %q", id, n.ID)
		}
		if n.Label == "" || n.Kind == "" || n.File == "" || n.Line < 1 {
			return fmt.Errorf("node %q requires label, kind, file, and line >= 1", id)
		}
		if !allowedResolution[n.Resolution] {
			return fmt.Errorf("node %q has invalid resolution %q", id, n.Resolution)
		}
		if n.Relevance != "" && !allowedRelevance[n.Relevance] {
			return fmt.Errorf("node %q has invalid relevance %q", id, n.Relevance)
		}
		path := filepath.Join(root, filepath.Clean(n.File))
		info, err := os.Stat(path)
		if err != nil {
			return fmt.Errorf("node %q file %q: %w", id, n.File, err)
		}
		if info.IsDir() {
			return fmt.Errorf("node %q file %q is a directory", id, n.File)
		}
		lines, err := countLines(path)
		if err != nil {
			return err
		}
		if n.Line > lines {
			return fmt.Errorf("node %q line %d beyond file length %d", id, n.Line, lines)
		}
		for _, child := range n.Children {
			if _, ok := f.Nodes[child]; !ok {
				return fmt.Errorf("node %q child %q not found", id, child)
			}
		}
		for _, br := range n.Branches {
			if br.Label == "" || br.Target == "" {
				return fmt.Errorf("node %q has branch with empty label/target", id)
			}
			if _, ok := f.Nodes[br.Target]; !ok {
				return fmt.Errorf("node %q branch target %q not found", id, br.Target)
			}
		}
	}
	return nil
}

func countLines(path string) (int, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	if len(b) == 0 {
		return 1, nil
	}
	c := 1
	for _, ch := range b {
		if ch == '\n' {
			c++
		}
	}
	return c, nil
}
