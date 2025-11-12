#!/usr/bin/env bash
# Holocron Setup Script
# Installs and configures the Hyperpod workspace

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOLOCRON_DIR="$HOME/.holocron"
HOLOCRON_WORKSPACE="$HOLOCRON_DIR/workspace"
CONFIG_DIR="$HOME/.config/holocron"
LAYOUT_DIR="$CONFIG_DIR/layouts"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║                 🌌  HOLOCRON  🌌                               ║"
    echo "║         Terminal Control System - Setup                        ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

prompt() {
    echo -e "${GREEN}[?]${NC} $1"
}

# ============================================================================
# Dependency Checking and Installation
# ============================================================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v dnf &> /dev/null; then
            echo "fedora"
        elif command -v pacman &> /dev/null; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

check_dependency() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        log_success "$cmd is installed ($(command -v "$cmd"))"
        return 0
    else
        log_warn "$cmd is not installed"
        return 1
    fi
}

install_with_brew() {
    local package=$1
    log_info "Installing $package via Homebrew..."
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not found!"
        echo "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
    brew install "$package"
}

install_with_apt() {
    local package=$1
    log_info "Installing $package via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y "$package"
}

install_zellij_linux() {
    log_info "Installing Zellij from GitHub releases..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1

    # Detect architecture
    local arch=$(uname -m)
    local zellij_url

    if [[ "$arch" == "x86_64" ]]; then
        zellij_url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
    elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        zellij_url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz"
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
    log_success "Zellij installed to /usr/local/bin/zellij"
}

install_kubectl_linux() {
    log_info "Installing kubectl from official releases..."
    local stable_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    local arch=$(uname -m)

    if [[ "$arch" == "x86_64" ]]; then
        arch="amd64"
    elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        arch="arm64"
    fi

    curl -LO "https://dl.k8s.io/release/${stable_version}/bin/linux/${arch}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    log_success "kubectl installed to /usr/local/bin/kubectl"
}

install_k9s_linux() {
    log_info "Installing k9s from GitHub releases..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1

    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        arch="amd64"
    elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        arch="arm64"
    fi

    local k9s_url="https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz"

    if ! curl -L "$k9s_url" | tar -xzf -; then
        log_error "Failed to download k9s"
        return 1
    fi

    sudo install -m 755 k9s /usr/local/bin/k9s
    cd - > /dev/null
    rm -rf "$temp_dir"
    log_success "k9s installed to /usr/local/bin/k9s"
}

install_dependencies() {
    local os=$(detect_os)
    log_info "Detected OS: $os ($(uname -m))"
    echo ""

    log_info "Checking required dependencies..."
    echo ""

    # Check and install Zellij
    if ! check_dependency "zellij"; then
        case $os in
            macos)
                install_with_brew zellij || exit 1
                ;;
            ubuntu|linux)
                install_zellij_linux || exit 1
                ;;
            *)
                log_error "Unsupported OS: $os"
                echo "Please install Zellij manually: https://zellij.dev/documentation/installation"
                exit 1
                ;;
        esac
    fi

    # Check and install Git
    if ! check_dependency "git"; then
        case $os in
            macos)
                install_with_brew git || exit 1
                ;;
            ubuntu|linux)
                install_with_apt git || exit 1
                ;;
            *)
                log_error "Unsupported OS: $os"
                exit 1
                ;;
        esac
    fi

    echo ""
    log_info "Checking optional dependencies..."
    echo ""

    # Check and install kubectl
    if ! check_dependency "kubectl"; then
        prompt "kubectl not found. Install it? (y/n): "
        read -r install_kubectl
        if [[ "$install_kubectl" == "y" ]]; then
            case $os in
                macos)
                    install_with_brew kubectl
                    ;;
                ubuntu|linux)
                    install_kubectl_linux
                    ;;
                *)
                    log_warn "Please install kubectl manually: https://kubernetes.io/docs/tasks/tools/"
                    ;;
            esac
        fi
    fi

    # Check and install k9s
    if ! check_dependency "k9s"; then
        prompt "k9s not found. Install it? (y/n): "
        read -r install_k9s
        if [[ "$install_k9s" == "y" ]]; then
            case $os in
                macos)
                    install_with_brew k9s
                    ;;
                ubuntu|linux)
                    install_k9s_linux
                    ;;
                *)
                    log_warn "Please install k9s manually: https://k9scli.io/topics/install/"
                    ;;
            esac
        fi
    fi

    echo ""
    log_success "Dependency check complete!"
}

# ============================================================================
# Configuration Collection
# ============================================================================

