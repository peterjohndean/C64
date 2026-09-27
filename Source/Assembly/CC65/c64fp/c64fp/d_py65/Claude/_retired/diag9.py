#!/usr/bin/env python3
"""
diag9.py - Confirm the sentinel-stack fix actually resolves
@force_underflow's RTS, by tracing exactly where PC goes immediately
after it, with the fake return address pushed first.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag2 import classify_state_for, split_exponents, FP_NORM_BOUNDARY_STATE_ADDR
from diag1 import provisional_exponent

te_sum = -129
e1, e2 = split_exponents(te_sum)
prov_exp = provisional_exponent(e1, e2)
print(f"te_sum={te_sum}  e1=${e1:02x} e2=${e2:02x}  prov_exp=${prov_exp:02x}")

m = (0x40, 0x00, 0x00)
reset_state()
mpu.memory[0x61] = prov_exp
mpu.memory[0x62:0x65] = [0, 0, 0]
mpu.memory[0x65:0x68] = list(m)
mpu.memory[0x6a:0x6d] = list(m)
mpu.memory[FP_NORM_BOUNDARY_STATE_ADDR] = classify_state_for(te_sum)
mpu.y = 0x17

# --- the sentinel push, EXACTLY as proposed for run_mul_loop_from ---
SENTINEL = 0xFFFE   # RTS lands at SENTINEL+1 = $FFFF, not $0000 -
                     # $0000 is BRK/reset-vector territory and is
                     # exactly what caused the last hang
print(f"SP before push: ${mpu.sp:02x}")
mpu.memory[0x100 + mpu.sp] = (SENTINEL >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = SENTINEL & 0xFF
mpu.sp -= 1
print(f"SP after push: ${mpu.sp:02x}, stack bytes: "
      f"{[hex(mpu.memory[0x100+mpu.sp+i]) for i in (1,2)]}")

mpu.pc = LABELS['.mul1']

addr_to_label = {}
for name, a in LABELS.items():
    addr_to_label.setdefault(a, name)

mdend_addr = LABELS['.mdend']
force_underflow_addr = LABELS['.@force_underflow']
seen_mdend = False

for step in range(1400):
    pc = mpu.pc
    if pc == mdend_addr and not seen_mdend:
        seen_mdend = True
        print(f"\nreached .mdend at step {step}")
    if seen_mdend:
        label = addr_to_label.get(pc, '')
        print(f"step {step:5d}  PC=${pc:04x} {label:20s} opcode=${mpu.memory[pc]:02x} SP=${mpu.sp:02x}")
    mpu.step()
    if seen_mdend and step > 1350:
        break