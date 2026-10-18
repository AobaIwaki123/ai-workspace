package memo

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Store handles discovering, listing, creating, and updating memos.
type Store struct {
	Dir string
}

// NewStore initializes a Store with an auto-discovered memo directory if not provided.
func NewStore(customDir string) (*Store, error) {
	dir, err := ResolveMemoDir(customDir)
	if err != nil {
		return nil, err
	}
	return &Store{Dir: dir}, nil
}

// ResolveMemoDir resolves the absolute path to private/memo directory.
func ResolveMemoDir(customDir string) (string, error) {
	if customDir != "" {
		abs, err := filepath.Abs(customDir)
		if err != nil {
			return "", err
		}
		if info, err := os.Stat(abs); err == nil && info.IsDir() {
			return abs, nil
		}
		return "", fmt.Errorf("specified memo directory not found: %s", customDir)
	}

	if env := os.Getenv("MEMO_DIR"); env != "" {
		if info, err := os.Stat(env); err == nil && info.IsDir() {
			return env, nil
		}
	}

	// Search relative candidates
	candidates := []string{
		"private/memo",
		"../private/memo",
		"../../private/memo",
	}

	for _, c := range candidates {
		if abs, err := filepath.Abs(c); err == nil {
			if info, err := os.Stat(abs); err == nil && info.IsDir() {
				return abs, nil
			}
		}
	}

	// Search upwards from cwd to git root
	cwd, err := os.Getwd()
	if err == nil {
		dir := cwd
		for {
			target := filepath.Join(dir, "private", "memo")
			if info, err := os.Stat(target); err == nil && info.IsDir() {
				return target, nil
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}

	// Fallback to $HOME/ai-workspace/private/memo
	if home, err := os.UserHomeDir(); err == nil {
		target := filepath.Join(home, "ai-workspace", "private", "memo")
		if info, err := os.Stat(target); err == nil && info.IsDir() {
			return target, nil
		}
	}

	return "", fmt.Errorf("could not locate private/memo directory. Specify with --dir or MEMO_DIR env var")
}

// ListOptions configures filtering for memos.
type ListOptions struct {
	Status     string
	IncludeAll bool
	Limit      int
}

// List returns memos matching options sorted descending by creation time.
func (s *Store) List(opts ListOptions) ([]*Memo, error) {
	entries, err := os.ReadDir(s.Dir)
	if err != nil {
		return nil, fmt.Errorf("read memo dir: %w", err)
	}

	var filenames []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasSuffix(name, ".md") || strings.EqualFold(name, "README.md") {
			continue
		}
		filenames = append(filenames, name)
	}

	// Sort newest first by filename (YYYY-MM-DD-HHMM prefix)
	sort.Slice(filenames, func(i, j int) bool {
		return filenames[i] > filenames[j]
	})

	var memos []*Memo
	for _, name := range filenames {
		path := filepath.Join(s.Dir, name)
		m, err := ParseFile(path)
		if err != nil {
			// Skip unparseable non-memo markdown files gracefully
			continue
		}

		status := strings.ToLower(m.Frontmatter.Status)
		if status == "" {
			status = StatusHot
		}

		if opts.Status != "" && status != strings.ToLower(opts.Status) {
			continue
		}

		// By default, exclude cold and done if no specific status was requested and !IncludeAll
		if !opts.IncludeAll && opts.Status == "" {
			if status == StatusCold || status == StatusDone {
				continue
			}
		}

		memos = append(memos, m)
		if opts.Limit > 0 && len(memos) >= opts.Limit {
			break
		}
	}

	return memos, nil
}

// Latest returns the most recent hot or active memo.
func (s *Store) Latest() (*Memo, error) {
	// First look for latest HOT memo
	hotMemos, err := s.List(ListOptions{Status: StatusHot, Limit: 1})
	if err == nil && len(hotMemos) > 0 {
		return hotMemos[0], nil
	}

	// Otherwise, return newest overall
	allMemos, err := s.List(ListOptions{IncludeAll: true, Limit: 1})
	if err != nil {
		return nil, err
	}
	if len(allMemos) == 0 {
		return nil, fmt.Errorf("no memos found in %s", s.Dir)
	}
	return allMemos[0], nil
}

// Find locates a memo by partial filename or slug.
func (s *Store) Find(query string) (*Memo, error) {
	if query == "" || query == "latest" {
		return s.Latest()
	}

	memos, err := s.List(ListOptions{IncludeAll: true})
	if err != nil {
		return nil, err
	}

	for _, m := range memos {
		if m.Filename == query || strings.Contains(m.Filename, query) {
			return m, nil
		}
	}

	return nil, fmt.Errorf("memo matching %q not found", query)
}

// Create generates a new memo file conforming to the Time-Decaying Memo Protocol.
func (s *Store) Create(slug string, title string, tags []string) (*Memo, error) {
	if slug == "" {
		slug = "untitled"
	}
	slug = strings.ToLower(strings.ReplaceAll(slug, " ", "-"))

	now := time.Now()
	// YYYY-MM-DD-HHMM_<slug>.md
	filename := fmt.Sprintf("%s_%s.md", now.Format("2006-01-02-1504"), slug)
	path := filepath.Join(s.Dir, filename)

	if _, err := os.Stat(path); err == nil {
		return nil, fmt.Errorf("memo file already exists: %s", filename)
	}

	if title == "" {
		title = strings.ReplaceAll(slug, "-", " ")
	}

	if len(tags) == 0 {
		tags = []string{"schedule", "handover"}
	}

	expiresAt := now.Add(48 * time.Hour)

	fm := Frontmatter{
		CreatedAt: now,
		ExpiresAt: expiresAt,
		Status:    StatusHot,
		Title:     title,
		Tags:      tags,
	}

	dateStr := now.Format("2006-01-02")
	body := fmt.Sprintf("# %s (%s)\n\n## 1. 目的・要点\n\n- \n\n## 2. アクション・スケジュール\n\n- [ ] \n", title, dateStr)

	m := &Memo{
		Path:        path,
		Filename:    filename,
		Frontmatter: fm,
		Body:        body,
	}

	if err := m.WriteFile(); err != nil {
		return nil, err
	}

	return m, nil
}

// DecayItem records a transition in status.
type DecayItem struct {
	Filename  string  `json:"filename"`
	OldStatus string  `json:"old_status"`
	NewStatus string  `json:"new_status"`
	AgeHours  float64 `json:"age_hours"`
}

// Decay updates statuses of expired memos based on 48h and 7d rules.
func (s *Store) Decay(dryRun bool) ([]DecayItem, error) {
	memos, err := s.List(ListOptions{IncludeAll: true})
	if err != nil {
		return nil, err
	}

	now := time.Now()
	var decayed []DecayItem

	for _, m := range memos {
		status := strings.ToLower(m.Frontmatter.Status)
		if status == StatusDone || status == StatusCold {
			continue
		}

		age := now.Sub(m.Frontmatter.CreatedAt)
		ageHours := age.Hours()

		var newStatus string

		// Hot -> Warm if age > 48h or now > expires_at
		if status == StatusHot {
			expired := false
			if !m.Frontmatter.ExpiresAt.IsZero() && now.After(m.Frontmatter.ExpiresAt) {
				expired = true
			} else if ageHours >= 48.0 {
				expired = true
			}

			if expired {
				newStatus = StatusWarm
			}
		}

		// Warm -> Cold if age > 7 days (168 hours)
		if status == StatusWarm && ageHours >= (7*24.0) {
			newStatus = StatusCold
		}

		if newStatus != "" && newStatus != status {
			decayed = append(decayed, DecayItem{
				Filename:  m.Filename,
				OldStatus: status,
				NewStatus: newStatus,
				AgeHours:  ageHours,
			})

			if !dryRun {
				m.Frontmatter.Status = newStatus
				if err := m.WriteFile(); err != nil {
					return nil, fmt.Errorf("write decayed memo %s: %w", m.Filename, err)
				}
			}
		}
	}

	return decayed, nil
}
