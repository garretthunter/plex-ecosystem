#!/usr/bin/env bash
# resolve-reviews.sh - run by hand on the host to work through everything
# import-watch.sh flagged with .beets-needs-review, one at a time.
#
# For each flagged item still sitting in /input, opens an interactive
# `beet import` so you can pick the right match (or skip/leave it). Once an
# item is resolved, beets removes it from /input itself, so the marker never
# needs manual cleanup.
#
# Usage: ./beets/scripts/resolve-reviews.sh

set -euo pipefail

CONTAINER=beets-audible
INPUT_HOST="${HOST_MOUNT:-/media/garrett/plexmedia}/data/torrents/books"

shopt -s nullglob
items=()
for item in "$INPUT_HOST"/*; do
    name="$(basename "$item")"
    [[ "$name" == *.beets-imported || "$name" == *.beets-needs-review ]] && continue
    if [[ -d "$item" ]]; then
        marker="$item/.beets-needs-review"
    else
        marker="$item.beets-needs-review"
    fi
    [[ -e "$marker" ]] && items+=("$name")
done

if [[ ${#items[@]} -eq 0 ]]; then
    echo "Nothing flagged for review."
    exit 0
fi

echo "${#items[@]} item(s) need review:"
printf '  - %s\n' "${items[@]}"
echo

for name in "${items[@]}"; do
    echo "=== $name ==="
    docker exec -it -u abc "$CONTAINER" beet import "/input/$name" || true
    if [[ -e "$INPUT_HOST/$name" ]]; then
        echo ">> still in /input, left for later."
    else
        echo ">> resolved."
    fi
    echo
done
