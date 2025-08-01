#!/bin/bash

# Production setup: Install and configure External Secrets Operator
set -e

NAMESPACE="external-secrets-system"
STARKNET_NAMESPACE="starknet-node"

echo "🚀 Setting up External Secrets Operator for production"

# Check if External Secrets Operator is already installed
if kubectl get deployment external-secrets -n $NAMESPACE >/dev/null 2>&1; then
    echo "✅ External Secrets Operator already installed"
else
    echo "📦 Installing External Secrets Operator..."
    
    # Install using Helm (preferred method)
    if command -v helm >/dev/null 2>&1; then
        echo "Using Helm to install External Secrets Operator..."
        helm repo add external-secrets https://charts.external-secrets.io
        helm repo update
        helm install external-secrets external-secrets/external-secrets \
            -n $NAMESPACE \
            --create-namespace \
            --wait \
            --set installCRDs=true
    else
        # Fallback to kubectl
        echo "Helm not found, using kubectl..."
        kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
        kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/charts/external-secrets/templates/rbac.yaml
        kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/charts/external-secrets/templates/deployment.yaml
    fi
    
    echo "⏳ Waiting for External Secrets Operator to be ready..."
    kubectl wait --for=condition=available deployment/external-secrets -n $NAMESPACE --timeout=300s
fi

# Create starknet namespace
kubectl create namespace $STARKNET_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "✅ External Secrets Operator setup complete"
echo ""
echo "🔧 Next steps to complete setup:"
echo ""
echo "1. Choose your secret backend and configure authentication:"
echo "   AWS Secrets Manager:"
echo "     - Create IAM role with SecretsManager permissions"
echo "     - Update secret-stores.yaml with your AWS region and role ARN"
echo ""
echo "   Google Secret Manager:"
echo "     - Create GCP service account with Secret Manager permissions"
echo "     - Update secret-stores.yaml with your project ID"
echo ""
echo "   Azure Key Vault:"
echo "     - Create managed identity with Key Vault permissions"
echo "     - Update secret-stores.yaml with your vault URL"
echo ""
echo "   HashiCorp Vault:"
echo "     - Configure Kubernetes auth method in Vault"
echo "     - Update secret-stores.yaml with your Vault URL and role"
echo ""
echo "2. Store your secrets in the chosen backend:"
echo "   - starknet/pathfinder: ethereum_api_url, rust_log"
echo "   - starknet/validator-a: remote_signer_url, operational_private_key, rust_log"
echo "   - starknet/validator-b: remote_signer_url, operational_private_key, rust_log"
echo ""
echo "3. Apply the secret store configuration:"
echo "   kubectl apply -f k8s/secret-stores.yaml"
echo ""
echo "4. Apply the external secrets:"
echo "   kubectl apply -f k8s/external-secrets.yaml"
echo ""
echo "5. Deploy the applications:"
echo "   ./deploy.sh"