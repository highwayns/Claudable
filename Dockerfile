# Claudable Dockerfile
# Multi-stage build for optimized production image

# ============================================================
# Stage 1: Dependencies (All)
# ============================================================
FROM node:20-alpine AS deps

# Install system dependencies required for Prisma and native modules
RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install ALL dependencies (including devDependencies needed for build)
RUN npm ci --ignore-scripts && \
    npm cache clean --force

# ============================================================
# Stage 2: Production Dependencies Only
# ============================================================
FROM node:20-alpine AS production-deps

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install only production dependencies
RUN npm ci --omit=dev --ignore-scripts && \
    npm cache clean --force

# ============================================================
# Stage 3: Builder
# ============================================================
FROM node:20-alpine AS builder

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Copy Prisma schema
COPY prisma ./prisma/

# Generate Prisma Client
RUN npx prisma generate

# Set environment for build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Build Next.js application
RUN npm run build

# ============================================================
# Stage 3: Runner (Production)
# ============================================================
FROM node:20-alpine AS runner

# Install runtime dependencies
RUN apk add --no-cache \
    libc6-compat \
    openssl \
    sqlite

WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Set environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy package files
COPY --from=builder /app/package.json ./package.json

# Copy necessary files from builder
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./next.config.js

# Copy Prisma files
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Copy standalone build
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy scripts
COPY --from=builder /app/scripts ./scripts

# Create data directories with proper permissions
RUN mkdir -p /app/data/projects /app/data/backups && \
    chown -R nextjs:nodejs /app/data

# Create volume mount points
VOLUME ["/app/data"]

# Switch to non-root user
USER nextjs

# Expose ports
# Main application port
EXPOSE 3000
# Preview ports range (3100-3999)
EXPOSE 3100-3999

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "server.js"]