# Claude Code UI - Web interface for Claude Code CLI
FROM node:20-slim

# Install dependencies for Claude CLI, terminal emulation (node-pty), and native builds
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create app directory and user
WORKDIR /app

# Clone and build Claude Code UI
RUN git clone --depth 1 https://github.com/siteboon/claudecodeui.git . \
    && npm ci \
    && npm run build

# Create directories for persistent data
RUN mkdir -p /home/node/.claude /data \
    && chown -R node:node /app /home/node /data

# Switch to non-root user
USER node

# Environment variables
ENV PORT=3001 \
    NODE_ENV=production \
    DATABASE_PATH=/data/auth.db

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/api/health || exit 1

# Start the server
CMD ["npm", "start"]
