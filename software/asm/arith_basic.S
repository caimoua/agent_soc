# Basic arithmetic program used by sim/testcases/rv32i_core_tb.sv.
#
# Expected final state:
#   x1 = 5
#   x2 = 7
#   x3 = 12
#   x4 = 7

addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2
sub  x4, x3, x1
