#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/gitignore.template"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "error: template not found at $TEMPLATE"
    exit 1
fi

if [[ -f ".gitignore" ]]; then
    read -rp ".gitignore already exists. overwrite? (y/n): " OVERWRITE
    [[ "$OVERWRITE" != "y" ]] && echo "cancelled." && exit 0
fi

cp "$TEMPLATE" ".gitignore"
echo "done: .gitignore created."
