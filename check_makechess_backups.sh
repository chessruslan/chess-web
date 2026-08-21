#!/bin/sh
set -u

SITE="/opt/flexytube/supabase-stack/volumes/proxy/caddy/makechess"
URL="https://chmebxirnmqgvdpwskhw.supabase.co"
KEY_PREFIX="eyJhbGciOiJIUzI1Ni"

echo "============================================================"
echo "MAKECHESS SAFE BACKUP REPORT"
echo "============================================================"
date
echo

echo "[CURRENT SITE]"
if [ -f "$SITE/main.dart.js" ]; then
    echo "main.dart.js: FOUND"
    ls -lh "$SITE/main.dart.js"
    if grep -Fq "$URL" "$SITE/main.dart.js"; then
        echo "SUPABASE_URL_IN_CURRENT_BUILD=YES"
    else
        echo "SUPABASE_URL_IN_CURRENT_BUILD=NO"
    fi
    if grep -Fq "$KEY_PREFIX" "$SITE/main.dart.js"; then
        echo "SUPABASE_KEY_PREFIX_IN_CURRENT_BUILD=YES"
    else
        echo "SUPABASE_KEY_PREFIX_IN_CURRENT_BUILD=NO"
    fi
else
    echo "main.dart.js: NOT FOUND"
fi
echo

echo "[ARCHIVES FOUND]"
ARCHIVES="$(find /home/flexyops /root /opt/flexytube -maxdepth 6 -type f \( -name '*.tar.gz' -o -name '*.tgz' \) 2>/dev/null | sort)"
if [ -z "$ARCHIVES" ]; then
    echo "NO_ARCHIVES_FOUND"
else
    echo "$ARCHIVES"
fi
echo

echo "[ARCHIVE CONTENT CHECK]"
FOUND_WORKING=0
if [ -n "$ARCHIVES" ]; then
    echo "$ARCHIVES" | while IFS= read -r archive; do
        [ -n "$archive" ] || continue
        echo "------------------------------------------------------------"
        echo "ARCHIVE=$archive"
        ls -lh "$archive" 2>/dev/null || true

        js_entry="$(tar -tzf "$archive" 2>/dev/null | grep -E '(^|/)main\.dart\.js$' | head -n 1 || true)"
        if [ -z "$js_entry" ]; then
            echo "MAIN_DART_JS=NO"
            continue
        fi

        echo "MAIN_DART_JS=YES"
        echo "ENTRY=$js_entry"

        if tar -xOzf "$archive" "$js_entry" 2>/dev/null | grep -Fq "$URL"; then
            echo "SUPABASE_URL=YES"
        else
            echo "SUPABASE_URL=NO"
        fi

        if tar -xOzf "$archive" "$js_entry" 2>/dev/null | grep -Fq "$KEY_PREFIX"; then
            echo "SUPABASE_KEY_PREFIX=YES"
        else
            echo "SUPABASE_KEY_PREFIX=NO"
        fi
    done
fi
echo

echo "[OTHER DEPLOYED FLUTTER BUILDS]"
find /opt/flexytube/supabase-stack/volumes/proxy/caddy -maxdepth 4 -type f -name main.dart.js -print 2>/dev/null || true
echo
echo "REPORT_COMPLETE"
