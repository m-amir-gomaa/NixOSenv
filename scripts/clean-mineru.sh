#!/usr/bin/env bash
set -euo pipefail

# MinerU cleanup script
# Removes intermediate artifacts and keeps only the useful files.

TARGET_DIR="${1:-.}"

echo "Cleaning MinerU artifacts in: $TARGET_DIR"
echo

cd "$TARGET_DIR"

removed=0

for pattern in \
	"*_layout.pdf" \
	"*_span.pdf" \
	"*_origin.pdf" \
	"*_content_list.json" \
	"*_middle.json" \
	"*_model.json"; do
	files=($pattern)
	if [ -e "${files[0]}" ]; then
		echo "Removing $pattern"
		rm -f $pattern
		((removed += 1))
	fi
done

echo
echo "Cleanup finished."

if [ "$removed" -eq 0 ]; then
	echo "No MinerU artifacts found."
else
	echo "$removed artifact groups removed."
fi
