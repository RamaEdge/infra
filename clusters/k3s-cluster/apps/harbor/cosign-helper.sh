#!/bin/bash

# Harbor Cosign Helper Script
# This script provides convenient commands for working with Cosign and Harbor

set -e

HARBOR_REGISTRY="harbor.theedgeworks.ai"
COSIGN_KEY_DIR="${HOME}/.cosign"
COSIGN_PRIVATE_KEY="${COSIGN_KEY_DIR}/cosign.key"
COSIGN_PUBLIC_KEY="${COSIGN_KEY_DIR}/cosign.pub"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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

# Check if cosign is installed
check_cosign() {
    if ! command -v cosign &> /dev/null; then
        log_error "Cosign is not installed. Please install it first."
        log_info "Installation instructions:"
        log_info "curl -O -L \"https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-arm64\""
        log_info "sudo mv cosign-linux-arm64 /usr/local/bin/cosign"
        log_info "sudo chmod +x /usr/local/bin/cosign"
        exit 1
    fi
    log_success "Cosign is installed: $(cosign version | head -1)"
}

# Setup Cosign keys
setup_keys() {
    log_info "Setting up Cosign keys..."
    
    # Create key directory
    mkdir -p "${COSIGN_KEY_DIR}"
    
    # Check if keys already exist
    if [[ -f "${COSIGN_PRIVATE_KEY}" && -f "${COSIGN_PUBLIC_KEY}" ]]; then
        log_warning "Keys already exist at ${COSIGN_KEY_DIR}"
        read -p "Do you want to generate new keys? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing keys"
            return 0
        fi
    fi
    
    # Generate new keys
    log_info "Generating new Cosign key pair..."
    cd "${COSIGN_KEY_DIR}"
    cosign generate-key-pair
    
    # Set proper permissions
    chmod 600 "${COSIGN_PRIVATE_KEY}"
    chmod 644 "${COSIGN_PUBLIC_KEY}"
    
    log_success "Keys generated successfully!"
    log_info "Private key: ${COSIGN_PRIVATE_KEY}"
    log_info "Public key: ${COSIGN_PUBLIC_KEY}"
    log_warning "Keep your private key secure and never share it!"
}

# Login to Harbor
login_harbor() {
    log_info "Logging in to Harbor..."
    docker login "${HARBOR_REGISTRY}"
    log_success "Logged in to Harbor successfully!"
}

# Sign an image
sign_image() {
    local image_tag="$1"
    
    if [[ -z "$image_tag" ]]; then
        log_error "Usage: $0 sign <project>/<image>:<tag>"
        log_info "Example: $0 sign myproject/myapp:v1.0.0"
        exit 1
    fi
    
    local full_image="${HARBOR_REGISTRY}/${image_tag}"
    
    # Check if image exists
    if ! docker manifest inspect "${full_image}" &> /dev/null; then
        log_error "Image ${full_image} not found in registry"
        exit 1
    fi
    
    # Check if keys exist
    if [[ ! -f "${COSIGN_PRIVATE_KEY}" ]]; then
        log_error "Private key not found at ${COSIGN_PRIVATE_KEY}"
        log_info "Run '$0 setup' to generate keys first"
        exit 1
    fi
    
    log_info "Signing image: ${full_image}"
    cosign sign --key "${COSIGN_PRIVATE_KEY}" "${full_image}"
    log_success "Image signed successfully!"
}

# Verify an image
verify_image() {
    local image_tag="$1"
    
    if [[ -z "$image_tag" ]]; then
        log_error "Usage: $0 verify <project>/<image>:<tag>"
        log_info "Example: $0 verify myproject/myapp:v1.0.0"
        exit 1
    fi
    
    local full_image="${HARBOR_REGISTRY}/${image_tag}"
    
    # Check if public key exists
    if [[ ! -f "${COSIGN_PUBLIC_KEY}" ]]; then
        log_error "Public key not found at ${COSIGN_PUBLIC_KEY}"
        log_info "Run '$0 setup' to generate keys first"
        exit 1
    fi
    
    log_info "Verifying image: ${full_image}"
    if cosign verify --key "${COSIGN_PUBLIC_KEY}" "${full_image}"; then
        log_success "Image verification successful!"
    else
        log_error "Image verification failed!"
        exit 1
    fi
}

# List signatures for an image
list_signatures() {
    local image_tag="$1"
    
    if [[ -z "$image_tag" ]]; then
        log_error "Usage: $0 list <project>/<image>:<tag>"
        log_info "Example: $0 list myproject/myapp:v1.0.0"
        exit 1
    fi
    
    local full_image="${HARBOR_REGISTRY}/${image_tag}"
    
    log_info "Listing signatures for: ${full_image}"
    cosign tree "${full_image}"
}

# Show public key
show_public_key() {
    if [[ ! -f "${COSIGN_PUBLIC_KEY}" ]]; then
        log_error "Public key not found at ${COSIGN_PUBLIC_KEY}"
        log_info "Run '$0 setup' to generate keys first"
        exit 1
    fi
    
    log_info "Public key content:"
    echo "----------------------------------------"
    cat "${COSIGN_PUBLIC_KEY}"
    echo "----------------------------------------"
    log_info "You can share this public key for verification"
}

# Create Kubernetes secrets for keys
create_k8s_secrets() {
    local namespace="${1:-harbor}"
    
    if [[ ! -f "${COSIGN_PRIVATE_KEY}" || ! -f "${COSIGN_PUBLIC_KEY}" ]]; then
        log_error "Keys not found. Run '$0 setup' first"
        exit 1
    fi
    
    log_info "Creating Kubernetes secrets in namespace: ${namespace}"
    
    # Create private key secret
    kubectl create secret generic cosign-private-key \
        --from-file=cosign.key="${COSIGN_PRIVATE_KEY}" \
        --namespace="${namespace}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create public key secret
    kubectl create secret generic cosign-public-key \
        --from-file=cosign.pub="${COSIGN_PUBLIC_KEY}" \
        --namespace="${namespace}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Kubernetes secrets created successfully!"
}

# Show help
show_help() {
    echo "Harbor Cosign Helper Script"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  setup                    - Generate Cosign key pair"
    echo "  login                    - Login to Harbor registry"
    echo "  sign <project>/<image>:<tag>     - Sign an image"
    echo "  verify <project>/<image>:<tag>   - Verify an image signature"
    echo "  list <project>/<image>:<tag>     - List signatures for an image"
    echo "  show-key                 - Display public key"
    echo "  create-secrets [namespace]       - Create Kubernetes secrets for keys"
    echo "  help                     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 login"
    echo "  $0 sign myproject/myapp:v1.0.0"
    echo "  $0 verify myproject/myapp:v1.0.0"
    echo "  $0 list myproject/myapp:v1.0.0"
    echo "  $0 create-secrets harbor"
    echo ""
    echo "Environment:"
    echo "  HARBOR_REGISTRY: ${HARBOR_REGISTRY}"
    echo "  COSIGN_KEY_DIR: ${COSIGN_KEY_DIR}"
}

# Main script logic
main() {
    check_cosign
    
    case "${1:-help}" in
        "setup")
            setup_keys
            ;;
        "login")
            login_harbor
            ;;
        "sign")
            sign_image "$2"
            ;;
        "verify")
            verify_image "$2"
            ;;
        "list")
            list_signatures "$2"
            ;;
        "show-key")
            show_public_key
            ;;
        "create-secrets")
            create_k8s_secrets "$2"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"
