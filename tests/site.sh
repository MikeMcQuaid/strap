#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
STRAP_SITE_DIR=${1:-_site}

cmp bin/strap.sh "$STRAP_SITE_DIR/strap.sh"
cmp bin/strap.sh "$STRAP_SITE_DIR/strap.sh.txt"
for path in Gemfile Gemfile.lock Brewfile Dockerfile README.md bin/dev bin/setup config script tests vendor; do
  if [ -e "$STRAP_SITE_DIR/$path" ] || [ -L "$STRAP_SITE_DIR/$path" ]; then
    echo "Build-only file was published: $path" >&2
    exit 1
  fi
done

echo 'Site build checks passed.'
