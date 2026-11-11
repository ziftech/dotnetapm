#!/usr/bin/env bash
# Build preso/ and force-publish to the gh-pages branch (GitHub Pages).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$(mktemp -d /tmp/dotnetapm-gh-pages.XXXXXX)"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

cd "$ROOT/preso"
npm ci
npm run build

cp -R "$ROOT/preso/dist/." "$STAGING/"
cd "$STAGING"
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-cursor-agent}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-cursor-agent@users.noreply.github.com}" \
    commit -qm "Deploy Contoso .NET APM preso to GitHub Pages"
git remote add origin "https://github.com/ziftech/dotnetapm.git"
git push -f origin gh-pages
echo "Published https://ziftech.github.io/dotnetapm/"
