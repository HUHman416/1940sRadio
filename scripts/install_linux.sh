#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="${1:-$ROOT_DIR/build/linux/x64/release/bundle}"
APP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/radio1940s"
APP_DIR="$APP_HOME/app"
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
BIN_DIR="$HOME/.local/bin"

if [[ ! -x "$BUNDLE_DIR/radio1940s" ]]; then
  echo "Linux release bundle not found at: $BUNDLE_DIR" >&2
  echo "Run 'flutter build linux --release' first, or pass a bundle directory." >&2
  exit 1
fi

mkdir -p "$APP_DIR" "$APPLICATIONS_DIR" "$ICONS_DIR" "$BIN_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -a "$BUNDLE_DIR/." "$APP_DIR/"
cp "$ROOT_DIR/packaging/linux/radio1940s.svg" "$ICONS_DIR/radio1940s.svg"

cat > "$APPLICATIONS_DIR/radio1940s.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=1940s Radio
Comment=1940s-inspired internet radio featuring Fog Point Radio
Exec=$APP_DIR/radio1940s
Icon=radio1940s
Terminal=false
Categories=Audio;AudioVideo;Player;
StartupNotify=true
EOF

cat > "$BIN_DIR/radio1940s" <<EOF
#!/usr/bin/env bash
exec "$APP_DIR/radio1940s" "\$@"
EOF
chmod +x "$BIN_DIR/radio1940s"

cp "$ROOT_DIR/scripts/uninstall_linux.sh" "$APP_HOME/uninstall.sh"
chmod +x "$APP_HOME/uninstall.sh"
cat > "$BIN_DIR/uninstall-radio1940s" <<EOF
#!/usr/bin/env bash
exec "$APP_HOME/uninstall.sh" "\$@"
EOF
chmod +x "$BIN_DIR/uninstall-radio1940s"

update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" >/dev/null 2>&1 || true

echo "1940s Radio installed."
echo "Launcher: $APPLICATIONS_DIR/radio1940s.desktop"
echo "Command:  $BIN_DIR/radio1940s"
echo "Uninstall: $BIN_DIR/uninstall-radio1940s"
