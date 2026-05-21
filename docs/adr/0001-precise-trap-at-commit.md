# ADR 0001: Handle Traps at Commit

Date: 2026-05-15

## Status

Accepted

## Context

The pipeline has multiple in-flight instructions. If a trap redirects the PC too early, older instructions may not have committed yet and younger instructions may produce side effects.

## Decision

All architectural traps and `mret` redirects are handled at the MEM/WB commit boundary.

The core sends commit information to `rv32i_pipe_csr`, including:

- commit PC
- illegal/ecall/ebreak/mret flags
- instruction/load/store fault flags
- CSR write request information.

`rv32i_pipe_csr` generates:

- CSR architectural updates
- `commit_redirect`
- `commit_redirect_pc`.

## Consequences

- Precise exception behavior is easier to reason about.
- Younger pipeline stages are flushed on trap or `mret`.
- Store side effects are blocked when a commit redirect is active.
- Current design assumes fixed 32-bit instructions and derives commit PC from `pc4 - 4`.
