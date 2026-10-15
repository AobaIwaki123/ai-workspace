package fetcher

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/aooba/zeitgeist/pkg/driver"
	"github.com/aooba/zeitgeist/pkg/model"
)

// Engine orchestrates concurrent fetching across multiple sources.
type Engine struct {
	registry    *driver.Registry
	concurrency int
	timeout     time.Duration
}

// NewEngine creates an Engine with the given driver registry and settings.
func NewEngine(reg *driver.Registry, concurrency int, timeout time.Duration) *Engine {
	if concurrency <= 0 {
		concurrency = 5
	}
	if timeout <= 0 {
		timeout = 15 * time.Second
	}
	return &Engine{
		registry:    reg,
		concurrency: concurrency,
		timeout:     timeout,
	}
}

// Execute runs all enabled sources concurrently and aggregates results.
func (e *Engine) Execute(ctx context.Context, sources []model.Source) (*model.Output, error) {
	ctx, cancel := context.WithTimeout(ctx, e.timeout)
	defer cancel()

	var enabledSources []model.Source
	for _, src := range sources {
		if src.Enabled {
			enabledSources = append(enabledSources, src)
		}
	}

	total := len(enabledSources)
	results := make([]model.SourceResult, total)
	succeeded := 0

	sem := make(chan struct{}, e.concurrency)
	var wg sync.WaitGroup
	var mu sync.Mutex

	startTime := time.Now()
	slog.Info("Starting concurrent fetch",
		"total_sources", total,
		"concurrency", e.concurrency,
		"timeout", e.timeout.String(),
	)

	for idx, src := range enabledSources {
		wg.Add(1)
		go func(i int, s model.Source) {
			defer wg.Done()

			select {
			case sem <- struct{}{}:
				defer func() { <-sem }()
			case <-ctx.Done():
				mu.Lock()
				results[i] = model.SourceResult{
					Source: s,
					Error:  ctx.Err().Error(),
				}
				mu.Unlock()
				slog.Warn("Source cancelled before start", "source_id", s.ID, "error", ctx.Err())
				return
			}

			d, err := e.registry.Get(s.Driver)
			if err != nil {
				mu.Lock()
				results[i] = model.SourceResult{
					Source: s,
					Error:  err.Error(),
				}
				mu.Unlock()
				slog.Error("Driver lookup failed", "source_id", s.ID, "driver", s.Driver, "error", err)
				return
			}

			slog.Debug("Fetching source", "source_id", s.ID, "driver", s.Driver, "endpoint", s.Endpoint)
			items, fetchErr := d.Fetch(ctx, s)

			mu.Lock()
			defer mu.Unlock()

			if fetchErr != nil {
				results[i] = model.SourceResult{
					Source: s,
					Error:  fetchErr.Error(),
				}
				slog.Warn("Source fetch failed", "source_id", s.ID, "error", fetchErr)
			} else {
				results[i] = model.SourceResult{
					Source: s,
					Items:  items,
				}
				succeeded++
				slog.Info("Source fetched successfully", "source_id", s.ID, "items_count", len(items))
			}
		}(idx, src)
	}

	wg.Wait()

	slog.Info("Fetch completed",
		"total", total,
		"succeeded", succeeded,
		"elapsed", time.Since(startTime).String(),
	)

	return &model.Output{
		FetchedAt:        time.Now(),
		TotalSources:     total,
		SucceededSources: succeeded,
		Results:          results,
	}, nil
}
