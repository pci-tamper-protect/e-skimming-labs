FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/node-base:latest

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Mark as standalone deployment (uses PORT env var instead of hardcoded 3000)
ENV C2_STANDALONE=true

# Expose port 8080 for Cloud Run
EXPOSE 8080

# Health check on PORT (8080 on Cloud Run)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-8080}/health || exit 1

# Start the server
CMD ["node", "extension-data-server.js"]
