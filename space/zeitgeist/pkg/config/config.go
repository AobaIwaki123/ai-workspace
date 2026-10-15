package config

import (
	"fmt"
	"os"

	"github.com/aooba/zeitgeist/pkg/model"
	"gopkg.in/yaml.v3"
)

// Config holds the overall runtime configuration and source definitions.
type Config struct {
	TimeoutSeconds int            `yaml:"timeout_seconds"`
	Concurrency    int            `yaml:"concurrency"`
	DefaultLimit   int            `yaml:"default_limit"`
	Sources        []model.Source `yaml:"sources"`
}

// Load reads and parses a YAML configuration file from the given path.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file %q: %w", path, err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse YAML from %q: %w", path, err)
	}

	// Apply sensible defaults
	if cfg.TimeoutSeconds <= 0 {
		cfg.TimeoutSeconds = 15
	}
	if cfg.Concurrency <= 0 {
		cfg.Concurrency = 5
	}
	if cfg.DefaultLimit <= 0 {
		cfg.DefaultLimit = 5
	}

	for i := range cfg.Sources {
		if cfg.Sources[i].Limit <= 0 {
			cfg.Sources[i].Limit = cfg.DefaultLimit
		}
	}

	return &cfg, nil
}
