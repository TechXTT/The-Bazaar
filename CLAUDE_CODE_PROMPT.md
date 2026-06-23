# Autonomous build prompt — The Bazaar (Vault redesign + improvement plan)

> Paste everything below the line into Claude Code, running from the root of the `The-Bazaar` monorepo. It is written to be executed autonomously end-to-end.

---

You are an autonomous senior engineer working in **The Bazaar**, a decentralized escrow marketplace organized as a **git-submodule monorepo**:

- `bazaar-contract/` — Solidity 0.8.19 escrow + arbitration (Hardhat, OpenZeppelin).
- `bazaar-backend/` — Go 1.21 API (gorilla/mux, samber/do, GORM/Postgres) with SIWE auth and an on-chain event observer.
- `bazaar-frontend/` — Next.js 13 App Router, TypeScript (strict), Redux Toolkit, ethers v6, MetaMask SDK, Tailwind, Playwright e2e.

Each submodule is its own git repo. The superproject pins each via a commit SHA; CI includes an **ABI-sync job** and a full-stack Playwright e2e job.

## Your mission (two workstreams, one delivery)

1. **Implement the "Vault" redesign** in `bazaar-frontend/` — a premium, dark-first, escrow-native design language (tokens → component library → every screen, with states and responsive variants).
2. **Implement the improvement plan** in `IMPROVEMENT_PLAN.md` (repo root) — security, reliability, correctness, testing, observability, infra — across all three components, in its prioritized phase order.

`IMPROVEMENT_PLAN.md` is the **authoritative spec for the fixes** (every item has an ID, file refs, severity, effort, and a concrete fix). `ROADMAP.html` shows the phasing. The **Figma file is the authoritative spec for the visual design** (see "Design reference" below). Read all three before starting.

## Operating rules (autonomy + safety)

- **Work in branches, commit constantly.** In each submodule create `feat/vault-redesign` (frontend) and `fix/improvement-plan` (or per-phase branches). Make small, atomic commits with clear messages referencing item IDs (e.g. `fix(backend): BE-1 pin CORS origins, reject * with credentials`). After finishing a phase in a submodule, open a PR for that submodule and bump the submodule pointer in the superproject.
- **Never break the build. Gate every phase** on: frontend `pnpm install && pnpm tsc --noEmit && pnpm lint && pnpm build`; backend `go build ./... && go vet ./... && go test ./...`; contract `npx hardhat compile && npx hardhat test && npx hardhat coverage`. Fix failures before moving on.
- **Keep the ABI in sync.** Any contract change → `npx hardhat compile`, then update `bazaar-backend/Escrow.json` and `bazaar-frontend/escrow_abi.ts` from the artifact so the `abi-sync` CI job stays green.
- **Do NOT do anything irreversible.** Never deploy or upgrade contracts to any live/testnet network, never move funds, never rotate/commit secrets, never force-push shared branches, never `git push` to `main`. Smart-contract changes are code + tests only; add a note that a professional third-party audit is required before mainnet.
- **Preserve behavior while redesigning.** The redesign is visual/UX — keep all web3 logic, Redux state, API calls, and routes working. Where the plan says a money-path screen has a bug (FE-1/FE-2/FE-3), fix the logic as you rebuild that screen.
- **Don't weaken security to make things pass.** (e.g. keep the CORS fix strict; keep auth on protected routes.)
- **When something is ambiguous, make the reasonable choice, record it in `DECISIONS.md` (repo root), and keep going.** Only stop if you hit a truly blocking external dependency (missing credentials, a needed paid service). Otherwise do not wait for input.
- **Track progress in `PROGRESS.md`** (repo root): a checklist of every plan item ID and redesign screen, updated as you complete each, with the commit/PR that addressed it.

## Design reference (Figma)

Use the Figma MCP to read exact specs. **File key: `EcYrT6j1UBpK8rNTojraWI`** (`https://www.figma.com/design/EcYrT6j1UBpK8rNTojraWI`).

For each component/screen, call the Figma MCP on its node ID to extract exact values:
- `get_variable_defs` on the Design System page for tokens, `get_design_context` for layout/structure/auto-layout/styles, `get_screenshot` to verify your built result matches.

**Node map** (page → node id):
- Pages: Cover `0:1` · Design System `1:2` · Buyer Flows `1:3` · Seller·Auth·Dispute `1:4` · States·Mobile `1:5`
- Components: Button `5:13` · StatusBadge `5:33` · ProductCard `6:5` · StoreCard `6:20` · Navbar `8:2` · Footer `9:2` · SellerSidebar `25:2`
- Buyer: Home `10:2` · Product detail `15:162` · Stores `17:210` · Store detail `24:378` · Cart `18:306` · Checkout `19:324` · Orders `20:342` · Order detail `21:360`
- Seller/Auth/Dispute: Wallet connect `28:31` · Seller dashboard `26:2` · Seller orders `31:49` · Dispute detail `29:31` · Product editor `32:78` · Account settings `33:121`
- States/Mobile: Mobile Home `34:2` · Mobile Product `35:30` · Empty cart `36:30` · 404 `36:37` · Loading skeleton `37:30`

If the Figma MCP is unavailable in your environment, fall back to this token quick-reference (the Figma file remains authoritative for spacing/layout detail):

