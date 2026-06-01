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
SITE_URL="https://stormcrawler.apache.org"

# In-place sed differs between GNU sed (Linux) and BSD sed (macOS)
if sed --version >/dev/null 2>&1; then
  SED_I=(sed -i)
else
  SED_I=(sed -i '')
fi

echo "Downloading ${URL}"
mkdir -p "${DEST_DIR}"

curl -L "${URL}" -o "/tmp/${FILENAME}"

echo "Extracting to ${DEST_DIR}"
tar -xzf "/tmp/${FILENAME}" -C "${DEST_DIR}"

echo "Injecting dark mode script into doc pages"
find "${DEST_DIR}" -name '*.html' -exec "${SED_I[@]}" 's|</head>|<script src="/js/darkmode-docs.js"></script></head>|' {} +

# ASF content policy: serve fonts/CSS ourselves instead of from third-party CDNs.
# Carry the vendored assets over from the most recent prior docs version (fonts.css,
# font-awesome.min.css, and their woff2/otf binaries are identical across releases).
FONTS_SRC=$(find docs -mindepth 2 -maxdepth 2 -type d -name fonts ! -path 'docs/latest/*' | sort -V | tail -n1)
if [[ -z "${FONTS_SRC}" ]]; then
  echo "ERROR: no existing docs/<version>/fonts/ found to copy from" >&2
  exit 1
fi
echo "Copying vendored font assets from ${FONTS_SRC}"
cp -R "${FONTS_SRC}" "${DEST_DIR}/fonts"

echo "Rewriting external font/CSS references to local paths"
find "${DEST_DIR}" -maxdepth 1 -name '*.html' -exec "${SED_I[@]}" \
  -e 's|https://fonts.googleapis.com/css?family=Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700|fonts/fonts.css|g' \
  -e 's|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css|fonts/font-awesome.min.css|g' \
  {} +

# Stable "latest" alias: docs/latest/ is a full copy of the newest version's docs
# (same approach as Apache Storm's releases/current/). Only refresh it if the
# fetched version is the newest one available, so backfilling an older version
# never downgrades it.
NEWEST=$(find docs -mindepth 1 -maxdepth 1 -type d ! -name latest | sed 's|^docs/||' | sort -V | tail -n1)
if [[ "${NEWEST}" == "${VERSION}" ]]; then
  echo "Injecting canonical links pointing to ${SITE_URL}/docs/latest/"
  for f in "${DEST_DIR}"/*.html; do
    BASE=$(basename "${f}")
    "${SED_I[@]}" "s|</head>|<link rel=\"canonical\" href=\"${SITE_URL}/docs/latest/${BASE}\"></head>|" "${f}"
  done

  echo "Refreshing docs/latest from ${DEST_DIR}"
  rm -rf docs/latest
  cp -R "${DEST_DIR}" docs/latest
else
  echo "Fetched ${VERSION}, but newest available docs are ${NEWEST}; leaving docs/latest unchanged"
fi
