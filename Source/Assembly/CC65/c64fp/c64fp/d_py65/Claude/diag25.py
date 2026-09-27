#!/usr/bin/env python3
"""
diag25.py - Resolves the contradiction found in diag23/diag2: for
true_diff=128, mantissa=1.0/1.0 (should NOT need a decrement, so per
the classify design should hit rts1's own "already normalized, no
rescue -> genuine overflow -> trap" path), diag23's two methods
disagreed (one said trapped, one said not), and diag2's sanity check
independently says NOT trapped for all three fixed mantissas.

This does exactly ONE thing: a single reset_state(), single set of
operands, single full run, with COMPLETE instruction-level visibility
from .fdiv entry through to whatever the real final exit actually is
- no dual-method comparison, no ambiguity about which result to
trust.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag_woz import decode

SENTINEL = 0x1234

divisor  = (0x40, 0x40, 0x00, 0x00)   # te=-64, mantissa 1.0
dividend = (0xc0, 0x40, 0x00, 0x00)   # te=64,  mantissa 1.0
# true_diff = 64 - (-64) = 128

print(f"divisor={divisor}={decode(*divisor)}  dividend={dividend}={decode(*dividend)}")
print("true_diff = 128 (invalid, one past the true ceiling)")
print("mantissa 1.0/1.0 -> quotient mantissa should be exactly 1.0, "
      "ALREADY normalized, no decrement needed\n")

reset_state()
mpu.memory[0x61:0x65] = list(divisor)
mpu.memory[0x69:0x6d] = list(dividend)

ret_addr = SENTINEL - 1
mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
mpu.sp -= 1
mpu.pc = LABELS['.fdiv']

addr_to_label = {}
for name, a in LABELS.items():
    addr_to_label.setdefault(a, name)

flag_addr = LABELS['.md2']  # placeholder, real flag addr below
flag_addr = LABELS['.fp_norm_boundary_state']
md2_addr = LABELS['.md2']
div1_addr = LABELS['.div1']
mdend_addr = LABELS['.mdend']
norm_addr = LABELS['.norm']
norm1_addr = LABELS['.norm1']
rts1_addr = LABELS['.rts1']
error_addr = LABELS['.FP_ERROR_PROC']

seen = set()
for step in range(1500):
    pc = mpu.pc
    if pc in (md2_addr, div1_addr, mdend_addr, norm_addr, norm1_addr, rts1_addr) and pc not in seen:
        seen.add(pc)
        label = addr_to_label.get(pc, '')
        print(f"step {step:5d}  FIRST HIT {label:12s} PC=${pc:04x}  "
              f"A=${mpu.a:02x} FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == error_addr:
        print(f"\n*** TRAPPED at step {step}, code={mpu.memory[0xFE]} ***")
        break
    if pc == SENTINEL:
        print(f"\n*** REAL EXIT (sentinel) at step {step} ***")
        break
    mpu.step()
else:
    print("\n*** didn't finish in 1500 steps ***")

final = dump_fp()
print(f"\nfinal FP1 = {tuple(hex(b) for b in final['FP1'])}")
if final['FP1'] != None:
    try:
        print(f"decoded = {decode(*final['FP1'])}")
    except Exception:
        pass
