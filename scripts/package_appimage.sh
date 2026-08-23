#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_DIR="build/linux/x64/release/bundle"
APPDIR="build/appimage/1940sRadio.AppDir"
OUT_DIR="build/appimage/out"
VERSION="${1:-0.1.0}"

if [[ ! -x "$BUNDLE_DIR/radio1940s" ]]; then
  echo "Linux release bundle not found. Run: flutter build linux --release" >&2
  exit 1
fi

rm -rf "$APPDIR" "$OUT_DIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps" "$OUT_DIR"
cp -a "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

cat > "$APPDIR/usr/share/applications/radio1940s.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=1940s Radio
Comment=1940s-inspired internet radio featuring Fog Point Radio
Exec=radio1940s
Icon=radio1940s
Terminal=false
Categories=Audio;AudioVideo;Player;
StartupNotify=true
EOF

rsvg-convert -w 512 -h 512 packaging/linux/radio1940s.svg -o "$APPDIR/usr/share/icons/hicolor/512x512/apps/radio1940s.png"
cp "$APPDIR/usr/share/icons/hicolor/512x512/apps/radio1940s.png" "$APPDIR/radio1940s.png"
cp "$APPDIR/usr/share/applications/radio1940s.desktop" "$APPDIR/radio1940s.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/radio1940s" "$@"
EOF
chmod +x "$APPDIR/AppRun"

TOOLS_DIR="build/appimage/tools"
mkdir -p "$TOOLS_DIR"

if [[ ! -x "$TOOLS_DIR/linuxdeploy" ]]; then
  curl -L --fail --retry 3 \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
    -o "$TOOLS_DIR/linuxdeploy"
  chmod +x "$TOOLS_DIR/linuxdeploy"
fi

if [[ ! -x "$TOOLS_DIR/appimagetool" ]]; then
  curl -L --fail --retry 3 \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
    -o "$TOOLS_DIR/appimagetool"
  chmod +x "$TOOLS_DIR/appimagetool"
fi

APPIMAGE_EXTRACT_AND_RUN=1 "$TOOLS_DIR/linuxdeploy" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/radio1940s" \
  --desktop-file "$APPDIR/usr/share/applications/radio1940s.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/512x512/apps/radio1940s.png"

OUTPUT="$OUT_DIR/1940sRadio-${VERSION}-x86_64.AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOLS_DIR/appimagetool" "$APPDIR" "$OUTPUT"
chmod +x "$OUTPUT"
echo "Created $OUTPUT"
