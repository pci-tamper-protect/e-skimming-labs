FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY server.js dashboard.html ./

# Create directory for stolen data
RUN mkdir -p stolen-data analysis

# Port: 3000 when used with nginx; 8080 when C2_STANDALONE=true (e.g. Cloud Run)
EXPOSE 3000
EXPOSE 8080

# C2_STANDALONE=true uses PORT (default 8080); otherwise uses 3000
ENV C2_STANDALONE=${C2_STANDALONE:-false}

CMD ["node", "server.js"]
