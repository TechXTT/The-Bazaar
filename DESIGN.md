# The Bazaar Design Notes

## Order Lifecycle

The order lifecycle is shared across the contract, backend database, observer, and frontend.

| State | Contract Source | Backend Status | Meaning |
|---|---|---|---|
| Pending | `Order.completed == false` and `Order.release == false` | `pending` | Escrow exists but cannot be claimed until release time. |
| Released | `Order.release == true` and `Order.completed == false` | `released` | Buyer approved early seller claim. |
| Completed | `Order.completed == true` after `claimOrder` or `claimOrders` | `completed` | Seller claimed escrow funds. |
| Cancelled | `Order.completed == true` after `refundOrder` | `cancelled` | Seller refunded the buyer. |

The backend observer maps contract events to database states:

| Event | Backend Status |
|---|---|
| `OrderReleased` | `released` |
| `OrderCompleted` | `completed` |
| `OrderRefunded` | `cancelled` |

The frontend `OrderStatus` enum should stay in sync with these backend values.
