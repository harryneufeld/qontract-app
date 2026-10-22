#!/bin/sh
# Writes the web client's runtime configuration (config.js) from the container
# environment. Run by the nginx image's entrypoint before nginx starts; a
# non-zero exit stops the container instead of serving a local-dev endpoint.
set -eu

api="${QONTRACT_API_BASE_URL:-}"
allow_server_switch="${QONTRACT_ALLOW_SERVER_SWITCH:-false}"
case "$allow_server_switch" in
    true|false) ;;
    *) echo "qontract: QONTRACT_ALLOW_SERVER_SWITCH must be true or false." >&2; exit 1 ;;
esac
https_url='^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~%-]+)*/api$'
loopback_url='^http://(localhost|127\.0\.0\.1)(:[0-9]{1,5})?(/[A-Za-z0-9._~%-]+)*/api$'

if ! printf '%s' "$api" | grep -Eq "$https_url|$loopback_url"; then
    echo "qontract: set QONTRACT_API_BASE_URL to the browser-reachable HTTPS API URL" \
        "ending in /api, without credentials, query, fragment or trailing slash." \
        "HTTP loopback is allowed for smoke checks." >&2
    exit 1
fi

# The pattern above admits no quotes or backslashes, so the value is JSON-safe.
target="/usr/share/nginx/html${QONTRACT_BASE_HREF:-/}config.js"
printf 'window.qontractConfig = {"QONTRACT_API_BASE_URL": "%s", "QONTRACT_ALLOW_SERVER_SWITCH": "%s"};\n' "$api" "$allow_server_switch" > "$target"
echo "qontract: API base URL $api"

# App Links (Android) and Universal Links (iOS) let the OS open emailed links in
# the installed app. They are verified against files at the host root, so these
# are written only when the operator provides the signing identities.
well_known="/usr/share/nginx/html/.well-known"
android_fingerprints="${QONTRACT_ANDROID_CERT_SHA256:-}"
apple_team="${QONTRACT_APPLE_TEAM_ID:-}"
app_id="${QONTRACT_APP_ID:-app.qontract}"
printf '%s' "$app_id" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$' \
    || { echo "qontract: QONTRACT_APP_ID must be a package name such as app.qontract." >&2; exit 1; }
if [ -n "$android_fingerprints" ] || [ -n "$apple_team" ]; then
    mkdir -p "$well_known"
fi
if [ -n "$android_fingerprints" ]; then
    fingerprint='[0-9A-F]{2}(:[0-9A-F]{2}){31}'
    printf '%s' "$android_fingerprints" | grep -Eq "^$fingerprint(,$fingerprint)*$" \
        || { echo "qontract: QONTRACT_ANDROID_CERT_SHA256 must list SHA-256 fingerprints (AA:BB:...) separated by commas." >&2; exit 1; }
    quoted=$(printf '%s' "$android_fingerprints" | sed 's/[^,]*/"&"/g')
    printf '[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":"%s","sha256_cert_fingerprints":[%s]}}]\n' \
        "$app_id" "$quoted" > "$well_known/assetlinks.json"
    echo "qontract: wrote Android App Links file"
fi
if [ -n "$apple_team" ]; then
    printf '%s' "$apple_team" | grep -Eq '^[A-Z0-9]{10}$' \
        || { echo "qontract: QONTRACT_APPLE_TEAM_ID must be the 10-character Apple team ID." >&2; exit 1; }
    printf '{"applinks":{"details":[{"appIDs":["%s.%s"],"components":[{"/":"/confirm-email"},{"/":"/reset-password"}]}]}}\n' \
        "$apple_team" "$app_id" > "$well_known/apple-app-site-association"
    echo "qontract: wrote iOS Universal Links file"
fi
