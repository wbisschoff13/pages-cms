# ============================================================================
# DEPENDENCIES STAGE
# ============================================================================
# This stage creates a base layer with only production dependencies.
# It's optimized for Docker layer caching - dependencies are only rebuilt
# when package*.json changes, not when source code changes.
# ============================================================================

FROM node:18-alpine AS dependencies

# Set working directory
WORKDIR /app

# Install runtime dependencies
# - git: required for content operations in PagesCMS
# - dumb-init: proper signal handling for PID 1
RUN apk add --no-cache git dumb-init

# Configure npm for optimal caching
# Creates a dedicated cache directory for better layer caching
RUN npm config set cache /tmp/.npm --global

# Copy package files
# Copy these before source to leverage Docker layer caching
COPY package*.json ./

# Install only production dependencies
# npm ci --only=production ensures reproducible, production-only builds
# --ignore-scripts skips postinstall hooks that may require dev tools
RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

# ============================================================================
# BUILDER STAGE
# ============================================================================
# This stage builds the Next.js application with all dependencies including
# devDependencies. It creates the standalone output in .next/standalone
# which will be used by the runner stage for a minimal production image.
# ============================================================================

FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
# Copy package*.json before source code to leverage Docker cache
COPY package*.json ./

# Install all dependencies (including devDependencies)
# npm ci is preferred over npm install for reproducible builds
RUN npm ci

# Copy entire source code
COPY . .

# Build the application
# Skip postbuild script (db:migrate) since migrations should run at deployment time
# This creates .next/standalone directory with minimal production bundle
RUN npx next build

# ============================================================================
# RUNTIME STAGE
# ============================================================================
# This is the final production image with minimal footprint.
# It copies only the necessary artifacts from previous stages.
# ============================================================================

FROM node:18-alpine AS runtime

# Set runtime arguments
ARG NODE_ENV=production
ARG PORT=3000

# Set environment variables
# NODE_ENV: production mode
# NEXT_TELEMETRY_DISABLED: disable Next.js telemetry
# PORT: configurable port for Dokku compatibility
# HOSTNAME: bind to all interfaces
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=${PORT} \
    HOSTNAME="0.0.0.0"

# Install runtime dependencies
# - git: required for GitHub content operations
# - dumb-init: proper signal handling for PID 1
# - wget: for health checks
RUN apk add --no-cache \
    git \
    dumb-init \
    wget

# Create non-root user for security
# UID/GID 1001 matches standard practice
RUN addgroup -g 1001 -S pagescms && \
    adduser -S pagescms -u 1001 && \
    mkdir -p /app/content /app/media && \
    chown -R pagescms:pagescms /app

# Set working directory
WORKDIR /app

# Copy production dependencies from dependencies stage
COPY --from=dependencies --chown=pagescms:pagescms /app/node_modules ./node_modules

# Copy Next.js standalone output from builder stage
# The standalone output contains a minimal server.js and necessary files
COPY --from=builder --chown=pagescms:pagescms /app/.next/standalone ./
COPY --from=builder --chown=pagescms:pagescms /app/.next/static ./.next/static
COPY --from=builder --chown=pagescms:pagescms /app/public ./public

# Copy database configuration and scripts
COPY --chown=pagescms:pagescms db ./db

# Switch to non-root user for security
USER pagescms

# Expose port (for documentation; overridden by Dokku PORT env var)
EXPOSE 3000

# Health check (Dokku-compatible)
# Uses PORT environment variable for flexibility
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/api/health || exit 1

# Use dumb-init to handle signals properly
# This ensures graceful shutdown when receiving SIGTERM
ENTRYPOINT ["dumb-init", "--"]

# Start Next.js server
# The standalone output includes a minimal server.js file
CMD ["node", "server.js"]
