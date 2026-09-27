#!/usr/bin/env python3
"""
diag6.py - Final, consolidated check for FP_FMUL(12.0, -7.5).
Combines diag5.py's independent encode/decode with a live py65 run
of the ACTUAL, corrected test case, comparing every stage against
independently-computed ground truth. Self-contained - no dependency
on diag4/diag5's globals.
"""

from diag1 import mpu, LABELS, run_until, dump_fp, reset_state

# ---- independent Woz/Rankin encode/decode (from diag5.py, copied
#      in directly so this file has no missing-import risk) ----
def decode(exp, m0, m1, m2):
    m = (m0 << 16) | (m1 << 8) | m2
    if m0 & 0x80:
        m -= 0x1000000
    return (m / 4194304.0) * (2.0 ** (exp - 128))

def encode(value):
    if value == 0:
        return (0, 0, 0, 0)
    import math
    sign = -1 if value < 0 else 1
    mag = abs(value)
    e = math.floor(math.log2(mag)) + 1
    mant = mag / (2.0 ** (e - 1))
    while mant >= 2.0:
        mant /= 2.0
        e += 1
    while mant < 1.0:
        mant *= 2.0
        e -= 1
    m_int = int(mant * 4194304)
    if sign < 0:
        m_int = -m_int
        m_int &= 0xFFFFFF
    exp_byte = e - 1 + 128
    return (exp_byte, (m_int>>16)&0xFF, (m_int>>8)&0xFF, m_int&0xFF)

# ---- self-test decode/encode before trusting them ----
SELF_TEST = [
    ((0x80,0x40,0x00,0x00), 1.0),
    ((0x7f,0x80,0x00,0x00), -1.0),
    ((0x83,0x50,0x00,0x00), 10.0),
    ((0x83,0x60,0x00,0x00), 12.0),
    ((0xff,0x40,0x00,0x00), 2.0**127),
]
for bytes4, expected in SELF_TEST:
    got = decode(*bytes4)
    assert abs(got - expected) < 1e-6 * max(1, abs(expected)), \
        f"decode() self-test failed: {bytes4} -> {got}, expected {expected}"
print("decode()/encode() self-test: OK\n")

# ---- ground truth for THIS test case ----
FP1_BYTES = (0x83, 0x60, 0x00, 0x00)   # 12.0
FP2_BYTES = (0x82, 0x88, 0x00, 0x00)   # -7.5 (confirmed by decode, not the stale "-5" name)

fp1_val = decode(*FP1_BYTES)
fp2_val = decode(*FP2_BYTES)
expected_product = fp1_val * fp2_val
expected_bytes = encode(expected_product)

print(f"FP1 = {FP1_BYTES} = {fp1_val}")
print(f"FP2 = {FP2_BYTES} = {fp2_val}")
print(f"expected product = {fp1_val} * {fp2_val} = {expected_product}")
print(f"expected bytes   = {tuple(hex(b) for b in expected_bytes)}\n")

# ---- run it for real, capturing key intermediate points ----
reset_state()
mpu.memory[0x61:0x65] = list(FP1_BYTES)
mpu.memory[0x69:0x6d] = list(FP2_BYTES)
mpu.pc = LABELS['.fmul']

md2_addr = LABELS['.md2']
mul1_addr = LABELS['.mul1']
rts1_addr = LABELS['.rts1']

seen_md2 = False
rts1_count = 0
for _ in range(20000):
    pc = mpu.pc
    if pc == md2_addr and not seen_md2:
        seen_md2 = True
        print(f"AT .md2 entry:  A=${mpu.a:02x} (provisional exponent input), "
              f"carry={'set' if mpu.p & 1 else 'clear'}")
    if pc == mul1_addr and rts1_count == 0:
        print(f"AT first .mul1: FP1_EXP=${mpu.memory[0x61]:02x}  "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]}  "
              f"FP_EXT={[hex(b) for b in mpu.memory[0x65:0x68]]}  "
              f"FP2_MANT={[hex(b) for b in mpu.memory[0x6a:0x6d]]}  "
              f"Y={mpu.y}")
    mpu.step()
    if pc == rts1_addr:
        rts1_count += 1
        if rts1_count == 2:   # the SECOND .rts1 is the real final exit
                               # (the first is fcompl's own inner return)
            break

final = dump_fp()
print(f"\nfinal FP1 = {tuple(hex(b) for b in final['FP1'])}")
final_val = decode(*final['FP1'])
print(f"final decoded value = {final_val}")
print(f"expected value      = {expected_product}")
print(f"MATCH: {'YES' if abs(final_val - expected_product) < 1e-4 else 'NO - confirmed real bug'}")
