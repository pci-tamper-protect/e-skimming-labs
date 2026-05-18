FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY server.js ./

# Create per-lab data directories
RUN mkdir -p /app/data/lab1 /app/data/lab2 /app/data/lab3

ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
