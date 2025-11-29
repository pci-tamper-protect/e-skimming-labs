#!/bin/sh
# Start C2 server in background
cd /app/c2-server && node extension-data-server.js &
# Start nginx in foreground
nginx -g "daemon off;"

