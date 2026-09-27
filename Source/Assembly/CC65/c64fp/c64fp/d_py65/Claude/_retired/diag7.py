#!/usr/bin/env python3
"""
diag7.py - Direct A/B comparison of run_fmul() vs diag6.py's inline
script, for the EXACT same operand pair, to find whatever is
actually different between them - since diag1.py's patched run_fmul
still produces a different answer than diag6.py's inline script for
identical inputs, meaning something concrete differs between the two
code paths that hasn't been identified by inspection alone.
"""

from diag1 import mpu, LABELS, run_until, dump_fp, reset_state, run_fmul

FP1_BYTES = (0x83, 0x60, 0x00, 0x00)   # 12.0
FP2_BYTES = (0x82, 0x88, 0x00, 0x00)   # -7.5

def set_fp1(exp, m0, m1, m2):
    mpu.memory[0x61:0x65] = [exp, m0, m1, m2]

def set_fp2(exp, m0, m1, m2):
    mpu.memory[0x69:0x6d] = [exp, m0, m1, m2]

print("=== PATH A: run_fmul() as imported from diag1.py ===")
trapped, outcome, state = run_fmul(FP1_BYTES, FP2_BYTES)
print(f"trapped={trapped} outcome={outcome} state={state}\n")

print("=== PATH B: diag6.py's exact inline sequence, replicated here ===")
reset_state()
mpu.memory[0x61:0x65] = list(FP1_BYTES)
mpu.memory[0x69:0x6d] = list(FP2_BYTES)
mpu.pc = LABELS['.fmul']

rts1_addr = LABELS['.rts1']
rts1_count = 0
step_count = 0
for _ in range(20000):
    pc = mpu.pc
    mpu.step()
    step_count += 1
    if pc == rts1_addr:
        rts1_count += 1
        if rts1_count == 2:
            break
final_b = dump_fp()
print(f"stopped after {step_count} steps, rts1_count={rts1_count}")
print(f"final state = {final_b}\n")

print("=== Do these two paths actually run the same number of steps? ===")
print("(if PATH A's run_until-based approach exits after fewer total")
print(" steps than PATH B's fixed rts1_count==2 approach, that's the")
print(" smoking gun - it means run_until's exit condition is firing")
print(" on an EARLIER, spurious hit of one of its watched labels)")
