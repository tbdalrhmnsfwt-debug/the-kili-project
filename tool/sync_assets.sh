#!/data/data/com.termux/files/usr/bin/bash
# Copy the content assets recovered from the original APK into the app.
#
# The payloads are large (mostly the manhaji textbook figures), so they are
# kept out of git.  Run this once after cloning, or whenever the extraction
# under work/ is refreshed.
#
# Usage: tool/sync_assets.sh [source-assets-dir]
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$HERE/../work/zakirly/assets/assets}"
DEST="$HERE/assets"

if [ ! -d "$SRC" ]; then
  echo "sync_assets: source not found: $SRC" >&2
  exit 1
fi

for dir in manhaji courses data dictionary i18n quran fonts lottie tessdata; do
  if [ ! -d "$SRC/$dir" ]; then
    echo "sync_assets: missing $SRC/$dir" >&2
    exit 1
  fi
  rm -rf "$DEST/$dir"
  cp -a "$SRC/$dir" "$DEST/$dir"
  echo "  synced $dir"
done

cp -a "$SRC/tessdata_config.json" "$DEST/tessdata_config.json"
echo "sync_assets: done -> $DEST"
