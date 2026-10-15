package driver

import (
	"context"
	"fmt"
	"html"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/aooba/zeitgeist/pkg/model"
	"github.com/mmcdole/gofeed"
)

var (
	htmlTagRegex = regexp.MustCompile(`<[^>]*>`)
	spaceRegex   = regexp.MustCompile(`\s+`)
)

// RSSDriver parses standard RSS, Atom, and JSON feeds using gofeed.
type RSSDriver struct {
	client *http.Client
}

// NewRSSDriver creates an RSSDriver with a default HTTP client.
func NewRSSDriver(client *http.Client) *RSSDriver {
	if client == nil {
		client = &http.Client{
			Timeout: 15 * time.Second,
		}
	}
	return &RSSDriver{client: client}
}

// Fetch executes feed parsing and cleans up items.
func (d *RSSDriver) Fetch(ctx context.Context, src model.Source) ([]model.Item, error) {
	fp := gofeed.NewParser()
	fp.Client = d.client
	fp.UserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Zeitgeist/1.0"

	feed, err := fp.ParseURLWithContext(src.Endpoint, ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to parse feed %s: %w", src.Endpoint, err)
	}

	limit := src.Limit
	if limit <= 0 {
		limit = 5
	}

	var items []model.Item
	for i, entry := range feed.Items {
		if i >= limit {
			break
		}

		title := sanitizeText(entry.Title)
		url := strings.TrimSpace(entry.Link)
		snippet := sanitizeText(entry.Description)
		if snippet == "" {
			snippet = sanitizeText(entry.Content)
		}

		// Truncate overly long snippets to keep token usage minimal (max 200 runes)
		runes := []rune(snippet)
		if len(runes) > 200 {
			snippet = string(runes[:200]) + "..."
		}

		var pubDate *time.Time
		if entry.PublishedParsed != nil {
			pubDate = entry.PublishedParsed
		} else if entry.UpdatedParsed != nil {
			pubDate = entry.UpdatedParsed
		}

		items = append(items, model.Item{
			Title:       title,
			URL:         url,
			PublishedAt: pubDate,
			Snippet:     snippet,
		})
	}

	return items, nil
}

// sanitizeText strips HTML tags, decodes entities, and collapses excessive whitespace.
func sanitizeText(raw string) string {
	stripped := htmlTagRegex.ReplaceAllString(raw, " ")
	unescaped := html.UnescapeString(stripped)
	collapsed := spaceRegex.ReplaceAllString(unescaped, " ")
	return strings.TrimSpace(collapsed)
}