- **Color (dark):** bg `#0B0E14` · surface `#121724` · surface-2 `#1A2030` · surface-3 `#222A3D` · inset `#0E121B` · border `#222A39` / strong `#313C50` / accent-border `#3B3FB0` · text `#E8EDF6` / secondary `#A6B2C4` / tertiary `#6C7689` / on-accent `#FFFFFF` · accent `#6366F1` · violet `#8B5CF6` · accent-soft `#191B36` · success `#10B981` / soft `#0E2A22` · warning `#F59E0B` / soft `#2C2410` · danger `#F85149` / soft `#2C1719` · info `#38BDF8`.
- **Radius:** 6 / 8 / 12 / 16 / 20 / 28 / 999.
- **Type (Inter):** Display XL 56/60/-2% · Display L 44/48/-2% · H1 32/38 · H2 24/30 · H3 20/26 · Title 16/22 (600) · Body-L 17/27 · Body 15/23 · Body-Strong 15/23 (500) · Label 13/18 (500) · Caption 13/18 · Overline 11/14 (600, +8% tracking, UPPERCASE).
- **Effects:** card shadow (y8 blur24 + y2 blur6) · popover (y16 blur40) · accent glow (indigo, blur28) · success glow (emerald, blur24).
- **Order status colors:** Pending=warning · Shipped=info · Released=accent · Completed=success · Cancelled=tertiary · Disputed=danger.

## Execution plan

Do the phases in order. Run the build/test gate at the end of each. Update `PROGRESS.md` after each item.

### Phase 0 — Baseline & safety net
- Read `IMPROVEMENT_PLAN.md`, `ROADMAP.html`, `DESIGN.md`, and skim each submodule. Get all three components building and their existing tests green. Record the starting state in `PROGRESS.md`. Create the working branches.

### Phase 1 — Frontend design foundation (Vault)
- Encode the tokens as CSS variables + a `tailwind.config.ts` theme (colors, radius, fontSize/lineHeight, boxShadow). Wire Inter.
- Build/upgrade the `components/ui/` library to match the Figma components (Button, StatusBadge with all 6 states, Input/Field, Textarea, Badge, Card, ProductCard, StoreCard, Navbar, Footer, SellerSidebar, Skeleton, Spinner, escrow Stepper, segmented токen toggle, toggle/switch). Pull exact specs from Figma per the node map.
- Gate, commit, PR.

### Phase 2 — Frontend redesign screens + money-path fixes
- Rebuild every screen to match Figma, reusing the new components: Home, Stores, Store detail, Product detail, Cart, Checkout, Orders, Order detail/tracking, Wallet connect (SIWE), Seller dashboard, Seller orders, Product editor, Account settings, Dispute detail, plus empty/loading/error states and the mobile/responsive variants.
- While rebuilding the cart/checkout, **fix FE-1, FE-2, FE-3** (atomic, correlation-safe multi-order checkout; correct ETH vs USDC denomination/amounts). Also do **FE-4** (stop persisting JWT to localStorage), **FE-5** (re-sync the e2e wallet fixture ABI), and the remaining frontend items (FE-6…FE-15) from the plan.
- Keep Playwright e2e passing; update specs to the new DOM where needed. Verify each screen against `get_screenshot`. Gate, commit, PR.

### Phase 3 — Backend launch-blockers & reliability (BE-1…BE-9, BE-13, BE-14)
- Implement in plan order: BE-1 CORS, BE-2 observer panic guards + recover, BE-4 order-creation transaction, BE-3 graceful shutdown + cancellable contexts, BE-5 upload hardening, BE-6 rate limiting, BE-7 de-duplicate models, BE-8 observer error handling, BE-9 dispute→order status, BE-13 soft-delete, BE-14 versioned migrations. Add tests as you go.

### Phase 4 — Contract fixes & tests (SC-1…SC-7, test gaps)
- SC-1 dispute-griefing, SC-2 `rule()` mapping verification, SC-5 Ownable2Step/admin, SC-6 pull-payment refunds, SC-4 rescue, SC-3 fee snapshot, SC-7 fee-on-transfer-safe accounting. Add the missing tests (unpause, dispute/reclaim interaction, `rule()` wrong-ID, reverting-recipient settlement) and keep coverage high. Regenerate + sync ABIs. Add a `SECURITY.md` note: external audit required before mainnet.

### Phase 5 — Testing, observability, hardening (BE-10…BE-21, XL-1/2, DEP-1)
- Backend test suite (BE-11), readiness/metrics/structured logs (BE-15), JWT hardening (BE-16), pagination (BE-10), money types (BE-18), single OrderStatus source of truth + typed frontend enum (XL-1/XL-2), and upgrade Next.js off 13.5.4 + fix the broken `react` dep (DEP-1, FE-9).

### Phase 6 — Infra, CI/CD, docs (INFRA-1…5, CI-1, DEP-2, DOC-1, SEC-1/2)
- Multi-stage Dockerfiles per component + split dev/prod compose + healthchecks/secrets (INFRA-1/5), CI lint+audit+secret-scan+Slither (CI-1), commit untracked docs & expand `.gitignore` (INFRA-2/3), real README + architecture/deploy docs (DOC-1), sanitize example env + GA-ID to config (SEC-1/2), one package manager + Go version align (DEP-2).

## Definition of done
- All three components build, lint, typecheck, and test green; contract coverage maintained; ABI byte-identical across the three layers; Playwright e2e green.
- Every screen visually matches its Figma node (verify via `get_screenshot`), is responsive, and keeps its web3/data behavior.
- Every `IMPROVEMENT_PLAN.md` item is implemented or, if intentionally deferred, listed in `PROGRESS.md` with a reason.
- `PROGRESS.md` and `DECISIONS.md` are complete; PRs opened per submodule with summaries; superproject submodule pointers bumped. No secrets committed; no contract deployed.

Begin with Phase 0 now. Work autonomously through to Phase 6, gating on builds/tests at each step, and keep `PROGRESS.md` current.
