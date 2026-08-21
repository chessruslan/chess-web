#!/bin/sh
set -eu

SITE="/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess"
ARCHIVE="/home/flexyops/makechess_backups/makechess_20260725_222249.tar.gz"
NEW="/home/flexyops/makechess_restore_20260725_222249_new"
CURRENT="/home/flexyops/makechess_before_exact_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
KEY_PREFIX="eyJhbGciOiJIUzI1Ni"

restore_current() {
    find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    tar -xzf "$CURRENT" -C "$SITE"
}

test -f "$ARCHIVE"
test -d "$SITE"

rm -rf "$NEW"
mkdir -p "$NEW"

tar -xzf "$ARCHIVE" -C "$NEW"

test -f "$NEW/index.html"
test -f "$NEW/main.dart.js"

if ! grep -Fq "$KEY_PREFIX" "$NEW/main.dart.js"; then
    echo "ERROR: selected archive does not contain the known Supabase key prefix"
    rm -rf "$NEW"
    exit 31
fi

tar -czf "$CURRENT" -C "$SITE" .

find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$NEW"/. "$SITE"/

if [ ! -f "$SITE/index.html" ] || [ ! -f "$SITE/main.dart.js" ]; then
    restore_current
    exit 32
fi

if ! grep -Fq "$KEY_PREFIX" "$SITE/main.dart.js"; then
    restore_current
    exit 33
fi

rm -rf "$NEW"
rm -f "$ARCHIVE"
rm -f "/home/flexyops/restore_makechess_20260725_222249.sh"

echo "RESTORE_OK"
echo "RESTORED_ARCHIVE=/home/flexyops/makechess_backups/makechess_20260725_222249.tar.gz"
echo "BROKEN_SITE_BACKUP=$CURRENT"
