#!/usr/bin/env bash
# Holocron Test Setup Script
# Runs a complete test installation in an isolated test directory
# No user input required - perfect for rapid testing!

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test Configuration
TEST_ROOT="/tmp/holocron-test-$$"
TEST_HOLOCRON_DIR="$TEST_ROOT/.holocron"
TEST_WORKSPACE="$TEST_HOLOCRON_DIR/workspace"
TEST_CONFIG_DIR="$TEST_ROOT/.config/holocron"
TEST_LAYOUT_DIR="$TEST_CONFIG_DIR/layouts"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║            🧪  HOLOCRON TEST MODE  🧪                          ║"
    echo "║         Automated Testing Environment                          ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    echo ""
    log_info "Cleaning up test environment..."

    if [[ -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
        log_success "Removed test directory: $TEST_ROOT"
    fi

    # Kill any test Zellij sessions
    if command -v zellij &> /dev/null; then
        zellij delete-session holocron-test 2>/dev/null || true
    fi

    log_success "Cleanup complete!"
}

# ============================================================================
# Test Repository Setup
# ============================================================================

create_test_repos() {
    log_info "Creating test repositories..."

    # Create fake repo 1
    mkdir -p "$TEST_WORKSPACE/repo1"
    (
        cd "$TEST_WORKSPACE/repo1"
        git init -q
        echo "# Driving Repository (Test)" > README.md
        echo "print('Hello from Driving repo')" > main.py
        git add . && git commit -q -m "Initial commit"
    )
    log_success "Created test repo1: Driving"

    # Create fake repo 2
    mkdir -p "$TEST_WORKSPACE/repo2"
    (
        cd "$TEST_WORKSPACE/repo2"
        git init -q
        echo "# K8s Repository (Test)" > README.md
        mkdir -p manifests
        cat > manifests/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
YAML
        git add . && git commit -q -m "Initial commit"
    )
    log_success "Created test repo2: K8s"

    # Create fake repo 3
    mkdir -p "$TEST_WORKSPACE/repo3"
    (
        cd "$TEST_WORKSPACE/repo3"
        git init -q
        echo "# Deploy Repository (Test)" > README.md
        echo "#!/bin/bash" > deploy.sh
        echo "echo 'Deploying...'" >> deploy.sh
        chmod +x deploy.sh
        git add . && git commit -q -m "Initial commit"
    )
    log_success "Created test repo3: Deploy"
}

# ============================================================================
# Configuration Generation
# ============================================================================

generate_test_config() {
    log_info "Generating test configuration..."

    mkdir -p "$TEST_CONFIG_DIR"

    cat > "$TEST_CONFIG_DIR/config.yaml" <<EOF
# Holocron Test Configuration
# Generated: $(date)

repositories:
  repo1:
    name: "Driving"
    url: "file://$TEST_WORKSPACE/repo1"
    path: "$TEST_WORKSPACE/repo1"

  repo2:
    name: "K8s"
    url: "file://$TEST_WORKSPACE/repo2"
    path: "$TEST_WORKSPACE/repo2"

  repo3:
    name: "Deploy"
    url: "file://$TEST_WORKSPACE/repo3"
    path: "$TEST_WORKSPACE/repo3"

kubernetes:
  enabled: false
  context1:
    name: "Test Prod"
    context: "minikube"

  context2:
    name: "Test Dev"
    context: "minikube"

  context3:
    name: "Test Ray"
    context: "minikube"

workspace:
  name: "Hyperpod-Test"
  holocron_dir: "$TEST_HOLOCRON_DIR"
  workspace_dir: "$TEST_WORKSPACE"

test_mode: true
EOF

    log_success "Configuration saved"
}

generate_test_layout() {
    log_info "Generating test layout..."

    mkdir -p "$TEST_LAYOUT_DIR"

    # Read template
    template_file="$PROJECT_ROOT/src/layouts/hyperpod.kdl"

    if [[ ! -f "$template_file" ]]; then
        log_error "Layout template not found: $template_file"
        exit 1
    fi

    # Replace template variables
    sed -e "s|{{HOLOCRON_WORKSPACE}}|$TEST_WORKSPACE|g" \
        -e "s|{{REPO_1_NAME}}|Driving (TEST)|g" \
        -e "s|{{REPO_2_NAME}}|K8s (TEST)|g" \
        -e "s|{{REPO_3_NAME}}|Deploy (TEST)|g" \
        -e "s|{{K8S_CONTEXT_1}}|minikube|g" \
        -e "s|{{K8S_CONTEXT_2}}|minikube|g" \
        -e "s|{{K8S_CONTEXT_3}}|minikube|g" \
        -e 's|command "k9s"|command "bash"|g' \
        "$template_file" > "$TEST_LAYOUT_DIR/hyperpod.kdl"

    log_success "Layout generated"
}

# ============================================================================
# Dependency Check
# ============================================================================

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v zellij &> /dev/null; then
        log_error "Zellij is not installed!"
        echo "Please install Zellij first: https://zellij.dev/documentation/installation"
        exit 1
    fi

    log_success "Zellij found: $(command -v zellij)"

    if ! command -v git &> /dev/null; then
        log_error "Git is not installed!"
        exit 1
    fi

    log_success "Git found: $(command -v git)"
}

