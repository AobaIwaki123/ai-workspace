package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/AobaIwaki123/memo-cli/pkg/memo"
)

const version = "0.1.0"

func printUsage() {
	fmt.Fprintf(os.Stderr, `memo - Personal Time-Decaying Memo CLI (v%s)

Usage:
  memo [command] [options]

Commands:
  list                 List recent active memos (default command)
  show [query]         Display the content of a memo (default: latest hot memo)
  path [query]         Print the absolute file path of a memo
  new <slug>           Create a new timestamped memo
  decay                Inspect and auto-decay expired memos (48h/7d lifecycle)
  version              Show CLI version

Options for 'list':
  -dir string          Override private/memo directory path
  -status string       Filter by status (hot, warm, cold, done)
  -all                 Include cold and done memos
  -limit int           Maximum number of memos to list (0 = unlimited)
  -json                Output list in JSON format

Options for 'show':
  -dir string          Override private/memo directory path
  -path                Print only the file path instead of content

Options for 'new':
  -dir string          Override private/memo directory path
  -title string        Title for the memo (default: humanized slug)
  -tags string         Comma-separated tags (default: schedule,handover)
  -open                Open the created memo in $EDITOR or code

Options for 'decay':
  -dir string          Override private/memo directory path
  -dry-run             Preview status changes without writing to disk
  -json                Output decay report in JSON format

`, version)
}

func main() {
	if len(os.Args) < 2 {
		runList(os.Args[1:])
		return
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	case "list", "ls":
		runList(args)
	case "show", "cat":
		runShow(args)
	case "path":
		runPath(args)
	case "new", "create":
		runNew(args)
	case "decay":
		runDecay(args)
	case "version", "-v", "--version":
		fmt.Printf("memo version %s\n", version)
	case "help", "-h", "--help":
		printUsage()
	default:
		// If arg starts with '-', treat as flag for list
		if strings.HasPrefix(cmd, "-") {
			runList(os.Args[1:])
			return
		}
		// Otherwise check if it's a slug to show
		runShow(os.Args[1:])
	}
}

func runList(args []string) {
	fs := flag.NewFlagSet("list", flag.ExitOnError)
	dir := fs.String("dir", "", "Path to private/memo directory")
	status := fs.String("status", "", "Filter by status (hot, warm, cold, done)")
	all := fs.Bool("all", false, "Include cold and done memos")
	limit := fs.Int("limit", 0, "Limit number of items")
	jsonOutput := fs.Bool("json", false, "Output in JSON format")
	_ = fs.Parse(args)

	store, err := memo.NewStore(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	memos, err := store.List(memo.ListOptions{
		Status:     *status,
		IncludeAll: *all,
		Limit:      *limit,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if *jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(memos)
		return
	}

	memo.RenderTable(os.Stdout, memos)
}

func runShow(args []string) {
	fs := flag.NewFlagSet("show", flag.ExitOnError)
	dir := fs.String("dir", "", "Path to private/memo directory")
	pathOnly := fs.Bool("path", false, "Print file path only")
	_ = fs.Parse(args)

	query := "latest"
	if fs.NArg() > 0 {
		query = fs.Arg(0)
	}

	store, err := memo.NewStore(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	m, err := store.Find(query)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if *pathOnly {
		fmt.Println(m.Path)
		return
	}

	// Print formatted memo
	fmt.Printf("%s=== %s (%s) ===%s\n", "\033[1m\033[36m", m.Frontmatter.Title, m.Filename, "\033[0m")
	fmt.Printf("Status: %s | Created: %s | Tags: [%s]\n\n",
		memo.FormatBadge(m.Frontmatter.Status),
		m.Frontmatter.CreatedAt.Format("2006-01-02 15:04"),
		strings.Join(m.Frontmatter.Tags, ", "),
	)
	fmt.Println(m.Body)
}

func runPath(args []string) {
	fs := flag.NewFlagSet("path", flag.ExitOnError)
	dir := fs.String("dir", "", "Path to private/memo directory")
	_ = fs.Parse(args)

	query := "latest"
	if fs.NArg() > 0 {
		query = fs.Arg(0)
	}

	store, err := memo.NewStore(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	m, err := store.Find(query)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(m.Path)
}

func runNew(args []string) {
	fs := flag.NewFlagSet("new", flag.ExitOnError)
	dir := fs.String("dir", "", "Path to private/memo directory")
	title := fs.String("title", "", "Title for the memo")
	tagsStr := fs.String("tags", "", "Comma-separated tags")
	openEditor := fs.Bool("open", false, "Open created file in editor")
	_ = fs.Parse(args)

	if fs.NArg() == 0 {
		fmt.Fprintf(os.Stderr, "Error: memo slug name is required\nUsage: memo new <slug> [-title=\"...\"] [-tags=\"...\"]\n")
		os.Exit(1)
	}

	slug := fs.Arg(0)
	var tags []string
	if *tagsStr != "" {
		for _, t := range strings.Split(*tagsStr, ",") {
			trimmed := strings.TrimSpace(t)
			if trimmed != "" {
				tags = append(tags, trimmed)
			}
		}
	}

	store, err := memo.NewStore(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	m, err := store.Create(slug, *title, tags)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating memo: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("%sCreated new memo:%s %s\n", "\033[32m\033[1m", "\033[0m", m.Filename)
	fmt.Printf("Path: %s\n", m.Path)

	if *openEditor {
		editor := os.Getenv("EDITOR")
		if editor == "" {
			if _, err := exec.LookPath("code"); err == nil {
				editor = "code"
			} else {
				editor = "vi"
			}
		}
		cmd := exec.Command(editor, m.Path)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		_ = cmd.Run()
	}
}

func runDecay(args []string) {
	fs := flag.NewFlagSet("decay", flag.ExitOnError)
	dir := fs.String("dir", "", "Path to private/memo directory")
	dryRun := fs.Bool("dry-run", false, "Preview status transitions without writing")
	jsonOutput := fs.Bool("json", false, "Output in JSON format")
	_ = fs.Parse(args)

	store, err := memo.NewStore(*dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	items, err := store.Decay(*dryRun)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if *jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(items)
		return
	}

	if len(items) == 0 {
		fmt.Println("All memos are up to date. No decay transitions required.")
		return
	}

	mode := "Applied"
	if *dryRun {
		mode = "Dry-run Preview"
	}
	fmt.Printf("=== Memo Decay Status (%s) ===\n", mode)
	for _, item := range items {
		fmt.Printf("- %-50s : %s -> %s (age: %.1fh)\n",
			item.Filename,
			memo.FormatBadge(item.OldStatus),
			memo.FormatBadge(item.NewStatus),
			item.AgeHours,
		)
	}
}
