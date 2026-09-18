#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#
# library-prune.sh - run on a cron schedule to keep beets' library.db in sync when
# books are deleted directly from /audiobooks (e.g. by hand, or via Audiobookshelf).
#
# beets' own duplicate detection (used by import-watch.sh to silently drop
# re-downloads of books you already have) checks the database, not the filesystem.
# If a book's folder is deleted but its db record isn't, a future re-download of
# that same book gets misdetected as "already in the library" and silently thrown
# away, even though no copy exists anywhere anymore. This script removes db
# records whose backing file/folder no longer exists, without touching anything
# else (unlike `beet update`, which would also overwrite db-only fields to match
# on-disk tags on every run).

set -uo pipefail

LOG=/config/logs/library-prune.log
LOCK=/config/library-prune.lock

mkdir -p "$(dirname "$LOG")"

exec 200>"$LOCK"
flock -n 200 || exit 0

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"
}

prune() {
    local query="$1" # "-a" for albums, "" for singleton items
    # shellcheck disable=SC2086
    # shellcheck disable=SC2016
    /lsiopy/bin/beet list $query -f '$id::$path' | while IFS=: read -r id _ path; do
        [[ -e "$path" ]] && continue
        # shellcheck disable=SC2086
        /lsiopy/bin/beet remove $query -f "id:$id" >/dev/null 2>&1
        log "Removed missing from library: $path"
    done
}

prune "-a"
prune ""
