#!/bin/sh
set -e

echo "🚀 Starting PagesCMS container..."

# Run database migrations using PagesCMS's built-in migration script
echo "📊 Running database migrations..."
npm run db:migrate || echo "⚠️  Migrations already applied or failed"

echo "✅ Starting Next.js server..."

# Start the application
exec node server.js
