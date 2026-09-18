#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#
# import-watch.sh - run on a cron schedule (see /config/crontabs/abc) to auto-import
# confidently-matched audiobooks as soon as qBittorrent finishes downloading them.
#
# For each top-level item under /input -- ideally each completed download lands in its own
# folder (requires the qBittorrent "books" category's Torrent Content Layout set to "Create
# subfolder"), but loose files directly under /input are also handled since that setting
# isn't reliably on for every torrent:
#   - Skip it if modified within the last QUIET_PERIOD seconds (still being written/moved).
#   - Skip it if already handled. Directories get an internal .beets-imported /
#     .beets-needs-review marker; loose files get a sidecar marker next to them
#     (name.beets-imported / name.beets-needs-review) since a marker can't live inside a file.
#   - Run beets.sh (the existing SABnzbd/NZBGet-style import hook) against it. Quiet mode
#     (-q, baked into beets.sh) only auto-applies strong matches; anything weaker is
#     skipped and left in place, so we grep beets' own "Skipping." message to tell the
#     two cases apart -- there's no cheap way to ask beets directly whether a given source
#     path ended up imported, since the library only tracks destination paths.
#   - Strong match -> beets already copied it into the library, so delete the source from
#     /input, and send a single green-checkmark success notification via Apprise.
#   - Weak/no match -> mark .beets-needs-review, and send a single red-X failure
#     notification via Apprise so a human knows to run `beet import` interactively on
#     it. Source is left in place untouched, since the match wasn't applied and there's
#     nothing to clean up.
#
# Each item gets at most one notification per run (guarded by notify_once, keyed on
# name) -- flock already stops two runs overlapping, but this is cheap insurance
# against the same item somehow being notified about twice in one pass.

set -uo pipefail

INPUT_DIR=/input
QUIET_PERIOD=300 # seconds; skip anything touched more recently than this
LOG=/config/logs/import-watch.log
FAIL_LOG=/config/logs/needs-review.log
LOCK=/config/import-watch.lock

mkdir -p "$(dirname "$LOG")"

fail_log() {
    printf '%s :: %s :: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$FAIL_LOG"
}

# An import can take far longer than the 5-minute cron interval. Without this, the next
# tick starts a second pass over /input while the first is still running, and any item both
# passes reach before either one marks/removes it gets imported twice (observed in practice:
# duplicate library entries, orphaned duplicate files).
exec 200>"$LOCK"
flock -n 200 || exit 0

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"
}

SUCCESS_ICON="✅"
FAILURE_ICON="❌"

notify() {
    local title="$1" body="$2"
    [[ -z "${APPRISE_URL:-}" || -z "${APPRISE_KEY:-}" ]] && return 0
    curl -sf -X POST "${APPRISE_URL}/notify/${APPRISE_KEY}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg title "$title" --arg body "$body" --arg tag "Discord" \
            '{title: $title, body: $body, tag: $tag}')" \
        >/dev/null 2>&1 || true
}

# Sends at most one notification per $1 (item name) per run, icon-prefixed at the
# start of the title line ($SUCCESS_ICON or $FAILURE_ICON).
declare -A notified_items
notify_once() {
    local name="$1" icon="$2" title="$3" body="$4"
    [[ -n "${notified_items[$name]:-}" ]] && return 0
    notified_items[$name]=1
    notify "${icon} ${title}" "$body"
}

shopt -s nullglob
for item in "$INPUT_DIR"/*; do
    name="$(basename "$item")"

    # Skip marker files and anything already handled.
    [[ "$name" == *.beets-imported || "$name" == *.beets-needs-review ]] && continue
    if [[ -d "$item" ]]; then
        marker_imported="$item/.beets-imported"
        marker_review="$item/.beets-needs-review"
    else
        marker_imported="$item.beets-imported"
        marker_review="$item.beets-needs-review"
    fi
    [[ -e "$marker_imported" || -e "$marker_review" ]] && continue

    if [[ -n "$(find "$item" -newermt "-${QUIET_PERIOD} seconds")" ]]; then
        continue # still being written to
    fi

    log "Importing: $name"
    output="$(/config/beets.sh "$item" 2>&1)"
    printf '%s\n' "$output" >>"$LOG"

    if grep -qi "already in the library" <<<"$output"; then
        # A re-downloaded duplicate of something already imported -- safe to clean up
        # silently, no human needs to look at this.
        rm -rf -- "$item"
        log "Duplicate of an already-imported book, removed from /input: $name"
    elif grep -qi "Skipping\." <<<"$output"; then
        touch "$marker_review"
        log "Needs review: $name"
        fail_log "$name" "weak or no match"
        notify_once "$name" "$FAILURE_ICON" "Audiobookshelf: import needs review" \
            "\"$name\" wasn't a confident match. Run: docker exec -it -u abc beets-audible beet import \"/input/$name\""
    elif grep -qi "Sending event: album_imported\|Sending event: item_imported" <<<"$output"; then
        rm -rf -- "$item"
        log "Imported and removed from /input: $name"
        notify_once "$name" "$SUCCESS_ICON" "Audiobookshelf: import succeeded" \
            "\"$name\" was matched and imported into the library."
    else
        # Output didn't match any known success/skip pattern -- don't assume success
        # (this previously caused false "Imported" log entries when the source had
        # already been moved out from under a still-running beets.sh call).
        touch "$marker_review"
        log "Unrecognized beets.sh output, needs review: $name"
        fail_log "$name" "unrecognized beets.sh output"
        notify_once "$name" "$FAILURE_ICON" "Audiobookshelf: import needs review" \
            "\"$name\" produced unexpected output during import. Check the log."
    fi
done
