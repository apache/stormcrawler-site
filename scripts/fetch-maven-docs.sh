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
