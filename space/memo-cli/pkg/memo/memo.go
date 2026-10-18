package memo

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// Status represents the freshness state of a memo.
const (
	StatusHot  = "hot"
	StatusWarm = "warm"
	StatusCold = "cold"
	StatusDone = "done"
)

// Frontmatter holds the structured metadata header of a memo.
type Frontmatter struct {
	CreatedAt time.Time `yaml:"created_at" json:"created_at"`
	ExpiresAt time.Time `yaml:"expires_at,omitempty" json:"expires_at,omitempty"`
	Status    string    `yaml:"status" json:"status"`
	Title     string    `yaml:"title" json:"title"`
	Tags      []string  `yaml:"tags,omitempty" json:"tags,omitempty"`
}

// Memo represents a parsed timestamped personal memo.
type Memo struct {
	Path        string      `json:"path"`
	Filename    string      `json:"filename"`
	Frontmatter Frontmatter `json:"frontmatter"`
	Body        string      `json:"-"`
}

// Age returns the duration elapsed since CreatedAt.
func (m *Memo) Age() time.Duration {
	if m.Frontmatter.CreatedAt.IsZero() {
		return 0
	}
	return time.Since(m.Frontmatter.CreatedAt)
}

// ParseFile reads and parses a markdown memo file with frontmatter.
func ParseFile(path string) (*Memo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read file: %w", err)
	}

	content := string(data)
	filename := filepath.Base(path)

	// Check for frontmatter delimited by "---"
	if !strings.HasPrefix(content, "---\n") && !strings.HasPrefix(content, "---\r\n") {
		return &Memo{
			Path:     path,
			Filename: filename,
			Body:     content,
		}, nil
	}

	// Split by frontmatter delimiters
	parts := strings.SplitN(content, "---", 3)
	if len(parts) < 3 {
		return &Memo{
			Path:     path,
			Filename: filename,
			Body:     content,
		}, nil
	}

	var fm Frontmatter
	if err := yaml.Unmarshal([]byte(parts[1]), &fm); err != nil {
		return nil, fmt.Errorf("parse frontmatter for %s: %w", filename, err)
	}

	body := strings.TrimSpace(parts[2])

	return &Memo{
		Path:        path,
		Filename:    filename,
		Frontmatter: fm,
		Body:        body,
	}, nil
}

// WriteFile writes the memo's frontmatter and body back to disk.
func (m *Memo) WriteFile() error {
	var buf bytes.Buffer
	buf.WriteString("---\n")

	encoder := yaml.NewEncoder(&buf)
	encoder.SetIndent(2)
	if err := encoder.Encode(&m.Frontmatter); err != nil {
		return fmt.Errorf("encode frontmatter: %w", err)
	}
	buf.WriteString("---\n\n")
	buf.WriteString(strings.TrimSpace(m.Body))
	buf.WriteString("\n")

	return os.WriteFile(m.Path, buf.Bytes(), 0644)
}
