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
