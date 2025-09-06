#!/bin/bash

echo "🔧 Starting {{cookiecutter.project_slug}} devcontainer setup..."

# Update package lists
sudo apt-get update

# Install uv (which provides uvx) for MCP server management
echo "📦 Installing uv (provides uvx) for MCP servers..."
python3 -m pip install --user uv

# Ensure uv/uvx is in PATH for current session
export PATH="$HOME/.local/bin:$PATH"

# Install Claude Code CLI
echo "🤖 Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# Install MCP server packages using uv tool install
echo "🤖 Installing MCP servers..."

# Create shared MCP servers directory and setup Graphiti
echo "🧠 Setting up Graphiti MCP server in shared directory..."
sudo mkdir -p /mcp-servers
sudo chown dev:dev /mcp-servers
git clone https://github.com/getzep/graphiti.git /mcp-servers/graphiti
cd /mcp-servers/graphiti && uv sync || echo "⚠️  Graphiti setup failed"

# Install Playwright browsers
echo "🎭 Installing Playwright browsers..."
npx --yes playwright install chromium firefox webkit
npx --yes playwright install-deps

echo "🚀 {{cookiecutter.project_slug}} devcontainer is ready for development!"