# StarkNet Multi-Validator Node Kubernetes Deployment

This repository contains Kubernetes manifests for deploying a complete StarkNet node setup with multi-tenant monitoring for two validators.

## Architecture

- **Single Pathfinder Node**: Shared StarkNet full node providing RPC access
- **Dual Validator Attestation**: Two separate validator attestation services with local signing
- **Multi-Tier Monitoring**: 
  - Admin dashboard (full access to all metrics)
  - Client dashboards (per-validator isolated monitoring)
- **Prometheus**: Centralized metrics collection
- **Grafana**: Three separate instances for role-based access

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured
- At least 8GB RAM and 4 CPU cores available
- 150GB+ storage for persistent volumes

## Configuration

Configure your secrets using environment variables (recommended approach):

### 1. Create Environment File
```bash
# Copy the template and edit with your actual values
cp .env.example .env

# Edit .env with your API keys and private keys
# NEVER commit .env files to version control!
```

### 2. Required Environment Variables
Edit `.env` file with your actual values:

```bash
# Pathfinder Node - Ethereum WebSocket access
PATHFINDER_ETHEREUM_API_URL=wss://eth-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_API_KEY

# Validator A - Company 1 (Local Signing)
VALIDATOR_A_OPERATIONAL_PRIVATE_KEY=0xYOUR_ACTUAL_PRIVATE_KEY

# Validator B - Company 2 (Local Signing)
VALIDATOR_B_OPERATIONAL_PRIVATE_KEY=0xYOUR_ACTUAL_PRIVATE_KEY

# Optional logging configuration
RUST_LOG=info
```

### 3. Security Notes
- ✅ **Local signing**: Private keys stored securely in Kubernetes secrets  
- ✅ **No remote dependencies**: Validators sign transactions locally
- ✅ **Secrets isolation**: Each validator has separate private key storage
- ✅ **Environment protection**: `.env` file is gitignored (never committed)
- ✅ **Validation**: Script validates all required variables before deployment
- ⚠️ **Key security**: Keep your `.env` file and private keys secure and backed up

## Deployment

### Quick Deploy (Recommended)
```bash
# 1. Configure your secrets
cp .env.example .env
# Edit .env with your actual API keys and private keys

# 2. Deploy everything
./deploy.sh
```

### Manual Steps (If Needed)
```bash
# Create secrets from .env file
./scripts/create-secrets.sh

# Deploy applications (skip secret creation)
./deploy.sh --skip-secrets
```

### Deployment Options
```bash
# Deploy with secret creation (default)
./deploy.sh

# Deploy without recreating secrets (for updates)
./deploy.sh --skip-secrets

# Show help
./deploy.sh --help
```

## Access Services

### Admin Access (Full Monitoring)
```bash
# Admin Grafana - See all validators and node metrics
kubectl port-forward -n starknet-node svc/grafana-admin-service 3000:3000
# Credentials: admin/admin123

# Prometheus - Raw metrics access
kubectl port-forward -n starknet-node svc/prometheus-service 9090:9090

# Pathfinder RPC - Node API access
kubectl port-forward -n starknet-node svc/pathfinder-service 9545:9545
```

### Client Access (Per-Validator Monitoring)
```bash
# Validator A Client Dashboard
kubectl port-forward -n starknet-node svc/grafana-validator-a-service 3001:3001
# Credentials: admin/validator-a-pass123 OR anonymous viewer access

# Validator B Client Dashboard  
kubectl port-forward -n starknet-node svc/grafana-validator-b-service 3002:3002
# Credentials: admin/validator-b-pass123 OR anonymous viewer access
```

### Load Balancer Access (if available)
```bash
# Get external IPs for Grafana services
kubectl get svc -n starknet-node -l grafana-tier
```

## Monitoring

### Dashboard Overview

#### Admin Dashboard (Port 3000)
Complete operational overview for node operator:
- Pathfinder node health and status
- Both validator statuses (A & B)
- Combined CPU/memory usage across all services
- Attestation counts per validator
- Network block height

#### Validator A Dashboard (Port 3001)
Client-specific view showing only:
- Shared pathfinder node health (dependency status)
- Validator A's specific metrics and performance
- Validator A's attestation activity
- Current network state

