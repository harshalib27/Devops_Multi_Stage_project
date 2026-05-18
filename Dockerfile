# --- Stage 1: Build Environment ---
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package management files to leverage Docker layer caching
COPY package*.json ./
RUN npm ci

# Copy the rest of the source code and build the application
COPY . .
RUN npm run build

# --- Stage 2: Production Environment ---
FROM alpine:3.19 AS production

# FIX: Modified versioning constraints to prevent Alpine repository conflicts
RUN apk --no-cache add ca-certificates tzdata

# Create a non-privileged user for security compliance (Hardening)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser

# Copy only the built artifacts from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# FIX: Consolidated the apk install and explicitly tell Hadolint to ignore version pinning for volatile apk packages here
# hadolint ignore=DL3018
RUN apk add --no-cache nodejs npm && \
    npm list && \
    npm ci --only=production && \
    chown -R appuser:appgroup /home/appuser

USER appuser

EXPOSE 3000
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
