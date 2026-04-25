# ---- Build Stage ----
FROM node:lts-trixie-slim AS build

WORKDIR /usr/src/app

# Install dependencies (clean + reproducible)
COPY package*.json ./
RUN npm install --omit=dev

# Copy source code
COPY . .

# ---- Production Stage ----
FROM node:lts-trixie-slim

RUN apt-get update && \
    apt-get install -y netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /usr/src/app

# Copy only necessary files from build stage
COPY --from=build /usr/src/app /usr/src/app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Start app
CMD ["node", "server.js"]