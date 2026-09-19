# Pairing and Trust

## Discovery is not trust

Seeing a peer named "Rahul" does not prove identity.

## MVP

1. Discover Offlink service.
2. Connect.
3. Exchange protocol capabilities.
4. Perform authenticated key exchange.
5. Establish encrypted session.
6. Show peer identity.

## Future verification

Add an explicit identity verification mechanism:
- safety code
- QR comparison
- manual identity confirmation

The verification mechanism should be designed before claiming protection against active impersonation.

## Blocking

Future:
- block peer
- ignore discovery
- reject messages
- stop forwarding to/from blocked node where appropriate

Blocking must be local and must not require a central server.
