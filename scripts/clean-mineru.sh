#!/usr/bin/env bash
set -euo pipefail

# MinerU "Perfect" Cleanup Script
# Removes intermediate artifacts, visual debugging files, and empty byproduct folders.
# Keeps: Markdown files, useful images (if they contain content), and document structure.

VERSION="2.0.0"

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [TARGET_DIR]

A perfect cleanup utility for MinerU output artifacts. 

Options:
  -d, --dry-run    Show what would be removed without actually deleting.
  -f, --force      Force removal without confirmation.
  -r, --recursive  Recursively clean subdirectories.
  -h, --help       Show this help message and exit.
  -v, --version    Show version information.

If TARGET_DIR is not specified, the current directory is used.

Files removed:
  * _layout.pdf, _span.pdf, _origin.pdf (Visual debugging)
  * _content_list.json, _middle.json, _model.json (Intermediate data)
  * model_output.txt (Log artifacts)
  * Empty directories resulting from cleanup.
EOF
}

# Default values
TARGET_DIR="."
DRY_RUN=false
FORCE=false
RECURSIVE=false

# Simple argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "clean-mineru version $VERSION"
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory '$TARGET_DIR' does not exist.${NC}"
    exit 1
fi

# Expand path to absolute
TARGET_DIR=$(realpath "$TARGET_DIR")

echo -e "${BLUE}Cleaning MinerU artifacts in: ${YELLOW}$TARGET_DIR${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}*** DRY RUN MODE - No files will be deleted ***${NC}"
fi

# Patterns to remove
PATTERNS=(
    "*_layout.pdf"
    "*_span.pdf"
    "*_origin.pdf"
    "*_content_list.json"
    "*_middle.json"
    "*_model.json"
    "model_output.txt"
)

# Find command construction
FIND_CMD=("find" "$TARGET_DIR")
if [ "$RECURSIVE" = false ]; then
    FIND_CMD+=("-maxdepth" "1")
fi

# Build patterns for find
PATTERN_ARGS=()
for i in "${!PATTERNS[@]}"; do
    if [ $i -gt 0 ]; then
        PATTERN_ARGS+=("-o")
    fi
    PATTERN_ARGS+=("-name" "${PATTERNS[$i]}")
done

# Execute find and delete
total_removed=0

# Use a temp file for list of files to avoid issues with spaces and large numbers of files
temp_list=$(mktemp)
"${FIND_CMD[@]}" \( "${PATTERN_ARGS[@]}" \) -type f > "$temp_list"

while IFS= read -r file; do
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Will remove: ${NC}$file"
    else
        if [ "$FORCE" = true ]; then
            rm -f "$file"
            echo -e "${RED}[REMOVED]${NC} $file"
        else
            echo -n "Remove $file? [y/N] "
            read -r response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                rm -f "$file"
                echo -e "${RED}[REMOVED]${NC} $file"
            else
                echo "Skipping $file"
                continue
            fi
        fi
    fi
    ((total_removed += 1))
done < "$temp_list"
rm "$temp_list"

# Cleanup empty directories
echo -e "${BLUE}Cleaning up empty directories...${NC}"
# We always do this recursively for empty dirs in the target
if [ "$DRY_RUN" = true ]; then
    find "$TARGET_DIR" -type d -empty -not -path "$TARGET_DIR" -exec echo -e "${BLUE}[DRY-RUN] Will remove empty dir: ${NC}{}" \;
else
    find "$TARGET_DIR" -type d -empty -not -path "$TARGET_DIR" -delete
fi

echo
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}Dry run finished. $total_removed files would be removed.${NC}"
else
    echo -e "${GREEN}Cleanup finished. $total_removed files removed.${NC}"
fi
