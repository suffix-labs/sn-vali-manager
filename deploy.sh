#!/bin/bash

# Deploy StarkNet Multi-Validator Node Setup
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SKIP_SECRETS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-secrets)
            SKIP_SECRETS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-secrets    Skip secret creation (use existing secrets)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Normal workflow:"
            echo "  1. cp .env.example .env"
            echo "  2. Edit .env with your API keys and private keys"
            echo "  3. ./deploy.sh"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 Deploying StarkNet Multi-Validator Node Setup${NC}"
echo ""

# Create secrets from .env file (unless skipped)
if [[ "$SKIP_SECRETS" == "false" ]]; then
    echo -e "${BLUE}🔐 Creating secrets from .env file...${NC}"
    if [[ ! -f ".env" ]]; then
        echo -e "${RED}❌ Error: .env file not found${NC}"
        echo ""
        echo "Please create your .env file first:"
        echo -e "${YELLOW}  cp .env.example .env${NC}"
        echo -e "${YELLOW}  # Edit .env with your actual values${NC}"
        echo ""
        exit 1
    fi
    
    bash ./scripts/create-secrets.sh
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping secret creation (using existing secrets)${NC}"
    echo ""
fi

# Create namespace (create-secrets.sh also does this, but safe to repeat)
echo -e "${BLUE}🏗️  Creating namespace 'starknet-node'...${NC}"
kubectl create namespace starknet-node --dry-run=client -o yaml | kubectl apply -f -

# Deploy all resources
echo -e "${BLUE}📦 Deploying Kubernetes resources...${NC}"
kubectl apply -k k8s/

echo "Deployment complete. Services will be available at:"
echo ""
echo "Admin Access (Full monitoring):"
echo "- Admin Grafana: kubectl port-forward -n starknet-node svc/grafana-admin-service 3000:3000"
echo "- Prometheus: kubectl port-forward -n starknet-node svc/prometheus-service 9090:9090"
echo "- Pathfinder RPC: kubectl port-forward -n starknet-node svc/pathfinder-service 9545:9545"
echo ""
echo "Client Access (Per-validator monitoring):"
echo "- Validator A Grafana: kubectl port-forward -n starknet-node svc/grafana-validator-a-service 3001:3001"
echo "- Validator B Grafana: kubectl port-forward -n starknet-node svc/grafana-validator-b-service 3002:3002"
echo ""
echo "Credentials:"
echo "- Admin Grafana: admin/admin123"
echo "- Validator A Grafana: admin/validator-a-pass123 (or anonymous viewer access)"
echo "- Validator B Grafana: admin/validator-b-pass123 (or anonymous viewer access)"
echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Verify all pods are running: kubectl get pods -n starknet-node"
echo "2. Check logs if needed: kubectl logs -n starknet-node -l app=pathfinder"
echo "3. Access your dashboards using the port-forward commands above"
