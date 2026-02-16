#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-.}"
OUT_DIR="${2:-./converter_out_android}"
ARCHIVE_NAME="${3:-lo_android_pack}"

SRC_DIR="$(cd "$SRC_DIR" && pwd)"
OUT_DIR="$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)"

ANDROID_JNILIBS="$SRC_DIR/android/jniLibs"
ASSETS_DIR="$SRC_DIR/android/source/assets"
ASSETS_STRIPPED_DIR="$SRC_DIR/android/source/assets_strippedUI"

STAGE_DIR="$OUT_DIR/stage_android_pack"
ARCHIVE_PATH="$OUT_DIR/${ARCHIVE_NAME}.tar.gz"

have_rsync() { command -v rsync >/dev/null 2>&1; }

echo "Source: $SRC_DIR"
echo "Output: $OUT_DIR"
echo "Archive: $ARCHIVE_PATH"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

echo "Copy jniLibs"
if [[ -d "$ANDROID_JNILIBS" ]]; then
  mkdir -p "$STAGE_DIR/src/main/jni"
  if have_rsync; then
    rsync -a "$ANDROID_JNILIBS"/ "$STAGE_DIR/src/main/jni"/
  else
    cp -R "$ANDROID_JNILIBS"/. "$STAGE_DIR/src/main/jni"/
  fi
fi

echo "Copy assets"
if [[ -d "$ASSETS_DIR" ]]; then
  mkdir -p "$STAGE_DIR/assets"
  if have_rsync; then
    rsync -a "$ASSETS_DIR"/ "$STAGE_DIR/assets"/
  else
    cp -R "$ASSETS_DIR"/. "$STAGE_DIR/assets"/
  fi
fi

echo "Copy assets_strippedUI"
if [[ -d "$ASSETS_STRIPPED_DIR" ]]; then
  mkdir -p "$STAGE_DIR/assets_strippedUI"
  if have_rsync; then
    rsync -a "$ASSETS_STRIPPED_DIR"/ "$STAGE_DIR/assets_strippedUI"/
  else
    cp -R "$ASSETS_STRIPPED_DIR"/. "$STAGE_DIR/assets_strippedUI"/
  fi
fi

echo "Create tar.gz"
rm -f "$ARCHIVE_PATH"
(cd "$STAGE_DIR" && tar -czf "$ARCHIVE_PATH" .)

echo "Done: $ARCHIVE_PATH"