#!/bin/sh

# Select variant: LAB2_VARIANT (runtime) overrides LAB2_VARIANT_DEFAULT; fallback dom-monitor
VARIANT="${LAB2_VARIANT:-${LAB2_VARIANT_DEFAULT:-dom-monitor}}"
SRC="/usr/share/nginx/html/malicious-code/${VARIANT}.js"
DST="/usr/share/nginx/html/js/skimmer.js"
if [ -f "$SRC" ]; then
  cp "$SRC" "$DST"
  echo "Lab 2 variant: ${VARIANT} -> js/skimmer.js"
else
  echo "WARNING: variant ${VARIANT} not found at ${SRC}, skimmer will not load"
fi

# Start nginx in foreground
nginx -g "daemon off;"
