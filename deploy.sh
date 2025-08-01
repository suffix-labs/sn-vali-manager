#!/bin/bash

# Create namespace
kubectl create namespace starknet-node --dry-run=client -o yaml | kubectl apply -f -

# Deploy all resources
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
echo "Configuration required:"
echo "1. Update pathfinder-deployment.yaml:"
echo "   - PATHFINDER_ETHEREUM_API_URL"
echo "2. Update validator secrets:"
echo "   - validator-attestation-deployment.yaml (Validator A)"
echo "   - validator-b-deployment.yaml (Validator B)"
echo "   Both need REMOTE_SIGNER_URL and OPERATIONAL_PRIVATE_KEY"