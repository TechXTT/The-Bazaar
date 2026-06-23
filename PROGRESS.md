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

## Parallel execution (4 worker agents + coordinator)

Per "maximise productivity", work is parallelized one agent per isolated git repo
(more than one agent per submodule would race the shared index/working-tree/build gate):

| Stream | Scope | Branch |
|---|---|---|
| **Backend agent** | `bazaar-backend/` — BE-3,5,6,7,8,9,11,13,14,… (BE-1/2/4 already done by coordinator) | `fix/improvement-plan` |
| **Contract agent** | `bazaar-contract/` — SC-1…SC-7, test gaps, SECURITY.md | `fix/improvement-plan` |
| **Frontend agent (F1)** | `bazaar-frontend/` — Vault tokens + `components/ui/*` + all screens (incl. transactional visuals); FE-5 done | `feat/vault-redesign` |
| **Frontend money-path (F2)** | worktree `bazaar-frontend-money-path` — FE-3/1/2/12/13/4/15/9 (logic only) | `feat/vault-money-path` |
| **Root agent** | superproject root only — CI-1, INFRA-5, DEP-2(root), DOC-1 | `feature/shipment-escrow` |
| **Coordinator (me)** | PROGRESS/DECISIONS, ABI sync across layers, submodule pointer bumps, integration, unblocking | — |

Agents do NOT edit `PROGRESS.md`/`DECISIONS.md` (coordinator-owned) or the ABI artifacts
(`Escrow.json`, `escrow_abi.ts` — coordinator syncs after contract ABI changes).

## Improvement plan items

### Smart contract (`bazaar-contract`)
- ☑ SC-1 — Dispute can block shipment / force refund — `6d37f81` (disputes only after shipment)
- ☑ SC-2 — `rule()` unverified disputeID→order mapping — `7b24e16` (assert+clear+activeDisputes guard; dead var removed)
- ☑ SC-3 — Fee not snapshotted per order — `2ddee9f` (feeBps in Order struct)
- ☑ SC-4 — No emergency fund recovery — `f377c6b` (rescueERC20/ETH w/ obligation floor + events)
- ☑ SC-5 — Single-EOA owner, no transfer/timelock — `96754c8` (OZ Ownable2Step)
- ☑ SC-6 — Settlement bricked by reverting recipient — `5c4daee` (pull-payment withdrawable+withdraw())
- ☑ SC-7 — Fee-on-transfer token not handled — `ca85a0c` (balanceOf delta)
- ☑ SC-10 `a55201d` · ☑ SC-11 `c619298` · ⊘ SC-8/SC-9 (deferred: pure gas/refactor churn, no security gain — see agent report)
- ☑ SC test gaps — `46c439d` + covered alongside SC items — **82 passing** (was 65)
- ☑ SECURITY.md — `12d25f4` (audit-required-before-mainnet note)

### Pending integration (coordinator, after backend + F1 finish)
- ☑ **ABI sync** — backend `Escrow.json` `ff4ede5` + frontend `escrow_abi.ts` `8f8ad9bd`, byte-identical to artifact (abi-sync logic verified locally). `OrderCreated` event unchanged → observer unaffected. FE-5 fixture `orders()` got `uint96 feeBps` (positional decode fix). FE/BE gates green.
- ◐ **Pull-payment UX follow-up (SC-6)** — documented in DESIGN.md `6853843`; frontend "Withdraw" action in progress (Agent A).

