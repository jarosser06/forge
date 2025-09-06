#!/bin/bash

# Script to enter the running forge devcontainer
# Usage: ./enter_devcontainer.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Looking for forge devcontainer...${NC}"

# Find the running forge devcontainer
CONTAINER_ID=$(docker ps --filter "name=forge" --filter "status=running" --format "{{.ID}}" | head -1)

if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}❌ No running forge devcontainer found!${NC}"
    echo -e "${YELLOW}💡 Available options:${NC}"
    echo "   1. Start devcontainer: 'docker-compose up -d' in .devcontainer/"
    echo "   2. Open in VS Code: 'code .' and reopen in container"
    echo "   3. Check running containers: 'docker ps'"
    exit 1
fi

# Get container name for display
CONTAINER_NAME=$(docker ps --filter "id=$CONTAINER_ID" --format "{{.Names}}")

echo -e "${GREEN}✅ Found running container: ${CONTAINER_NAME} (${CONTAINER_ID})${NC}"
echo -e "${BLUE}🚀 Entering interactive shell...${NC}"
echo -e "${YELLOW}💡 Tip: Type 'exit' to leave the container${NC}"
echo ""

# Execute interactive shell in the container
docker exec -it "$CONTAINER_ID" /bin/bash

echo -e "${GREEN}👋 Exited devcontainer shell${NC}"