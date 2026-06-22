# Local Run

This setup runs the full stack locally:

- Postgres at `localhost:5432`
- Hardhat JSON-RPC/WebSocket at `localhost:8545`
- Backend at `http://localhost:8000`
- Frontend at `http://localhost:3000`

The local Hardhat deployment uses the deterministic first contract address:

```text
0x5FbDB2315678afecb367f032d93F642f64180aa3
```

## Start

```bash
docker compose up --build
```

Or:

```bash
make local-up
```

Open:

```text
http://localhost:3000
```

## Wallet

Add the local Hardhat network to MetaMask:

```text
Network name: Hardhat Local
RPC URL: http://localhost:8545
Chain ID: 31337
Currency symbol: ETH
```

Import one of the private keys printed by the `hardhat` container logs.

## Local Services

File uploads are stored in the backend container volume and served from:

```text
http://localhost:8000/api/uploads/...
```

Email sending is disabled locally. Verification links are printed in backend logs.

JWT PEM keys are optional locally. If the example placeholders are used, the backend generates an ephemeral development keypair at boot.

## Reset

```bash
docker compose down -v
```

Or:

```bash
make local-reset
```

This removes Postgres data, uploaded files, and installed container dependencies.