### Backend (`bazaar-backend`)
- ☑ BE-1 — Wildcard CORS + credentials (🔴 Critical, S) — `e97caf1` fail-fast config guard + test + sanitized env
- ☑ BE-2 — Observer panics on malformed logs (🟠 High, S) — `014a176` recover() + Topics guards + test
- ☑ BE-3 — Graceful shutdown / cancellable contexts — `1e7c65a` (NotifyContext SIGINT/SIGTERM → observer/backfill; srv.Shutdown)
- ☑ BE-4 — Order creation has no DB transaction (🟠 High, S) — `8089b49` batch wrapped in db.Transaction
- ☑ BE-5 — Upload path traversal + content-type — `094f180` (content-type allowlist all drivers; server uuid+ext key; traversal reject)
- ☑ BE-6 — No rate limiting — `67591db` (IP+route token-bucket; strict on auth; nonce map capped+swept)
- ☑ BE-7 — Duplicate/drifted GORM models — `b2aa662` (services/db single source; per-module aliases; hooks moved to db)
- ☑ BE-8 — Observer swallows DB errors — `87777f4` (check/log .Error op+topic+orderId)
- ☑ BE-9 — Orders never leave `disputed` — `9a2c212` (derive terminal status from ruling)
- ☑ BE-10 — `GetOrders` no pagination — `8f3a7f0` (cursor pagination + next-cursor header)
- ☑ BE-11 — Backend test suite — `527fa14` (JWT negatives, SIWE, IDOR, bytes32↔UUID, computeScore, httptest auth flow)
- ☑ BE-12 — Malformed gorm unique tags — `9737e05` (real partial unique indexes; 23505→ErrConflict)
- ☑ BE-13 — Soft-delete vs unique wallet — `59e1113` (partial unique index WHERE deleted_at IS NULL)
- ◐ BE-14 — Versioned migrations — `1d600bf` (advisory-lock'd tx, conditional destructive SQL; file-based golang-migrate deferred)
- ◐ BE-15 — Readiness/metrics/structured logs — `de976f1` (`/readyz` DB ping + slog request logging; Prometheus /metrics deferred)
- ◐ BE-16 — JWT hardening — `4530cdf` (TTL 1h, sub identity, jti/iat/aud, alg+iss+aud pinned; refresh denylist deferred)
- ☑ BE-17 — Identity via context not headers — `7c196b5` (context.WithValue + middleware.UserID)
- ⊘ BE-18 — Integer money types — deferred (cross-cutting schema/contract change needing FE + observer reconciliation + live DB; too risky to land blind)
- ☑ BE-19 — Bounded Algolia worker — `32153bd` (bounded worker-queue + retry/backoff)
- ☑ BE-20 — Fail-fast config validation — `88c10e2` (parse-error handling, defaults, range checks, required-DB)
- ☑ BE-21 — Don't leak raw errors to clients — `08058c6` (httpjson.WriteAppError chokepoint; 5xx generic+logged)

### Frontend (`bazaar-frontend`)
> **Canonical frontend branch = `feat/vault-redesign` (F1).** F1 ended up a strict
> superset of the F2 money-path worktree, so F2 (`feat/vault-money-path`) is
> **superseded/not merged** (see DECISIONS #7/#9). SHAs below are F1's.
- ☑ FE-1 — Multi-order checkout partial-failure recovery — `4e410707` (per-item progress; retry only unpaid; "N of M paid")
- ☑ FE-2 — Checkout positional correlation — `b99c1230` (correlate by ProductID; OrderResponse +product_id/quantity; ⚠ backend `OrderResponse` still `{id,owner_address}` — fallback to index until BE adds fields)
- ☑ FE-3 — ETH/USDC price denomination — `899b5c3b` (settles in listing `Unit`; default ETH; no buyer free toggle; mixed-currency carts blocked; see DECISIONS #7)
- ☑ FE-4 — JWT in localStorage — `4c1d081e` (persist transform strips jwt; in-memory + refresh-cookie bootstrap)
- ☑ FE-5 — E2E wallet fixture ABI desync — `73f0d4db` (fixture re-synced to escrow_abi.ts struct)
- ☑ FE-6 — Server Components + metadata/SEO — `8bdb02ab` (layout→SC + metadata; Providers island; static marketing SCs; product generateMetadata)
- ☑ FE-7 — `next/image` + CDN whitelist — `5891c9ad` (Spaces CDN remotePatterns; BucketImage→next/image)
- ☑ FE-8 — GA ID to env — `624ec241` (`NEXT_PUBLIC_GA_ID`, gated, not-e2e) *(= SEC-2)*
- ☑ FE-9 — Broken `react` dep + dead deps — `cea7ca8a` (react@^18; pruned wagmi/web3/socket.io/jsonwebtoken)
- ☑ FE-10 — Duplicate Footer components — `1f57bead` (both unused dupes deleted)
- ☑ FE-11 — PersistGate / auth bootstrap flash — `6f0bc8b9` (PersistGate + `bootstrapped` flag)
- ☑ FE-12 — Type `_createOrders` + zod — `fcf879d6`
- ☑ FE-13 — `messageToBytes32` early validation — `98e1923f`
- ☑ FE-14 — A11y pass — `de1c3184` (inline ship form; ARIA combobox search; toggle removed in FE-3)
- ☑ FE-15 — Remove client-set CORS request headers — `ed26cb8d`

### Infra / CI / cross-layer (`root`)
- ◐ INFRA-1 — Prod Dockerfiles + CD + split compose — split compose `86543c6`; CD workflow `59b2daf` (build+push GHCR on tags); per-component Dockerfiles in progress (Agent B: backend+contract; Agent A: frontend)
- ☑ INFRA-2 — Commit untracked docs (Phase 0 `docs:` commit + `62b97b9`)
- ☑ INFRA-3 — Expand `.gitignore`, clean tree — `62b97b9`
- ☐ INFRA-4 — Merge to `main` across repos (🟡 Med, M) — *requires shared-branch push; see DECISIONS*
- ☑ INFRA-5 — Compose secrets/healthchecks — `86543c6` (env interpolation, pg_isready/`/health` healthchecks, service_healthy gating, split dev compose)
- ◐ SEC-1 — Sanitize example env — root `.env.example` fake placeholders done (`86543c6`); backend `.env.example` partly done by BE-1 (`e97caf1`), remaining sanitization with backend agent
- ☐ SEC-2 — GA ID (= FE-8) (🟢 Low, S) — frontend agent
- ☑ CI-1 — Lint/audit/secret-scan/Slither — `ee5cc5b` (+ `dependabot.yml`)
- ☐ DEP-1 — Upgrade Next off 13.5.4 + fix react dep (🟡 Med, M) — frontend
- ◐ DEP-2 — One package manager + Go version align — root compose Go aligned (`79c0dfc`); submodule lockfiles/e2e-npm remain (submodule agents)
- ☑ DOC-1 — Real README + architecture/deploy docs — `e619ad5` (README + docs/ARCHITECTURE/DEPLOY/CONTRIBUTING)
- ◐ XL-1 — Single OrderStatus source + typed FE enum — backend single-source via BE-7 `b2aa662`; DESIGN.md updated `6853843`; FE typed union in progress (Agent A)
- ◐ XL-2 — FE interfaces drift from Go structs — in progress (Agent A: IUser/IOrder field additions)

## Vault redesign screens

> **Figma MCP unavailable headlessly** (`get_variable_defs`/`get_screenshot` need a
> live selection in the Figma desktop app). F1 used the `CLAUDE_CODE_PROMPT.md` token
> quick-reference for the foundation. The pixel-accurate screen rebuild + verification
> is **BLOCKED** on Figma access — see DECISIONS #9.

### Foundation / component library
- ☑ Design tokens (CSS vars + Tailwind theme: vault-* colors, radii, Inter scale, shadows) — `d577b4aa`
- ☑ Existing `components/ui/`: Button · Card · Badge · order-status-badge (6 states) · Input/Textarea/Field/Label · Spinner · Skeleton · empty-state
- ☐ New component files: ProductCard · StoreCard · Navbar · Footer · SellerSidebar · escrow Stepper · segmented toggle · switch *(deferred — Figma)*

### Screens — ⊘ deferred (Figma MCP blocker); web3/route/redux logic preserved, FE-1…FE-15 done
- ⊘ Home · Stores · Store detail · Product detail
- ⊘ Cart · Checkout · Orders · Order detail/tracking
- ⊘ Wallet connect (SIWE) · Seller dashboard · Seller orders
- ⊘ Product editor · Account settings · Dispute detail
- ⊘ Empty/loading/error states · Mobile/responsive (Home, Product, 404, skeleton)
  *(Agent A is now executing these as token-approximation + Figma-via-node-id where reachable.)*

## Autonomous improvements backlog (post-plan, user-authorized)

To run after the current wave (each in the repo it owns, no collisions), beyond the strict plan:
1. **Backend partials → complete:** BE-14 file-based `golang-migrate`; BE-15 Prometheus `/metrics`; BE-16 server-side refresh-token denylist/rotation.
2. **E2E correctness specs (plan testing item 3):** multi-item cart, partial-failure checkout (FE-1), USDC-vs-ETH pricing assertion (FE-3) — in `bazaar-frontend/e2e` after Agent A frees it.
3. **Contract fuzzing harness (pre-mainnet):** Foundry/Echidna invariants on escrow + dispute accounting (obligation floor `escrowedFunds+heldDeposits+totalWithdrawable` never exceeds balance).
4. **Reconciliation:** observer reconciles DB `Total`/`Fee` against on-chain `Amount`/`feeBps` (groundwork for BE-18).
5. **DX:** `tygo` to generate TS types from Go structs (kills XL-2 drift permanently).
