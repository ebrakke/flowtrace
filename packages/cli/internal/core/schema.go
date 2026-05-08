package core

import (
	"encoding/json"
	"fmt"
	"os"
)

const SchemaVersion = "0.1"

type Flow struct {
	SchemaVersion string              `json:"schemaVersion"`
	ID            string              `json:"id"`
	Title         string              `json:"title"`
	CreatedAt     string              `json:"createdAt"`
	Root          string              `json:"root"`
	Nodes         map[string]FlowNode `json:"nodes"`
}

type FlowNode struct {
	ID           string            `json:"id"`
	Label        string            `json:"label"`
	Kind         string            `json:"kind"`
	File         string            `json:"file"`
	Line         int               `json:"line"`
	Column       int               `json:"column,omitempty"`
	Summary      string            `json:"summary,omitempty"`
	Symbol       string            `json:"symbol,omitempty"`
	Anchor       string            `json:"anchor,omitempty"`
	Resolution   string            `json:"resolution"`
	Children     []string          `json:"children,omitempty"`
	Branches     []FlowBranch      `json:"branches,omitempty"`
	Alternatives []FlowAlternative `json:"alternatives,omitempty"`
}

type FlowBranch struct {
	Label  string `json:"label"`
	Target string `json:"target"`
}
type FlowAlternative struct {
	Label  string `json:"label"`
	File   string `json:"file"`
	Line   int    `json:"line"`
	Reason string `json:"reason,omitempty"`
}

var allowedResolution = map[string]bool{"lsp": true, "ast": true, "search": true, "llm_inferred": true, "llm_validated": true, "manual": true}

func LoadFlow(path string) (*Flow, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var f Flow
	if err := json.Unmarshal(b, &f); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return &f, nil
}

func WriteFlow(path string, f *Flow) error {
	b, err := json.MarshalIndent(f, "", "  ")
	if err != nil {
		return err
	}
	b = append(b, '\n')
	return os.WriteFile(path, b, 0644)
}
