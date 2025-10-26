FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY server.js ./

# Create directory for stolen data
RUN mkdir -p stolen-data

# Expose port
EXPOSE 3000

# Start server
CMD ["node", "server.js"]
