#!/bin/bash
PATH=/snap/bin:/usr/local/bin:/usr/bin:/bin

cd "$(dirname "$(readlink -f "$0")")"

APPRISE_URL="${APPRISE_URL:-http://localhost:8000}"
APPRISE_KEY="33fe5ea69a19d28aa69a2d89aaadc200c9e6386238127ac9b34f274ced91f444"
APPRISE_TAG="Discord"

ntfy_send() {
    local event="$1" reason="${2:-}"
    local title type body

    case "$event" in
        start)
            title="🔄  Plex Stack — Update Starting"
            type="info"
            body="Pulling latest images and recreating containers…"
            ;;
        success)
            title="✅  Plex Stack — Update Complete"
            type="success"
            body="All containers updated and running."
            ;;
        failure)
            title="❌  Plex Stack — Update Failed"
            type="failure"
            body="**Error:**  ${reason}"
            ;;
    esac

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg body "$body" \
        --arg type "$type" \
        --arg tag "$APPRISE_TAG" \
        '{title: $title, body: $body, type: $type, tag: $tag, body_format: "markdown"}')
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${APPRISE_URL}/notify/${APPRISE_KEY}" >/dev/null 2>&1 || true
}

ntfy_send "start"

tmpfile=$(mktemp)

(
    set -e
    echo "==> Pulling latest images..."
    docker compose pull

    echo "==> Rebuilding Plex with latest base image..."
    docker compose build --pull plex

    echo "==> Recreating updated containers..."
    docker compose up -d

    echo "==> Cleaning up old images..."
    docker image prune -f

    echo "==> Done."
    docker compose ps
) 2>&1 | tee "$tmpfile"
exit_code=${PIPESTATUS[0]}

if [[ $exit_code -eq 0 ]]; then
    ntfy_send "success"
else
    reason=$(grep -iE 'error|failed|fatal' "$tmpfile" | \
        sed 's/\x1b\[[0-9;]*m//g' | tail -3 | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
    [[ -z "$reason" ]] && \
        reason=$(tail -3 "$tmpfile" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
    ntfy_send "failure" "${reason:0:200}"
fi

rm -f "$tmpfile"
exit $exit_code