collect_repo_config() {
    echo ""
    log_info "Repository Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Repo 1
    prompt "Enter name for Repository 1 (default: Driving): "
    read -r repo1_name
    repo1_name=${repo1_name:-"Driving"}

    prompt "Enter git URL for Repository 1 (or press Enter to skip): "
    read -r repo1_url

    # Repo 2
    prompt "Enter name for Repository 2 (default: K8s): "
    read -r repo2_name
    repo2_name=${repo2_name:-"K8s"}

    prompt "Enter git URL for Repository 2 (or press Enter to skip): "
    read -r repo2_url

    # Repo 3
    prompt "Enter name for Repository 3 (default: Deploy): "
    read -r repo3_name
    repo3_name=${repo3_name:-"Deploy"}

    prompt "Enter git URL for Repository 3 (or press Enter to skip): "
    read -r repo3_url
}

collect_k8s_config() {
    echo ""
    log_info "Kubernetes Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! command -v kubectl &> /dev/null; then
        log_warn "kubectl not found. Skipping Kubernetes configuration."
        k8s_enabled=false
        return
    fi

    prompt "Configure Kubernetes contexts? (y/n): "
    read -r configure_k8s

    if [[ "$configure_k8s" != "y" ]]; then
        k8s_enabled=false
        return
    fi

    k8s_enabled=true

    # Show available contexts
    log_info "Available kubectl contexts:"
    kubectl config get-contexts -o name | sed 's/^/  - /'

    # Context 1
    prompt "Enter kubectl context for Prod EKS (or press Enter to skip): "
    read -r k8s_context1

    # Context 2
    prompt "Enter kubectl context for Dev EKS (or press Enter to skip): "
    read -r k8s_context2

    # Context 3
    prompt "Enter kubectl context for Ray EKS (or press Enter to skip): "
    read -r k8s_context3
}

# ============================================================================
# Repository Management
# ============================================================================

clone_repositories() {
    echo ""
    log_info "Setting up workspace directories..."

    # Create workspace directory
    mkdir -p "$HOLOCRON_WORKSPACE"/{repo1,repo2,repo3}
    mkdir -p "$HOLOCRON_DIR"/{k9s/{prod,dev,ray},logs,utils,analysis}

    # Copy analyzer script
    cp "$PROJECT_ROOT/src/scripts/analyze-on-demand.sh" "$HOLOCRON_DIR/utils/"
    chmod +x "$HOLOCRON_DIR/utils/analyze-on-demand.sh"

    log_success "Created workspace at $HOLOCRON_WORKSPACE"

    # Clone repo1
    if [[ -n "$repo1_url" ]]; then
        log_info "Cloning $repo1_name..."
        if [[ -d "$HOLOCRON_WORKSPACE/repo1/.git" ]]; then
            log_warn "repo1 already exists, skipping clone"
        else
            git clone "$repo1_url" "$HOLOCRON_WORKSPACE/repo1" || {
                log_error "Failed to clone repo1"
                log_warn "You can manually clone it later to: $HOLOCRON_WORKSPACE/repo1"
            }
        fi
    else
        log_info "Skipping repo1 clone (no URL provided)"
    fi

    # Clone repo2
    if [[ -n "$repo2_url" ]]; then
        log_info "Cloning $repo2_name..."
        if [[ -d "$HOLOCRON_WORKSPACE/repo2/.git" ]]; then
            log_warn "repo2 already exists, skipping clone"
        else
            git clone "$repo2_url" "$HOLOCRON_WORKSPACE/repo2" || {
                log_error "Failed to clone repo2"
                log_warn "You can manually clone it later to: $HOLOCRON_WORKSPACE/repo2"
            }
        fi
    else
        log_info "Skipping repo2 clone (no URL provided)"
    fi

    # Clone repo3
    if [[ -n "$repo3_url" ]]; then
        log_info "Cloning $repo3_name..."
        if [[ -d "$HOLOCRON_WORKSPACE/repo3/.git" ]]; then
            log_warn "repo3 already exists, skipping clone"
        else
            git clone "$repo3_url" "$HOLOCRON_WORKSPACE/repo3" || {
                log_error "Failed to clone repo3"
                log_warn "You can manually clone it later to: $HOLOCRON_WORKSPACE/repo3"
            }
        fi
    else
        log_info "Skipping repo3 clone (no URL provided)"
    fi
}

# ============================================================================
# Configuration Generation
# ============================================================================

generate_config() {
    echo ""
    log_info "Generating configuration..."

    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_FILE" <<EOF
# Holocron Configuration
# Generated on $(date)

repositories:
  repo1:
    name: "$repo1_name"
    url: "$repo1_url"
    path: "$HOLOCRON_WORKSPACE/repo1"

  repo2:
    name: "$repo2_name"
    url: "$repo2_url"
    path: "$HOLOCRON_WORKSPACE/repo2"

  repo3:
    name: "$repo3_name"
    url: "$repo3_url"
    path: "$HOLOCRON_WORKSPACE/repo3"

kubernetes:
  enabled: $k8s_enabled
  context1:
    name: "Prod EKS"
    context: "$k8s_context1"

  context2:
    name: "Dev EKS"
    context: "$k8s_context2"

  context3:
    name: "Ray EKS"
    context: "$k8s_context3"

workspace:
  name: "Hyperpod"
  holocron_dir: "$HOLOCRON_DIR"
  workspace_dir: "$HOLOCRON_WORKSPACE"
EOF

    log_success "Configuration saved to $CONFIG_FILE"
}

