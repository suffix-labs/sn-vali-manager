# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StarkNet Multi-Validator Node Manager - a Kubernetes-based infrastructure for running StarkNet validator nodes with multi-tenant monitoring. Manages a shared Pathfinder full node with multiple validators (Suffix and Ethchi), each with isolated monitoring dashboards.

## Common Commands

### Deployment
```bash
./deploy.sh                    # Full deployment (creates secrets + applies manifests)
./deploy.sh --skip-secrets     # Deploy without recreating secrets
./scripts/create-secrets.sh    # Create Kubernetes secrets from .env file
```

### Kubernetes Operations
```bash
kubectl apply -k k8s/                          # Apply all manifests via Kustomize
kubectl get pods -n starknet-node              # Check pod status
kubectl logs -n starknet-node deployment/NAME  # View logs
kubectl top pods -n starknet-node              # Check resource usage
```

### Service Access (Port Forwarding)
```bash
kubectl port-forward -n starknet-node svc/grafana-admin-service 3000:3000    # Admin dashboard
kubectl port-forward -n starknet-node svc/prometheus-service 9090:9090        # Prometheus
kubectl port-forward -n starknet-node svc/pathfinder-service 9545:9545        # Pathfinder RPC
```

## Architecture

```
                    StarkNet Network (Ethereum WebSocket API)
                                    │
                    ┌───────────────▼───────────────┐
                    │    Pathfinder Full Node       │
                    │    (Port 9545 RPC, 9546 metrics)
                    │    300GB storage              │
                    └───────┬───────────────┬───────┘
                            │               │
                ┌───────────▼───┐   ┌───────▼───────────┐
                │ Suffix Vali   │   │ Ethchi Vali       │
                │ (Port 9090)   │   │ (Port 9091)       │
                │ Local Signing │   │ Local Signing     │
                └───────┬───────┘   └───────┬───────────┘
                        │                   │
                ┌───────▼───────────────────▼───────┐
                │         Prometheus (9090)         │
                │    Centralized Metrics, 20GB      │
                └───┬───────────┬───────────┬───────┘
                    │           │           │
             ┌──────▼──┐  ┌─────▼────┐  ┌───▼──────┐
             │ Grafana │  │ Grafana  │  │ Grafana  │
             │ Admin   │  │ Suffix   │  │ Ethchi   │
             │ :3000   │  │ :3001    │  │ :3002    │
             └─────────┘  └──────────┘  └──────────┘
                    │           │           │
                    └───────────┴───────────┘
                                │
                    ┌───────────▼───────────┐
                    │   Nginx Reverse Proxy │
                    │       (Port 80)       │
                    └───────────────────────┘
```

**Key Connections:**
- Validators connect to Pathfinder via HTTP RPC: `http://pathfinder-service:9545/rpc/v0_8`
- All Grafana instances query Prometheus: `http://prometheus-service:9090`
- Prometheus scrapes metrics at 15-30 second intervals with Kubernetes service discovery

## Key Files

| File | Purpose |
|------|---------|
| `deploy.sh` | Main deployment orchestration script |
| `scripts/create-secrets.sh` | Creates Kubernetes secrets from .env |
| `k8s/kustomization.yaml` | Kustomize base defining namespace `starknet-node` |
| `k8s/pathfinder-deployment.yaml` | Shared StarkNet full node (Rust) |
| `k8s/suffix-validator-deployment.yaml` | Suffix validator with local signing |
| `k8s/ethchi-validator-deployment.yaml` | Ethchi validator with local signing |
| `k8s/prometheus-config.yaml` | Prometheus scrape configuration and deployment |
| `k8s/prometheus-rules.yaml` | Alerting rules for outages and sync issues |
| `k8s/alertmanager-config.yaml` | Alertmanager with Telegram webhook |
| `k8s/telegram-daily-summary.yaml` | CronJob for daily status report at 8 AM Eastern |
| `k8s/grafana-admin-deployment.yaml` | Admin dashboard (full access) |
| `k8s/grafana-client-deployments.yaml` | Per-validator client dashboards |
| `k8s/nginx-reverse-proxy.yaml` | Domain routing (admin/suffix/ethchi.suffixlabs.xyz) |

## Configuration

**Required:** Copy `.env.example` to `.env` and set these variables:
- `PATHFINDER_ETHEREUM_API_URL` - Ethereum WebSocket endpoint
- `SUFFIX_VALIDATOR_ADDRESS` - Suffix validator StarkNet address
- `SUFFIX_VALIDATOR_PRIVATE_KEY` - Suffix validator signing key
- `ETHCHI_VALIDATOR_ADDRESS` - Ethchi validator StarkNet address
- `ETHCHI_VALIDATOR_PRIVATE_KEY` - Ethchi validator signing key

Private keys are stored as Kubernetes secrets and never committed to git.

**Optional - Telegram Notifications:**
- `TELEGRAM_BOT_TOKEN` - Bot token from @BotFather
- `TELEGRAM_CHAT_ID` - Your chat ID (get via Telegram API after messaging the bot)

When configured, you get:
- Real-time alerts for validator/node outages and sync issues (via Alertmanager)
- Daily summary at 8 AM Eastern with sync status, uptime, and performance metrics

## Adding a New Validator

1. Create a new deployment YAML based on existing validator deployments
2. Add corresponding secret variables to `.env.example` and `.env`
3. Update `scripts/create-secrets.sh` to create the new secrets
4. Add Prometheus scrape targets in `k8s/prometheus-config.yaml`
5. Create Grafana client dashboard in `k8s/grafana-client-deployments.yaml` and `k8s/grafana-client-configs.yaml`
6. Add the new resources to `k8s/kustomization.yaml`
7. Update Nginx config in `k8s/nginx-reverse-proxy.yaml` if domain routing needed
