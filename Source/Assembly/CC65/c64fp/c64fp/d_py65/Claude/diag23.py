#!/usr/bin/env python3
"""
diag23.py - Investigates FDIV's SECOND collision point: true_diff=-128
(genuinely valid - the real floor) vs true_diff=+128 (genuinely
invalid - one step past the ceiling), both of which naively bias to
byte $00. This mirrors the true_diff=127/-129 collision at $FF
already found and fixed - but the actual mechanics may differ, since
md3's eor#$80 turns $00 into $80, NOT into norm1's literal
FP1_EXP==0 guard value the way the $FF collision's md3 output ($FF)
did NOT hit norm1's guard either. Traces both real cases directly
rather than assuming symmetry with the already-fixed $FF collision.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state, run_fdiv
from diag_woz import decode

def split_for_true_diff(true_diff):
    """Same centering approach as diag2.py's split_exponents_div."""
    base_te1 = max(-128, min(127, -true_diff // 2))
    te2 = base_te1 + true_diff
    if not (-128 <= base_te1 <= 127) or not (-128 <= te2 <= 127):
        raise ValueError(f"true_diff={true_diff} has no valid split "
                          f"(tried base_te1={base_te1}, te2={te2})")
    return (base_te1 + 128) & 0xff, (te2 + 128) & 0xff

def trace_case(label, true_diff, mantissa=(0x40, 0x00, 0x00)):
    e1, e2 = split_for_true_diff(true_diff)
    divisor = (e1,) + mantissa
    dividend = (e2,) + mantissa
    print(f"\n=== {label} (true_diff={true_diff}) ===")
    print(f"divisor=byte(${e1:02x})  dividend=byte(${e2:02x})")

    # first: what does the REAL run_fdiv produce?
    trapped, outcome, state = run_fdiv(divisor, dividend)
    print(f"via run_fdiv(): trapped={trapped} outcome={outcome} "
          f"FP1={tuple(hex(b) for b in state['FP1'])}")
    if not trapped:
        print(f"decoded={decode(*state['FP1'])}")

    # now trace step by step
    reset_state()
    mpu.memory[0x61:0x65] = list(divisor)
    mpu.memory[0x69:0x6d] = list(dividend)
    SENTINEL = 0x1234
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.fdiv']

    md2_addr = LABELS['.md2']
    div1_addr = LABELS['.div1']
    error_addr = LABELS['.FP_ERROR_PROC']
    flag_addr = LABELS['.fp_norm_boundary_state']

    seen_md2 = seen_div1 = False
    for step in range(3000):
        pc = mpu.pc
        if pc == md2_addr and not seen_md2:
            seen_md2 = True
            print(f"  AT .md2 entry (step {step}): A=${mpu.a:02x} "
                  f"carry={'SET' if mpu.p & 1 else 'CLEAR'} "
                  f"N={'SET' if mpu.p & 0x80 else 'CLEAR'} "
                  f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
        if pc == div1_addr and not seen_div1:
            seen_div1 = True
            print(f"  -> reached .div1 (step {step}): "
                  f"FP1_EXP=${mpu.memory[0x61]:02x}")
        if pc == error_addr:
            print(f"  -> TRAPPED at step {step}, code={mpu.memory[0xFE]}")
            break
        if pc == SENTINEL:
            print(f"  -> REAL EXIT at step {step}")
            break
        mpu.step()
    else:
        print("  -> didn't finish in 3000 steps")
    return state

print("=== raw byte-arithmetic check ===")
for label, td in [("VALID FLOOR", -128), ("INVALID one-past-ceiling", 128)]:
    e1, e2 = split_for_true_diff(td)
    raw_diff = (e2 - e1) & 0xFF
    signed = raw_diff - 256 if raw_diff >= 128 else raw_diff
    print(f"{label}: divisor=${e1:02x} dividend=${e2:02x} "
          f"raw(dividend-divisor) mod256=${raw_diff:02x} (signed: {signed})")

trace_case("VALID FLOOR", -128)
trace_case("INVALID one-past-ceiling", 128)
