#!/usr/bin/env bash
set -euo pipefail

# LibreOffice packer
# 0) saves ios-all-static-libs.list -> <out>/ios-all-static-libs.list
# 1) (flat) copies files listed in ios-all-static-libs.list -> <out>/compiled_sources (no dirs)
# 2) (structured) copies ONLY header-like files from selected search paths -> <out>/search_paths/<same rel root>/...
# 3) copies resources -> <out>/resources (keeps structure)
#    + post-process:
#      - rename icudt*.dat -> ICU.dat (in resources root)
#      - patch rc + fundamentalrc: replace ALL $APP_DATA_DIR -> $APP_DATA_DIR/Frameworks/libre_office_kit_converter_plugin.framework

usage() {
  cat <<'EOF'
Usage:
  lo_pack.sh [-s <lo_core_src_dir>] [-o <output_dir>]

Defaults:
  -s: current directory
  -o: ./converter_out
EOF
}

SRC_DIR="."
OUT_DIR="./converter_out"

while getopts ":s:o:h" opt; do
  case "$opt" in
    s) SRC_DIR="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Missing argument for -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

SRC_DIR="$(cd "$SRC_DIR" && pwd)"
OUT_DIR="$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)"

LIST_FILE="$SRC_DIR/workdir/CustomTarget/ios/ios-all-static-libs.list"

COMPILED_DIR="$OUT_DIR/compiled_sources"
SEARCH_DIR="$OUT_DIR/search_paths"
RES_OUT_DIR="$OUT_DIR/resources"

mkdir -p "$COMPILED_DIR" "$SEARCH_DIR"

have_rsync() { command -v rsync >/dev/null 2>&1; }

# ------------------------
# Step 1 helpers (flat)
# ------------------------
copy_flat_unique() {
  local src_path="$1"
  local dst_dir="$2"

  local base
  base="$(basename "$src_path")"
  local dst="$dst_dir/$base"

  if [[ ! -e "$dst" ]]; then
    cp -p "$src_path" "$dst"
    return 0
  fi

  local name ext candidate n=1
  if [[ "$base" == *.* ]]; then
    ext=".${base##*.}"
    name="${base%$ext}"
  else
    ext=""
    name="$base"
  fi

  while :; do
    candidate="$dst_dir/${name}__${n}${ext}"
    if [[ ! -e "$candidate" ]]; then
      cp -p "$src_path" "$candidate"
      return 0
    fi
    n=$((n+1))
  done
}

