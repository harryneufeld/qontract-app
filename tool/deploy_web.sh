#!/usr/bin/env bash
#
# Deploy the Qontract web release build to GitHub Pages.
#
# Target:  GitHub Pages project site  https://<owner>.github.io/<repo>/
# Source:  the `gh-pages` branch (kept in sync by this script — do not edit)
#
# Usage:
#   ./tool/deploy_web.sh                                   # dev backend (localhost)
#   QONTRACT_API_BASE_URL=https://api.example.com ./tool/deploy_web.sh
#
# Requirements: flutter + git on PATH, push access to the repo's origin.
# One-time prerequisite: GitHub Pages must be enabled on the gh-pages branch
# (already done for this repo — see DEPLOY.md).

set -euo pipefail

cd "$(dirname "$0")/.."

# --- repo metadata ----------------------------------------------------------
ORIGIN_URL="$(git remote get-url origin)"
REPO="$(basename "$ORIGIN_URL" .git)"
OWNER="$(printf '%s' "$ORIGIN_URL" | sed -n 's|.*github\.com/\([^/]*\)/.*|\1|p')"
if [ -z "$OWNER" ]; then
  echo "error: cannot parse owner from origin URL: $ORIGIN_URL" >&2
  exit 1
fi
BASE_HREF="/${REPO}/"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
SITE_URL="https://${OWNER}.github.io/${REPO}/"

# --- build -------------------------------------------------------------------
DART_DEFINE=()
if [ -n "${QONTRACT_API_BASE_URL:-}" ]; then
  DART_DEFINE=(--dart-define=QONTRACT_API_BASE_URL="$QONTRACT_API_BASE_URL")
fi

echo "==> flutter build web --release --base-href ${BASE_HREF}"
flutter build web --release --base-href "$BASE_HREF" ${DART_DEFINE[@]+"${DART_DEFINE[@]}"}

# --- sync build/web -> gh-pages (via throw-away worktree) --------------------
# Staging dir lives inside build/ (gitignored) so nothing is written outside
# the repo checkout.
WT="$(mktemp -d "build/gh-pages-deploy.XXXXXX")"
cleanup() { git worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"; }
trap cleanup EXIT

git worktree add --detach "$WT" HEAD >/dev/null
find "$WT" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a build/web/. "$WT"/
git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then
  git -C "$WT" commit --allow-empty -q -m "deploy web: no changes ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
else
  git -C "$WT" commit -q -m "deploy web: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
git -C "$WT" push --force origin "HEAD:refs/heads/${PAGES_BRANCH}"

git worktree remove --force "$WT" >/dev/null
trap - EXIT

echo ""
echo "Deployed ${REPO} web release to '${PAGES_BRANCH}'."
echo "Site: ${SITE_URL} (GitHub Pages can take a minute or two to go live.)"
echo "Verify: curl -fsI ${SITE_URL}"
