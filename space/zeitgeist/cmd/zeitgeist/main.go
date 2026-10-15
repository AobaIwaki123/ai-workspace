package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/aooba/zeitgeist/pkg/config"
	"github.com/aooba/zeitgeist/pkg/driver"
	"github.com/aooba/zeitgeist/pkg/fetcher"
	"github.com/aooba/zeitgeist/pkg/model"
)

func main() {
	configPath := flag.String("config", "configs/sources.sample.yaml", "Path to sources YAML configuration file")
	categoryFilter := flag.String("category", "", "Filter sources by category")
	sourceFilter := flag.String("source", "", "Filter sources by source ID")
	timeoutSec := flag.Int("timeout", 0, "Override timeout in seconds (0 = use config default)")
	verbose := flag.Bool("verbose", false, "Enable debug structured logging to stderr")
	flag.Parse()

	logLevel := slog.LevelInfo
	if *verbose {
		logLevel = slog.LevelDebug
	}
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: logLevel}))
	slog.SetDefault(logger)

	cfg, err := config.Load(*configPath)
	if err != nil {
		slog.Error("Configuration load failed", "error", err)
		os.Exit(1)
	}

	timeout := time.Duration(cfg.TimeoutSeconds) * time.Second
	if *timeoutSec > 0 {
		timeout = time.Duration(*timeoutSec) * time.Second
	}

	// Filter sources based on flags
	var filteredSources []model.Source
	for _, s := range cfg.Sources {
		if *categoryFilter != "" && s.Category != *categoryFilter {
			continue
		}
		if *sourceFilter != "" && s.ID != *sourceFilter {
			continue
		}
		filteredSources = append(filteredSources, s)
	}

	if len(filteredSources) == 0 {
		slog.Warn("No sources matched filters", "category", *categoryFilter, "source", *sourceFilter)
		fmt.Println(`{"total_sources":0,"succeeded_sources":0,"results":[]}`)
		return
	}

	// Setup Driver Registry
	reg := driver.NewRegistry()
	reg.Register("rss", driver.NewRSSDriver(nil))

	engine := fetcher.NewEngine(reg, cfg.Concurrency, timeout)

	ctx := context.Background()
	output, err := engine.Execute(ctx, filteredSources)
	if err != nil {
		slog.Error("Execution failed", "error", err)
		os.Exit(1)
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(output); err != nil {
		slog.Error("JSON encoding failed", "error", err)
		os.Exit(1)
	}
}
