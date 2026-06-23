# The Bazaar — Improvement Plan

> Generated 2026-05-27 via graphify dependency graph (643 nodes · 873 edges) + full source audit.
> Graph outputs: `graphify-out/graph.html` (interactive), `graphify-out/GRAPH_REPORT.md`.

---

## Suggested Execution Order

Fix in this sequence to unblock dependent work:

1. **A1, D1** — Regenerate both ABI files from the live contract first. Every other cross-layer issue depends on accurate ABIs.
2. **B1** — Fix DB connection pool (one line change, prevents prod outage under any real load).
3. **B2** — Fix observer ABI event subscription (system can't track order lifecycle at all right now).
4. **A6 + B12** — Add `released` to DB enum and fix the Disputes `primaryKey` tag (data integrity).
5. **B5** — Fix `CreateDispute` authorization bug (security: anyone can create a dispute for any order).
6. **B4** — Protect `GET /api/products/orders/{id}` with auth (security: order data exposed publicly).
7. **C3** — Fix `forEach` async bug in checkout (functional: multiple-item cart silently corrupts escrow state).
8. **C5** — Fix register redirect (UX blocker for new users).
9. **B3** — Fix auth middleware to return JSON 401 instead of redirect.
10. **B7** — Add multipart size limit to product upload (security: DoS vector).
11. All remaining Medium/Low items can proceed in parallel by layer.

---

## A. Smart Contract (`bazaar-contract`)

---

### A1 — ABI Mismatch Between Contract Source and Exported ABIs

**Priority: 🔴 Critical**

**Problem:**
`contracts/Escrow.sol` and both `bazaar-backend/Escrow.json` + `bazaar-frontend/escrow_abi.ts` describe completely different contracts. The ABI files appear to be from an earlier version.

| Entity | In `Escrow.sol` | In `Escrow.json` / `escrow_abi.ts` |
|---|---|---|
| `claimOrder` (singular) | ✅ | ❌ missing |
| `claimOrders` (batch) | ✅ | ✅ |
| `releaseOrder` | ✅ | ❌ missing |
| `refundOrder` | ✅ | ❌ missing |
| `getUserIncompleteOrders` | ✅ | ❌ missing |
| `getUserCompleteOrders` | ✅ | ❌ missing |
| `getUserOrders` | ❌ does not exist | ✅ in ABI (phantom) |
| `userOrders` mapping | ❌ does not exist | ✅ in ABI (phantom) |
| Event `OrderReleased` | ✅ | ❌ missing |
| Event `OrderRefunded` | ✅ | ❌ missing |

**Impact:**
- Frontend `getUserOrders` call will always revert (function doesn't exist on-chain).
- Backend observer subscribes to `OrderRefunded`/`OrderReleased` topics that are zero-hashes — these events are never delivered.
- Entire order lifecycle backend tracking is broken (see B2).

**Fix:**
```bash
cd bazaar-contract
npx hardhat compile
# Copy artifacts/contracts/Escrow.sol/Escrow.json .abi array to:
cp artifacts/contracts/Escrow.sol/Escrow.json abi_only.json
# Then update:
# - bazaar-backend/Escrow.json  ← replace with new ABI array
# - bazaar-frontend/escrow_abi.ts  ← replace ABI export
```
Then update frontend to use `getUserIncompleteOrders`/`getUserCompleteOrders` instead of `getUserOrders`.

---

### A2 — Missing Reentrancy Guard on ETH Transfer Functions

**Priority: 🟠 High**

**Problem:**
`claimOrder`, `claimOrders`, and `refundOrder` all transfer ETH to external addresses via `.transfer()`. Although the Checks-Effects-Interactions pattern is followed (state set to `completed=true` before transfer), there is no `nonReentrant` modifier and no formal reentrancy guard.

- `claimOrder` (`Escrow.sol:79`): `payable(msg.sender).transfer(orderInfo.amount)` — correct CEI order.
- `claimOrders` (`Escrow.sol:105`): batch transfer after all state changes — correct.
- `refundOrder` (`Escrow.sol:44`): `payable(orderInfo.buyer).transfer(orderInfo.amount)` — correct CEI order.

The `_moveOrder` helper is called **after** the `transfer` in `claimOrder` (`Escrow.sol:82`) and inside the loop in `claimOrders` before the batch transfer (`Escrow.sol:100`). This is safe now, but fragile against future edits.

**Fix:**
```solidity
// Add to Escrow.sol
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    function claimOrder(bytes32 orderId) external nonReentrant { ... }
    function claimOrders(bytes32[] memory orderIds) external nonReentrant { ... }
    function refundOrder(bytes32 orderId) external nonReentrant { ... }
}
```

---

### A3 — Gas Inefficiency: O(n) Linear Scan in `_moveOrder`

**Priority: 🟡 Medium**

**Problem:**
`_moveOrder` (`Escrow.sol:116-125`) does a linear scan through `incompleteOrders[user]` to find and remove an entry. For a user with many orders this costs O(n) gas and can make claims prohibitively expensive or hit the block gas limit.

**Fix:** Use an `EnumerableSet` from OpenZeppelin, or track array index in a mapping:
```solidity
mapping(bytes32 => uint256) private _incompleteOrderIndex;
// On add: _incompleteOrderIndex[orderId] = incompleteOrders[user].length;
// On remove: swap-and-pop using stored index — O(1)
```

---

### A4 — Pragma Version Inconsistency

**Priority: 🟡 Medium**

**Problem:**
`Escrow.sol:3` uses `pragma solidity ^0.8.0` (accepts any 0.8.x), but `hardhat.config.ts` pins the compiler to `0.8.19`. A loose pragma allows recompilation under future compiler versions with different codegen behaviour.

**Fix:** `Escrow.sol:3`: `pragma solidity 0.8.19;`

---

### A5 — No Optimizer Configured in Hardhat

**Priority: 🟢 Low**

**Problem:**
`bazaar-contract/hardhat.config.ts` has no Solidity optimizer settings. The contract will deploy with unoptimized bytecode, increasing deployment cost and per-call gas.

**Fix:**
```typescript
// hardhat.config.ts
solidity: {
  version: "0.8.19",
  settings: {
    optimizer: { enabled: true, runs: 200 },
  },
},
```

---

### A6 — Test Coverage Gaps

**Priority: 🟠 High**

**Problem:** `bazaar-contract/test/Escrow.ts` has multiple coverage gaps and at least two **incorrect** tests:

1. **`refundOrder` tests have buyer/seller roles swapped** (`Escrow.ts:99,108`):
   - Line 99: `"Should revert if caller is not the receiver"` uses `sellerAddress` — who IS the receiver — so this test will NOT revert. The assertion is wrong.
   - Line 108: `"Should refund the order"` uses `buyerAddress` — who is NOT the receiver — so this will revert, failing the positive test.

2. **`releaseOrder` function is entirely untested.** This function sets a `release` flag that bypasses the time check in `claimOrder` — a critical path with zero coverage.

3. **No test for `claimOrders` (batch).**

4. **Events are never verified** — none of the `it()` blocks assert that events were emitted (`expect(...).to.emit(escrow, "OrderCompleted").withArgs(...)`).

5. **No test for `getUserIncompleteOrders`/`getUserCompleteOrders` after the full lifecycle.**

6. **No test for the `release` bypass path** (buyer calls `releaseOrder`, then seller calls `claimOrder` before `releaseTime`).

7. **Deploy script mismatch** (`scripts/deploy.ts` passes `[unlockTime]` as constructor arg, tests deploy with `Escrow.deploy()` and no args). The contract has no constructor — the deploy script is wrong.

**Fix:** Correct the buyer/seller swap on lines 99 and 108, add `releaseOrder` test suite, add event assertions throughout, fix `deploy.ts` to match the no-constructor contract.

---

### A7 — Missing Contract Features vs. Backend/Frontend Expectations

**Priority: 🟠 High**

**Problem:**
- Frontend `checkout/index.tsx:71` hardcodes a 14-day release time. This is not enforced or configurable via the contract — the receiver can immediately set `release=true` via `releaseOrder` and claim. The 14-day default should be a contract constant or emit an event the frontend can read.
- There is no `pause` or `admin` mechanism for emergency situations (stuck funds).
- `orders` mapping is `public` which exposes internal struct details. Consider a purpose-built view function.

---

## B. Backend (`bazaar-backend`)

---

### B1 — DB Connection Pool Anti-Pattern

**Priority: 🔴 Critical**

**Problem:**
`services/db/db.go:72-88` — `DB()` calls `gorm.Open()` on every invocation, establishing a new TCP connection to Postgres each time. Since every service method calls `p.db.DB()` at the start (e.g., `service.go:77`, `service.go:95`, `observer.go:74`), every single database operation opens a brand new connection and never reuses or pools.

Under any real traffic this exhausts Postgres's `max_connections` limit and causes cascading failures.

**Fix:** Store `*gorm.DB` once at `NewDB` time:
```go
// services/db/db.go
type db struct {
    cfg  config.Config
    conn *gorm.DB   // add this
}

func NewDB(i *do.Injector) (DB, error) {
    cfg := do.MustInvoke[config.Config](i)
    conn, err := gorm.Open(postgres.New(postgres.Config{
        DSN: buildDSN(cfg.GetDB()),
        PreferSimpleProtocol: true,
    }), &gorm.Config{})
    if err != nil { return nil, err }

    sqlDB, _ := conn.DB()
    sqlDB.SetMaxOpenConns(25)
    sqlDB.SetMaxIdleConns(10)
    sqlDB.SetConnMaxLifetime(5 * time.Minute)

    // run migrations ...
    return &db{cfg: cfg, conn: conn}, nil
}

func (d *db) DB() *gorm.DB { return d.conn }
```
Also remove `NewConnectionPerFunc` anti-pattern node — it's not needed once the above is done.

---

### B2 — Observer: ABI Missing Events → Order Status Never Updated

**Priority: 🔴 Critical**

**Problem:**
`services/observer/observer.go:62-64`:
```go
Topics: [][]common.Hash{
    {contractABI.Events["OrderCompleted"].ID,
     contractABI.Events["OrderRefunded"].ID,   // NOT in Escrow.json → zero hash
     contractABI.Events["OrderReleased"].ID},  // NOT in Escrow.json → zero hash
},
```
Because `OrderRefunded` and `OrderReleased` don't exist in `Escrow.json`, `contractABI.Events[...]` returns a zero `abi.Event` struct. The filter includes the zero hash which matches no real event. Statuses `"cancelled"` and `"released"` are **never set**.

Additionally, `RunSubscription:115` unconditionally tries to unpack every received log as `"OrderCompleted"`:
```go
err := contractABI.UnpackIntoMap(eventMap, "OrderCompleted", vLog.Data)
```
If `OrderRefunded` or `OrderReleased` events ever arrive (after the ABI fix), this will fail and cause the observer to exit.

There is also no reconnect/retry logic — a single WebSocket error terminates the observer permanently.

**Fix (after A1 ABI update):**
```go
// Unpack based on actual topic
switch vLog.Topics[0].Hex() {
case contractABI.Events["OrderCompleted"].ID.Hex():
    if err := contractABI.UnpackIntoMap(eventMap, "OrderCompleted", vLog.Data); err != nil {
        log.Println("unpack OrderCompleted:", err)
        continue
    }
    // update status ...
case contractABI.Events["OrderRefunded"].ID.Hex():
    if err := contractABI.UnpackIntoMap(eventMap, "OrderRefunded", vLog.Data); err != nil { continue }
    // update status ...
case contractABI.Events["OrderReleased"].ID.Hex():
    // ...
}
```
Add exponential-backoff reconnect loop around `RunSubscription`:
```go
for {
    if err := o.RunSubscription(abiPath); err != nil {
        log.Printf("observer exited (%v), reconnecting in %s", err, backoff)
        time.Sleep(backoff)
        backoff = min(backoff*2, 5*time.Minute)
    }
}
```

---

### B3 — Auth Middleware Returns HTTP Redirect Instead of 401 JSON

**Priority: 🟠 High**

**Problem:**
`services/middleware/middleware.go:42,49`:
```go
http.Redirect(w, r, "/login", http.StatusUnauthorized)
```
Returning a 302 redirect from a REST API is wrong. Axios clients will follow the redirect to `/login` and receive an HTML or 404 response, making error handling impossible.

**Fix:**
```go
w.Header().Set("Content-Type", "application/json")
w.WriteHeader(http.StatusUnauthorized)
json.NewEncoder(w).Encode(map[string]string{"error": "unauthorized"})
return
```

---

### B4 — Order Detail Endpoint Publicly Accessible

**Priority: 🟠 High**

**Problem:**
`GET /api/products/orders/{id}` is on the public subrouter (no `AuthMiddleware`). Anyone can fetch any order's details, including buyer IDs, amounts, statuses, and tx hashes.

**Fix:** Move `productsHandler.GetOrder` from the public route group to the authenticated route group in `modules/products/products.go`. Add a check that the requesting user is the buyer or the product's store owner.

---

### B5 — `CreateDispute` Authorization Checks Wrong ID

**Priority: 🟠 High**

**Problem:**
`modules/disputes/service.go:45`:
```go
WHERE orders.id = ?;
`, userId, userId, d.ID)
```
`d` is a freshly decoded `*Disputes{}` struct — `d.ID` is the dispute ID which is zero (UUID nil) before creation. The WHERE clause should use `d.OrderID`, which is the ID of the order being disputed. As written, the authorization check either matches no rows (role returns empty string, not "unrelated") or behaves unpredictably.

**Fix:** `service.go:45`: change `d.ID` → `d.OrderID`:
```go
WHERE orders.id = ?;
`, userId, userId, d.OrderID)
```

---

### B6 — `Disputes` Model Missing `gorm:"primaryKey"` Tag

**Priority: 🟠 High**

**Problem:**
`services/db/models.go:75`:
```go
type Disputes struct {
    gorm.Model                                // embeds uint ID
    ID       uuid.UUID `gorm:"not null"`      // ← missing primaryKey
    ...
```
`gorm.Model` embeds a `uint` field called `ID`. The `uuid.UUID ID` field declared here conflicts without the `gorm:"primaryKey"` tag. GORM will use the embedded uint `ID` as the primary key, making UUID-based lookups fail silently.

**Fix:** `services/db/models.go:75`:
```go
ID uuid.UUID `gorm:"primaryKey;type:uuid"`
```

---

### B7 — No Multipart Size Limit on Product Image Upload

**Priority: 🟠 High**

**Problem:**
`modules/products/handler.go:70`: `r.FormFile("image")` is called without first setting a request body size limit. A client can send an arbitrarily large file, causing OOM or disk exhaustion. The disputes handler correctly uses `r.ParseMultipartForm(10 << 20)` (10 MB), but products does not.

**Fix:** `modules/products/handler.go:64`, before `r.FormFile`:
```go
r.Body = http.MaxBytesReader(w, r.Body, 10<<20) // 10 MB
if err := r.ParseMultipartForm(10 << 20); err != nil {
    http.Error(w, `{"error":"file too large"}`, http.StatusRequestEntityTooLarge)
    return
}
```

---

### B8 — Inconsistent Error Response Format

**Priority: 🟠 High**

**Problem:**
All handlers use `http.Error(w, err.Error(), statusCode)` which returns plain text, but `disputes/handler.go:63` returns `json.NewEncoder(w).Encode(map[string]string{"id": id})`. API clients cannot reliably distinguish error bodies.

**Fix:** Create a shared error helper and use it everywhere:
```go
// pkg/httputil/errors.go
func WriteError(w http.ResponseWriter, code int, msg string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
```
Replace all `http.Error(w, err.Error(), ...)` calls.

---

### B9 — N+1 Queries in `CreateOrders`

**Priority: 🟠 High**

**Problem:**
`modules/products/service.go:108-136`: for every order item in the loop, `p.GetProduct()` is called (`service.go:110`), which itself calls `p.db.DB()` (new connection), then queries products with a JOIN on Store. For a cart with N items: N new connections + N product queries + N owner queries = O(3N) connections.

**Fix:** Batch load all products before the loop:
```go
productIDs := make([]uuid.UUID, len(ordersData))
for i, o := range ordersData { productIDs[i] = o.ProductID }

var products []Products
db.Preload("Store.Owner").Where("id IN ?", productIDs).Find(&products)

productMap := make(map[uuid.UUID]*Products, len(products))
for i := range products { productMap[products[i].ID] = &products[i] }

for _, orderData := range ordersData {
    product := productMap[orderData.ProductID]
    // ... rest of logic
}
```

---

### B10 — `OrderStatus` Enum Missing `"released"` Value

**Priority: 🟠 High**

**Problem:**
`services/db/models.go:58`:
```go
Status OrderStatus `gorm:"not null, type:ENUM('pending', 'completed', 'cancelled')"`
```
The observer (`observer.go:141`) can set status to `"released"` via `UpdateOrderStatus`. PostgreSQL ENUM constraint will reject this, causing a silent failure (error not checked, see B11).

**Fix:** Add `released` to the enum and the Go constant:
```go
const (
    OrderStatusPending   OrderStatus = "pending"
    OrderStatusCompleted OrderStatus = "completed"
    OrderStatusCancelled OrderStatus = "cancelled"
    OrderStatusReleased  OrderStatus = "released"   // add
)
// models.go:58:
Status OrderStatus `gorm:"not null;type:varchar(20);default:'pending'"`
```
Note: GORM AutoMigrate cannot alter ENUM types after creation. Prefer `varchar` with application-level validation.

---

### B11 — `UpdateOrderStatus` Silently Ignores DB Errors

**Priority: 🟠 High**

**Problem:**
`services/observer/observer.go:74-78`:
```go
func (o *observer) UpdateOrderStatus(orderID string, status string) error {
    db := o.db.DB()
    db.Exec("UPDATE orders SET status = $1 WHERE id = $2", status, orderID)
    return nil  // always returns nil regardless of DB error
}
```
DB errors (connection failure, invalid enum value) are silently discarded.

**Fix:**
```go
result := db.Exec("UPDATE orders SET status = ? WHERE id = ?", status, orderID)
return result.Error
```

---

### B12 — JWT Validation Dead Code / Logic Error

**Priority: 🟡 Medium**

**Problem:**
`services/jwt/jwt.go:77-103`: after `parser.ParseWithClaims` returns `err != nil` at line 77 and executes `return "", err`, lines 85-91 can never be reached. The `errors.Is` checks for `ErrSignatureInvalid` and `ErrTokenExpired` are dead code. Additionally, `claims.ExpiresAt.Time.Before(time.Now())` at line 99 duplicates expiry checking already done by the JWT library.

**Fix:** Remove lines 85-103 and replace with:
```go
if err != nil {
    return "", fmt.Errorf("invalid token: %w", err)
}
claims, ok := parsedToken.Claims.(*jwt.RegisteredClaims)
if !ok || !parsedToken.Valid {
    return "", errors.New("invalid claims")
}
return claims.ID, nil
```

---

### B13 — No JWT Refresh Token Strategy

**Priority: 🟡 Medium**

**Problem:**
Tokens expire after 24 hours (`jwt.go:51`) with no refresh endpoint. Users are silently logged out with no way to renew.

**Fix:** Add a `POST /api/users/refresh` endpoint that accepts a valid (unexpired) token and returns a new one. Or implement refresh tokens stored server-side.

---

### B14 — S3 Configuration Hardcoded and Session Not Reused

**Priority: 🟡 Medium**

**Problem:**
`services/s3spaces/s3spaces.go:47`: `"https://fra1.digitaloceanspaces.com"` is hardcoded. Every `SaveFile` call creates a new AWS session and S3 client with no reuse. The function also returns just the file path (`filepath`), not a full CDN URL, so frontend must hardcode the CDN prefix separately.

**Fix:** Add `SpacesEndpoint` and `SpacesCDNBase` to `S3SpacesConfig`. Initialize S3 client once in `NewS3Spaces` (store on struct). Return full CDN URL:
```go
return fmt.Sprintf("%s/%s/%s", cfg.SpacesCDNBase, cfg.SpacesName, filepath), nil
```

---

### B15 — Email Verification URL Hardcoded to `localhost`

**Priority: 🟡 Medium**

**Problem:**
Email verification link is hardcoded to `http://localhost:3000`. In staging/production, verification emails lead users to localhost (their own machine), not the actual app.

**Fix:** Add `APP_FRONTEND_URL` environment variable, expose it via `AppConfig`, and use it when generating verification links.

---

### B16 — Missing Database Indexes

**Priority: 🟡 Medium**

**Problem:**
GORM `AutoMigrate` creates tables but no indexes beyond primary keys. Columns used in WHERE clauses with no index:
- `orders.buyer_id` — used in `GetOrders` filter
- `orders.product_id` — used in subquery for "sending" filter
- `products.store_id` — used in `GetProductsFromStore`
- `stores.owner_id` — used in join queries
- `disputes.order_id` — used in `GetDispute`, `CreateDispute`

**Fix:** Add `gorm:"index"` tags and/or a dedicated migration file:
```go
type Orders struct {
    BuyerID   uuid.UUID `gorm:"not null;index"`
    ProductID uuid.UUID `gorm:"not null;index"`
    ...
}
```

---

### B17 — No Test Coverage

**Priority: 🟡 Medium**

**Problem:** Zero test files in `bazaar-backend`. No unit tests for services, no integration tests for handlers, no table-driven tests.

**Fix:** Start with table-driven unit tests for `jwt.go` (token generation/validation), service layer tests with mocked DB, and at least one integration test for the auth flow.

---

### B18 — WebSocket Client Panics on Connection Failure

**Priority: 🟡 Medium**

**Problem:**
`services/wsclient/wsclient.go:37`: `InitEthClient` panics if the WebSocket connection fails. In production this crashes the entire backend process.

**Fix:** Return `error` instead of panicking, and propagate to `NewObserver`. The observer should log and retry rather than terminating the app.

---

## C. Frontend (`bazaar-frontend`)

---

### C1 — `forEach` with `async` Loses Errors and Fires Unsequenced

**Priority: 🔴 Critical**

**Problem:**
`app/cart/components/checkout/index.tsx:64`:
```typescript
orderIds.forEach(async (orderId, index) => {
    // ...
    const result = await escrow.createOrder(...)
    dispatch(clearCart())
})
```
`Array.forEach` does not await async callbacks. For a multi-item cart, all `escrow.createOrder` calls are fired in parallel without waiting, and errors thrown inside are silently swallowed. The cart is cleared after the first order regardless of whether subsequent ones succeed.

**Fix:** Use `Promise.allSettled` (or sequential `for...of`) and collect errors:
```typescript
const results = await Promise.allSettled(
    orderIds.map((orderId, index) =>
        escrow.createOrder(orderId.id, orderId.owner_address, timeToRelease, { value })
    )
)
const failures = results.filter(r => r.status === "rejected")
if (failures.length === 0) dispatch(clearCart())
else setError(`${failures.length} order(s) failed`)
```

---

### C2 — No Loading/Transaction-Pending State During Checkout

**Priority: 🟠 High**

**Problem:**
`checkout/index.tsx:19-93`: `handleCheckout` is async and calls the blockchain, but the button has no loading state, disabled state during processing, or transaction hash shown. Blockchain calls on Sepolia can take 30+ seconds. Users have no feedback and can click multiple times.

**Fix:**
```typescript
const [isPending, setIsPending] = useState(false)
const [txHash, setTxHash] = useState("")

// In handleCheckout:
setIsPending(true)
try { ... const result = await escrow.createOrder(...); setTxHash(result.hash) }
finally { setIsPending(false) }

// In JSX:
<button disabled={isPending || !connected} ...>
    {isPending ? "Processing..." : "Checkout"}
</button>
{txHash && <p>TX: <a href={`https://sepolia.etherscan.io/tx/${txHash}`}>{txHash}</a></p>}
```

---

### C3 — Register Page Has No Redirect or Success Feedback After Submission

**Priority: 🟠 High**

**Problem:**
`app/auth/register/page.tsx`: after successful registration (201 response), the user remains on the registration page with no indication that registration succeeded, no redirect to login, and no email verification notice.

**Fix:** After the API call returns 201:
```typescript
router.push("/auth/login?registered=true")
```
And add a login page banner for `?registered=true` telling users to check their email for verification.

---

### C4 — Every API Call Manually Injects Auth Token

**Priority: 🟠 High**

**Problem:**
All authenticated API service functions (`api/services/*.ts`) manually pass `Authorization: Bearer ${token}` in each request headers. This pattern is error-prone — any new endpoint can easily forget the header. The JWT is stored in Redux state, not accessed via an interceptor.

**Fix:** Add a request interceptor to `api/index.ts`:
```typescript
backendAxiosInstance.interceptors.request.use((config) => {
    const state = store.getState()
    const token = state.auth.jwt
    if (token) config.headers.Authorization = `Bearer ${token}`
    return config
})
```
Remove the manual `Authorization` header from all service functions.

---

### C5 — Checkout Response Type Mismatch

**Priority: 🟠 High**

**Problem:**
`checkout/index.tsx:45-46`:
```typescript
const response: AxiosResponse<string[]> = await productsService.createOrders(...)
// ...
response.data.forEach((resp: any) => {
    orderIds.push({ id: messageToBytes32(resp.id), owner_address: resp.owner_address })
})
```
The type annotation says `string[]` but the backend returns `[]OrderResponse{ID, OwnerAddress}`. The `any` cast hides this. TypeScript provides no safety and the shape is only correct by accident.

**Fix:** Define a proper interface in `api/interfaces/products.ts`:
```typescript
export interface IOrderResponse {
    id: string
    owner_address: string
}
```
And type the response as `AxiosResponse<IOrderResponse[]>`.

---

### C6 — All Components Are `"use client"` — No Server Components Used

**Priority: 🟠 High**

**Problem:**
Every `.tsx` file including `app/layout.tsx` has `"use client"`. This disables all Next.js 13 app router server-side rendering benefits: no RSC, no automatic code splitting by server/client, no streaming. The entire app hydrates client-side like a CRA app.

**Fix:**
- `layout.tsx` should not be a client component. Extract the MetaMask SDK provider and Redux provider into a separate `"use client"` `Providers` wrapper.
- Pages that only fetch data and don't need interactivity (e.g., `stores/page.tsx`, `stores/[id]/page.tsx`) can become server components using `async`/`await` with `fetch`.
- Keep `"use client"` only on leaf components that use hooks, event handlers, or browser APIs.

---

### C7 — Missing Suspense Boundary for `useSearchParams`

**Priority: 🟠 High**

**Problem:**
`app/users/[id]/page.tsx` uses `useSearchParams()` without wrapping the component in `<Suspense>`. In Next.js 13+ production builds this throws:
```
Error: useSearchParams() should be wrapped in a suspense boundary
```

**Fix:**
```tsx
// app/users/[id]/page.tsx
import { Suspense } from "react"
export default function UserPage() {
    return (
        <Suspense fallback={<div>Loading...</div>}>
            <UserPageInner />
        </Suspense>
    )
}
```

---

### C8 — WebSocket Dispute Chat Commented Out

**Priority: 🟠 High**

**Problem:**
`app/orders/components/openDispute/index.tsx`: the entire WebSocket dispute messaging feature is commented out. The backend has `services/wsclient/wsclient.go` and the `db/models.go` has a commented-out `Messages` struct. This is an advertised feature that doesn't work.

**Fix:** Either:
1. Implement dispute messaging (uncomment backend `Messages` struct, implement WebSocket handler, implement frontend chat component), or
2. Remove the commented-out code and feature references until it's ready.

---

### C9 — Hardcoded Values That Belong in Config

**Priority: 🟡 Medium**

| Value | Location | Fix |
|---|---|---|
| `0xaa36a7` (Sepolia chain ID) | `navbar/index.tsx:104` | `NEXT_PUBLIC_CHAIN_ID` env var |
| `https://bazaar-space.fra1.digitaloceanspaces.com` (CDN) | Multiple components | `NEXT_PUBLIC_CDN_BASE_URL` env var |
| `G-1H1H1CR559` (Google Analytics ID) | `app/layout.tsx` | `NEXT_PUBLIC_GA_ID` env var |
| `14 * 24 * 60 * 60` (escrow release time) | `checkout/index.tsx:71` | `NEXT_PUBLIC_ESCROW_RELEASE_DAYS` env var |

Add these to `config/config.ts` and `.env.example`.

---

### C10 — TypeScript Strict Mode Not Enabled

**Priority: 🟡 Medium**

**Problem:**
`bazaar-frontend/tsconfig.json` lacks `"strict": true`. This allows implicit `any` types, unchecked nullable accesses, and loose function parameter types. `checkout/index.tsx` declares `const Checkout = (props: any)` — completely untyped.

**Fix:** `tsconfig.json` → `"compilerOptions"`: add `"strict": true`. Fix the type errors that surface (most will be in `props: any` patterns).

---

### C11 — Old Redux `connect()` HOC Pattern

**Priority: 🟢 Low**

**Problem:**
`checkout/index.tsx:144-150` uses the class-era `connect(mapStateToProps)` HOC while all other components use modern `useSelector`/`useDispatch` hooks. Inconsistent.

**Fix:**
```typescript
// Remove connect() and mapStateToProps. Inside Checkout:
const auth = useSelector((state: RootState) => state.auth)
```

---

### C12 — Client-Side JWT Decode Used as Security Guard

**Priority: 🟢 Low**

**Problem:**
`api/services/products.ts:32` and `api/services/users.ts:8`: `jwt.decode(token)` is used before API calls as an early-exit guard. `jwt.decode` does NOT verify the signature — a tampered token would pass this check. The actual validation happens on the server. This pattern creates false security confidence.

**Fix:** Remove the `jwt.decode` guard calls. If the token is expired/invalid, the backend will return 401. Handle 401 responses in the axios response interceptor by dispatching `logout()`.

---

## D. Cross-Layer Concerns

---

### D1 — ABI Triple-Layer Sync Problem

**Priority: 🔴 Critical**

**Problem:**
The ABI chain `Escrow.sol → Escrow.json → escrow_abi.ts` is broken (see A1 for details). Backend and frontend ABIs are in sync with each other but both describe a phantom older contract.

**Fix:** After regenerating ABIs from the live contract (see A1), add a CI step that fails if `bazaar-backend/Escrow.json` differs from the Hardhat artifact:
```yaml
# .github/workflows/abi-sync.yml
- run: |
    cd bazaar-contract && npx hardhat compile
    diff artifacts/contracts/Escrow.sol/Escrow.json ../bazaar-backend/Escrow.json \
      || (echo "ABI out of sync" && exit 1)
```

---

### D2 — Order Lifecycle State Machine Inconsistency

**Priority: 🟠 High**

**Problem:**
The state machine is defined across three systems with no single source of truth:

| Layer | States |
|---|---|
| Contract (`Escrow.sol`) | `pending` (implicit) → `release=true` (via `releaseOrder`) → `completed=true` (via `claimOrder`) or `completed=true` (via `refundOrder`) |
| Backend DB (`models.go:8-13`) | `"pending"`, `"completed"`, `"cancelled"` — missing `"released"` |
| Observer mapping (`observer.go:128-143`) | Maps `OrderCompleted→"completed"`, `OrderRefunded→"cancelled"`, `OrderReleased→"released"` |
| Frontend (`api/interfaces/products.ts`) | `IOrder` has no `Status` field typed — uses raw string |

**Fix:**
1. Add `"released"` to DB enum (see B10).
2. Define `OrderStatus` enum as a shared constant in frontend interfaces.
3. Update `IOrder.Status` to use the typed enum.
4. Document the full state machine in a DESIGN.md.

---

### D3 — Frontend `IUser` Missing Backend Fields

**Priority: 🟡 Medium**

**Problem:**
`api/interfaces/users.ts:4-13`: `IUser` doesn't include `EmailVerified` (which the backend uses for gating access), `Address` (which differs from `WalletAddress`), or `Password`. The `IOrder` interface needs a `TxHash string` field (present in backend model). The cart products in Redux use a flat object shape `{ ID, Name, Price, Quantity }` but `ICart` in interfaces/users.ts defines `products: { product: IProduct; quantity: number }[]` — these shapes are incompatible.

**Fix:** Audit each interface against its corresponding Go struct and add missing fields. Consider generating TypeScript interfaces from Go structs using a tool like `tygo`.

---

### D4 — No `.env.example` Files

**Priority: 🟡 Medium**

**Problem:**
None of the three sub-projects have `.env.example` files. A new developer has no reference for what environment variables are required.

**Fix:** Create `.env.example` for each:

`bazaar-backend/.env.example`:
```
HTTP_PORT=8080
HTTP_HOSTNAME=0.0.0.0
HTTP_READ_TIMEOUT=5s
HTTP_WRITE_TIMEOUT=10s
HTTP_IDLE_TIMEOUT=120s
HTTP_ALLOWED_ORIGINS=http://localhost:3000
HTTP_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS
HTTP_ALLOWED_HEADERS=Content-Type,Authorization
HTTP_EXPOSED_HEADERS=next-cursor
HTTP_ALLOW_CREDENTIALS=true
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=bazaar
POSTGRES_PASSWORD=secret
POSTGRES_DB=bazaar
PRIVATE_KEY=<RSA private key PEM>
PUBLIC_KEY=<RSA public key PEM>
JWKS_URI=
ETH_URL=wss://sepolia.infura.io/ws/v3/<PROJECT_ID>
CONTRACT_ADDRESS=0x...
SPACES_KEY=<DigitalOcean Spaces key>
SPACES_SECRET=<DigitalOcean Spaces secret>
SPACES_NAME=bazaar-space
APP_NAME=bazaar
APP_TIMEOUT=30s
APP_FRONTEND_URL=http://localhost:3000
```

`bazaar-frontend/.env.example`:
```
NEXT_PUBLIC_BACKEND_URL=http://localhost:8080
NEXT_PUBLIC_CONTRACT_ADDRESS=0x...
NEXT_PUBLIC_CHAIN_ID=0xaa36a7
NEXT_PUBLIC_CDN_BASE_URL=https://bazaar-space.fra1.digitaloceanspaces.com
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
NEXT_PUBLIC_ESCROW_RELEASE_DAYS=14
```

---

### D5 — No CI/CD Configuration

**Priority: 🟡 Medium**

**Problem:**
No GitHub Actions workflows, no Dockerfile, no docker-compose for local development, no deployment pipeline.

**Fix (minimal):**
```yaml
# .github/workflows/ci.yml
jobs:
  backend:
    - go build ./...
    - go test ./...
    - go vet ./...
  frontend:
    - npm ci && npm run build
    - npx tsc --noEmit
  contract:
    - npm ci && npx hardhat compile && npx hardhat test
  abi-sync:
    - diff bazaar-backend/Escrow.json bazaar-contract/artifacts/...
```
Add `docker-compose.yml` with postgres, backend, and frontend services for local dev.

---

### D6 — Auth Token Middleware Bounds Assumption

**Priority: 🟢 Low**

**Problem:**
`middleware.go:47`: `token = token[7:]` assumes the `Authorization` header always starts with exactly `"Bearer "` (7 characters). If the header is present but shorter (e.g., just `"Bear"`), this panics with an index out of range.

**Fix:**
```go
if !strings.HasPrefix(token, "Bearer ") {
    writeUnauthorized(w)
    return
}
token = strings.TrimPrefix(token, "Bearer ")
```
