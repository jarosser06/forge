#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_DIR="/tmp/forge-test-$(date +%s)"
TEST_PROJECT_NAME="test-project"
TEST_PROJECT_SLUG="test-project"  # This will match the project_slug after cookiecutter processing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        log_info "Removed test directory: $TEST_DIR"
    fi
    
    # Stop any running containers that might have been started
    if command -v docker &> /dev/null; then
        local containers
        containers=$(docker ps -q --filter "label=devcontainer.config_file")
        if [[ -n "$containers" ]]; then
            log_info "Stopping devcontainer instances..."
            echo "$containers" | xargs docker stop
        fi
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if ! command -v cookiecutter &> /dev/null; then
        missing_deps+=("cookiecutter")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Install devcontainer CLI if not present
install_devcontainer_cli() {
    log_info "Checking for devcontainer CLI..."
    
    if command -v devcontainer &> /dev/null; then
        log_success "devcontainer CLI already installed"
        devcontainer --version
        return 0
    fi
    
    log_info "Installing devcontainer CLI..."
    if npm install -g @devcontainers/cli; then
        log_success "devcontainer CLI installed successfully"
        devcontainer --version
    else
        log_error "Failed to install devcontainer CLI"
        exit 1
    fi
}

# Create test environment
create_test_environment() {
    log_info "Creating test environment in $TEST_DIR..."
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    log_success "Test environment created"
}

# Generate project from cookiecutter template
generate_test_project() {
    log_info "Generating test project from cookiecutter template..."
    
    # Generate project using cookiecutter with --no-input and explicit parameters
    log_info "Running cookiecutter with explicit parameters..."
    cookiecutter "$SCRIPT_DIR" --no-input \
        project_name="$TEST_PROJECT_NAME" \
        project_description="Test project for forge validation" \
        author_name="Test User" \
        author_email="test@example.com" \
        --overwrite-if-exists
    local cookiecutter_exit_code=$?
    
    if [[ $cookiecutter_exit_code -eq 0 ]]; then
        log_success "Test project generated successfully"
        log_info "Contents of test directory:"
        ls -la
    else
        log_error "Cookiecutter failed with exit code: $cookiecutter_exit_code"
        exit 1
    fi
    
    # Verify project structure
    if [[ -d "$TEST_PROJECT_SLUG" ]]; then
        log_info "Verifying project structure..."
        cd "$TEST_PROJECT_SLUG"
        
        # Check for essential files
        local required_files=(
            ".devcontainer/devcontainer.json"
            ".devcontainer/docker-compose.yml"
            ".devcontainer/Dockerfile"
            ".devcontainer/setup.sh"
            ".mcp.json"
        )
        
        for file in "${required_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_success "Found required file: $file"
            else
                log_error "Missing required file: $file"
                exit 1
            fi
        done
    else
        log_error "Generated project directory not found"
        exit 1
    fi
}

# Build devcontainer
build_devcontainer() {
    log_info "Building devcontainer..."
    
    log_info "Building devcontainer (this may take several minutes)..."
    log_info "This includes building Docker images, installing features, and running post-create commands..."
    devcontainer build --workspace-folder .
    local build_exit_code=$?
    
    if [[ $build_exit_code -eq 0 ]]; then
        log_success "DevContainer built successfully"
    else
        log_error "DevContainer build failed with exit code: $build_exit_code"
        log_error "Check the output above for specific error details"
        exit 1
    fi
}

# Start devcontainer and run tests
test_devcontainer() {
    log_info "Starting devcontainer and running validation tests..."
    
    # Start the devcontainer
    log_info "Starting devcontainer..."
    local up_output
    up_output=$(devcontainer up --workspace-folder . 2>&1)
    local up_exit_code=$?
    
    if [[ $up_exit_code -eq 0 ]]; then
        log_success "DevContainer started successfully"
        
        # Extract container ID from the output
        local container_id
        container_id=$(echo "$up_output" | grep -o '"containerId":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$container_id" ]]; then
            log_error "Could not extract container ID from devcontainer up output"
            exit 1
        fi
        
        log_info "Container ID: $container_id"
        
        # Wait a moment for the container to fully initialize
        log_info "Waiting for container to fully initialize..."
        sleep 5
        
    else
        log_error "Failed to start devcontainer with exit code: $up_exit_code"
        echo "$up_output"
        exit 1
    fi
    
    # Test basic functionality inside the container using docker exec
    log_info "Testing development tools inside container..."
    
    # Test Python
    if docker exec "$container_id" python3 --version; then
        log_success "Python 3 is working"
    else
        log_error "Python 3 test failed"
        exit 1
    fi
    
    # Test Node.js
    if docker exec "$container_id" node --version; then
        log_success "Node.js is working"
    else
        log_error "Node.js test failed"
        exit 1
    fi
    
    # Test GitHub CLI
    if docker exec "$container_id" gh --version; then
        log_success "GitHub CLI is working"
    else
        log_warning "GitHub CLI test failed (may require authentication)"
    fi
    
    # Test Terraform
    if docker exec "$container_id" terraform version; then
        log_success "Terraform is working"
    else
        log_error "Terraform test failed"
        exit 1
    fi
    
    # Test uv installation (for MCP servers)
    if docker exec "$container_id" bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv --version'; then
        log_success "uv (Python package manager) is working"
    else
        log_warning "uv test failed (may not be in PATH yet)"
    fi
}

# Test Neo4j service
test_neo4j_service() {
    log_info "Testing Neo4j database service..."
    
    # Get container ID from docker ps
    local container_id
    container_id=$(docker ps -q --filter "label=devcontainer.config_file" | head -1)
    
    if [[ -z "$container_id" ]]; then
        log_error "Could not find running devcontainer"
        return 1
    fi
    
    # Wait for Neo4j to start up (it may take some time)
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec "$container_id" curl -f http://neo4j:7474 &>/dev/null; then
            log_success "Neo4j service is accessible"
            return 0
        fi
        
        log_info "Waiting for Neo4j to start (attempt $attempt/$max_attempts)..."
        sleep 5
        ((attempt++))
    done
    
    log_warning "Neo4j service test timeout - service may still be starting"
    return 1
}

# Test MCP configuration
test_mcp_configuration() {
    log_info "Testing MCP configuration..."
    
    # Get container ID from docker ps
    local container_id
    container_id=$(docker ps -q --filter "label=devcontainer.config_file" | head -1)
    
    if [[ -z "$container_id" ]]; then
        log_error "Could not find running devcontainer"
        return 1
    fi
    
    # Check if .mcp.json exists and is valid JSON
    if docker exec "$container_id" python3 -m json.tool /workspaces/test-project/.mcp.json > /dev/null; then
        log_success "MCP configuration is valid JSON"
    else
        log_error "Invalid MCP configuration"
        exit 1
    fi
    
    # Check for Graphiti installation
    if docker exec "$container_id" test -d /mcp-servers/graphiti; then
        log_success "Graphiti MCP server directory exists"
    else
        log_warning "Graphiti MCP server directory not found"
    fi
}

# Main test execution
main() {
    log_info "Starting Forge repository validation test..."
    log_info "Test directory: $TEST_DIR"
    
    # Run test phases
    check_prerequisites
    install_devcontainer_cli
    create_test_environment
    generate_test_project
    build_devcontainer
    test_devcontainer
    test_neo4j_service
    test_mcp_configuration
    
    log_success "All tests completed successfully!"
    log_info "The forge repository is working correctly and can generate functional development environments."
}

# Run main function
main "$@"