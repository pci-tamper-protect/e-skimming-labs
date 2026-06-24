# Enhanced Dockerfile supporting both local and cloud storage modes
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including optional Google Cloud Storage)
RUN npm install --production

# Copy application files
COPY *.js *.html ./

# Create directory for local storage (only used in local mode)
RUN mkdir -p stolen-data analysis

# Support both storage modes
# Local mode: uses volume mounts for persistence
# Cloud mode: uses Google Cloud Storage

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/health || exit 1

# Expose ports for different deployment scenarios
EXPOSE 3000 8080

# Enhanced server with storage abstraction and auto-detection
CMD ["node", "server.js"]
