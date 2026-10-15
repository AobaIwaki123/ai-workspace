package model

import "time"

// Source defines a single content provider/medium and how to fetch it.
type Source struct {
	ID          string `yaml:"id" json:"id"`
	Name        string `yaml:"name" json:"name"`
	Description string `yaml:"description" json:"description"`
	Category    string `yaml:"category" json:"category"`
	Driver      string `yaml:"driver" json:"driver"`
	Endpoint    string `yaml:"endpoint" json:"endpoint"`
	Limit       int    `yaml:"limit" json:"limit"` // max items to retain (default: 5)
	Enabled     bool   `yaml:"enabled" json:"enabled"`
}

// Item represents a normalized piece of content extracted from a source.
type Item struct {
	Title       string     `json:"title"`
	URL         string     `json:"url"`
	PublishedAt *time.Time `json:"published_at,omitempty"`
	Snippet     string     `json:"snippet"`
}

// SourceResult wraps a source's metadata alongside its fetched items.
type SourceResult struct {
	Source Source `json:"source"`
	Items  []Item `json:"items"`
	Error  string `json:"error,omitempty"`
}

// Output is the root JSON structure emitted by the CLI.
type Output struct {
	FetchedAt        time.Time      `json:"fetched_at"`
	TotalSources     int            `json:"total_sources"`
	SucceededSources int            `json:"succeeded_sources"`
	Results          []SourceResult `json:"results"`
}
