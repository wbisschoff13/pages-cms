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
# The builder stage is complete. The .next/standalone directory now contains
# the standalone output with a minimal server.js file.
# Next stage: Runner stage (to be implemented)
# ============================================================================
