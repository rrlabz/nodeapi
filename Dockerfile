# ---- Build Stage ----
FROM node:20-alpine AS build

# Create app directory
WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install
RUN npm ci --only=production

# Copy rest of the application
COPY . .

# ---- Production Stage ----
FROM node:20-alpine

WORKDIR /usr/src/app

# Copy built app from build stage
COPY --from=build /usr/src/app .

# Expose the API port (adjust as needed)
EXPOSE 5000

# Start the app
CMD ["npm", "start"]