generate_layout() {
    echo ""
    log_info "Generating Zellij layout..."

    mkdir -p "$LAYOUT_DIR"

    # Read template
    template_file="$PROJECT_ROOT/src/layouts/hyperpod.kdl"

    if [[ ! -f "$template_file" ]]; then
        log_error "Layout template not found: $template_file"
        exit 1
    fi

    # Replace template variables
    sed -e "s|{{HOLOCRON_WORKSPACE}}|$HOLOCRON_WORKSPACE|g" \
        -e "s|{{REPO_1_NAME}}|$repo1_name|g" \
        -e "s|{{REPO_2_NAME}}|$repo2_name|g" \
        -e "s|{{REPO_3_NAME}}|$repo3_name|g" \
        -e "s|{{K8S_CONTEXT_1}}|${k8s_context1:-minikube}|g" \
        -e "s|{{K8S_CONTEXT_2}}|${k8s_context2:-minikube}|g" \
        -e "s|{{K8S_CONTEXT_3}}|${k8s_context3:-minikube}|g" \
        -e "s|{{K9S_PROD_DIR}}|$HOLOCRON_DIR/k9s/prod|g" \
        -e "s|{{K9S_DEV_DIR}}|$HOLOCRON_DIR/k9s/dev|g" \
        -e "s|{{K9S_RAY_DIR}}|$HOLOCRON_DIR/k9s/ray|g" \
        -e "s|{{LOGS_DIR}}|$HOLOCRON_DIR/logs|g" \
        -e "s|{{UTILS_DIR}}|$HOLOCRON_DIR/utils|g" \
        -e "s|{{ANALYSIS_DIR}}|$HOLOCRON_DIR/analysis|g" \
        "$template_file" > "$LAYOUT_DIR/hyperpod.kdl"

    log_success "Layout saved to $LAYOUT_DIR/hyperpod.kdl"
}

# ============================================================================
# Zellij Configuration
# ============================================================================

configure_zellij_keybindings() {
    echo ""
    log_info "Zellij keybinding configuration skipped (no custom keybindings)"
}

# ============================================================================
# Wrapper Script Creation
# ============================================================================

create_launcher() {
    echo ""
    log_info "Creating launcher script..."

    local launcher="/usr/local/bin/holocron"

    sudo tee "$launcher" > /dev/null <<'EOF'
#!/usr/bin/env bash
# Holocron Launcher

CONFIG_DIR="$HOME/.config/holocron"
LAYOUT="$CONFIG_DIR/layouts/hyperpod.kdl"

if [[ ! -f "$LAYOUT" ]]; then
    echo "Error: Holocron layout not found at $LAYOUT"
    echo "Please run the setup script first."
    exit 1
fi

case "${1:-start}" in
    start)
        zellij --layout "$LAYOUT"
        ;;
    config)
        ${EDITOR:-nano} "$CONFIG_DIR/config.yaml"
        ;;
    layout)
        ${EDITOR:-nano} "$LAYOUT"
        ;;
    update)
        echo "Updating repositories..."
        for repo in "$HOME/.holocron/workspace"/repo*; do
            if [[ -d "$repo/.git" ]]; then
                echo "Updating $(basename "$repo")..."
                (cd "$repo" && git pull)
            fi
        done
        ;;
    *)
        echo "Holocron - Terminal Control System"
        echo ""
        echo "Usage: holocron [command]"
        echo ""
        echo "Commands:"
        echo "  start      Launch Hyperpod workspace (default)"
        echo "  config     Edit configuration"
        echo "  layout     Edit layout"
        echo "  update     Update all repositories"
        ;;
esac
EOF

    sudo chmod +x "$launcher"
    log_success "Launcher created at $launcher"
}

# ============================================================================
# Main Setup Flow
# ============================================================================

main() {
    print_header

    log_info "Starting Holocron setup..."
    echo ""

    # Install dependencies
    install_dependencies

    # Collect configuration
    collect_repo_config
    collect_k8s_config

    # Setup workspace
    clone_repositories

    # Generate files
    generate_config
    generate_layout

    # Configure Zellij
    configure_zellij_keybindings

    # Create launcher
    create_launcher

    # Success!
    echo ""
    log_success "🎉 Holocron setup complete!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To launch Hyperpod, run:"
    echo -e "  ${GREEN}holocron${NC}"
    echo ""
    echo "Other commands:"
    echo -e "  ${BLUE}holocron config${NC}   - Edit configuration"
    echo -e "  ${BLUE}holocron layout${NC}   - Edit layout"
    echo -e "  ${BLUE}holocron update${NC}   - Update repositories"
    echo ""
    echo "Configuration saved to: $CONFIG_FILE"
    echo "Layout saved to: $LAYOUT_DIR/hyperpod.kdl"
    echo "Workspace directory: $HOLOCRON_WORKSPACE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main setup
main "$@"
