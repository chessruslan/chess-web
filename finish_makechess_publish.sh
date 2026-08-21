#!/bin/sh
set -eu

SITE="/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess"
ARCHIVE="/home/flexyops/makechess_web_safe.tar.gz"
SCRIPT="/home/flexyops/finish_makechess_publish.sh"
NEW="/home/flexyops/makechess_finish_new"
OLD="/home/flexyops/makechess_finish_old"
BACKUPS="/home/flexyops/makechess_backups"
STAMP="$(date +%Y%m%d_%H%M%S)"
URL="https://chmebxirnmqgvdpwskhw.supabase.co"
KEY_PREFIX="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"

rollback() {
  if [ -d "$OLD" ]; then
    find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "$OLD"/. "$SITE"/
  fi
}

trap 'rollback' INT TERM HUP

test -f "$ARCHIVE"
test -d "$SITE"

rm -rf "$NEW" "$OLD"
mkdir -p "$NEW" "$OLD" "$BACKUPS"

tar -xzf "$ARCHIVE" -C "$NEW"

test -f "$NEW/index.html"
test -f "$NEW/main.dart.js"
grep -Fq "$URL" "$NEW/main.dart.js"
grep -Fq "$KEY_PREFIX" "$NEW/main.dart.js"

cp -a "$SITE"/. "$OLD"/
tar -czf "$BACKUPS/makechess_before_publish_$STAMP.tar.gz" -C "$SITE" .

find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$NEW"/. "$SITE"/

if [ ! -f "$SITE/index.html" ] || [ ! -f "$SITE/main.dart.js" ]; then
  rollback
  exit 42
fi

if ! grep -Fq "$URL" "$SITE/main.dart.js"; then
  rollback
  exit 43
fi

if ! grep -Fq "$KEY_PREFIX" "$SITE/main.dart.js"; then
  rollback
  exit 44
fi

rm -rf "$NEW" "$OLD"
rm -f "$ARCHIVE" "$SCRIPT"

echo "PUBLISH_OK"
echo "BACKUP=$BACKUPS/makechess_before_publish_$STAMP.tar.gz"
