package memo

import (
	"fmt"
	"io"
	"strings"
	"time"
)

// ANSI terminal colors
const (
	colorReset  = "\033[0m"
	colorBold   = "\033[1m"
	colorDim    = "\033[2m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
	colorCyan   = "\033[36m"
)

// FormatBadge returns an emoji badge with colored label.
func FormatBadge(status string) string {
	switch strings.ToLower(status) {
	case StatusHot:
		return fmt.Sprintf("%s%s🔥 HOT %s", colorBold, colorRed, colorReset)
	case StatusWarm:
		return fmt.Sprintf("%s%s⛅ WARM%s", colorBold, colorYellow, colorReset)
	case StatusCold:
		return fmt.Sprintf("%s❄️ COLD%s", colorDim, colorReset)
	case StatusDone:
		return fmt.Sprintf("%s%s✅ DONE%s", colorBold, colorGreen, colorReset)
	default:
		return status
	}
}

// FormatAge returns a compact human-readable duration (e.g., "4h", "1d").
func FormatAge(d time.Duration) string {
	if d < 0 {
		return "just now"
	}
	if d < time.Minute {
		return "just now"
	}
	if d < time.Hour {
		return fmt.Sprintf("%dm ago", int(d.Minutes()))
	}
	if d < 24*time.Hour {
		return fmt.Sprintf("%dh ago", int(d.Hours()))
	}
	days := int(d.Hours() / 24)
	return fmt.Sprintf("%dd ago", days)
}

// RenderTable writes a formatted list of memos to the writer.
func RenderTable(w io.Writer, memos []*Memo) {
	if len(memos) == 0 {
		fmt.Fprintln(w, "No memos found matching criteria.")
		return
	}

	fmt.Fprintf(w, "%-12s  %-10s  %-40s  %-20s  %s\n", "STATUS", "AGE", "TITLE", "TAGS", "FILENAME")
	fmt.Fprintf(w, "%s\n", strings.Repeat("-", 110))

	for _, m := range memos {
		statusBadge := FormatBadge(m.Frontmatter.Status)
		ageStr := FormatAge(m.Age())
		title := m.Frontmatter.Title
		if len([]rune(title)) > 38 {
			title = string([]rune(title)[:35]) + "..."
		}

		tags := strings.Join(m.Frontmatter.Tags, ",")
		if len(tags) > 18 {
			tags = tags[:15] + "..."
		}

		// Calculate visual padding for status since ANSI codes alter byte length
		fmt.Fprintf(w, "%-20s  %-10s  %-40s  %-20s  %s%s%s\n",
			statusBadge,
			ageStr,
			title,
			tags,
			colorDim,
			m.Filename,
			colorReset,
		)
	}
}
