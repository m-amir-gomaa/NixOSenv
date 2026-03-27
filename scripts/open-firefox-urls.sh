#!/usr/bin/env bash

# Script to open Firefox on NixOS with URLs constructed from a base URL + list of strings from a file
# Usage: ./open-firefox-urls.sh "https://example.com/search?q=" strings.txt

set -euo pipefail

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Incorrect number of arguments"
    echo "Usage: $0 <base-url> <strings-file>"
    echo "Example: $0 'https://example.com/page/' strings.txt"
    echo ""
    echo "The strings file should contain one string per line."
    exit 1
fi

BASE_URL="$1"
STRINGS_FILE="$2"

# Check if the strings file exists
if [ ! -f "$STRINGS_FILE" ]; then
    echo "Error: File '$STRINGS_FILE' not found"
    exit 1
fi

# Read strings from file into array (one per line)
mapfile -t STRINGS < "$STRINGS_FILE"

# Check if any strings were read
if [ ${#STRINGS[@]} -eq 0 ]; then
    echo "Error: No strings found in '$STRINGS_FILE'"
    exit 1
fi

# Array to hold all constructed URLs
URLS=()

# Construct URLs by appending each string to the base URL
for string in "${STRINGS[@]}"; do
    URLS+=("${BASE_URL}${string}")
done

# Check if Firefox is available
if ! command -v firefox &> /dev/null; then
    echo "Error: Firefox is not installed or not in PATH"
    echo "On NixOS, you can install it by adding 'firefox' to your configuration.nix"
    exit 1
fi

# Open all URLs in Firefox
# Each URL will open in a new tab
echo "Opening ${#URLS[@]} URLs in Firefox..."
firefox "${URLS[@]}" &

echo "Done! Firefox should now be opening with your URLs."
