#!/bin/bash

# Create Kubernetes secrets from .env file
# This script provides secure secret management without external dependencies
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
NAMESPACE="starknet-node"

echo -e "${BLUE}🔐 Creating Kubernetes secrets from .env file${NC}"
echo ""

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}❌ Error: .env file not found at $ENV_FILE${NC}"
    echo ""
    echo "Please create your .env file first:"
    echo -e "${YELLOW}  cp .env.example .env${NC}"
    echo -e "${YELLOW}  # Edit .env with your actual API keys and private keys${NC}"
    echo ""
    exit 1
fi

# Load environment variables from .env file
echo -e "${BLUE}📄 Loading environment variables from .env...${NC}"
set -a  # Export all variables
source "$ENV_FILE"
set +a  # Stop exporting

# Validate required variables
echo -e "${BLUE}✅ Validating required environment variables...${NC}"

required_vars=(
    "PATHFINDER_ETHEREUM_API_URL"
    "VALIDATOR_A_OPERATIONAL_PRIVATE_KEY"
    "VALIDATOR_B_OPERATIONAL_PRIVATE_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    elif [[ "${!var}" == *"YOUR_"* ]] || [[ "${!var}" == *"your-"* ]]; then
        missing_vars+=("$var (contains placeholder value)")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Error: Missing or placeholder values found in .env file:${NC}"
    printf '  %s\n' "${missing_vars[@]}"
    echo ""
    echo "Please edit your .env file and set real values for all variables."
    exit 1
fi

# Validate private keys format (basic check)
for validator in "A" "B"; do
    var_name="VALIDATOR_${validator}_OPERATIONAL_PRIVATE_KEY"
    private_key="${!var_name}"
    
    # Remove 0x prefix if present for validation
    clean_key="${private_key#0x}"
    
    if [[ ! "$clean_key" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo -e "${YELLOW}⚠️  Warning: ${var_name} doesn't look like a valid 64-character hex private key${NC}"
    fi
done

echo -e "${GREEN}✅ All required variables validated${NC}"
echo ""

# Create namespace if it doesn't exist
echo -e "${BLUE}🏗️  Creating namespace '$NAMESPACE' if needed...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo -e "${BLUE}🔑 Creating Kubernetes secrets...${NC}"

# Generate pathfinder secret
kubectl create secret generic pathfinder-secrets \
    --namespace="$NAMESPACE" \
    --from-literal=PATHFINDER_ETHEREUM_API_URL="$PATHFINDER_ETHEREUM_API_URL" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --from-literal=PATHFINDER_LOG_LEVEL="${PATHFINDER_LOG_LEVEL:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}  ✓ pathfinder-secrets created${NC}"

# Generate validator-a secret
kubectl create secret generic validator-a-secrets \
    --namespace="$NAMESPACE" \
    --from-literal=OPERATIONAL_PRIVATE_KEY="$VALIDATOR_A_OPERATIONAL_PRIVATE_KEY" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}  ✓ validator-a-secrets created${NC}"

# Generate validator-b secret  
kubectl create secret generic validator-b-secrets \
    --namespace="$NAMESPACE" \
    --from-literal=OPERATIONAL_PRIVATE_KEY="$VALIDATOR_B_OPERATIONAL_PRIVATE_KEY" \
    --from-literal=RUST_LOG="${RUST_LOG:-info}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}  ✓ validator-b-secrets created${NC}"

echo ""
echo -e "${GREEN}🎉 Successfully created all Kubernetes secrets!${NC}"
echo ""
echo -e "${BLUE}📋 Created secrets in namespace '$NAMESPACE':${NC}"
echo "  • pathfinder-secrets (Ethereum API access)"
echo "  • validator-a-secrets (Validator A private key for local signing)"  
echo "  • validator-b-secrets (Validator B private key for local signing)"
echo ""
echo -e "${BLUE}🔍 You can verify the secrets were created with:${NC}"
echo -e "${YELLOW}  kubectl get secrets -n $NAMESPACE${NC}"
echo ""
echo -e "${BLUE}⚠️  Security reminders:${NC}"
echo "  • Never commit .env files to version control"
echo "  • Regularly rotate your private keys and API keys"
echo "  • Monitor access to your Kubernetes cluster"
echo ""
echo -e "${GREEN}✅ Ready to deploy applications with: ./deploy.sh${NC}"