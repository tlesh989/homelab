# Use uv for fast Python management on Debian
FROM ghcr.io/astral-sh/uv:debian-slim AS base

# Install Node.js, npm, and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  nodejs \
  npm \
  build-essential \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user for security
RUN useradd -m -u 1000 appuser
WORKDIR /app

# PRE-SEED CONFIG: This prevents the "Freeze" by skipping onboarding
RUN mkdir -p /home/appuser/.claude && \
  echo '{"hasCompletedOnboarding": true}' > /home/appuser/.claude.json && \
  chown -R appuser:appuser /home/appuser

USER appuser

# Default to shell
CMD ["/bin/bash"]

# docker run -it --rm \
#   -e ANTHROPIC_BASE_URL="[https://openrouter.ai/api](https://openrouter.ai/api)" \
#   -e ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY" \
#   -e ANTHROPIC_API_KEY="" \
#   -e ANTHROPIC_MODEL="nvidia/nemotron-3-super-120b-a12b:free" \
#   -e ANTHROPIC_SMALL_FAST_MODEL="nvidia/nemotron-3-super-120b-a12b:free" \
#   -v "$(pwd)":/app \
#   my-claude-image \
#   claude --model nvidia/nemotron-3-super-120b-a12b:free
