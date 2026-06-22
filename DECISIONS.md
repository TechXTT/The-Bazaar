# Decisions Log

Ambiguities resolved during the autonomous build, per the operating rule
"make the reasonable choice, record it, and keep going."

## 1. Workspace = `Claude/Projects/The-Bazaar`, not the `Github` clone
Two clones of The-Bazaar exist on disk with the same upstream remote. The session
launched in `~/Documents/Github/The-Bazaar` (branch `main`, old submodule pointers,
no specs), but all specs, prior redesign work, and the `feature/shipment-escrow`
submodule branches live in `~/Documents/Claude/Projects/The-Bazaar`.
**Decision:** all work happens in the Claude/Projects clone. Confirmed with user.

## 2. Spec authority: IMPROVEMENT_PLAN.md > ROADMAP.html
`IMPROVEMENT_PLAN.md` (line-level audit with file:line refs, severities, fixes) is
the authoritative fix spec. `ROADMAP.html` is the visual roadmap (optional).
`DESIGN.md` documents the order lifecycle (and is itself stale per XL-1 — it omits
`shipped`/`disputed`; XL-1 will update it). The Figma file (key
`EcYrT6j1UBpK8rNTojraWI`) is authoritative for the visual redesign.

## 3. Branch strategy
- `bazaar-backend`, `bazaar-contract`: `fix/improvement-plan` (branched off `feature/shipment-escrow`).
- `bazaar-frontend`: `feat/vault-redesign` carries **both** the redesign and the FE-* fixes,
  because Phase 2 of the build intertwines them (money-path screens are rebuilt while
  FE-1/FE-2/FE-3 are fixed). A separate `fix/improvement-plan` frontend branch would create
  artificial merge conflicts on the same files.

## 4. Node 25.9 vs Hardhat (unsupported) — noted, not blocking
Hardhat prints "Node v25.9.0 is not supported." Compile + 65 tests pass anyway.
Not pinning Node down now; flagged as a risk for the contract toolchain. If contract
work hits Node-related failures, will install a supported LTS via the version manager.

## 5. Irreversible actions deferred (per operating rules)
- **INFRA-4** (merge `feature/shipment-escrow` → `main` across all repos) requires pushing
  shared branches; will be prepared as PRs only, not pushed/merged autonomously.
- No contract deployment/upgrade to any network; contract work is code + tests only.
  A `SECURITY.md` note (external audit required before mainnet) will be added in Phase 4.
- No secret rotation/commits; example env will be sanitized (SEC-1) but no real secrets touched.
