FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/node-base:latest

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Expose port (8080 for Cloud Run, 3000 for local)
# Server uses PORT env var, defaults to 3000 if not set
EXPOSE 8080
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the server
CMD ["node", "extension-data-server.js"]
