Pod::Spec.new do |s|
  s.name             = 'libre_office_kit_converter_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.5'

  s.prepare_command = <<-SH
    set -euo pipefail

    PLUGIN_DIR="$(pwd)"
    OUT_DIR="${PLUGIN_DIR}/converter_out"

    URL="https://github.com/qscr/libre_office_kit_converter_plugin/releases/download/v0.0.1/ios-lok.tar.gz"

    echo "[LOK] prepare_command started"
    echo "[LOK] plugin dir: $PLUGIN_DIR"

    # если уже есть — не скачиваем повторно
    if [ -d "$OUT_DIR/compiled_sources" ] && [ -d "$OUT_DIR/resources" ]; then
      echo "[LOK] converter_out already prepared, skip"
      exit 0
    fi

    TMP_DIR="$(mktemp -d)"
    ARCHIVE="$TMP_DIR/ios-lok.tar.gz"

    echo "[LOK] downloading..."
    curl -L --retry 3 -o "$ARCHIVE" "$URL"

    echo "[LOK] extracting to temp..."
    tar -xzf "$ARCHIVE" -C "$TMP_DIR"

    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    echo "[LOK] searching content..."

    FOUND="$(find "$TMP_DIR" -type d -name converter_out | head -n 1 || true)"

    echo "[LOK] converter_out folder not found, copying everything"
    cp -R "$TMP_DIR"/. "$OUT_DIR"/

    rm -rf "$TMP_DIR"

    echo "[LOK] prepare complete"
    SH

  s.script_phases = [
    {
    :name => 'Generate LibreOffice libs.filelist',
    :execution_position => :before_compile,
    :shell_path => '/bin/sh',
    :script => <<-'SH'
      set -e

      OUT_DIR="${PODS_TARGET_SRCROOT}/converter_out"
      LIB_DIR="${OUT_DIR}/compiled_sources"
      LIST="${OUT_DIR}/libs.filelist"
      ORDER_LIST="${OUT_DIR}/ios-all-static-libs.list"

      rm -f "$LIST"

      if [ ! -f "$ORDER_LIST" ]; then
        echo "ERROR: ordering list not found: $ORDER_LIST"
        exit 1
      fi

      # 1) .a in exact order from ios-all-static-libs.list
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ""|\#*) continue ;; esac
        base="$(basename "$line")"
        candidate="$LIB_DIR/$base"
        [ -f "$candidate" ] && echo "$candidate" >> "$LIST"
      done < "$ORDER_LIST"

      # 2) Add ONLY required loose .o (avoid duplicate symbols)
      for o in "$LIB_DIR/anchor.o" "$LIB_DIR/ldvector.o"; do
        [ -f "$o" ] && echo "$o" >> "$LIST"
      done

      # 3) De-dup while preserving order
      awk '!seen[$0]++' "$LIST" > "$LIST.tmp" && mv "$LIST.tmp" "$LIST"

      echo "Generated libs.filelist: $LIST"
      SH
  },
  {
    :name => 'Copy ICU.dat to main bundle',
    :execution_position => :after_compile,
    :shell_path => '/bin/sh',
    :script => <<-SCRIPT
      set -e

      SRC="${PODS_TARGET_SRCROOT}/converter_out/resources/ICU.dat"
      DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ICU.dat"

      if [ ! -f "$SRC" ]; then
        echo "error: ICU.dat not found at $SRC"
        exit 1
      fi

      echo "Copying ICU.dat -> $DST"
      /bin/cp -f "$SRC" "$DST"
    SCRIPT
  }]
  
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) IOS=IOS DISABLE_DYNLOADING=1',
    'OTHER_LDFLAGS' => [
      '$(inherited)',
      '-Wl,-filelist,$(PODS_TARGET_SRCROOT)/converter_out/libs.filelist',
    ],
    'HEADER_SEARCH_PATHS' => '$(inherited) $(PODS_TARGET_SRCROOT)/converter_out/search_paths/config_host $(PODS_TARGET_SRCROOT)/converter_out/search_paths/include $(PODS_TARGET_SRCROOT)/converter_out/search_paths/workdir/UnoApiHeadersTarget/offapi/comprehensive $(PODS_TARGET_SRCROOT)/converter_out/search_paths/workdir/UnoApiHeadersTarget/udkapi/comprehensive $(PODS_TARGET_SRCROOT)/converter_out/search_paths/workdir/UnpackedTarball/libpng $(PODS_TARGET_SRCROOT)/converter_out/search_paths/workdir/UnpackedTarball/boost $(PODS_TARGET_SRCROOT)/converter_out/search_paths/workdir/CustomTarget/ios'
  }
  s.swift_version = '5.0'
  s.resources = [
    'converter_out/resources/rc',
    'converter_out/resources/services',
    'converter_out/resources/fundamentalrc',
    'converter_out/resources/oovbaapi.rdb',
    'converter_out/resources/udkapi.rdb',
    'converter_out/resources/unorc',
    'converter_out/resources/services.rdb',
    'converter_out/resources/offapi.rdb',
    'converter_out/resources/config',
    'converter_out/resources/program',
    'converter_out/resources/share',
  ];
  s.libraries = 'z', 'iconv', 'sqlite3'
  s.frameworks = 'CoreServices', 'UniformTypeIdentifiers', 'WebKit'
end