#### Validator B Dashboard (Port 3002)
Client-specific view showing only:
- Shared pathfinder node health (dependency status)
- Validator B's specific metrics and performance
- Validator B's attestation activity
- Current network state

### Prometheus Targets
- **Admin URL**: http://localhost:9090
- **Targets**: pathfinder, validator-a (port 9090), validator-b (port 9091)
- Check all targets at: http://localhost:9090/targets

## Scaling & Resource Management

### Validator Scaling
Each validator runs independently and can be scaled separately:
```bash
# Scale individual validators
kubectl scale -n starknet-node deployment/validator-a --replicas=1
kubectl scale -n starknet-node deployment/validator-b --replicas=1

# Pathfinder should remain single instance (shared state)
kubectl scale -n starknet-node deployment/pathfinder --replicas=1
```

### Resource Adjustment
Current resource allocations:
- **Pathfinder**: 2-4GB RAM, 0.5-2 CPU
- **Each Validator**: 256-512MB RAM, 0.1-0.5 CPU  
- **Admin Grafana**: 256-512MB RAM, 0.1-0.5 CPU
- **Client Grafanas**: 128-256MB RAM, 0.05-0.2 CPU each

## Storage

Persistent volumes are configured for:
- Pathfinder data: 100GB
- Prometheus data: 20GB  
- Grafana data: 5GB

### Backup
```bash
# Backup Pathfinder data
kubectl exec -n starknet-node deployment/pathfinder -- tar czf - /usr/share/pathfinder/data > pathfinder-backup.tar.gz
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n starknet-node
kubectl logs -n starknet-node deployment/pathfinder
```

### Common Issues

1. **Pathfinder not syncing**: Check Ethereum API URL configuration
2. **Validator attestation failing**: Verify signer URL and private key
3. **Prometheus not scraping**: Check service discovery and annotations

### Debug Commands
```bash
# Check all services
kubectl get svc -n starknet-node

# Check validator-specific pods
kubectl get pods -n starknet-node -l validator=validator-a
kubectl get pods -n starknet-node -l validator=validator-b

# Check persistent volumes
kubectl get pv,pvc -n starknet-node

# View resource usage
kubectl top pods -n starknet-node

# Check validator logs
kubectl logs -n starknet-node deployment/validator-a
kubectl logs -n starknet-node deployment/validator-b
```

## Security Best Practices

### Secret Management
- ✅ **Never commit `.env` files** to version control (enforced by .gitignore)
- ✅ **Rotate secrets regularly** - Update .env and re-run `./scripts/create-secrets.sh`
- ✅ **Backup .env securely** - Store encrypted backups of your .env file
- ✅ **Limit access** - Only authorized personnel should have access to .env files
- ✅ **Monitor usage** - Watch for unauthorized access to your validator accounts

### Kubernetes Security
- Use RBAC for service account permissions
- Consider network policies for pod-to-pod communication
- Regular backup of persistent data
- Monitor resource usage and pod health

### Operational Security
- Keep Kubernetes cluster updated
- Monitor validator performance and attestation success rates
- Set up alerts for validator downtime or errors
- Regularly audit who has access to the cluster and secrets

## Updates

Update container images:
```bash
# Update pathfinder (affects both validators)
kubectl set image -n starknet-node deployment/pathfinder pathfinder=eqlabs/pathfinder:v0.x.x

# Update individual validators
kubectl set image -n starknet-node deployment/validator-a validator-attestation=ghcr.io/eqlabs/starknet-validator-attestation:latest
kubectl set image -n starknet-node deployment/validator-b validator-attestation=ghcr.io/eqlabs/starknet-validator-attestation:latest

# Update monitoring stack
kubectl set image -n starknet-node deployment/grafana-admin grafana=grafana/grafana:latest
kubectl set image -n starknet-node deployment/prometheus prometheus=prom/prometheus:latest
```

## Multi-Tenant Access Management

### For Clients
Provide clients with:
1. **Port forward command** for their specific validator dashboard
2. **Anonymous viewer access** (no login required) OR **unique credentials**
3. **Dashboard URL** showing only their validator's metrics

### Client Onboarding Example
```bash
# For Validator A client
echo "Access your validator dashboard:"
echo "kubectl port-forward -n starknet-node svc/grafana-validator-a-service 3001:3001" 
echo "Then visit http://localhost:3001 (no login required)"
```
