# ADR 0002: Use Blocking Caches and a Simple Internal Bus

Date: 2026-05-15

## Status

Accepted

## Context

The project is focused on learning CPU microarchitecture and small SoC integration. Adding AHB/AXI details too early would shift attention from the core pipeline and cache behavior to protocol mechanics.

## Decision

Use blocking I-cache, blocking D-cache, and a simple internal `valid/ready` memory bus first.

The internal bus supports:

- I-cache master
- D-cache master
- ROM/SRAM/MMIO slaves
- fixed D-priority arbitration
- decode error response through `i_error` and `d_error`.

## Consequences

- The design is easy to debug and explain.
- No outstanding transactions or bursts are supported.
- A future AHB-lite or AXI-lite adapter should sit behind this simple internal bus boundary.
- Cache and core RTL stay independent from external bus protocol details.
