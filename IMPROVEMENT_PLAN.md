# The Bazaar — Comprehensive Improvement Plan

> **Generated:** 2026-06-22 · Based on a deep, line-level audit of the current code across all three components (smart contract, Go backend, Next.js frontend) plus infrastructure and cross-layer concerns.
> **Supersedes:** `IMPROVEMENTS.md` (2026-05-27), which is now largely stale — most of its items (A1–A7, B1–B18, C1–C12, D1–D6) have been fixed. See the [appendix](#appendix--status-of-the-old-improvementsmd) for the fixed/open status of every prior item.

---

## 1. Executive summary

The Bazaar is a decentralized escrow marketplace built as a git-submodule monorepo:

- **`bazaar-contract`** — a Solidity 0.8.19 escrow contract (Hardhat, OpenZeppelin 4.9.6) supporting ETH and USDC payments, a shipment/reclaim flow, platform fees, and ERC-792/1497 Kleros-style arbitration.
- **`bazaar-backend`** — a Go 1.21 API (gorilla/mux, samber/do DI, GORM/Postgres) with SIWE (Sign-In With Ethereum) auth, an on-chain event observer that mirrors contract state into the database, pluggable storage (S3/local/IPFS), and Algolia search.
- **`bazaar-frontend`** — a Next.js 13 App Router app (TypeScript strict, Redux Toolkit, ethers v6, MetaMask SDK) with a full buy → escrow → ship → claim → dispute UI and a Playwright e2e suite.

**Overall health: solid and maturing, but not yet production-ready for real funds.** Since the May audit the project has made major strides — auth moved to SIWE, USDC + fees + arbitration + shipment were added, the **ABI is now byte-identical across all three layers and enforced by CI**, an end-to-end test suite stands up the whole stack, and the vast majority of previously-identified bugs are fixed. The architecture is clean and the engineering instincts are good (Checks-Effects-Interactions, SafeERC20, idempotent observer upserts, axios interceptors, on-chain state reads driving UI).

The remaining work clusters into five themes, in priority order:

1. **Money-path correctness (frontend + contract).** The checkout charges the *same* listing price as either ETH or USDC with no conversion, multi-order checkouts can desync from on-chain escrow, and the contract's dispute flow can be griefed to block shipment or force refunds. These are launch-blocking for an app that moves real value.
2. **Backend security & reliability.** A wildcard-CORS-with-credentials default, no rate limiting, unsanitized S3 upload keys, no database transactions around order creation, an observer that can panic the whole process, and no graceful shutdown.
3. **Smart-contract trust & recoverability.** A single-EOA owner with no ownership transfer or timelock, no emergency fund-recovery path, and a settlement that can be bricked by a reverting recipient — all serious for a contract custodying third-party funds.
4. **Testing, observability & data integrity.** Backend test coverage is effectively zero; the contract has untested dispute/pause paths; there are duplicate, already-drifted data models; and migrations run destructive SQL on every boot.
5. **Production infrastructure & docs.** No Dockerfiles or deploy pipeline (services run in dev mode), key docs are untracked, and the root README is a one-line stub.

**Before mainnet with real money, a professional third-party smart-contract audit is strongly recommended** in addition to the fixes below.

---

## 2. How to read this plan

**Severity**

| Badge | Meaning |
|---|---|
| 🔴 Critical | Launch-blocking. Risk of fund loss, data breach, or outage under normal use. |
| 🟠 High | Serious correctness/security/reliability gap; fix before scaling to real users. |
| 🟡 Medium | Meaningful quality, maintainability, or hardening issue. |
| 🟢 Low | Polish, DX, minor cleanup. |

**Effort:** **S** ≈ ≤ half a day · **M** ≈ 1–3 days · **L** ≈ 1–2 weeks.

Every item lists the **file(s)** to change so work can start immediately. Items are grouped by component; the [phased roadmap](#3-phased-roadmap) sequences them across all components by dependency and risk.

---

## 3. Phased roadmap

Work is sequenced into five phases. Phase 0 is launch-blocking; later phases can overlap once Phase 0 lands. IDs link to the detailed sections.

### Phase 0 — Launch blockers (money safety, ~1.5–2 weeks)
The app must not handle real funds until these are fixed.

- **FE-3** Fix ETH/USDC price denomination (currently charges the same number as either token).
- **FE-1 / FE-2** Make multi-order checkout atomic & correlation-safe (no positional alignment, partial-failure recovery).
- **BE-1** Remove wildcard-CORS-with-credentials default.
- **BE-4** Wrap order creation in a DB transaction (set `contract_order_id` pre-insert).
- **SC-1** Close the dispute-griefing hole that blocks shipment / forces refunds.
- **SC-2** Verify `disputeID → order` mapping in `rule()`.
- **BE-2** Guard observer against malformed logs (panic = full backend crash).
- **FE-5** Re-sync the e2e wallet fixture ABI (it currently masks lifecycle bugs).
- **BE-6** Add rate limiting (nonce endpoint is a memory-exhaustion DoS).
- **BE-5** Harden file uploads (path traversal + content-type on the S3 path).
- **FE-4** Stop persisting the JWT to `localStorage`.

### Phase 1 — Reliability & data integrity (~2–3 weeks)
- **BE-3** Graceful shutdown + cancellable contexts.
- **BE-8** Stop swallowing observer DB errors; add a dead-letter/replay path.
- **BE-9** Move orders out of `disputed` after a dispute resolves.
- **BE-7 / XL-1** De-duplicate the divergent GORM models and `OrderStatus` enums (single source of truth).
- **BE-14** Replace boot-time AutoMigrate + destructive SQL with versioned migrations.
- **SC-5** `Ownable2Step` + multisig/timelock for admin.
- **SC-6** Pull-payment pattern for dispute-deposit refunds.
- **SC-4** Emergency ERC-20/ETH rescue path.
- **BE-13** Fix soft-delete vs unique-wallet (blocks re-registration).

### Phase 2 — Testing, hardening & observability (~3–4 weeks)
- **BE-11** Backend test suite (JWT negatives, SIWE, authz/IDOR, observer conversions, reputation math).
- **SC test gaps** `unpause`, dispute/reclaim interactions, `rule()` wrong-ID, reverting-recipient settlement, appeals.
- **BE-15** Readiness probe, Prometheus metrics, structured request logging.
- **BE-16** JWT hardening (short TTL, `jti`, revocation, real refresh tokens).
- **SC-3 / SC-7** Per-order fee snapshot; fee-on-transfer-safe accounting.
- **CI-1** Add lint, dependency audit, secret scanning, and Slither to CI.
- **DEP-1** Upgrade Next.js off 13.5.4 (known CVEs); fix the broken `react` dependency spec.
- **Engage a professional contract auditor.**

### Phase 3 — Production infrastructure & docs (~2–3 weeks)
- **INFRA-1** Multi-stage Dockerfiles per component + a CD pipeline; split dev vs prod compose.
- **INFRA-5** Compose secrets via env, healthchecks, `service_healthy` gating.
- **INFRA-2 / INFRA-3** Commit untracked docs/config; expand `.gitignore`; clean the working tree.
- **INFRA-4** Merge `feature/shipment-escrow` → `main` across all repos; document submodule init.
- **DOC-1 / SEC-1 / SEC-2** Real README + architecture/contributing/deploy docs; sanitize example env; move the GA ID to config.

### Phase 4 — Performance, UX & polish (ongoing)
- **FE-6** Adopt Server Components + per-route metadata (SSR/SEO).
- **FE-7** Migrate images to `next/image`; whitelist the CDN.
- **FE-9** Remove dead/corrupt dependencies.
- **BE-10 / BE-18** Order pagination; integer money types.
- **FE-14** Accessibility pass (replace `window.prompt`, keyboard-navigable search).
- Remaining low-severity items: **FE-10/11/12/13**, **BE-19/20/21**, **SC-8/9/10/11**, **DEP-2**, **XL-2**.

A visual version of this roadmap is in **`ROADMAP.html`**.

---

## 4. Smart contract (`bazaar-contract`)

**What it does today.** A single, non-upgradeable, fee-taking escrow. Roles: `owner` (admin), `treasury` (fee + forfeited-deposit sink), `arbitrator` (ERC-792), and per-order `buyer`/`receiver`. Funding is ETH (`createOrder`) or USDC (`createOrderERC20`). Lifecycle: create → `markShipped` (starts delivery window) → `releaseOrder` (buyer confirms early) or wait for `releaseTime` → `claimOrder`/`claimOrders`. Alternatives: `refundOrder`, `buyerReclaim` (no-ship timeout), and a full dispute path (`raiseDispute*`, `rule`, timeouts, `submitEvidence`). O(1) per-user order bookkeeping via swap-and-pop. **Strengths:** consistent Checks-Effects-Interactions, SafeERC20 everywhere, dispute over-payment capped & refunded, refused rulings default to receiver (no trapped funds), fee capped at 10%, thorough event coverage, ~80-case test suite.

### SC-1 — Dispute can be opened to block shipment and force a refund 🟠 High · Effort M
**File:** `contracts/Escrow.sol` — `markShipped` (~L300), `buyerReclaim` (~L317), `_raiseDispute` (~L494–509)
**Problem:** `_raiseDispute` flips `dispute.status` to `1` on *any* `msg.value > 0`, while both `markShipped` and `buyerReclaim` `require(orderDisputes[orderId].status == 0)`. So a buyer can deposit a tiny amount immediately after ordering, permanently preventing the receiver from shipping; the buyer can then ride `timeoutByBuyer` to a full refund without a real arbitration ever occurring, or force the honest receiver to pay the full arbitration fee.
**Impact:** Griefing / free-refund vector; honest receivers can be forced to absorb arbitration costs.
**Fix:** Only allow disputes *after* shipment (a delivery dispute pre-supposes delivery) — pre-shipment, the buyer's remedy is `buyerReclaim`. Alternatively, don't freeze `markShipped`/`buyerReclaim` until `status >= 2`, and block the buyer-win timeout path for orders the receiver was structurally prevented from shipping.

### SC-2 — `rule()` trusts an unverified `disputeID → order` mapping 🟠 High · Effort S
**File:** `contracts/Escrow.sol` — `rule` (~L435–448), `disputeIDToOrder` write (~L523)
**Problem:** `rule` resolves `orderId = disputeIDToOrder[disputeID]` and proceeds on `arbitrator`-only auth, but never asserts `orderDisputes[orderId].arbitratorDisputeID == disputeID`, and the mapping is never cleared. Safe with the current mock, but `setArbitrator` is owner-swappable; a replaced/overlapping arbitrator ID space could settle the wrong still-`status==2` order. The dead `nextLocalDisputeId` (written, never read) hints at an abandoned namespacing scheme.
**Fix:** Assert `arbitratorDisputeID == disputeID` in `rule`, clear `disputeIDToOrder` on resolution, and forbid `setArbitrator` while any dispute is `status==2` (or namespace IDs by arbitrator). Remove the dead variable.

### SC-3 — Platform fee is not snapshotted per order 🟡 Medium · Effort S
**File:** `contracts/Escrow.sol` — `setFeeBps` (~L176), `_payout` (~L631)
**Problem:** Fee is read from the live global `feeBps` at payout, not captured at creation, so the owner can raise the fee (up to 10%) on orders already in escrow.
**Fix:** Store `feeBps` in the `Order` struct at creation and use `orderInfo.feeBps` in `_payout`.

### SC-4 — No emergency recovery for stuck funds 🟡 Medium · Effort M
**File:** `contracts/Escrow.sol` (no rescue function; no `receive`/`fallback`)
**Problem:** ERC-20 sent directly to the contract is permanently locked; `pause()` freezes user flows with no admin escape for a known-broken order; accounting dust is unrecoverable.
**Fix:** Add an owner-only, paused-only `rescueERC20`/`rescueETH` that refuses to drop below active escrow obligations, with events.

### SC-5 — Owner is a single EOA, irreplaceable, no timelock 🟡 Medium · Effort S
**File:** `contracts/Escrow.sol` — `owner` (~L26), constructor (~L129), `onlyOwner` (~L139)
**Problem:** There is **no `transferOwnership`** at all — admin is bound to the deployer forever. Powers are broad (`setArbitrator`, `setFeeBps`, `setTreasury`, `pause`). A lost key freezes governance; a compromised key can repoint the arbitrator and drain disputed orders.
**Fix:** Inherit OZ `Ownable2Step`; require the owner be a multisig/timelock at deploy; put `setArbitrator`/`setFeeBps` behind a timelock.

### SC-6 — Dispute settlement can be bricked by a reverting recipient 🟡 Medium · Effort M
**File:** `contracts/Escrow.sol` — `_sendETH` (~L652), `_settleDisputeDeposits` (~L609), `rule` (~L435)
**Problem:** Deposit refunds use `_sendETH` with `require(success)` inside the atomic `rule` callback. A winner that is a contract rejecting ETH (Safe/AA wallets) reverts the entire settlement, permanently locking the order amount and both deposits.
**Fix:** Pull-payment pattern — credit a `withdrawable[addr]` balance and expose `withdraw()`; keep order-payout and deposit-refund independent so one failure can't brick settlement.

### SC-7 — Fee-on-transfer / non-standard token not handled 🟡 Medium · Effort S
**File:** `contracts/Escrow.sol` — `createOrderERC20` (~L266, L277), `_payout` (~L625)
**Problem:** Records `amount` as requested without measuring the balance actually received; a fee-on-transfer token (or a future USDC implementation change) would under-collateralize the pool.
**Fix:** Measure `balanceOf(this)` before/after `safeTransferFrom` and store the delta; document that only standard tokens are supported.

### SC-8 → SC-11 — Lower-severity hardening 🟢 Low
- **SC-8 (S):** Replace hand-rolled `onlyOwner`/`whenNotPaused`/`nonReentrant` with audited OZ `Ownable2Step`/`Pausable`/`ReentrancyGuard`.
- **SC-9 (M):** Replace ~50 `require` strings with custom errors (cheaper bytecode/reverts under 0.8.19 + optimizer).
- **SC-10 (S):** Cache struct fields into memory in `_payout`/`_raiseDispute`; in timeouts compare against the *stored* `disputeArbitrationCost` instead of re-querying the live arbitrator (also a correctness fix if cost changes mid-window).
- **SC-11 (S):** Add `nonReentrant` to all state-mutating externals for uniformity; `orders` mapping is `public` — add a purpose-built view instead of exposing the full struct.

### Contract test gaps (address in Phase 2)
`unpause()` is never tested; the SC-1 markShipped↔dispute↔reclaim interaction is untested; `rule()` with a wrong/stale `disputeID` is untested; reverting-recipient settlement (SC-6) is untested; appeals (`currentRuling`/`disputeStatus`/`appeal`) are unused and untested; mid-flight `setFeeBps` (SC-3) is untested; `claimOrders` whole-batch-revert-on-one-bad-order is not asserted. **Event assertions and fee math are well covered** — build on that.

---

## 5. Backend (`bazaar-backend`)

**Architecture.** Go 1.21, gorilla/mux under `/api`, `samber/do` DI + `hooks`-based service registration, GORM/Postgres (pgx). Modules: `users`, `stores`, `products`, `disputes`. SIWE auth (per-wallet nonce → signature → RS256 JWT keyed to user UUID). An observer subscribes to ~10 contract events over WebSocket and mirrors them to the DB, with reconnect/backoff and startup backfill. **Strengths:** correct connection pooling, alg-pinned RS256 JWT, idempotent observer upserts (`clause.OnConflict`), ownership checks on sensitive reads, pluggable storage, indexes present, cursor pagination already used for product listings. Of the old B1–B18 items, **15 are fixed**.

### BE-1 — Wildcard CORS combined with credentials 🔴 Critical · Effort S
**File:** `.env.example:13,15,17`; `services/web/web.go:64–68`; `services/config/config.go`
**Problem:** The shipped config sets `HTTP_ALLOWED_ORIGINS="…,*"`, `HTTP_ALLOWED_HEADERS="*"`, and `HTTP_ALLOWED_CREDENTIALS="true"`, passed straight into `cors.New`. Allowing `*` (or reflecting any origin) *with credentials* is the canonical dangerous CORS misconfiguration — any website can drive authenticated cross-origin requests.
**Fix:** Never combine `*` with credentials. Pin explicit origins, set an explicit header allowlist (`Content-Type, Authorization`), and fail fast at config load if `AllowCredentials && origins contains "*"`.

### BE-2 — Observer panics on malformed logs (crashes the process) 🟠 High · Effort S
**File:** `services/observer/observer.go:129` (`vLog.Topics[0]`), plus unguarded `Topics[1]`/`Topics[2]` in most handlers
**Problem:** `handleLog` reads `Topics[0]` unconditionally; an anonymous/malformed log (empty `Topics`) panics. The `main.go` reconnect loop only restarts on *returned errors*, not panics, so the goroutine panic is fatal for the whole backend.
**Fix:** Guard `len(vLog.Topics)` at the top of `handleLog` and in each handler; wrap `handleLog` in a `recover()`. Same exposure in the backfill loop.

### BE-3 — No graceful shutdown; leaked goroutines, interrupted writes 🟠 High · Effort M
**File:** `main.go:70–95`, `services/web/web.go:61–83` (no `os/signal`, `srv.Shutdown`, or cancellable context anywhere)
**Problem:** `ListenAndServe` runs forever and `panic`s on error; observer/backfill use `context.Background()`. On SIGTERM (deploys, dyno cycling) in-flight requests are killed and multi-write order creation can be interrupted mid-flight.
**Fix:** `signal.NotifyContext(SIGINT,SIGTERM)`, thread the context into the observer/backfill (replace `context.Background()`), and `srv.Shutdown(ctx)` on signal.

### BE-4 — Order creation has no DB transaction → orphaned orders 🟠 High · Effort S
**File:** `modules/products/service.go:117–182` (Create then a separate Update of `contract_order_id`, looped per item, no transaction)
**Problem:** If the second write fails, the order row exists with an empty `contract_order_id` and the observer can never link it to chain. A mid-loop error on a multi-item cart leaves earlier items committed while later ones fail — DB and on-chain escrow diverge.
**Fix:** Set `ContractOrderID` on the struct *before* `Create` (single atomic insert) and/or wrap the loop in `db.Transaction(...)`.

### BE-5 — File upload: path traversal + no content-type validation 🟠 High · Effort M
**File:** `modules/products/handler.go:285–307` (`"evidence/"+header.Filename`); `services/s3spaces/s3spaces.go:86–105` (`saveS3`)
**Problem:** The storage key uses the raw client filename. The local driver sanitizes, but the **S3 driver does not** — `../` keys can overwrite other objects, and arbitrary extensions/MIME types are accepted and served `public-read` (stored-XSS vector). The 10 MB limit is the only control.
**Fix:** Generate a server-side key (`uuid + validated ext`), validate `http.DetectContentType` against an image allowlist for *all* drivers, and apply `filepath.Clean`/`..` rejection in `saveS3`.

### BE-6 — No rate limiting anywhere 🟠 High · Effort M
**File:** `services/web/web.go` (no limiter); nonce store `modules/users/service.go:34–47`
**Problem:** No throttling on any route. `POST /api/auth/nonce` writes to an unbounded in-memory `sync.Map` per wallet — floodable to memory exhaustion. `verify`, `/upload`, `/products/orders` are equally open.
**Fix:** IP+route rate-limit middleware; cap the nonce map with a sweeper, or move nonces to Redis with TTL.

### BE-7 — Duplicate, already-drifted GORM models 🟠 High · Effort M
**File:** `Users` defined 4× (`services/db/models.go:30`, `modules/{users,stores,products}/models.go`); `Orders` 2× (`db/models.go:60` vs `products/models.go:55`)
**Problem:** The same tables are modeled by divergent structs. `services/db.Orders` has the on-chain fields (`Token`, `Fee`, `OnChainProductID`, `shipped`/`disputed` statuses); `modules/products.Orders` is the *old* 4-status shape with none of them — yet the products module reads through it. `disputes` already does it right via type aliases (`type Disputes = db.Disputes`).
**Fix:** Make `services/db` the single source of truth; alias or import everywhere; delete the per-module copies.

### BE-8 — Observer swallows DB errors 🟠 High · Effort M
**File:** `services/observer/observer.go` — unchecked `.Updates`/`.Create`/`.Update`/`.First` at ~L216,220,235,262,283,313,378,441,510,690 (only `handleOrderShipped` checks `.Error`)
**Problem:** The lifecycle writes that are the observer's entire purpose ignore their error. A failed write (constraint, deadlock, blip) silently leaves the order/dispute status wrong, and the event is already consumed — no retry.
**Fix:** Check `.Error` on every op, log with orderId/topic, and record failures to a dead-letter table or metric so `RunBackfill` can replay.

### BE-9 — Orders never leave `disputed` after resolution 🟡 Medium · Effort M
**File:** `services/observer/observer.go:407–446` (`handleDisputeResolved` updates only the disputes row)
**Problem:** `DisputeRaised` sets the *order* to `disputed`, but `DisputeResolved` doesn't move it back to a terminal state — that only happens if a later order event arrives. Resolved orders can read `disputed` forever; reputation counts undercount resolved outcomes.
**Fix:** Derive the order status from the ruling in `handleDisputeResolved` (or verify/guarantee the contract emits an order event after resolution and order the handlers accordingly).

### BE-10 → BE-21 — Additional backend items
- **BE-10 🟡 M:** `GetOrders` (`modules/products/service.go:184`) returns all rows with no pagination — extend the existing cursor pattern.
- **BE-11 🟡 L:** Test coverage is ~zero beyond one JWT happy-path. Add table-driven JWT negatives, SIWE-verify, IDOR checks on `GetOrder`/`GetDispute`, `bytes32↔UUID` round-trips, `computeScore` edges, and an httptest auth-flow integration test.
- **BE-12 🟡 S:** Malformed tags `gorm:"unique, not null"` (`modules/stores/models.go:24`, `products/models.go:35`) apply neither; add real unique indexes and drop the racy app-level name pre-check.
- **BE-13 🟡 M:** `gorm.Model` + explicit UUID `ID` means soft-delete is on; the `WalletAddress` unique index ignores `deleted_at`, so a deleted user can never re-register. Use an explicit base model and decide soft vs hard delete deliberately.
- **BE-14 🟡 M:** Migrations run on every boot via AutoMigrate + ad-hoc `Exec` including a destructive `DELETE FROM disputes …` and DDL with no version table or lock (multi-replica race). Adopt `golang-migrate`/`goose` with an advisory lock.
- **BE-15 🟡 M:** `/health` is a static 200 (no DB/observer check). Add `/readyz` (DB ping + observer freshness), Prometheus `/metrics`, and structured request logging (`slog`).
- **BE-16 🟡 M:** 24h JWT, no `jti`/rotation/revocation; refresh just re-mints. Shorten TTL, add `jti`+`iat`+`aud`, server-side refresh tokens + denylist for logout.
- **BE-17 🟡 S:** Identity passed handler-to-handler via a mutable `r.Header.Set("user_id", …)` (`middleware.go:56`). Use `context.WithValue` instead.
- **BE-18 🟡 L:** Money stored as `float64` (`db/models.go:53,69`); `Total` ignores fees/decimals and is never reconciled with on-chain `Amount`. Move to integer minor units / `decimal`, record token+fee, reconcile in the observer.
- **BE-19 🟢 M:** Algolia index mutations fire as unbounded bare goroutines with dropped errors — use a bounded worker/queue with retry.
- **BE-20 🟢 S:** `services/config/config.go:119–211` discards all parse errors → silent misconfig (port 0, 0s timeouts). Validate required config and fail fast at boot.
- **BE-21 🟢 S:** Handlers forward raw `err.Error()` to clients (internal/DB detail leakage); a few success paths bypass the `httpjson` helper. Return generic 500s, log the real error, route everything through `httpjson`.

---

## 6. Frontend (`bazaar-frontend`)

**Architecture.** Next.js 13.5.4 App Router (TypeScript strict), Redux Toolkit + redux-persist, ethers v6 + MetaMask SDK, Tailwind, Playwright e2e. SIWE login; JWT injected by an axios request interceptor; 401 → logout via response interceptor; config centralized in `config/config.ts`. **Strengths:** ABI is correctly in sync and decoded by *named* fields; UI gating reads real on-chain order state (not just DB); good tx UX (toasts, disabled-while-pending, Etherscan links, USDC approve→order sequencing); react-hook-form + zod forms; real e2e coverage of the money path. Of the old C1–C12, **8 are fixed**.

### FE-3 — Cart total conflates ETH and USDC; USDC amounts are wrong 🔴 Critical (money) · Effort M
**File:** `app/cart/components/checkout/index.tsx:113,120`; `app/cart/page.tsx:130`; `app/products/components/addCart/index.tsx`
**Problem:** A listing's single numeric `Price` is charged as `parseEther(price)` for ETH **or** `BigInt(round(price*1e6))` for USDC, with no conversion. The *same* "0.01" listing costs 0.01 ETH (~tens of dollars) or 0.01 USDC (one cent) depending purely on the buyer's toggle. Price has no defined unit.
**Impact:** Buyers drastically underpay or sellers receive a wildly different value than listed. Core pricing is incorrect.
**Fix:** Define the price's denomination (per-currency listing, or a reference unit + price feed) and convert explicitly; don't let the buyer pick a token the price isn't denominated in.

### FE-1 — Multi-order checkout has no partial-failure recovery 🟠 High (money) · Effort L
**File:** `app/cart/components/checkout/index.tsx:107–140`
**Problem:** DB orders are created in one batch, then escrow txs are submitted one-by-one in a `for` loop. If item 2 of 3 is rejected/reverts, item 1 is already escrowed on-chain, the cart isn't cleared, and the user can re-submit — duplicating DB orders and escrows. No idempotency key, no per-item status.
**Fix:** Track per-item progress; on failure, persist what succeeded and remove paid items from the cart so a retry can't re-charge; surface "1 of 3 paid — retry remaining". Consider creating each DB order immediately before its escrow tx, or reconcile by tx hash on the backend.

### FE-2 — Checkout relies on positional response↔cart alignment 🟠 High (money) · Effort M
**File:** `app/cart/components/checkout/index.tsx:90–126`; `api/interfaces/products.ts:52`
**Problem:** `orderResponses[i]` is matched to `cart.products[i]` by index, but `OrderResponse` is only `{id, owner_address}` — no `ProductID` to correlate. If the backend ever reorders/dedups, the wrong price is escrowed against the wrong product.
**Fix:** Add `ProductID` (and `Quantity`) to `OrderResponse` and match by id, not index; type `_createOrders` as `Promise<AxiosResponse<OrderResponse[]>>`.

### FE-4 — JWT persisted to `localStorage` (XSS token theft) 🟠 High · Effort M
**File:** `redux/store.ts:25–35`; `redux/slices/auth-slice.ts`; `api/index.ts:16–23`
**Problem:** The bearer JWT is persisted in `localStorage` (readable by any script on the origin — GA, Algolia, MetaMask SDK, or any XSS).
**Fix:** Prefer an httpOnly/Secure/SameSite cookie from the backend; otherwise keep the JWT in memory only (blocklist `jwt` from persist) and rely on the existing refresh flow.

### FE-5 — E2E wallet fixture ABI is desynced from the contract 🟠 High · Effort S
**File:** `e2e/fixtures/wallet.ts:25,97–108`
**Problem:** The fixture's `orders(bytes32)` tuple omits the three fields the real struct added (`shippingDeadline`, `deliveryWindow`, `shipped`), so `readOrder` decodes positionally wrong — `completed`/`release` read numeric fields. The lifecycle suite meant to guard the order flow reads the wrong on-chain fields (false confidence).
**Fix:** Use the exact struct from `escrow_abi.ts` and decode by named properties.

### FE-6 → FE-15 — Additional frontend items
- **FE-6 🟡 L:** Every page + `app/layout.tsx` is `"use client"` — zero Server Components, no `metadata`/SEO, large hydration. Make `layout` a server component with a `Providers` child; convert read-only pages (`/stores`, `/products/[id]`, marketing pages) to async server components with `generateMetadata`.
- **FE-7 🟡 M:** Images use raw `<img>` (`app/components/image/index.tsx`, `components/search/index.tsx`) and the product CDN isn't in `next.config.js`. Whitelist the Spaces CDN and migrate to `next/image`.
- **FE-8 🟡 S:** GA ID `G-1H1H1CR559` hardcoded in `app/layout.tsx:121,127`. Move to `NEXT_PUBLIC_GA_ID`, render only when set and not under e2e.
- **FE-9 🟡 S:** `package.json:27` has a corrupt `"react": "link:@web3modal/wagmi/react"` spec; `wagmi`/`web3`/`@web3modal`/`socket.io`/`jsonwebtoken` appear unused. Pin `react@^18` and prune dead deps.
- **FE-10 🟢 S:** Two byte-identical, unused `Footer` components (`app/components/footer.tsx`, `footer/index.tsx`) — delete; layout has its own inline footer.
- **FE-11 🟢 M:** Protected routes gate via `useEffect` redirect with no `PersistGate`, causing a content flash / spurious redirect on refresh (the e2e suite had to add a rehydration wait). Add `PersistGate` + a `bootstrapped` auth flag.
- **FE-12 🟢 S:** `_createOrders` returns untyped `AxiosResponse`; type it and validate with zod (already a dep) before using amounts.
- **FE-13 🟢 S:** `messageToBytes32` (`utils/helpers.ts:29`) throws on any non-UUID id before the tx, surfacing as a generic toast; validate earlier with a specific message and document the encoding.
- **FE-14 🟢 M:** A11y gaps — `window.prompt` for shipping tracking (`app/seller/orders/page.tsx:202`), search dropdown not keyboard-navigable, token toggle not a radio group. Replace prompt with an inline form; add ARIA + roving tabindex.
- **FE-15 🟢 S:** `api/index.ts:7–13` sets `Access-Control-*` as *request* headers (meaningless, extra preflights) — remove; CORS belongs on the backend.

---

## 7. Infrastructure, CI/CD & cross-layer (`root`)

**State.** Submodule monorepo; all three pinned to `feature/shipment-escrow`. Local run via `docker compose up` (every service in dev mode). CI (`.github/workflows/ci.yml`) runs 5 jobs: backend test/vet/build, frontend tsc+build, contract compile+test, **abi-sync** (byte-compares all three ABIs), and full-stack Playwright e2e — genuinely strong for a project this size. **The ABI is byte-identical across all three layers** (verified) and CI enforces it.

### INFRA-1 — No production containerization or deploy pipeline 🟠 High · Effort L
**File:** `docker-compose.yml` (no Dockerfiles in repo); `bazaar-backend/Procfile`
**Problem:** Zero Dockerfiles. Compose runs backend as `go run ./...`, frontend as `pnpm dev`, contract as `npm ci && hardhat node` — all dev mode, source mounted as volumes, no built artifacts. No CD job.
**Fix:** Multi-stage Dockerfiles (Go → distroless; frontend `next build` → `next start` on slim node), a CD workflow (build/push/deploy), and split `docker-compose.yml` (base/prod) from `docker-compose.dev.yml` (dev overrides).

### INFRA-2 — Key docs & config are untracked 🟠 High · Effort S
**File:** repo root — `DESIGN.md`, `LOCAL_RUN.md`, `Makefile`, `.mcp.json`, `.gitignore` all show as untracked (`??`)
**Problem:** A fresh clone of the canonical branch gets none of the design notes, run instructions, Makefile, or ignore rules — onboarding docs effectively don't exist.
**Fix:** Commit them; decide whether `IMPROVEMENTS.md`/this plan live in-repo or in the issue tracker.

### INFRA-3 → DEP-2, DOC-1, XL-1/2 — Additional infra & cross-layer items
- **INFRA-3 🟡 S:** Root `.gitignore` only ignores `graphify-out/`; ~45 stray screenshot PNGs, `.playwright-mcp/`, `.DS_Store`, `.claude/` clutter the tree (54 untracked entries). Expand `.gitignore`, move/delete screenshots.
- **INFRA-4 🟡 M:** Submodules + superproject live on `feature/shipment-escrow`, not `main`; a recursive clone of `main` gets an older state. Merge to `main` across repos, re-pin, and document `git submodule update --init --recursive`.
- **INFRA-5 🟡 M:** Compose hardcodes `POSTGRES_PASSWORD: secret`, uses `.env.example` as the runtime `env_file`, and has healthchecks only for hardhat (backend waits on `service_started`, racing Postgres readiness). Use env interpolation/secrets, add `pg_isready`/`/health` healthchecks, gate on `service_healthy`.
- **SEC-1 🟡 S:** `.env.example` ships realistic-looking placeholders (`SMTP_PASSWORD="aaaa bbbb cccc dddd"`, `DEPLOYER_PRIVATE_KEY="0x…"`) and is the de-facto compose config — one `git add` from a leak. Make examples obviously fake; point compose at a gitignored `.env`; remove `*` from example CORS. (No *real* secrets are currently committed — verified.)
- **SEC-2 🟢 S:** Hardcoded GA ID (same as FE-8).
- **CI-1 🟡 M:** CI lacks linting (`golangci-lint`/`next lint`/`solhint`), dependency/vuln audit (`pnpm audit`/`govulncheck`), secret scanning (gitleaks), contract security (Slither), and coverage gates (`solidity-coverage` is a dep but unused). Add these jobs + `dependabot.yml`.
- **DEP-1 🟡 M:** `next@13.5.4` predates several security patches; `react` resolved via a broken `link:` spec; redux-toolkit/react-redux a major behind. Upgrade Next to a patched release, pin React normally, plan the redux v2/v9 migration.
- **DEP-2 🟢 S:** `bazaar-contract` has *both* `package-lock.json` and `pnpm-lock.yaml` (the pnpm one is stale/orphaned); e2e uses `npm install` (unpinned); compose runs Go 1.22 while `go.mod` says 1.21.11. Pick one package manager, use `npm ci`, align Go versions.
- **DOC-1 🟡 M:** Root README is a 12-byte stub; no architecture overview, submodule-init guide, CONTRIBUTING, API reference, or deploy runbook. Write a real README + docs; consider generating OpenAPI from the Go routes.
- **XL-1 🟡 M:** `OrderStatus` has **two divergent backend enums** (6 states in `services/db` vs 4 in `modules/products`), `DESIGN.md` documents only 4 (stale — omits `shipped`/`disputed`), and the frontend types `Status` as raw `string`. Single source of truth in `services/db`, update `DESIGN.md`, add a typed union on the frontend.
- **XL-2 🟢 S:** Frontend interfaces still drift from Go structs — `IUser` omits `Address`/`LastLoginAt`; `IOrder` omits `TxHash`/`ContractOrderID`/`Token`/`Fee`/`OnChainProductID`/`MetaEvidenceURI`. Add the fields; consider `tygo` to generate TS types from Go.

---

## 8. Testing & QA strategy

Testing is the single biggest gap relative to the project's maturity. Target, in order:

1. **Backend unit/integration (BE-11)** — currently ~zero. Priorities: JWT negative cases (expired, wrong key, tampered, wrong alg), SIWE verification, authorization/IDOR on every owned resource, observer `bytes32↔UUID` conversions and per-event handlers (with simulated logs), reputation math, and an httptest auth-flow integration test. Use an in-memory sqlite GORM or a Postgres test container.
2. **Contract test gaps (Phase 2)** — `unpause`, the SC-1 dispute/ship/reclaim interaction, `rule()` with a wrong `disputeID`, reverting-recipient settlement (SC-6), the fee-snapshot path (SC-3), and `claimOrders` batch-revert. Enable `solidity-coverage` in CI with a threshold.
3. **E2E correctness (FE-5)** — fix the fixture ABI desync first (otherwise the suite gives false confidence), then add multi-item-cart and partial-failure checkout scenarios (FE-1/FE-2) and a USDC-vs-ETH pricing assertion (FE-3).
4. **CI gates (CI-1)** — lint + typecheck + dependency audit + Slither + coverage thresholds, failing the build.
5. **Pre-mainnet** — a professional third-party smart-contract audit and a focused fuzzing pass (Foundry/Echidna) on the escrow and dispute accounting.

---

## 9. Production-readiness checklist (handling real funds)

Must be green before mainnet with real money:

- [ ] Smart-contract: SC-1, SC-2 fixed; SC-4/SC-5/SC-6 addressed; **external audit complete**; admin is a multisig/timelock.
- [ ] Frontend money path: FE-3 (pricing), FE-1/FE-2 (checkout atomicity/correlation) fixed and e2e-covered.
- [ ] Backend security: BE-1 (CORS), BE-5 (uploads), BE-6 (rate limiting), BE-16 (JWT) fixed; secrets out of the repo and compose (SEC-1).
- [ ] Backend reliability: BE-2 (observer panic), BE-3 (graceful shutdown), BE-4 (order tx), BE-8 (observer errors), BE-9 (dispute resolution) fixed.
- [ ] Data integrity: BE-7/XL-1 (single model + enum source), BE-13 (soft-delete), BE-14 (versioned migrations) done.
- [ ] Observability: BE-15 (readiness, metrics, structured logs) in place; alerting on observer lag and error rates.
- [ ] Infra: INFRA-1 (prod images + CD), INFRA-5 (healthchecks/secrets) done; rollback runbook exists.
- [ ] Tests: backend + contract gaps closed; CI security gates (CI-1) green; dependencies patched (DEP-1).

---

## Appendix — Status of the old `IMPROVEMENTS.md`

The 2026-05-27 audit has been largely addressed. Summary by section (see component sections above for per-item evidence):

| Section | Items | Fixed | Partial | Open / superseded |
|---|---|---|---|---|
| **A. Contract** | A1–A7 | A1*, A2, A3, A4, A5, A7 | A6 (tests), A7 (`orders` public) | — |
| **B. Backend** | B1–B18 | 15 fixed | B11 (error swallow recurs as BE-8), B17 (tests, BE-11) | B5 superseded (disputes now read-only) |
| **C. Frontend** | C1–C12 | 8 fixed | C5 (BE→FE-12), C9 (GA, FE-8) | C6 (RSC, FE-6) |
| **D. Cross-layer** | D1–D6 | D1 (ABI sync, +CI), D4 (.env.example), D6 (auth bounds) | D2 (state machine, XL-1), D3 (interfaces, XL-2), D5 (CI done, CD open) | — |

\*A1 (ABI sync) is verified fixed at the contract level and enforced by the `abi-sync` CI job; all three ABI sources are byte-identical.

**Net:** the project moved from "broken core plumbing" (broken ABIs, no pooling, no tests, redirect-based auth) to "working system with production-hardening gaps." The new issues in this plan are mostly the *next layer* of concerns — money-path edge cases, multi-tenant security, recoverability, and operational readiness — that surface once the basics work.

