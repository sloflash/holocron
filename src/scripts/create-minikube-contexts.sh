#!/usr/bin/env bash
# Holocron Minikube Test Contexts
# Creates 3 minikube clusters for testing Holocron K8s integration

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cluster names
CLUSTERS=("holocron-prod" "holocron-dev" "holocron-ray")

# ============================================================================
# Utility Functions
# ============================================================================

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

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║         Holocron Minikube Test Contexts Setup                 ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================================================
# Dependency Check
# ============================================================================

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v minikube &> /dev/null; then
        log_error "minikube is not installed!"
        echo ""
        echo "Install minikube:"
        echo "  macOS:  brew install minikube"
        echo "  Linux:  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
        echo "          sudo install minikube-linux-amd64 /usr/local/bin/minikube"
        echo ""
        echo "More info: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed!"
        echo ""
        echo "Install kubectl:"
        echo "  macOS:  brew install kubectl"
        echo "  Linux:  See https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi

    log_success "Dependencies found!"
    echo "  minikube: $(minikube version --short)"
    echo "  kubectl:  $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# ============================================================================
# Cluster Creation
# ============================================================================

create_cluster() {
    local cluster_name=$1
    local profile=$cluster_name

    log_info "Creating cluster: $cluster_name"

    if minikube profile list 2>/dev/null | grep -q "$profile"; then
        log_warn "Cluster $cluster_name already exists"
        read -p "$(echo -e ${YELLOW}[?]${NC} Delete and recreate? \(y/n\): )" recreate
        if [[ "$recreate" == "y" ]]; then
            log_info "Deleting existing cluster..."
            minikube delete -p "$profile"
        else
            log_info "Skipping $cluster_name"
            return
        fi
    fi

    log_info "Starting minikube cluster: $cluster_name"
    minikube start \
        -p "$profile" \
        --nodes 1 \
        --cpus 2 \
        --memory 2048 \
        --driver docker \
        --kubernetes-version stable

    log_success "Cluster $cluster_name created!"

    # Deploy sample workload
    log_info "Deploying sample nginx deployment..."
    kubectl --context "$profile" create deployment nginx --image=nginx:latest || true
    kubectl --context "$profile" expose deployment nginx --port=80 --type=NodePort || true

    log_success "Sample workload deployed to $cluster_name"
}

# ============================================================================
# Context Verification
# ============================================================================

verify_contexts() {
    log_info "Verifying kubectl contexts..."

    for cluster in "${CLUSTERS[@]}"; do
        if kubectl config get-contexts "$cluster" &>/dev/null; then
            log_success "Context found: $cluster"
            kubectl --context "$cluster" get nodes --no-headers | while read -r line; do
                echo "  Node: $line"
            done
        else
            log_error "Context not found: $cluster"
        fi
    done
}

# ============================================================================
# Sample Resources
# ============================================================================

deploy_sample_resources() {
    log_info "Deploying sample resources to clusters..."

    for cluster in "${CLUSTERS[@]}"; do
        log_info "Deploying to $cluster..."

        # Create a namespace
        kubectl --context "$cluster" create namespace holocron-test || true

        # Deploy a simple app
        kubectl --context "$cluster" apply -n holocron-test -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: holocron-config
data:
  cluster_name: CLUSTER_NAME_PLACEHOLDER
  environment: test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: holocron-test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: holocron-test
  template:
    metadata:
      labels:
        app: holocron-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: holocron-test-svc
spec:
  selector:
    app: holocron-test
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

        # Update the configmap with actual cluster name
        kubectl --context "$cluster" -n holocron-test \
            patch configmap holocron-config \
            --type merge \
            -p "{\"data\":{\"cluster_name\":\"$cluster\"}}"

        log_success "Resources deployed to $cluster"
    done
}

# ============================================================================
# Cleanup
# ============================================================================

cleanup_clusters() {
    log_warn "This will delete ALL Holocron test clusters!"
    read -p "$(echo -e ${YELLOW}[?]${NC} Are you sure? \(y/n\): )" confirm

    if [[ "$confirm" != "y" ]]; then
        log_info "Cleanup cancelled"
        return
    fi

    for cluster in "${CLUSTERS[@]}"; do
        if minikube profile list 2>/dev/null | grep -q "$cluster"; then
            log_info "Deleting cluster: $cluster"
            minikube delete -p "$cluster"
            log_success "Deleted: $cluster"
        else
            log_warn "Cluster not found: $cluster"
        fi
    done

    log_success "Cleanup complete!"
}

# ============================================================================
# Information Display
# ============================================================================

display_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Minikube test contexts are ready!"
    echo ""
    echo "Available contexts:"
    for cluster in "${CLUSTERS[@]}"; do
        echo "  - $cluster"
    done
    echo ""
    echo "Test your contexts:"
    echo "  kubectl config get-contexts"
    echo "  kubectl --context holocron-prod get nodes"
    echo "  kubectl --context holocron-dev get pods -n holocron-test"
    echo ""
    echo "Use with k9s:"
    echo "  k9s --context holocron-prod"
    echo "  k9s --context holocron-dev"
    echo "  k9s --context holocron-ray"
    echo ""
    echo "Configure Holocron to use these contexts:"
    echo "  Run: holocron config"
    echo "  Or edit: ~/.config/holocron/config.yaml"
    echo ""
    echo "Example configuration:"
    echo "  kubernetes:"
    echo "    context1:"
    echo "      name: \"Prod EKS\""
    echo "      context: \"holocron-prod\""
    echo "    context2:"
    echo "      name: \"Dev EKS\""
    echo "      context: \"holocron-dev\""
    echo "    context3:"
    echo "      name: \"Ray EKS\""
    echo "      context: \"holocron-ray\""
    echo ""
    echo "To delete these test clusters:"
    echo "  ./src/scripts/create-minikube-contexts.sh cleanup"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_header

    case "${1:-create}" in
        create)
            check_dependencies

            echo ""
            log_info "Creating 3 Minikube clusters for Holocron testing..."
            echo ""

            for cluster in "${CLUSTERS[@]}"; do
                create_cluster "$cluster"
                echo ""
            done

            verify_contexts
            echo ""

            log_info "Deploying sample resources..."
            deploy_sample_resources

            display_info
            ;;

        cleanup)
            cleanup_clusters
            ;;

        status)
            log_info "Checking cluster status..."
            for cluster in "${CLUSTERS[@]}"; do
                if minikube profile list 2>/dev/null | grep -q "$cluster"; then
                    status=$(minikube status -p "$cluster" --format='{{.Host}}' 2>/dev/null || echo "Unknown")
                    log_info "$cluster: $status"
                else
                    log_warn "$cluster: Not found"
                fi
            done
            ;;

        *)
            echo "Usage: $0 {create|cleanup|status}"
            echo ""
            echo "Commands:"
            echo "  create   - Create 3 minikube test clusters (default)"
            echo "  cleanup  - Delete all test clusters"
            echo "  status   - Show cluster status"
            ;;
    esac
}

main "$@"
