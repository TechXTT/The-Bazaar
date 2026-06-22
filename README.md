# The Bazaar

A decentralized marketplace where buyer payments are held in an **on-chain escrow**
until orders are fulfilled. The Bazaar is a git-submodule **superproject** that
stitches together three independently-versioned repositories plus an off-chain
**observer** that mirrors on-chain escrow state into the application database.

## Architecture

The system is composed of three submodules and one on-chain contract:

| Component | Submodule | Stack | Responsibility |
|---|---|---|---|
| **Backend** | [`bazaar-backend`](bazaar-backend) | Go (1.21) | REST API, Postgres persistence, JWT auth, file uploads, and the chain **observer** that subscribes to escrow events and updates order state. |
| **Frontend** | [`bazaar-frontend`](bazaar-frontend) | Next.js / React / Redux Toolkit | Storefront, seller dashboard, wallet integration, and escrow interactions. |
| **Contract** | [`bazaar-contract`](bazaar-contract) | Solidity / Hardhat | The `Escrow` smart contract: holds funds, handles release/claim/refund, emits the events the observer consumes. |

The **ABI is the contract between layers** and is kept byte-identical across all
three (`bazaar-contract` artifact ↔ `bazaar-backend/Escrow.json` ↔
`bazaar-frontend/escrow_abi.ts`); CI enforces this via the `abi-sync` job.

```
            ┌──────────────┐         ┌──────────────┐
            │   Frontend   │  REST   │   Backend    │
            │  (Next.js)   │────────▶│    (Go)      │
            └──────┬───────┘         └──────┬───────┘
                   │ wallet                 │ observer (ws events)
                   ▼                        ▼
            ┌─────────────────────────────────────┐
            │        Escrow contract (chain)        │
            └─────────────────────────────────────┘
                   ▲                        │
                   └── buyer funds escrow   └── events: Released / Completed / Refunded
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full component diagram
and the data/event flow, and [`DESIGN.md`](DESIGN.md) for the order lifecycle.

## Getting started

This repo uses git submodules, so clone **recursively**:

```bash
git clone --recurse-submodules <repo-url>
# or, if you already cloned without --recurse-submodules:
git submodule update --init --recursive
```

### Run the full stack locally

The stack runs via Docker Compose (Postgres + a local Hardhat node + contract
deploy + backend + frontend). Copy the env template and start:

```bash
cp .env.example .env      # then edit POSTGRES_PASSWORD etc.
make local-up             # base compose + dev override (source mounts, hot reload)
```

`make local-up` is shorthand for:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

Then open <http://localhost:3000>. Other Make targets: `local-down`, `local-logs`,
`local-reset` (drops volumes), and `prod-config` (validates the production-shaped
base compose). Full walkthrough — including MetaMask network setup — lives in
[`LOCAL_RUN.md`](LOCAL_RUN.md).

The base `docker-compose.yml` is **production-shaped** (built images, no source
mounts, secrets from `.env`, healthcheck-gated startup); `docker-compose.dev.yml`
layers the development overrides on top.

## Documentation

- [`IMPROVEMENT_PLAN.md`](IMPROVEMENT_PLAN.md) — prioritized backlog across all layers.
- [`DESIGN.md`](DESIGN.md) — order lifecycle / state mapping across contract, observer, and DB.
- [`LOCAL_RUN.md`](LOCAL_RUN.md) — local run + wallet setup.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — component diagram + data/event flow.
- [`docs/DEPLOY.md`](docs/DEPLOY.md) — deploy runbook.
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — branch model, submodule workflow, commit conventions.

## License

See [`LICENSE`](LICENSE).
