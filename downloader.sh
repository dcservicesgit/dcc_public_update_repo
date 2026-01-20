#!/usr/bin/env sh
set -euo pipefail

BASE_URL="https://cud.dccore.io"

if [ -z "$1" ]; then
  echo "Usage: $0 <artifact_name>"
  exit 1
fi

ARTIFACT="$1"
ZIP="$ARTIFACT.zip"
SHA_FILE="$ZIP.sha256"

###############################################################################
# Fetch checksum
###############################################################################

echo "Fetching checksum"
curl -fsSL "$BASE_URL/$SHA_FILE" -o "$SHA_FILE"

EXPECTED_SHA=$(cat "$SHA_FILE")

###############################################################################
# Fetch chunks
###############################################################################

i=0
while :; do
  PART=$(printf "%s.part.%03d" "$ZIP" "$i")
  URL="$BASE_URL/$PART"

  echo "Downloading $PART"

  if ! curl -fsSL "$URL" -o "$PART.tmp"; then
    break
  fi

  # Stop if the downloaded file is suspiciously small (<10KB)
  SIZE=$(wc -c < "$PART.tmp")
  if [ "$SIZE" -lt 10024 ]; then
    rm -f "$PART.tmp"
    break
  fi

  mv "$PART.tmp" "$PART"
  i=$((i + 1))
done

if [ "$i" -eq 0 ]; then
  echo "ERROR: No chunks found for $ARTIFACT"
  exit 1
fi

###############################################################################
# Reassemble
###############################################################################

echo "Reassembling $ZIP"
cat "$ZIP.part."* > "$ZIP"

###############################################################################
# Verify checksum
###############################################################################

echo "Verifying checksum"
if command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
else
  ACTUAL_SHA=$(sha256sum "$ZIP" | awk '{print $1}')
fi

if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "ERROR: Checksum mismatch"
  exit 1
fi

echo "Checksum OK"

###############################################################################
# Extract
###############################################################################

echo "Extracting $ZIP"
unzip -o "$ZIP"

###############################################################################
# Cleanup
###############################################################################

rm -f "$ZIP.part."* "$ZIP" "$SHA_FILE"

echo "Done."