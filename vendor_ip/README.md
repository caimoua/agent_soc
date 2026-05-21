# Local Vendor IP

Place licensed third-party RTL/IP here only for local experiments.

This directory is ignored by git except for this README. Do not commit AE350, Andes, ARM, or other proprietary/confidential IP files into this public project unless you have explicit redistribution rights.

Preferred public-repo flow:

```text
rtl/top/rv32i_ahb_matrix_soc_top.v
  -> local clean-room AHB-Lite matrix

vendor_ip/
  -> optional local-only vendor replacement fabric
```
