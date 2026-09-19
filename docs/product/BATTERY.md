# Offlink Battery Strategy

## Requirement

Low battery consumption is a first-class product requirement.

We will optimize for:
- low idle scanning activity
- short BLE sessions
- batched synchronization
- bounded retries
- minimal database writes
- bounded cryptographic work
- no unnecessary location access
- reduced background activity

## Operating states

### IDLE
- Minimal background activity.
- No aggressive scanning loop.

### ACTIVE
User is in discovery/chat.
- More responsive scanning.
- Short connection windows.

### SYNC
A peer is connected.
- Batch queued packets.
- Exchange multiple messages/ACKs per connection.

### BACKOFF
Repeated failures.
- Exponential delay with a cap.
- Stop trying when message expiry is reached.

### LOW_BATTERY
- Reduce background discovery.
- Prioritize active conversations and user-triggered operations.
- Defer low-priority synchronization where safe.

### CHARGING
Potentially allow more frequent synchronization, subject to user settings and measurement.

## Initial policy

Do not choose arbitrary battery percentages as product guarantees.

First measure on representative devices:
- idle 30/60 minutes
- discovery 30/60 minutes
- active chat
- mesh forwarding
- low-battery behavior
- charging behavior

Then set evidence-based acceptance thresholds.

## Battery test record

For each test record:
- device model
- Android version
- battery start/end
- test duration
- Offlink state
- scan mode
- connected peers
- messages exchanged
- location usage
- screen state

## Principle

Battery optimization must never silently weaken encryption or message integrity.
