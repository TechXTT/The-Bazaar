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

## 6. Parallelization: 5 worker agents + coordinator
To maximize throughput, work is parallelized one agent per isolated git repo
(separate working tree/index/build gate per submodule; a 2nd agent in the same
submodule would race those). Streams: backend, contract, frontend-redesign (F1),
root infra/CI/docs, and a frontend money-path agent (F2).

**Frontend worktree split.** The frontend is the long pole and `SendMessage`
(to re-scope the running F1 agent) is unavailable here, so F2 runs in a linked
**git worktree** of `bazaar-frontend` at
`~/Documents/Claude/Projects/bazaar-frontend-money-path` on branch
`feat/vault-money-path`. F1 (`feat/vault-redesign`) owns the visual redesign +
all screens; F2 owns money-path correctness (FE-3/1/2/12/13/4/15/9) in
`app/cart/**`, `api/**`, `redux/**`, `utils/helpers.ts`, `package.json`. They run
on separate branches so they never collide at runtime; the coordinator merges
`feat/vault-money-path` → `feat/vault-redesign` at integration, preferring F2's
implementation for money-path files where the redesign also touched them.

## 7. FE-3 price denomination model (revisit if undesired)
The critical FE-3 bug was that one numeric `Price` was charged as either ETH or
USDC with no conversion. Chosen fix: **price is ETH-denominated** (one source-of-
truth number per listing). ETH checkout pays it verbatim; USDC checkout converts
at `NEXT_PUBLIC_USDC_PER_ETH` (`round(price × rate × 1e6)`), and USDC is only
offered when that rate is configured — when unset the token toggle is hidden and
checkout guards against it, so a buyer can never pay a token the price isn't
denominated in. All on-chain amounts derive solely from `priceToOnChainAmount()`.
**Why this default:** it's the smallest change that makes pricing correct without
introducing a price-feed oracle dependency. If the product wants USD-denominated
listings or per-currency prices instead, this is the place to change.

## 9. Frontend: F1 canonical, F2 superseded; visual redesign blocked on Figma
**F2 superseded.** Because `SendMessage` was unavailable (couldn't re-scope the
running F1 agent) and Figma was headless-unavailable, F1 pivoted to implementing
the same money-path items (FE-1/2/3/4/9/12/13/15) I had carved out for the F2
worktree — with its own implementations — *and* did the redesign-adjacent items
(FE-5/6/7/8/10/11/14) + the token foundation. F1's `feat/vault-redesign` is thus a
strict superset. Merging F2's `feat/vault-money-path` would be pure conflict
tax for zero gain, so F2 is **not merged**; its worktree is removed and the branch
kept for reference (reversible — nothing discarded irreversibly).

Notable divergence resolved in F1's favor: **FE-3** — F1 denominates each listing
in its own `Unit` field (default ETH, USDC iff `Unit=="USDC"`, mixed-currency carts
blocked, buyer toggle removed); F2's alternative used a global `NEXT_PUBLIC_USDC_PER_ETH`
rate. F1's per-listing model needs no global rate/oracle, so it's canonical.

**Visual redesign BLOCKED on Figma MCP.** `get_variable_defs`/`get_design_context`/
`get_screenshot` require a live selection in the Figma desktop app; headless they
return "nothing selected." F1 built the Vault token foundation + component library
from the `CLAUDE_CODE_PROMPT.md` token quick-reference, but the pixel-accurate
screen-by-screen rebuild (and screenshot verification) of the ~14 screens cannot be
done without Figma access. **This is the one genuinely-blocking external dependency.**
Options for the user: (a) open the Figma file (key `EcYrT6j1UBpK8rNTojraWI`) in the
desktop app and select nodes so the MCP can read them; or (b) accept the token-driven
approximation and have an agent restyle screens against the quick-reference only.

## 8. Irreversible actions deferred (per operating rules)
- **INFRA-4** (merge `feature/shipment-escrow` → `main` across all repos) requires pushing
  shared branches; will be prepared as PRs only, not pushed/merged autonomously.
- No contract deployment/upgrade to any network; contract work is code + tests only.
  A `SECURITY.md` note (external audit required before mainnet) will be added in Phase 4.
- No secret rotation/commits; example env will be sanitized (SEC-1) but no real secrets touched.
