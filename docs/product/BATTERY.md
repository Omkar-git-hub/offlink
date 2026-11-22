# Offlink Battery Strategy & Optimization Architecture

## Requirement

Low battery consumption is a first-class, non-negotiable product requirement for Offlink. In prolonged grid-down, disaster, or off-grid scenarios, mobile device battery longevity directly determines communications availability.

We optimize for:
- Duty-cycled BLE discovery scanning rather than continuous radio activation
- Elimination of unconditional idle periodic timers that wake up CPU or poll SQLite
- Reconnection storm mitigation with exponential backoff, jitter, and inter-peer attempt spacing
- Mesh relay flood suppression to prevent ping-pong broadcast storms
- Bounded retry counts and automatic expiration of stale offline packets
- Dynamic adaptation across app lifecycle states (foreground active, connected idle, background low-power, conserve)

---

## Battery Optimization Architecture (Module 10)

### 1. Duty-Cycled Adaptive BLE Discovery (`AdaptiveBleDiscovery`)

Continuous BLE scanning keeps the radio receiver hardware energized 100% of the time, consuming 10%–25% device battery per hour. Offlink employs duty-cycled discovery governed by `AdaptiveBleDiscovery` and `AdaptivePowerCoordinator`:

| Mode | Scan Window | Pause Window | Duty Cycle Ratio | Radio Idle Savings | Context |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`active`** | 8 seconds | 4 seconds | 66.7% | **33.3%** | User is actively browsing or has pending messages / live location |
| **`balanced`** | 6 seconds | 12 seconds | 33.3% | **66.7%** | App is open in foreground and connected to peers but idle |
| **`lowPower`** | 4 seconds | 60 seconds | 6.25% | **93.75%** | App is minimized / backgrounded with Android foreground service |
| **`conserve`** | 4 seconds | 120 seconds | 3.23% | **96.77%** | No peers nearby or repeated connection failures |

Key architectural safeguards:
- **Peripheral Advertising Continuity**: Peripheral advertising is maintained during scan pause windows so remote nodes can initiate incoming GATT connections even while our scan radio rests.
- **Cycle-End Pruning**: At the conclusion of each scan window, `completeScanCycle()` is invoked to prune peers that went out of range without lingering ghost nodes.
- **Immediate Scan Triggering**: User actions (e.g., pull-to-refresh on `HomePage`) or enqueueing of outgoing messages immediately trigger a fresh scan cycle.

---

### 2. Idle Timer Elimination (Zero Idle CPU Wakeups)

Unconditional periodic timers wake the CPU from deep sleep (C-states) and trigger unnecessary SQLite disk I/O:

1. **`LocationService`**:
   - Eliminated the 1-second periodic timer when 0 live location sessions exist.
   - Timer is lazily spawned only when an active outgoing live location session is started (`startLiveLocation`), and is cancelled immediately when all live sessions expire or are stopped.
   - Saves **3,600 CPU wakeups per hour** when idle.

2. **`PendingMessageRecoveryService`**:
   - Suspends the 10-second periodic SQLite retry polling when the pending unacknowledged message queue is empty.
   - Automatically resumes when `notifyPendingMessageQueued()` is invoked or on app foregrounding.
   - Saves **~360 SQLite database queries per hour** when idle.

3. **`StoreAndForwardManager`**:
   - Suspends the 15-second maintenance polling timer when the store-and-forward in-transit packet queue is empty (`getQueueSize() == 0`).
   - Resumes upon `enqueueInTransitPacket()`.
   - Saves **~240 SQLite database queries per hour** when idle.

---

### 3. Reconnection Storm Mitigation (`ConnectionRecoveryCoordinator`)

When multiple BLE connections drop simultaneously (e.g., passing through RF deadzones or node sleep):
- **Inter-Attempt Spacing**: Enforces `minAttemptSpacing` (500ms) between connection attempts across all peers to prevent simultaneous GATT connection storms.
- **Exponential Backoff with Jitter**: Computes exponential backoff with randomized +/-10% jitter to desynchronize retry waves between neighboring nodes.
- **Background Attempt Capping**: When backgrounded (`isBackgrounded == true`), max attempts are capped at 3 (down from 5) with an increased initial delay (4s instead of 1s).

---

### 4. Mesh Relay Flood Suppression (`MeshPacketRouter`)

Intermediate relay nodes flooding unrouted packets now explicitly exclude `peerId == packet.senderNodeId` in `_floodPacket()`. This prevents bouncing packets back to their originating source, eliminating multi-hop echo loops and radio channel congestion.

---

## Operating States Summary

### IDLE (Foreground / No Activity)
- Scanning operates in `balanced` mode (6s scan / 12s pause).
- Idle timers are completely suspended.
- Minimal CPU and battery consumption.

### ACTIVE (User Interacting / Live Location / Outgoing Queue)
- Scanning operates in `active` mode (8s scan / 4s pause).
- Location service updates at configured intervals (30s).
- Fast message retry backoff.

### BACKGROUND (Minimized / Screen Locked)
- Operates under Android Foreground Service.
- Discovery switches to `lowPower` mode (4s scan / 60s pause).
- GPS location capture throttled or deferred.
- Connection retry attempts capped at 3.

### CONSERVE (Low Battery or Extended Silence)
- Scanning backs off to `conserve` mode (4s scan / 120s pause).
- Background opportunistic scanning disabled if battery critical.

---

## Non-Negotiable Principle

**Battery optimization must never silently weaken encryption, message integrity, or security guarantees.** All payload encryption, ECDH pairwise key exchanges, HMAC signature validations, and replay protection remain 100% active and uncompromised regardless of the active power mode.
