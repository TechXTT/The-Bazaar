# The Bazaar Design Notes

## Order Lifecycle

The order lifecycle is shared across the contract, backend database, observer, and
frontend. The single source of truth for the status values is the `OrderStatus`
type in the backend `services/db` package (XL-1); the frontend mirrors it as a
typed union and the contract expresses the same states via `Order`/`orderDisputes`
fields. There are **six** states (the original four plus `shipped` and `disputed`).

| State | Contract source | Backend status | Meaning |
|---|---|---|---|
| Pending | `Order.completed == false`, `Order.release == false`, `Order.shipped == false` | `pending` | Escrow funded; cannot be claimed until shipment + release time. |
| Shipped | `Order.shipped == true` (after `markShipped`) | `shipped` | Seller marked the item shipped; delivery window started. |
| Released | `Order.release == true`, `Order.completed == false` | `released` | Buyer approved early seller claim (or won a dispute → release to receiver). |
| Completed | `Order.completed == true` after `claimOrder`/`claimOrders` | `completed` | Seller claimed escrow funds. |
| Cancelled | `Order.completed == true` after `refundOrder` (or buyer won a dispute) | `cancelled` | Buyer refunded. |
| Disputed | `orderDisputes[orderId].status >= 1` | `disputed` | A dispute was raised (only allowed after shipment, per SC-1); awaiting resolution. |

The backend observer maps contract events to database states:

| Event | Backend status |
|---|---|
| `OrderShipped` | `shipped` |
| `OrderReleased` | `released` |
| `OrderCompleted` | `completed` |
| `OrderRefunded` | `cancelled` |
| `DisputeRaised` | `disputed` |
| `DisputeResolved` | derived from the ruling (BE-9): ruling `1` (buyer wins) → `cancelled`; otherwise (receiver wins / refused / unknown) → `released`. The order no longer stays stuck in `disputed`. |

## Dispute settlement (pull payment — SC-6)

After a dispute resolves (arbitrated or by timeout), the **ETH** legs (order payout
+ deposit refund) are no longer pushed to recipients — they are credited to
`withdrawable[address]` and claimed via `withdraw()`. This prevents a reverting
recipient (e.g. a Safe/AA wallet) from bricking settlement. USDC order amounts are
still transferred directly. The frontend surfaces a "Withdraw" action when
`withdrawable(currentUser) > 0`.

The frontend `OrderStatus` union must stay in sync with the backend values above.
