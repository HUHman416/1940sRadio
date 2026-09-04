#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_HOME="$DATA_HOME/radio1940s"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
BIN_DIR="$HOME/.local/bin"

rm -f "$APPLICATIONS_DIR/radio1940s.desktop"
rm -f "$ICONS_DIR/radio1940s.svg"
rm -f "$BIN_DIR/radio1940s"
rm -f "$BIN_DIR/uninstall-radio1940s"
rm -rf "$APP_HOME"

update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true

echo "1940s Radio has been uninstalled."
echo "Your receiver preferences were left intact in the platform preferences store."
