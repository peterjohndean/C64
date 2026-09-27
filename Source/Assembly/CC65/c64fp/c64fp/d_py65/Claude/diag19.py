#!/usr/bin/env python3
"""
diag19.py - Direct trace of ONE concrete FDIV FLOOR-straddle case
(te2-te1=-129), to find why sweep_fdiv_straddle_point reports
204/204 BLOCKED_WRONG - a 100% failure rate, unlike FMUL's own
71.6%/28.4% split at the same true boundary shape. A uniform 100%
failure (not a mix depending on mantissa) suggests the classify
decision itself, or its consequence, never actually reaches the
FLOOR-handling code on FDIV's path - worth confirming directly
rather than guessing which.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state, run_fdiv
from diag_woz import decode, is_normalized

SENTINEL = 0x1234
FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

# Reproduce ONE case from the sweep's own fixed set: te2-te1=-129,
# mantissa "1.0" (0x40,0x00,0x00) for both operands - same split
# logic as diag2.py's split_exponents_div.
te_diff = -129
base_te1 = max(-128, min(127, -te_diff // 2))
te2_true = base_te1 + te_diff
e1 = (base_te1 + 128) & 0xff   # divisor exponent byte
e2 = (te2_true + 128) & 0xff   # dividend exponent byte
print(f"te_diff={te_diff}  base_te1={base_te1} (byte ${e1:02x})  "
      f"te2_true={te2_true} (byte ${e2:02x})")

m = (0x40, 0x00, 0x00)
divisor = (e1,) + m
dividend = (e2,) + m
print(f"divisor={divisor}={decode(*divisor)}  dividend={dividend}={decode(*dividend)}")

# First: run it through the REAL run_fdiv (same as the sweep does)
# and see what the sweep would have recorded.
trapped, outcome, state = run_fdiv(divisor, dividend)
print(f"\nvia run_fdiv(): trapped={trapped} outcome={outcome} "
      f"FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    norm_ok = is_normalized(state['FP1'][1:])
    print(f"is_normalized(mantissa)={norm_ok} "
          f"{'-> would be BLOCKED_WRONG' if not norm_ok else '-> OK'}")
    print(f"decoded={decode(*state['FP1'])}")

# Now trace it step by step, watching the classify block's own
# decision and fp_norm_boundary_state at key points.
print("\n--- instruction trace ---")
reset_state()
mpu.memory[0x61:0x65] = list(divisor)
mpu.memory[0x69:0x6d] = list(dividend)

ret_addr = SENTINEL - 1
mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
mpu.sp -= 1
mpu.pc = LABELS['.fdiv']

flag_addr = LABELS['.fp_norm_boundary_state']
md2_addr = LABELS['.md2']
div1_addr = LABELS['.div1']
mdend_addr = LABELS['.mdend']
norm1_addr = LABELS['.norm1']
rts1_addr = LABELS['.rts1']
error_addr = LABELS['.FP_ERROR_PROC']

seen_md2 = seen_div1 = seen_mdend = seen_norm1 = seen_rts1 = False

for step in range(5000):
    pc = mpu.pc
    if pc == md2_addr and not seen_md2:
        seen_md2 = True
        print(f"AT .md2 entry (step {step}): A=${mpu.a:02x} "
              f"carry={'set' if mpu.p & 1 else 'clear'} "
              f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == div1_addr and not seen_div1:
        seen_div1 = True
        print(f"AT first .div1 (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"FP_EXT={[hex(b) for b in mpu.memory[0x65:0x68]]} "
              f"FP2_MANT={[hex(b) for b in mpu.memory[0x6a:0x6d]]} "
              f"Y={mpu.y} fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == mdend_addr and not seen_mdend:
        seen_mdend = True
        print(f"AT .mdend (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == norm1_addr and not seen_norm1:
        seen_norm1 = True
        print(f"AT .norm1 (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == rts1_addr and not seen_rts1:
        seen_rts1 = True
        print(f"AT .rts1 (step {step}): FP1_EXP=${mpu.memory[0x61]:02x} "
              f"FP1_MANT={[hex(b) for b in mpu.memory[0x62:0x65]]} "
              f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
    if pc == error_addr:
        print(f"TRAPPED at step {step}, code={mpu.memory[0xFE]}")
        break
    if pc == SENTINEL:
        print(f"REAL EXIT at step {step}")
        break
    mpu.step()
else:
    print("didn't finish in 5000 steps")

final = dump_fp()
print(f"\nfinal FP1 = {tuple(hex(b) for b in final['FP1'])} = {decode(*final['FP1'])}")