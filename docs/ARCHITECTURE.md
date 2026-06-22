# Architecture

The Bazaar is a marketplace built around an on-chain **escrow**: buyer funds are
locked in the `Escrow` contract and only move (to seller or back to buyer) based
on explicit on-chain actions. An off-chain **observer** in the backend keeps the
application database in sync with on-chain state.

## Components

| Component | Submodule | Stack | Role |
|---|---|---|---|
| Backend | `bazaar-backend` | Go 1.21, Postgres | REST API, auth (JWT), uploads, and the chain observer. |
| Frontend | `bazaar-frontend` | Next.js / React / Redux Toolkit | UI, wallet integration, escrow calls. |
| Contract | `bazaar-contract` | Solidity / Hardhat | `Escrow` contract: escrow, release, claim, refund. |

The three layers share a single source of truth — the **Escrow ABI** — kept
byte-identical across all of them and enforced by the CI `abi-sync` job.

## Component diagram

```
                            ┌───────────────────────────┐
        browser  ◀────────▶ │        Frontend           │
                            │     (Next.js, Redux)      │
                            └──────┬───────────┬────────┘
                          REST API │           │ wallet (signed txs)
                                   ▼           ▼
                ┌───────────────────────┐   ┌───────────────────────────┐
                │       Backend (Go)     │   │   Escrow contract (EVM)   │
                │  ┌──────────────────┐  │   │  holds funds; release /   │
                │  │   HTTP / REST    │  │   │  claim / refund; emits    │
                │  ├──────────────────┤  │   │  events                   │
   Postgres ◀───┤  │  services/db     │  │   └────────────┬──────────────┘
                │  ├──────────────────┤  │                │ events (ws)
                │  │  observer        │◀─┼────────────────┘
                │  └──────────────────┘  │
                └───────────────────────┘
```

## Data & event flow

1. **Browse / order.** The frontend reads catalog/order data from the backend
   REST API (persisted in Postgres via `services/db`).
2. **Fund escrow.** To buy, the buyer's wallet signs a transaction directly
   against the `Escrow` contract, locking funds on-chain. The order is recorded
   in the backend with its on-chain references (contract order id, tx hash, etc.).
3. **Observe.** The backend **observer** subscribes (over a WebSocket RPC, e.g.
   `ws://hardhat:8545` locally) to escrow events and maps them onto order status:

   | Contract event | Order status |
   |---|---|
   | `OrderReleased` | `released` |
   | `OrderCompleted` | `completed` |
   | `OrderRefunded` | `cancelled` |

   See [`../DESIGN.md`](../DESIGN.md) for the full order lifecycle / state mapping.
4. **Settle.** On release time (or buyer approval) the seller claims escrow, or
   the seller refunds the buyer; the resulting event flows back through the
   observer to the DB and surfaces in the frontend.

## ABI sync invariant

`bazaar-contract` compiles the `Escrow` artifact; the same ABI is committed as
`bazaar-backend/Escrow.json` and `bazaar-frontend/escrow_abi.ts`. The CI
`abi-sync` job recompiles and byte-compares all three — any drift fails the
build. When the contract changes, regenerate and re-commit all three copies.

## Local topology

Locally everything runs under Docker Compose: a Hardhat node, a one-shot contract
deploy, Postgres, the backend, and the frontend. The production-shaped base
(`docker-compose.yml`) plus the dev override (`docker-compose.dev.yml`) define
this; see [`../LOCAL_RUN.md`](../LOCAL_RUN.md).
