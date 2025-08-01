#!/bin/bash

# Script to generate Kubernetes secrets from .env file
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Please copy .env.example to .env and fill in your values:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your actual values"
    exit 1
fi

# Load environment variables from .env file
export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)

# Validate required variables
required_vars=(
    "PATHFINDER_ETHEREUM_API_URL"
    "VALIDATOR_A_REMOTE_SIGNER_URL" 
    "VALIDATOR_A_OPERATIONAL_PRIVATE_KEY"
    "VALIDATOR_B_REMOTE_SIGNER_URL"
    "VALIDATOR_B_OPERATIONAL_PRIVATE_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Error: Missing required environment variables in .env file:"
    printf '  %s\n' "${missing_vars[@]}"
    exit 1
fi

echo "Generating Kubernetes secrets from .env file..."

# Create namespace if it doesn't exist
kubectl create namespace starknet-node --dry-run=client -o yaml | kubectl apply -f -

# Generate pathfinder secret
kubectl create secret generic pathfinder-secrets \
    --namespace=starknet-node \
    --from-literal=PATHFINDER_ETHEREUM_API_URL="$PATHFINDER_ETHEREUM_API_URL" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --from-literal=PATHFINDER_LOG_LEVEL="${PATHFINDER_LOG_LEVEL:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Generate validator-a secret
kubectl create secret generic suffix-validator-secrets \
    --namespace=starknet-node \
    --from-literal=REMOTE_SIGNER_URL="$VALIDATOR_A_REMOTE_SIGNER_URL" \
    --from-literal=OPERATIONAL_PRIVATE_KEY="$VALIDATOR_A_OPERATIONAL_PRIVATE_KEY" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Generate validator-b secret  
kubectl create secret generic ethchi-validator-secrets \
    --namespace=starknet-node \
    --from-literal=REMOTE_SIGNER_URL="$VALIDATOR_B_REMOTE_SIGNER_URL" \
    --from-literal=OPERATIONAL_PRIVATE_KEY="$VALIDATOR_B_OPERATIONAL_PRIVATE_KEY" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Successfully generated Kubernetes secrets from .env file"
echo ""
echo "Created secrets:"
echo "  - pathfinder-secrets (contains Ethereum API URL)"
echo "  - suffix-validator-secrets (Suffix Validator - contains signer URL and private key)"
echo "  - ethchi-validator-secrets (Ethchi Validator - contains signer URL and private key)"
echo ""
echo "You can now deploy the applications with: ./deploy.sh"