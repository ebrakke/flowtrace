package core

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func buildWithLLM(o BuildOptions, snippets string) (*Flow, error) {
	provider := o.Provider
	if provider == "none" {
		return nil, fmt.Errorf("llm disabled")
	}
	if provider == "auto" {
		if os.Getenv("ANTHROPIC_API_KEY") != "" {
			provider = "anthropic"
		} else if os.Getenv("OPENAI_API_KEY") != "" {
			provider = "openai"
		} else {
			return nil, fmt.Errorf("no llm api key")
		}
	}
	prompt := fmt.Sprintf(`You are building a jumpable code walkthrough. Return strict JSON only, matching this shape:
{"schemaVersion":"0.1","id":"...","title":"...","createdAt":"","root":"node-1","nodes":{"node-1":{"id":"node-1","label":"...","kind":"entrypoint|service|step|branch|sink","file":"relative/path","line":1,"column":1,"symbol":"runQuery","anchor":"function runQuery(query)","summary":"...","confidence":0.8,"resolution":"llm_inferred","children":["node-2"]}}}
Every node must reference a real file from the snippets. Prefer important data/control-flow steps. Do not invent files. Include anchor as exact source text from the snippets when possible; include symbol as a shorter fallback.

User request: %s

Candidate snippets:%s`, o.Request, snippets)
	switch provider {
	case "anthropic":
		return callAnthropic(o.Model, prompt)
	case "openai":
		return callOpenAI(o.Model, prompt)
	default:
		return nil, fmt.Errorf("unknown provider %q", provider)
	}
}

func callAnthropic(model, prompt string) (*Flow, error) {
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY not set")
	}
	if model == "" {
		model = "claude-3-5-haiku-latest"
	}
	body := map[string]any{"model": model, "max_tokens": 4096, "messages": []map[string]string{{"role": "user", "content": prompt}}}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(b))
	req.Header.Set("x-api-key", key)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")
	resp, err := httpClient().Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("anthropic %s: %s", resp.Status, string(rb))
	}
	var out struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.Unmarshal(rb, &out); err != nil {
		return nil, err
	}
	if len(out.Content) == 0 {
		return nil, fmt.Errorf("empty anthropic response")
	}
	return parseFlowJSON([]byte(extractJSON(out.Content[0].Text)))
}

func callOpenAI(model, prompt string) (*Flow, error) {
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		return nil, fmt.Errorf("OPENAI_API_KEY not set")
	}
	if model == "" {
		model = "gpt-4o-mini"
	}
	body := map[string]any{"model": model, "messages": []map[string]string{{"role": "system", "content": "Return strict JSON only."}, {"role": "user", "content": prompt}}, "response_format": map[string]string{"type": "json_object"}}
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(b))
	req.Header.Set("authorization", "Bearer "+key)
	req.Header.Set("content-type", "application/json")
	resp, err := httpClient().Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("openai %s: %s", resp.Status, string(rb))
	}
	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(rb, &out); err != nil {
		return nil, err
	}
	if len(out.Choices) == 0 {
		return nil, fmt.Errorf("empty openai response")
	}
	return parseFlowJSON([]byte(extractJSON(out.Choices[0].Message.Content)))
}

func httpClient() *http.Client { return &http.Client{Timeout: 60 * time.Second} }
func extractJSON(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		s = strings.TrimPrefix(s, "```json")
		s = strings.TrimPrefix(s, "```")
		if i := strings.LastIndex(s, "```"); i >= 0 {
			s = s[:i]
		}
	}
	return strings.TrimSpace(s)
}
