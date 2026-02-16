FROM node:22-alpine

WORKDIR /app

# Install curl and jq for the shell parts of daily summary
RUN apk add --no-cache curl jq

# Copy package files and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Copy scripts
COPY get-staking-data.mjs ./
COPY staking-abi.json ./

# Default command
CMD ["node", "get-staking-data.mjs"]
