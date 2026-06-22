# Contributing

The Bazaar is a git-submodule superproject: the root repo pins specific commits
of three submodules (`bazaar-backend`, `bazaar-frontend`, `bazaar-contract`).
Most code changes happen **inside a submodule**; the superproject only advances
the pinned pointer once the submodule change is merged.

## Branch model

- Active development happens on the `feature/shipment-escrow` line across all
  repos; `main` is the stable line.
- Branch per change off the appropriate base; open a PR into that base.
- Keep the superproject and submodules on matching branches so a recursive clone
  resolves to a coherent state.

## Submodule workflow

Clone (or initialize) recursively:

```bash
git clone --recurse-submodules <repo-url>
# already cloned flat?
git submodule update --init --recursive
```

Making a change inside a submodule:

```bash
cd bazaar-backend            # or -frontend / -contract
git checkout -b my-change
# ... edit, commit, push within the submodule's own repo, open its PR ...
```

Advancing the superproject pointer (done by the **coordinator** after the
submodule PR merges — do not bump pointers in unrelated PRs):

```bash
git submodule update --remote bazaar-backend
git add bazaar-backend
git commit -m "chore(root): bump bazaar-backend pointer"
```

> **Boundary:** changes to submodule contents belong in the submodule repo.
> Superproject PRs should touch only root files (`.github/`, `docker-compose*.yml`,
> `docs/`, `README.md`, `Makefile`, etc.) except for the deliberate pointer bumps
> above.

## ABI sync

The Escrow ABI is byte-identical across the contract artifact,
`bazaar-backend/Escrow.json`, and `bazaar-frontend/escrow_abi.ts`. If you change
the contract interface, regenerate and re-commit all three copies — CI's
`abi-sync` job will fail otherwise.

## Commit conventions

Use Conventional Commits. Scope root-level superproject changes with `(root)`:

```
ci(root): CI-1 add lint + audit jobs
chore(root): INFRA-5 harden compose secrets
docs(root): DOC-1 write README + docs
feat(backend): ...      # inside the backend submodule
```

Common types: `feat`, `fix`, `chore`, `ci`, `docs`, `test`, `refactor`.

## Before you push

Run the relevant checks locally (mirrors CI):

- Backend: `go test ./... && go vet ./...` and `golangci-lint run`.
- Frontend: `pnpm exec tsc --noEmit && pnpm run build && pnpm exec next lint`.
- Contract: `npx hardhat compile && npx hardhat test`, plus `npx solhint`.
- Stack: `make local-up` and exercise the e2e suite under `bazaar-frontend/e2e`.

CI additionally runs dependency/vuln audits, secret scanning (gitleaks), Slither,
and a coverage gate — see `.github/workflows/ci.yml`.
