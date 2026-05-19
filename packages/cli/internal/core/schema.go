package core

import (
	"encoding/json"
	"fmt"
	"os"
)

const SchemaVersion = "0.1"

type Flow struct {
	SchemaVersion    string                `json:"schemaVersion"`
	ID               string                `json:"id"`
	Title            string                `json:"title"`
	CreatedAt        string                `json:"createdAt"`
	Root             string                `json:"root"`
	Thesis           string                `json:"thesis,omitempty"`
	Investigation    *FlowInvestigation    `json:"investigation,omitempty"`
	Sections         []FlowSection         `json:"sections,omitempty"`
	Concepts         []FlowConcept         `json:"concepts,omitempty"`
	Impact           *FlowImpact           `json:"impact,omitempty"`
	TestScenarios    []FlowTestScenario    `json:"testScenarios,omitempty"`
	ConfidenceChecks []FlowConfidenceCheck `json:"confidenceChecks,omitempty"`
	Nodes            map[string]FlowNode   `json:"nodes"`
}

type FlowInvestigation struct {
	Goal          string   `json:"goal,omitempty"`
	Lens          string   `json:"lens,omitempty"`
	Question      string   `json:"question,omitempty"`
	OpenQuestions []string `json:"openQuestions,omitempty"`
}

type FlowSection struct {
	Title   string   `json:"title"`
	Summary string   `json:"summary,omitempty"`
	Nodes   []string `json:"nodes,omitempty"`
}

type FlowConcept struct {
	Name       string   `json:"name"`
	Summary    string   `json:"summary,omitempty"`
	Locations  []string `json:"locations,omitempty"`
	Nodes      []string `json:"nodes,omitempty"`
	UsedBy     []string `json:"usedBy,omitempty"`
	Risks      []string `json:"risks,omitempty"`
	Confidence string   `json:"confidence,omitempty"`
}

type FlowImpact struct {
	Change             string   `json:"change,omitempty"`
	LikelyAffected     []string `json:"likelyAffected,omitempty"`
	InspectIfUntouched []string `json:"inspectIfUntouched,omitempty"`
	Unknowns           []string `json:"unknowns,omitempty"`
}

type FlowTestScenario struct {
	Name       string `json:"name"`
	Summary    string `json:"summary,omitempty"`
	Existing   string `json:"existing,omitempty"`
	Confidence string `json:"confidence,omitempty"`
}

type FlowConfidenceCheck struct {
	Name    string `json:"name"`
	Prompt  string `json:"prompt,omitempty"`
	Success string `json:"success,omitempty"`
	Node    string `json:"node,omitempty"`
}

type FlowNode struct {
	ID           string            `json:"id"`
	Label        string            `json:"label"`
	Kind         string            `json:"kind"`
	File         string            `json:"file"`
	Line         int               `json:"line"`
	Column       int               `json:"column,omitempty"`
	Summary      string            `json:"summary,omitempty"`
	Relevance    string            `json:"relevance,omitempty"`
	Evidence     string            `json:"evidence,omitempty"`
	Tags         []string          `json:"tags,omitempty"`
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
var allowedRelevance = map[string]bool{"core": true, "domain": true, "supporting": true, "boilerplate": true, "test": true, "unclear": true}

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
