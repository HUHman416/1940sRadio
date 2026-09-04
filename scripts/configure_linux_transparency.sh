#!/usr/bin/env bash
set -euo pipefail

RUNNER="linux/runner/my_application.cc"

if [[ ! -f "$RUNNER" ]]; then
  echo "Linux runner not found at $RUNNER" >&2
  exit 1
fi

# flutter_acrylic requires the GTK runner to let the plugin control when the
# initial window/view are shown. Keeping the generated gtk_widget_show calls
# can leave an opaque/black GTK surface behind Flutter's transparent scene.
sed -i '/gtk_widget_show(GTK_WIDGET(window));/d' "$RUNNER"
sed -i '/gtk_widget_show(GTK_WIDGET(view));/d' "$RUNNER"

# Give the native GTK toplevel an alpha-capable visual. Without an RGBA visual,
# Flutter can paint transparent pixels but compositors such as KWin may render
# those pixels as opaque black instead of showing the desktop behind the radio.
#
# Keep this patch idempotent: CI regenerates the Linux runner today, but local
# packaging/rebuild workflows may invoke this script more than once.
python3 - <<'PY'
from pathlib import Path

path = Path("linux/runner/my_application.cc")
text = path.read_text()
marker = "// 1940s Radio RGBA transparency patch"

if marker in text:
    print("Linux RGBA transparency patch already present; skipping reinsertion.")
    raise SystemExit(0)

needle = "gtk_window_set_default_size(window, 1280, 720);"
insert = '''gtk_window_set_default_size(window, 1280, 720);\n\n  // 1940s Radio RGBA transparency patch\n  GdkScreen* radio_rgba_screen = gtk_widget_get_screen(GTK_WIDGET(window));\n  GdkVisual* radio_rgba_visual = gdk_screen_get_rgba_visual(radio_rgba_screen);\n  if (radio_rgba_visual != nullptr) {\n    gtk_widget_set_visual(GTK_WIDGET(window), radio_rgba_visual);\n  }\n  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);'''

if needle not in text:
    raise SystemExit(f"Could not find GTK window setup anchor: {needle}")

text = text.replace(needle, insert, 1)
path.write_text(text)
PY

echo "Configured Linux runner for RGBA transparent flutter_acrylic window."
