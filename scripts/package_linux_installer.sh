#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.5.0}"
BUNDLE_DIR="build/linux/x64/release/bundle"
STAGE="build/linux-installer/1940sRadio-${VERSION}-Linux-x86_64"
OUT_DIR="build/linux-installer/out"

if [[ ! -x "$BUNDLE_DIR/radio1940s" ]]; then
  echo "Linux release bundle not found. Run: flutter build linux --release" >&2
  exit 1
fi

rm -rf "build/linux-installer"
mkdir -p "$STAGE/app" "$STAGE/packaging/linux" "$STAGE/scripts" "$OUT_DIR"
cp -a "$BUNDLE_DIR/." "$STAGE/app/"
cp packaging/linux/radio1940s.svg "$STAGE/packaging/linux/"
cp scripts/install_linux.sh scripts/uninstall_linux.sh "$STAGE/scripts/"

cat > "$STAGE/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/scripts/install_linux.sh" "$HERE/app"
EOF
chmod +x "$STAGE/install.sh" "$STAGE/scripts/install_linux.sh" "$STAGE/scripts/uninstall_linux.sh"

cat > "$STAGE/README.txt" <<EOF
1940s Radio ${VERSION} — Linux Desktop Installer

INSTALL
  1. Extract this archive.
  2. Run: ./install.sh

The installer is per-user and does not require sudo. It installs the application
under ~/.local/share/radio1940s, creates a desktop launcher, and adds the
'radio1940s' and 'uninstall-radio1940s' commands under ~/.local/bin.

UNINSTALL
  Run: uninstall-radio1940s

The portable AppImage is distributed separately and does not need installation.
EOF

tar -C "build/linux-installer" -czf "$OUT_DIR/1940sRadio-${VERSION}-Linux-x86_64.tar.gz" "$(basename "$STAGE")"
echo "Created $OUT_DIR/1940sRadio-${VERSION}-Linux-x86_64.tar.gz"
