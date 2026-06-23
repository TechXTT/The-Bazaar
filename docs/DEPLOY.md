# Deploy runbook

> **Status: stub.** A production CD pipeline and the per-component Dockerfiles
> (INFRA-1) are not yet in place. This document captures the intended deploy
> shape and the manual steps available today. Fill in concrete targets
> (registry, hosts, secrets store) as the pipeline lands.

## Prerequisites

- Per-component Dockerfiles in each submodule (INFRA-1):
  - `bazaar-backend/Dockerfile` — multi-stage Go → distroless.
  - `bazaar-frontend/Dockerfile` — `next build` → `next start` on slim node.
  - `bazaar-contract/Dockerfile` — Hardhat toolchain (node-deploy / chain ops).
- A populated, **gitignored** `.env` at the repo root (see `.env.example`).
  Secrets (`POSTGRES_PASSWORD`, JWT keys, SMTP, deployer key) must come from a
  secrets manager, never from a committed file.
- A reachable Postgres and an EVM RPC endpoint (mainnet/testnet or a managed node).

## Build images

The production-shaped base compose builds each service from its submodule context:

```bash
docker compose -f docker-compose.yml build
```

Tag and push to your registry (placeholder names):

```bash
docker tag bazaar-backend:latest  <registry>/bazaar-backend:<sha>
docker tag bazaar-frontend:latest <registry>/bazaar-frontend:<sha>
docker push <registry>/bazaar-backend:<sha>
docker push <registry>/bazaar-frontend:<sha>
```

## Validate config before deploy

```bash
cp .env.example .env   # populate from your secrets store
make prod-config       # docker compose -f docker-compose.yml config -q
```

## Contract deployment

1. Deploy / verify the `Escrow` contract to the target chain from
   `bazaar-contract` (Hardhat deploy scripts).
2. Record the deployed address and set `CONTRACT_ADDRESS` /
   `NEXT_PUBLIC_CONTRACT_ADDRESS` in the environment.
3. Ensure the backend `ETH_URL` points at a WebSocket-capable RPC so the observer
   can subscribe to events.

## Bring up the stack

With images pushed and `.env` populated, start the production-shaped stack
(healthcheck-gated; dependents wait for `service_healthy`):

```bash
docker compose -f docker-compose.yml up -d
```

Order of readiness: Postgres (`pg_isready`) → contract deploy → backend
(`/health`) → frontend.

## Rollback

Re-deploy the previous image tags and re-point `CONTRACT_ADDRESS` if a contract
re-deploy was involved. Postgres migrations should be backward compatible within
a release window; otherwise restore from backup.

## TODO (tracked in IMPROVEMENT_PLAN.md)

- INFRA-1: author the Dockerfiles and a CD workflow (build → push → deploy).
- Wire secrets from a managed store instead of a flat `.env`.
- Define environment-specific overlays (staging vs production).
