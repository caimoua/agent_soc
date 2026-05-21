# ADR 0004: Add AHB-Lite Behind the Simple Bus Boundary

Date: 2026-05-15

## Status

Accepted

## Context

The core, I-cache, and D-cache currently use a small blocking `valid/ready` memory interface. This keeps CPU microarchitecture independent from external SoC bus protocol details.

The next integration step is to add an AHB-style bus path. The reference AE350 clone contains AHB busmatrix and decoder examples, but those IPs are much larger than the current teaching core needs.

## Decision

Add an AHB-Lite path behind the existing simple bus boundary:

- Keep `rv32i_mem_bus` as the already verified simple bus.
- Add `rv32i_mem_bus_ahb` as an AHB-Lite equivalent with the same external ROM/SRAM/MMIO simple ports.
- Add `rv32i_cached_system_ahb_top` as an opt-in top wrapper that uses the AHB-Lite bus path.
- Preserve the existing D-priority arbitration at the simple I/D request boundary.

The first AHB implementation supports standard address/data phase separation, `HREADY`, `HRESP`, `HSIZE`, `HTRANS`, `HBURST`, and byte-write conversion. It uses single-beat transfers because the current core/cache path has no outstanding requests or burst request metadata.

## Consequences

- Existing tests and the original cached system top remain stable.
- AHB behavior can be verified independently before replacing the default top.
- The design now has a clean point for adding a true multi-master AHB matrix later.
- Burst, SPLIT/RETRY, and parallel multi-master routing remain future work.
