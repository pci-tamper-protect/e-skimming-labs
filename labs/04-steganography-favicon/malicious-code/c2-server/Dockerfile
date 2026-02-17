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

ENV PORT=3000

# Expose port (3000 for internal/local use)
EXPOSE 3000

# Start server
CMD ["node", "server.js"]
