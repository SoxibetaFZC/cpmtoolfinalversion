# backend/Dockerfile
FROM node:18-alpine

WORKDIR /app

# 1. Copy package files (relative to root)
COPY backend/package*.json ./
RUN npm install --production

# 2. Copy the backend source code
COPY backend/ .

# 3. Copy the database folder from the root into the container
# This ensures your migrations have access to the SQL files
COPY database/ ./database/

EXPOSE 5000

CMD ["node", "server.js"]