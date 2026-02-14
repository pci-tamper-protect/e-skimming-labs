FROM us-central1-docker.pkg.dev/pcioasis-operations/containers/node-base:latest

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY server.js dashboard.html ./

# Create directory for stolen data
RUN mkdir -p stolen-data

# Expose port (8080 for Cloud Run standard)
EXPOSE 8080

# Start server
CMD ["node", "server.js"]
