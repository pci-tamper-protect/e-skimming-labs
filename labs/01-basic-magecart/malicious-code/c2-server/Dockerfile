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

# Expose port: Cloud Run sets PORT=8080, local dev defaults to 3000
EXPOSE 8080
EXPOSE 3000

# Start server
CMD ["node", "server.js"]
