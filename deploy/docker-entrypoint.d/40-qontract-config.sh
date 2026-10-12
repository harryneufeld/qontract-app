#!/bin/sh
# Writes the web client's runtime configuration (config.js) from the container
# environment. Run by the nginx image's entrypoint before nginx starts; a
# non-zero exit stops the container instead of serving a local-dev endpoint.
set -eu

api="${QONTRACT_API_BASE_URL:-}"
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
printf 'window.qontractConfig = {"QONTRACT_API_BASE_URL": "%s"};\n' "$api" > "$target"
echo "qontract: API base URL $api"
