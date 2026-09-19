# Offlink Data Map

| Data | Created by | Stored | Transmitted | Why |
|---|---|---|---|---|
| Username | User | Local DB | Authenticated peer flow | Display identity |
| Node ID | App | Local DB | Protocol as required | Node addressing |
| Public key | App | Local DB | Handshake | Identity verification |
| Private key | App | Secure storage | Never | Cryptographic identity |
| Message plaintext | User | Temporary/local message lifecycle | Never plaintext over mesh | User message |
| Encrypted message | App | Local DB/queue | BLE mesh | Delivery |
| Location | User action | Encrypted message lifecycle | Encrypted | Location sharing |
| Peer last-seen | App | Local DB | Not shared as a central service | Local presence |
| BLE RSSI | OS/BLE | Optional/ephemeral | No | Connection/discovery decisions |

## Rule

If a proposed feature requires a new data field, update this document before implementation.
