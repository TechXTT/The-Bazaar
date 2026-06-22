# Build Progress — Vault Redesign + Improvement Plan

> Tracks every `IMPROVEMENT_PLAN.md` item ID and every redesign screen.
> Status: ☐ not started · ◐ in progress · ☑ done · ⊘ deferred (with reason).
> Each completed item links the commit/PR that addressed it.

## Phase 0 — Baseline & safety net

- ☑ Workspace confirmed: `Claude/Projects/The-Bazaar` @ `feature/shipment-escrow` (see DECISIONS.md #1)
- ☑ Specs committed in-repo (`docs:` commit `8401592`) — also satisfies **INFRA-2**
- ☑ Baseline builds/tests **green**:
  - Backend: `go build/vet/test` exit 0 (only `services/jwt` has tests → confirms BE-11)
  - Contract: install/compile/test exit 0 — **65 passing**
  - Frontend: `tsc --noEmit` clean, `lint` warnings-only, `pnpm build` exit 0
- ☑ Working branches created: backend/contract `fix/improvement-plan`, frontend `feat/vault-redesign`

## Improvement plan items

### Smart contract (`bazaar-contract`)
- ☐ SC-1 — Dispute can block shipment / force refund (🟠 High, M)
- ☐ SC-2 — `rule()` unverified disputeID→order mapping (🟠 High, S)
- ☐ SC-3 — Fee not snapshotted per order (🟡 Med, S)
- ☐ SC-4 — No emergency fund recovery (🟡 Med, M)
- ☐ SC-5 — Single-EOA owner, no transfer/timelock (🟡 Med, S)
- ☐ SC-6 — Settlement bricked by reverting recipient (🟡 Med, M)
- ☐ SC-7 — Fee-on-transfer token not handled (🟡 Med, S)
- ☐ SC-8…SC-11 — Lower-severity hardening (🟢 Low)
- ☐ SC test gaps — unpause, ship/dispute/reclaim, rule wrong-ID, reverting recipient, fee snapshot, batch revert

### Backend (`bazaar-backend`)
- ☐ BE-1 — Wildcard CORS + credentials (🔴 Critical, S)
- ☐ BE-2 — Observer panics on malformed logs (🟠 High, S)
- ☐ BE-3 — No graceful shutdown / cancellable contexts (🟠 High, M)
- ☐ BE-4 — Order creation has no DB transaction (🟠 High, S)
- ☐ BE-5 — Upload path traversal + content-type (🟠 High, M)
- ☐ BE-6 — No rate limiting (🟠 High, M)
- ☐ BE-7 — Duplicate/drifted GORM models (🟠 High, M)
- ☐ BE-8 — Observer swallows DB errors (🟠 High, M)
- ☐ BE-9 — Orders never leave `disputed` (🟡 Med, M)
- ☐ BE-10 — `GetOrders` no pagination (🟡 Med, M)
- ☐ BE-11 — Backend test suite (🟡 Med, L)
- ☐ BE-12 — Malformed gorm unique tags (🟡 Med, S)
- ☐ BE-13 — Soft-delete vs unique wallet (🟡 Med, M)
- ☐ BE-14 — Versioned migrations (🟡 Med, M)
- ☐ BE-15 — Readiness/metrics/structured logs (🟡 Med, M)
- ☐ BE-16 — JWT hardening (🟡 Med, M)
- ☐ BE-17 — Identity via context not headers (🟡 Med, S)
- ☐ BE-18 — Integer money types (🟡 Med, L)
- ☐ BE-19 — Bounded Algolia worker (🟢 Low, M)
- ☐ BE-20 — Fail-fast config validation (🟢 Low, S)
- ☐ BE-21 — Don't leak raw errors to clients (🟢 Low, S)

### Frontend (`bazaar-frontend`)
- ☐ FE-1 — Multi-order checkout partial-failure recovery (🟠 High money, L)
- ☐ FE-2 — Checkout positional correlation (🟠 High money, M)
- ☐ FE-3 — ETH/USDC price denomination (🔴 Critical money, M)
- ☐ FE-4 — JWT in localStorage (🟠 High, M)
- ☐ FE-5 — E2E wallet fixture ABI desync (🟠 High, S)
- ☐ FE-6 — Server Components + metadata/SEO (🟡 Med, L)
- ☐ FE-7 — `next/image` + CDN whitelist (🟡 Med, M)
- ☐ FE-8 — GA ID to env (🟡 Med, S)
- ☐ FE-9 — Broken `react` dep + dead deps (🟡 Med, S)
- ☐ FE-10 — Duplicate Footer components (🟢 Low, S)
- ☐ FE-11 — PersistGate / auth bootstrap flash (🟢 Low, M)
- ☐ FE-12 — Type `_createOrders` + zod (🟢 Low, S)
- ☐ FE-13 — `messageToBytes32` early validation (🟢 Low, S)
- ☐ FE-14 — A11y pass (🟢 Low, M)
- ☐ FE-15 — Remove client-set CORS request headers (🟢 Low, S)

### Infra / CI / cross-layer (`root`)
- ☐ INFRA-1 — Prod Dockerfiles + CD + split compose (🟠 High, L)
- ☑ INFRA-2 — Commit untracked docs (done in Phase 0 `docs:` commit)
- ☐ INFRA-3 — Expand `.gitignore`, clean tree (🟡 Med, S)
- ☐ INFRA-4 — Merge to `main` across repos (🟡 Med, M) — *requires shared-branch push; see DECISIONS*
- ☐ INFRA-5 — Compose secrets/healthchecks (🟡 Med, M)
- ☐ SEC-1 — Sanitize example env (🟡 Med, S)
- ☐ SEC-2 — GA ID (= FE-8) (🟢 Low, S)
- ☐ CI-1 — Lint/audit/secret-scan/Slither (🟡 Med, M)
- ☐ DEP-1 — Upgrade Next off 13.5.4 + fix react dep (🟡 Med, M)
- ☐ DEP-2 — One package manager + Go version align (🟢 Low, S)
- ☐ DOC-1 — Real README + architecture/deploy docs (🟡 Med, M)
- ☐ XL-1 — Single OrderStatus source + typed FE enum (🟡 Med, M)
- ☐ XL-2 — FE interfaces drift from Go structs (🟢 Low, S)

## Vault redesign screens

### Foundation / component library
- ☐ Design tokens (CSS vars + tailwind.config.ts)
- ☐ Button · StatusBadge (6 states) · Input/Field · Textarea · Badge · Card
- ☐ ProductCard · StoreCard · Navbar · Footer · SellerSidebar
- ☐ Skeleton · Spinner · escrow Stepper · segmented token toggle · switch

### Screens
- ☐ Home · Stores · Store detail · Product detail
- ☐ Cart · Checkout · Orders · Order detail/tracking
- ☐ Wallet connect (SIWE) · Seller dashboard · Seller orders
- ☐ Product editor · Account settings · Dispute detail
- ☐ Empty/loading/error states · Mobile/responsive (Home, Product, 404, skeleton)
