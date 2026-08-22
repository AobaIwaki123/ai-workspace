#!/usr/bin/env bash
# validate-skill.sh - Antigravity Skill Validator & Quality Checker
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <skill-directory-or-skill.md>

Options:
  -v, --verbose    Show detailed validation output
  -h, --help       Show this help message

Examples:
  $0 .agents/skills/auto-allow-command
  $0 .agents/skills/auto-allow-command/SKILL.md
EOF
}

VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "Error: Skill path is required." >&2
  usage
  exit 1
fi

TARGET_PATH="$1"

if [[ -f "$TARGET_PATH" && "$(basename "$TARGET_PATH")" == "SKILL.md" ]]; then
  SKILL_DIR="$(dirname "$TARGET_PATH")"
  SKILL_MD="$TARGET_PATH"
elif [[ -d "$TARGET_PATH" ]]; then
  SKILL_DIR="$TARGET_PATH"
  SKILL_MD="$TARGET_PATH/SKILL.md"
else
  echo "❌ Error: Target path '$TARGET_PATH' does not exist." >&2
  exit 1
fi

DIR_NAME="$(basename "$SKILL_DIR")"
ERRORS=0
WARNINGS=0

echo "🔍 Validating skill: $DIR_NAME ($SKILL_DIR)"
echo "--------------------------------------------------"

# 1. Check SKILL.md exists
if [[ ! -f "$SKILL_MD" ]]; then
  echo "❌ Error: SKILL.md not found in $SKILL_DIR"
  ERRORS=$((ERRORS + 1))
else
  echo "✓ SKILL.md exists"
fi

# 2. Check Frontmatter and content via Python
if [[ -f "$SKILL_MD" ]]; then
  VALIDATION_RESULT=$(python3 - "$SKILL_MD" "$DIR_NAME" <<'EOF'
import sys
import os
import re

skill_md = sys.argv[1]
dir_name = sys.argv[2]

with open(skill_md, "r", encoding="utf-8") as f:
    content = f.read()

errors = []
warnings = []

# Frontmatter check
if not content.startswith("---"):
    errors.append("SKILL.md does not start with YAML frontmatter delimiter ('---').")
else:
    parts = content.split("---", 2)
    if len(parts) < 3:
        errors.append("SKILL.md frontmatter is not closed with '---'.")
    else:
        frontmatter = parts[1]
        
        # Check name
        name_match = re.search(r"^name:\s*([^\s]+)", frontmatter, re.MULTILINE)
        if not name_match:
            errors.append("Frontmatter missing 'name' field.")
        else:
            name_val = name_match.group(1).strip("\"'")
            if name_val != dir_name:
                warnings.append(f"Frontmatter name '{name_val}' does not match directory name '{dir_name}'.")
            if not re.match(r"^[a-z0-9-_]+$", name_val):
                errors.append(f"Skill name '{name_val}' contains invalid characters (should be lowercase, digits, hyphens).")
        
        # Check description
        desc_match = re.search(r"^description:\s*([>|-]?\s*\n\s+.*|.+)", frontmatter, re.MULTILINE)
        if not desc_match:
            errors.append("Frontmatter missing 'description' field.")
        else:
            # Extract full multiline description if folded/literal
            lines = frontmatter.splitlines()
            desc_lines = []
            capturing = False
            for line in lines:
                if line.startswith("description:"):
                    capturing = True
                    val = line.split("description:", 1)[1].strip()
                    if val and val not in (">-", ">", "|", "|-"):
                        desc_lines.append(val)
                elif capturing:
                    if line.startswith(" ") or line.startswith("\t"):
                        desc_lines.append(line.strip())
                    elif line and not line.startswith(" "):
                        break
            full_desc = " ".join(desc_lines)
            if len(full_desc) < 15:
                warnings.append(f"Description is very short ('{full_desc}'). Ensure it includes both What and When trigger conditions.")

# Line count / Progressive disclosure
line_count = len(content.splitlines())
if line_count > 300:
    warnings.append(f"SKILL.md is long ({line_count} lines). Consider moving detailed references to references/ directory.")

# Check relative links
links = re.findall(r'\[.*?\]\(((\./|\.\./)[^\)]+)\)', content)
base_dir = os.path.dirname(skill_md)
for link_tuple in links:
    link = link_tuple[0].split('#')[0]
    target_path = os.path.normpath(os.path.join(base_dir, link))
    if not os.path.exists(target_path):
        errors.append(f"Broken relative link in SKILL.md: '{link}' -> '{target_path}' not found.")

for e in errors:
    print(f"ERROR: {e}")
for w in warnings:
    print(f"WARN: {w}")
EOF
)

  while IFS= read -r line; do
    if [[ "$line" =~ ^ERROR: ]]; then
      echo "❌ $line"
      ERRORS=$((ERRORS + 1))
    elif [[ "$line" =~ ^WARN: ]]; then
      echo "⚠️  $line"
      WARNINGS=$((WARNINGS + 1))
    fi
  done <<< "$VALIDATION_RESULT"
fi

# 3. Check scripts directory & permissions
if [[ -d "$SKILL_DIR/scripts" ]]; then
  echo "✓ scripts/ directory found"
  for script in "$SKILL_DIR"/scripts/*; do
    if [[ -f "$script" ]]; then
      SCRIPT_BASE="$(basename "$script")"
      if [[ ! -x "$script" ]]; then
        echo "❌ Error: Script '$SCRIPT_BASE' is not executable (run chmod +x $script)"
        ERRORS=$((ERRORS + 1))
      else
        echo "  ✓ Executable: $SCRIPT_BASE"
      fi
      
      if [[ "$script" == *.sh ]]; then
        if ! bash -n "$script" 2>/dev/null; then
          echo "❌ Error: Bash syntax error in '$SCRIPT_BASE'"
          ERRORS=$((ERRORS + 1))
        fi
      fi
    fi
  done
fi

# 4. Check references directory
if [[ -d "$SKILL_DIR/references" ]]; then
  REF_COUNT=$(find "$SKILL_DIR/references" -type f | wc -l | tr -d ' ')
  echo "✓ references/ directory found ($REF_COUNT reference files)"
fi

echo "--------------------------------------------------"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "🎉 Validation PASSED: Skill is well-structured and follows best practices."
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo "⚠️  Validation PASSED with $WARNINGS warning(s)."
  exit 0
else
  echo "❌ Validation FAILED: Found $ERRORS error(s) and $WARNINGS warning(s)."
  exit 1
fi
