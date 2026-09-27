#!/usr/bin/env python3
"""
diag8.py - Independent ground-truth check for 10.0/12.0, using the
same decode()/encode() self-tested against known constants that
closed out every other discrepancy today (see diag5.py/diag6.py).
"""

from diag1 import mpu, LABELS, run_fdiv

def decode(exp, m0, m1, m2):
    m = (m0 << 16) | (m1 << 8) | m2
    if m0 & 0x80:
        m -= 0x1000000
    return (m / 4194304.0) * (2.0 ** (exp - 128))

SELF_TEST = [
    ((0x80,0x40,0x00,0x00), 1.0),
    ((0x7f,0x80,0x00,0x00), -1.0),
    ((0x83,0x50,0x00,0x00), 10.0),
    ((0x83,0x60,0x00,0x00), 12.0),
]
for bytes4, expected in SELF_TEST:
    got = decode(*bytes4)
    assert abs(got - expected) < 1e-6 * max(1, abs(expected)), \
        f"decode() self-test FAILED: {bytes4} -> {got}"
print("decode() self-test: OK\n")

FP1 = (0x83, 0x60, 0x00, 0x00)   # 12.0 (divisor)
FP2 = (0x83, 0x50, 0x00, 0x00)   # 10.0 (dividend)

expected = decode(*FP2) / decode(*FP1)
print(f"expected: {decode(*FP2)} / {decode(*FP1)} = {expected}")

trapped, outcome, state = run_fdiv(FP1, FP2)
print(f"\nsimulator: trapped={trapped} outcome={outcome}")
print(f"simulator FP1 bytes: {tuple(hex(b) for b in state['FP1'])}")
actual = decode(*state['FP1'])
print(f"simulator decoded value: {actual}")
print(f"MATCH: {'YES' if abs(actual - expected) < 1e-4 else 'NO - real discrepancy'}")
