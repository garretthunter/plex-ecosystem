#!/bin/bash
# Runs on every container start (linuxserver custom-cont-init.d convention).
# beets-audible isn't in the base beets image, so it's installed here instead of baked into a custom image.
echo "Installing beets-audible..."
pip install --no-cache-dir beets-audible

# This image's init-crontab-config only auto-configures cron for users that have a
# /defaults/crontabs/<user> file baked into the image, which this image doesn't ship.
# So install the crontab directly instead -- svc-cron already starts crond as soon as
# it finds a non-empty crontab for user abc. Re-running `crontab -u abc -` every boot
# is idempotent (it just replaces the whole table), so this is safe to repeat.
echo "Installing import-watch.sh and library-prune.sh cron jobs..."
{
    echo "*/5 * * * * /bin/bash /custom-cont-init.d/import-watch.sh"
    echo "0 * * * * /bin/bash /custom-cont-init.d/library-prune.sh"
} | crontab -u abc -