resolve_list_path() {
  local raw="$1"
  if [[ "$raw" = /* ]]; then
    printf "%s" "$raw"
  else
    printf "%s" "$SRC_DIR/$raw"
  fi
}

# ---------------------------------------------
# Step 2 helpers (structured headers-only copy)
# ---------------------------------------------
copy_headers_structured() {
  local src_dir="$1"     # absolute
  local dst_root="$2"    # absolute destination root for this subtree

  if [[ ! -d "$src_dir" ]]; then
    echo "WARNING: Search path dir not found, skipping: $src_dir" >&2
    return 0
  fi

  mkdir -p "$dst_root"

  local -a patterns=(
    "*.h" "*.hh" "*.hpp" "*.hxx"
    "*.inc" "*.inl" "*.ipp"
    "*.tcc" "*.tpp"
  )

  if have_rsync; then
    local rsync_args=( -a --prune-empty-dirs --include '*/' )
    for p in "${patterns[@]}"; do
      rsync_args+=( --include "$p" )
    done
    rsync_args+=( --exclude '*' )

    rsync "${rsync_args[@]}" "$src_dir"/ "$dst_root"/
  else
    local expr=( "(" )
    local first=1
    for p in "${patterns[@]}"; do
      if [[ $first -eq 1 ]]; then
        expr+=( -name "$p" ); first=0
      else
        expr+=( -o -name "$p" )
      fi
    done
    expr+=( ")" )

    while IFS= read -r -d '' f; do
      rel="${f#$src_dir/}"
      mkdir -p "$(dirname "$dst_root/$rel")"
      cp -p "$f" "$dst_root/$rel"
    done < <(find "$src_dir" -type f "${expr[@]}" -print0)
  fi
}

# ------------------------
# Post-process resources
# ------------------------
rename_icu_dat() {
  local res_dir="$1"

  # If ICU.dat already exists, do nothing
  if [[ -f "$res_dir/ICU.dat" ]]; then
    return 0
  fi

  # Find first icudt*.dat and rename to ICU.dat
  local icu_src=""
  icu_src="$(find "$res_dir" -maxdepth 1 -type f -name 'icudt*.dat' -print -quit || true)"

  if [[ -z "$icu_src" ]]; then
    echo "WARNING: icudt*.dat not found in resources root ($res_dir); ICU.dat not created" >&2
    return 0
  fi

  mv -f "$icu_src" "$res_dir/ICU.dat"
}

patch_bootstrap_files() {
  local res_dir="$1"
  local fw_subpath="Frameworks/libre_office_kit_converter_plugin.framework"
  local repl="\$APP_DATA_DIR/${fw_subpath}"

  local -a files=("$res_dir/rc" "$res_dir/fundamentalrc")

  for f in "${files[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "WARNING: bootstrap file not found, skipping: $f" >&2
      continue
    fi

    # Replace ALL occurrences of $APP_DATA_DIR
    # macOS sed requires a backup suffix for -i
    sed -i.bak \
      -e "s|\\\$APP_DATA_DIR|${repl}|g" \
      "$f"
    rm -f "${f}.bak"
  done
}

# ------------------------
# Info
# ------------------------
echo "Source:  $SRC_DIR"
echo "Output:  $OUT_DIR"
echo

# ------------------------
# Ensure list exists + save ordering list into OUT_DIR
# ------------------------
if [[ ! -f "$LIST_FILE" ]]; then
  echo "ERROR: List file not found: $LIST_FILE" >&2
  exit 1
fi

echo "0) Saving libs order list -> $OUT_DIR/ios-all-static-libs.list ..."
cp -p "$LIST_FILE" "$OUT_DIR/ios-all-static-libs.list"

# ------------------------
# 1) Flat copy listed libs
# ------------------------
echo "1) Copying listed files -> $COMPILED_DIR (flat)..."
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue

  src_path="$(resolve_list_path "$line")"
  if [[ ! -f "$src_path" ]]; then
    echo "WARNING: Listed file not found, skipping: $line" >&2
    continue
  fi

  copy_flat_unique "$src_path" "$COMPILED_DIR"
done < "$LIST_FILE"

# -----------------------------------------
# 2) Structured copy of headers-only folders
# -----------------------------------------
echo "2) Copying ONLY headers from search paths -> $SEARCH_DIR (preserving structure)..."
SEARCH_PATHS=(
  "workdir/CustomTarget/ios"
  "workdir/UnpackedTarball/boost"
  "workdir/UnpackedTarball/libpng"
  "workdir/UnoApiHeadersTarget/udkapi/comprehensive"
  "workdir/UnoApiHeadersTarget/offapi/comprehensive"
  "config_host"
  "include"
)

for rel in "${SEARCH_PATHS[@]}"; do
  src="$SRC_DIR/$rel"
  dst="$SEARCH_DIR/$rel"
  copy_headers_structured "$src" "$dst"
done

# ------------------------
# 3) Copy resources + post-process
# ------------------------
echo "3) Copying resources -> $RES_OUT_DIR ..."
RES_SRC="$SRC_DIR/workdir/CustomTarget/ios/resources"
if [[ ! -d "$RES_SRC" ]]; then
  echo "WARNING: Resources folder not found, skipping: $RES_SRC" >&2
else
  mkdir -p "$RES_OUT_DIR"
  if have_rsync; then
    rsync -a "$RES_SRC"/ "$RES_OUT_DIR"/
  else
    cp -R "$RES_SRC"/. "$RES_OUT_DIR"/
  fi

  echo "3.1) Renaming ICU data file to ICU.dat (if needed)..."
  rename_icu_dat "$RES_OUT_DIR"

  echo "3.2) Patching rc + fundamentalrc: replace ALL \$APP_DATA_DIR -> \$APP_DATA_DIR/Frameworks/libre_office_kit_converter_plugin.framework ..."
  patch_bootstrap_files "$RES_OUT_DIR"
fi

echo
echo "Done."
echo "Created:"
echo "  - $OUT_DIR/ios-all-static-libs.list (saved order list)"
echo "  - $COMPILED_DIR (flat libs)"
echo "  - $SEARCH_DIR (headers only, structured)"
echo "  - $RES_OUT_DIR"