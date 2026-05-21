# ADR 0003: Keep Lightweight Project State Documents

Date: 2026-05-15

## Status

Accepted

## Context

As the project grows, each new task can require reading many RTL, testbench, and documentation files to reconstruct current state. This increases review time and token usage.

## Decision

Maintain three short entry documents:

- `docs/status/PROJECT_STATUS.md`
- `docs/status/INTERFACE_INDEX.md`
- `docs/status/VERIFICATION_MATRIX.md`

Future work should read these first before scanning implementation files.

## Consequences

- New tasks start with a smaller context footprint.
- Interface changes have a single summary location.
- Verification status is explicit and easier to update after user-side VCS runs.
- The documents must be updated after each feature to stay trustworthy.
