#!/usr/bin/env python3
"""
diag14.py - Direct, isolated trace of FP_FMUL(34028120.0, 10.0),
reproducing call 9's exact operands from diag12.py, to find why an
exact 8-significant-digit multiply by an exact 10.0 produces a
result off by 112.0 (340281088.0 instead of 340281200.0).
"""

from diag1 import mpu, LABELS, reset_state, dump_fp
from diag_woz import decode

FP1_BYTES = (0x99, 0x40, 0xe7, 0x4b)   # 34028120.0
FP2_BYTES = (0x83, 0x50, 0x00, 0x00)   # 10.0

d1 = decode(*FP1_BYTES)
d2 = decode(*FP2_BYTES)
print(f"FP1 = {FP1_BYTES} = {d1}")
print(f"FP2 = {FP2_BYTES} = {d2}")
print(f"true product = {d1 * d2}")
expected_bytes_note = "expected exponent should be current+1 range, mantissa TBD"

reset_state()
mpu.memory[0x61:0x65] = list(FP1_BYTES)
mpu.memory[0x69:0x6d] = list(FP2_BYTES)

SENTINEL = 0x1234
ret_addr = SENTINEL - 1
mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
mpu.sp -= 1
entry_sp = mpu.sp

mpu.pc = LABELS['.fmul']

addr_to_label = {}
for name, a in LABELS.items():
    addr_to_label.setdefault(a, name)

md2_addr = LABELS['.md2']
mul1_addr = LABELS['.mul1']
mdend_addr = LABELS['.mdend']

seen_md2 = seen_mul1_first = seen_mdend = False

for step in range(3000):
    pc = mpu.pc
    if pc == md2_addr and not seen_md2:
        seen_md2 = True
        print(f"\nAT .md2 entry (step {step}): A=${mpu.a:02x} "
              f"(provisional exponent input), carry={'set' if mpu.p & 1 else 'clear'}")
    if pc == mul1_addr and not seen_mul1_first:
        seen_mul1_first = True
        print(f"AT first .mul1 (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"FP_EXT={[hex(b) for b in mpu.memory[0x65:0x68]]} "
              f"FP2_MANT={[hex(b) for b in mpu.memory[0x6a:0x6d]]} Y={mpu.y}")
    if pc == mdend_addr and not seen_mdend:
        seen_mdend = True
        print(f"AT .mdend (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"FP_SIGN=${mpu.memory[0x02]:02x}")
    if pc == SENTINEL:
        print(f"\nREAL EXIT at step {step}")
        break
    mpu.step()
else:
    print("didn't finish in 3000 steps")

final = dump_fp()
print(f"\nfinal FP1 = {tuple(hex(b) for b in final['FP1'])} = {decode(*final['FP1'])}")
print(f"expected  = {d1*d2}")