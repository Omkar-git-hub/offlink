# Group Messaging Design

Groups are a later phase.

## Requirements

Must handle:
- create group
- add member
- remove member
- member leaves
- member rejoins
- key rotation
- offline membership changes
- duplicate/out-of-order control messages

## Security requirement

A removed member must not automatically retain the ability to decrypt future group messages.

## MVP scope

Do not implement groups until one-to-one encrypted messaging and mesh delivery are stable and verified.