# ============================================================================
# Main Test Flow
# ============================================================================

run_test() {
    print_header

    log_info "Starting test setup..."
    echo ""
    log_info "Test root: $TEST_ROOT"
    echo ""

    # Check dependencies
    check_dependencies

    # Setup test environment
    log_info "Creating test directory structure..."
    mkdir -p "$TEST_ROOT"
    mkdir -p "$TEST_HOLOCRON_DIR"
    mkdir -p "$TEST_WORKSPACE"
    mkdir -p "$TEST_CONFIG_DIR"
    log_success "Test directories created"

    # Create test repos
    create_test_repos

    # Generate config and layout
    generate_test_config
    generate_test_layout

    # Success message
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "🎉 Test environment ready!"
    echo ""
    echo "Test Configuration:"
    echo "  Root:       $TEST_ROOT"
    echo "  Workspace:  $TEST_WORKSPACE"
    echo "  Layout:     $TEST_LAYOUT_DIR/hyperpod.kdl"
    echo "  Config:     $TEST_CONFIG_DIR/config.yaml"
    echo ""
    echo "To launch the test workspace:"
    echo -e "  ${GREEN}zellij --layout $TEST_LAYOUT_DIR/hyperpod.kdl --session holocron-test${NC}"
    echo ""
    echo "To clean up after testing:"
    echo -e "  ${YELLOW}rm -rf $TEST_ROOT${NC}"
    echo "  ${YELLOW}zellij delete-session holocron-test${NC}"
    echo ""
    echo "Or use the cleanup script:"
    echo -e "  ${YELLOW}./src/scripts/test-cleanup.sh${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Interactive Mode
# ============================================================================

interactive_mode() {
    run_test

    echo ""
    read -p "$(echo -e ${GREEN}[?]${NC} Launch test workspace now? \(y/n\): )" launch

    if [[ "$launch" == "y" ]]; then
        log_info "Launching test workspace..."
        echo ""
        zellij --layout "$TEST_LAYOUT_DIR/hyperpod.kdl" --session holocron-test
    fi

    echo ""
    read -p "$(echo -e ${YELLOW}[?]${NC} Clean up test environment? \(y/n\): )" clean

    if [[ "$clean" == "y" ]]; then
        cleanup
    else
        log_warn "Test environment kept at: $TEST_ROOT"
        log_info "Clean up manually with: rm -rf $TEST_ROOT"
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main() {
    case "${1:-interactive}" in
        setup)
            run_test
            ;;
        cleanup)
            cleanup
            ;;
        launch)
            if [[ ! -f "$TEST_LAYOUT_DIR/hyperpod.kdl" ]]; then
                log_error "Test environment not set up. Run './src/scripts/test-setup.sh setup' first"
                exit 1
            fi
            zellij --layout "$TEST_LAYOUT_DIR/hyperpod.kdl" --session holocron-test
            ;;
        interactive|*)
            interactive_mode
            ;;
    esac
}

# Trap cleanup on exit if interrupted
trap cleanup EXIT INT TERM

main "$@"
