# --- Stage 1: Build Environment ---
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
# CHANGED: Using npm install instead of npm ci
RUN npm install
COPY . .
RUN npm run build

# --- Stage 2: Production Environment ---
FROM alpine:3.19 AS production

# hadolint ignore=DL3018
RUN apk --no-cache add ca-certificates tzdata

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# hadolint ignore=DL3018
# CHANGED: Using npm install --omit=dev for production runtime packages
RUN apk add --no-cache nodejs npm && npm list && npm install --omit=dev

RUN chown -R appuser:appgroup /home/appuser
USER appuser

EXPOSE 3000
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
