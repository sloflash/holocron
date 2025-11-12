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
  enabled: true
  context1:
    name: "Prod EKS"
    context: "prod-eks"

  context2:
    name: "Dev EKS"
    context: "dev-eks"

  context3:
    name: "Ray EKS"
    context: "ray-eks"

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
    # Note: Uses existing minikube profiles (prod-eks, dev-eks, ray-eks)
    sed -e "s|{{HOLOCRON_WORKSPACE}}|$TEST_WORKSPACE|g" \
        -e "s|{{REPO_1_NAME}}|Driving (TEST)|g" \
        -e "s|{{REPO_2_NAME}}|K8s (TEST)|g" \
        -e "s|{{REPO_3_NAME}}|Deploy (TEST)|g" \
        -e "s|{{K8S_CONTEXT_1}}|prod-eks|g" \
        -e "s|{{K8S_CONTEXT_2}}|dev-eks|g" \
        -e "s|{{K8S_CONTEXT_3}}|ray-eks|g" \
        -e "s|{{K9S_PROD_DIR}}|$TEST_ROOT/k9s/prod|g" \
        -e "s|{{K9S_DEV_DIR}}|$TEST_ROOT/k9s/dev|g" \
        -e "s|{{K9S_RAY_DIR}}|$TEST_ROOT/k9s/ray|g" \
        -e "s|{{LOGS_DIR}}|$TEST_ROOT/logs|g" \
        -e "s|{{UTILS_DIR}}|$TEST_ROOT/utils|g" \
        "$template_file" > "$TEST_LAYOUT_DIR/hyperpod.kdl"

    # Create a k9s wrapper script that provides helpful error messages
    cat > "$TEST_CONFIG_DIR/k9s-wrapper.sh" <<'WRAPPER'
#!/usr/bin/env bash
# K9s wrapper for Holocron testing

if ! command -v k9s &> /dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "K9s is not installed!"
    echo ""
    echo "To install k9s:"
    echo "  macOS:   brew install derailed/k9s/k9s"
    echo "  Linux:   Check https://k9scli.io/topics/install/"
    echo ""
    echo "Starting zsh instead..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exec zsh
fi

# Check if minikube is running
if command -v minikube &> /dev/null; then
    if ! minikube status &> /dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Minikube is not running!"
        echo ""
        echo "Start minikube with:"
        echo "  minikube start"
        echo ""
        echo "Starting zsh instead..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exec zsh
    fi
fi

# Run k9s with provided arguments
exec k9s "$@"
WRAPPER
    chmod +x "$TEST_CONFIG_DIR/k9s-wrapper.sh"

    log_success "Layout generated"
}

# ============================================================================
# Dependency Check
# ============================================================================

install_zellij() {
    log_info "Attempting to install Zellij..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install zellij
            return 0
        else
            log_error "Homebrew not found. Please install Homebrew first or install Zellij manually."
            return 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Use the same install function from setup.sh
        local temp_dir=$(mktemp -d)
        cd "$temp_dir" || return 1

        local arch=$(uname -m)
        local zellij_url

        if [[ "$arch" == "x86_64" ]]; then
            zellij_url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
        elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
            zellij_url="https://github.com/derailed/k9s/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz"
        else
            log_error "Unsupported architecture: $arch"
            return 1
        fi

        if ! curl -L "$zellij_url" | tar -xzf -; then
            log_error "Failed to download Zellij"
            return 1
        fi

        sudo install -m 755 zellij /usr/local/bin/zellij
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 0
    else
        log_error "Unsupported OS. Please install Zellij manually."
        return 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    # Check and install Zellij automatically for test mode
    if ! command -v zellij &> /dev/null; then
        log_warn "Zellij is not installed!"
        log_info "Installing Zellij for testing..."

        if install_zellij; then
            log_success "Zellij installed successfully"
        else
            log_error "Failed to install Zellij"
            log_info "Please install Zellij manually and re-run: https://zellij.dev/documentation/installation"
            exit 1
        fi
    else
        log_success "Zellij found: $(command -v zellij)"
    fi

    if ! command -v git &> /dev/null; then
        log_error "Git is not installed!"
        exit 1
    fi

    log_success "Git found: $(command -v git)"

    # Check k9s
    if ! command -v k9s &> /dev/null; then
        log_warn "k9s is not installed (optional)"
        log_info "Install with: brew install derailed/k9s/k9s"
    else
        log_success "k9s found: $(command -v k9s)"
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_warn "kubectl is not installed (optional)"
        log_info "Install with: brew install kubectl"
    else
        log_success "kubectl found: $(command -v kubectl)"
    fi

    # Check for existing minikube clusters
    if command -v minikube &> /dev/null; then
        log_info "Checking for existing minikube clusters..."

        local clusters_found=0
        for profile in prod-eks dev-eks ray-eks; do
            if minikube profile list 2>/dev/null | grep -q "$profile"; then
                log_success "Found minikube profile: $profile"
                ((clusters_found++))
            fi
        done

        if [[ $clusters_found -eq 0 ]]; then
            log_warn "No minikube clusters found (prod-eks, dev-eks, ray-eks)"
            log_info "Create them with:"
            log_info "  minikube start -p prod-eks --driver=docker --cpus=2 --memory=2048"
            log_info "  minikube start -p dev-eks --driver=docker --cpus=2 --memory=2048"
            log_info "  minikube start -p ray-eks --driver=docker --cpus=2 --memory=2048"
        else
            log_success "Found $clusters_found minikube cluster(s)"
        fi
    else
        log_warn "minikube is not installed (optional for K8s testing)"
        log_info "Install with: brew install minikube"
    fi
}

# ============================================================================
# Analyze Script Creation
# ============================================================================

