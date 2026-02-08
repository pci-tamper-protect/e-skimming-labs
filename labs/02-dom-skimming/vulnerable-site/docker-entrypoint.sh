#!/bin/sh
# Select which DOM skimmer variant to inject.
# LAB2_VARIANT = runtime override (e.g. docker run -e LAB2_VARIANT=form-overlay).
# LAB2_VARIANT_DEFAULT = default when LAB2_VARIANT is not set (e.g. in .env).
# Final fallback: dom-monitor.
set -e
VARIANT="${LAB2_VARIANT:-${LAB2_VARIANT_DEFAULT:-dom-monitor}}"
SRC="/usr/share/nginx/html/malicious-code/${VARIANT}.js"
DST="/usr/share/nginx/html/js/skimmer.js"
if [ -f "$SRC" ]; then
  cp "$SRC" "$DST"
  echo "Lab 2 variant: ${VARIANT} -> js/skimmer.js"
else
  echo "WARNING: variant ${VARIANT} not found at ${SRC}, skimmer will not load"
fi
exec nginx -g "daemon off;"
