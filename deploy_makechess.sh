#!/bin/sh
set -eu

SITE="/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess"
ARCHIVE="/home/flexyops/makechess_web.tar.gz"
BACKUPS="/home/flexyops/makechess_backups"
NEW="/home/flexyops/makechess_new"
OLD="/home/flexyops/makechess_old"
STAMP="$(date +%Y%m%d_%H%M%S)"

restore_old() {
    find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "$OLD"/. "$SITE"/
}

mkdir -p "$BACKUPS"
rm -rf "$NEW" "$OLD"
mkdir -p "$NEW" "$OLD"

tar -xzf "$ARCHIVE" -C "$NEW"
test -f "$NEW/index.html"

cp -a "$SITE"/. "$OLD"/
tar -czf "$BACKUPS/makechess_$STAMP.tar.gz" -C "$SITE" .

find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$NEW"/. "$SITE"/

if [ ! -f "$SITE/index.html" ]; then
    restore_old
    exit 21
fi

if command -v curl >/dev/null 2>&1; then
    if ! curl -kfsS --max-time 20 --resolve makechess.com:443:127.0.0.1 https://makechess.com/ >/dev/null; then
        restore_old
        exit 22
    fi
fi

rm -rf "$NEW" "$OLD" "$ARCHIVE"
ls -1t "$BACKUPS"/makechess_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f

echo PUBLISH_OK