create_analyze_script() {
    local pane_dir="$1"
    local cluster_name="$2"

    cat > "$pane_dir/analyze.sh" <<'ANALYZE_SCRIPT'
#!/usr/bin/env zsh
# K9s Analyze Script - Capture and analyze Kubernetes logs with Claude

analyze() {
    local CLUSTER="${1:-current}"
    local TMPFILE="${ZELLIJ_SESSION_NAME:+/tmp/zellij-${ZELLIJ_SESSION_NAME}}-analyze-${CLUSTER}.txt"

    # Fallback if not in Zellij
    if [[ -z "$TMPFILE" ]]; then
        TMPFILE="/tmp/zellij-analyze-${CLUSTER}-$$.txt"
    fi

    echo "🔍 Capturing pane content for ${CLUSTER}..."

    # Ensure clean slate
    rm -f "$TMPFILE"

    # Dump current pane screen content
    if command -v zellij &> /dev/null; then
        zellij action dump-screen "$TMPFILE"
    else
        echo "❌ Zellij not found or not in a Zellij session"
        return 1
    fi

    # Verify file was created and has content
    if [[ ! -s "$TMPFILE" ]]; then
        echo "❌ Failed to capture pane content"
        return 1
    fi

    local line_count=$(wc -l < "$TMPFILE")
    echo "✅ Captured ${line_count} lines from ${CLUSTER}"

    # Check if claude command exists
    if ! command -v claude &> /dev/null; then
        echo "❌ 'claude' command not found. Please install Claude CLI."
        echo "📁 Content saved to: $TMPFILE"
        echo "   You can manually review or pipe to another tool."
        return 1
    fi

    # Analyze with Claude
    echo "🤖 Analyzing with Claude..."
    claude "Analyze these K8s logs from ${CLUSTER} cluster. Look for errors, warnings, resource issues, or anomalies:" < "$TMPFILE"

    # Keep the file for manual inspection
    echo ""
    echo "📁 Raw content saved to: $TMPFILE"
}

# Make analyze function available
export -f analyze 2>/dev/null || true

# Show help on load
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "K9s Analyze Script Loaded"
echo ""
echo "Usage:"
echo "  analyze [cluster-name]"
echo ""
echo "Example:"
echo "  analyze prod-eks"
echo ""
echo "This will:"
echo "  1. Capture current k9s pane content"
echo "  2. Send to Claude for analysis"
echo "  3. Save raw output to /tmp for inspection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ANALYZE_SCRIPT

    chmod +x "$pane_dir/analyze.sh"

    # Replace CLUSTER placeholder with actual cluster name
    sed -i.bak "s/current/${cluster_name}/g" "$pane_dir/analyze.sh"
    rm -f "$pane_dir/analyze.sh.bak"

    log_success "Created analyze script in $pane_dir"
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

    # Create working directories for each pane
    mkdir -p "$TEST_ROOT/k9s/prod"
    mkdir -p "$TEST_ROOT/k9s/dev"
    mkdir -p "$TEST_ROOT/k9s/ray"
    mkdir -p "$TEST_ROOT/logs"
    mkdir -p "$TEST_ROOT/utils"
    mkdir -p "/tmp/zellij-captures"

    # Initialize analysis output file
    touch /tmp/zellij-analysis-output.txt

    log_success "Test directories created"

    # Copy analyze script to utils directory for easy access
    log_info "Setting up analysis infrastructure..."
    cp "$PROJECT_ROOT/src/scripts/analyze-pane.sh" "$TEST_ROOT/utils/"
    chmod +x "$TEST_ROOT/utils/analyze-pane.sh"

    # Create analyze script for k9s panes
    log_info "Creating analyze scripts for k9s panes..."
    create_analyze_script "$TEST_ROOT/k9s/prod" "prod-eks"
    # TODO: Uncomment for dev and ray when ready to test
    # create_analyze_script "$TEST_ROOT/k9s/dev" "dev-eks"
    # create_analyze_script "$TEST_ROOT/k9s/ray" "ray-eks"

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
    echo -e "  ${GREEN}zellij --layout $TEST_LAYOUT_DIR/hyperpod.kdl${NC}"
    echo ""
    echo "To enable the Ctrl+Shift+A analyze hotkey:"
    echo "  1. Add this to your ~/.config/zellij/config.kdl:"
    echo ""
    echo "     shared_except \"locked\" {"
    echo "         bind \"Ctrl Shift A\" {"
    echo "             Run \"bash\" {"
    echo "                 args \"-c\" \"$TEST_ROOT/utils/analyze-pane.sh\""
    echo "                 close_on_exit true"
    echo "                 floating true"
    echo "             }"
    echo "         }"
    echo "     }"
    echo ""
    echo "  2. Or run manually from k9s panes: $TEST_ROOT/utils/analyze-pane.sh"
    echo ""
    echo "To clean up after testing:"
    echo -e "  ${YELLOW}rm -rf $TEST_ROOT${NC}"
    echo "  ${YELLOW}# Exit zellij with Ctrl+q or detach, then kill session with:${NC}"
    echo "  ${YELLOW}# zellij list-sessions  # to find session name${NC}"
    echo "  ${YELLOW}# zellij delete-session <session-name>${NC}"
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
        zellij --layout "$TEST_LAYOUT_DIR/hyperpod.kdl"
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
            zellij --layout "$TEST_LAYOUT_DIR/hyperpod.kdl"
            ;;
        interactive|*)
            interactive_mode
            ;;
    esac
}

# Trap cleanup on exit unless NO_CLEANUP is set
if [[ "${NO_CLEANUP:-false}" != "true" ]]; then
    trap cleanup EXIT INT TERM
fi

main "$@"
