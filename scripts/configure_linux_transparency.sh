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

echo "Configured Linux runner for transparent flutter_acrylic window."
