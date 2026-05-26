#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
FILENAME="stormcrawler-docs-${VERSION}-docs.tar.gz"
URL="https://repository.apache.org/content/repositories/releases/org/apache/stormcrawler/stormcrawler-docs/${VERSION}/${FILENAME}"
DEST_DIR="docs/${VERSION}"

echo "Downloading ${URL}"
mkdir -p "${DEST_DIR}"

curl -L "${URL}" -o "/tmp/${FILENAME}"

echo "Extracting to ${DEST_DIR}"
tar -xzf "/tmp/${FILENAME}" -C "${DEST_DIR}"

echo "Injecting dark mode script into doc pages"
find "${DEST_DIR}" -name '*.html' -exec sed -i '' 's|</head>|<script src="/js/darkmode-docs.js"></script></head>|' {} +

# ASF content policy: serve fonts/CSS ourselves instead of from third-party CDNs.
# Carry the vendored assets over from the most recent prior docs version (fonts.css,
# font-awesome.min.css, and their woff2/otf binaries are identical across releases).
FONTS_SRC=$(find docs -mindepth 2 -maxdepth 2 -type d -name fonts | sort -V | tail -n1)
if [[ -z "${FONTS_SRC}" ]]; then
  echo "ERROR: no existing docs/<version>/fonts/ found to copy from" >&2
  exit 1
fi
echo "Copying vendored font assets from ${FONTS_SRC}"
cp -R "${FONTS_SRC}" "${DEST_DIR}/fonts"

echo "Rewriting external font/CSS references to local paths"
find "${DEST_DIR}" -maxdepth 1 -name '*.html' -exec sed -i '' \
  -e 's|https://fonts.googleapis.com/css?family=Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700|fonts/fonts.css|g' \
  -e 's|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css|fonts/font-awesome.min.css|g' \
  {} +
