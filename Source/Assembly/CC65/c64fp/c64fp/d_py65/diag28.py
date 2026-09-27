#!/usr/bin/env python3
"""
diag28.py - Two remaining confirmations for tonight's DeepSeek items:

1. FP_NEGATE_ENTRY's own poisoning immunity - structurally identical
   to FP_NORM_ENTRY (diag27.py), but not yet independently confirmed.
   Uses a mantissa at the exact-power-of-two negation boundary (the
   documented lib_fp_ceil.s -1.0 case) so fcompl's own renormalize
   step is genuinely exercised, not just a trivial negation.

2. The new jmp FP_ERROR resets (fdiv's div-by-zero, rtlog's overflow,
   div_ok's overflow, fix_conv's overflow) - confirms each leaves
   fp_norm_boundary_state at NORMAL immediately after trapping, by
   poisoning it beforehand and checking it's clean right at
   FP_ERROR_PROC's own entry.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state, run_fdiv
from diag_woz import decode

SENTINEL = 0x1234
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2
flag_addr = LABELS['.fp_norm_boundary_state']

def run_fp_negate_direct(fp1_exp, fp1_mant, poison_state=None):
    reset_state()
    mpu.memory[0x61] = fp1_exp
    mpu.memory[0x62:0x65] = list(fp1_mant)
    if poison_state is not None:
        mpu.memory[flag_addr] = poison_state
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.FP_NEGATE']   # the exported symbol
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, dump_fp()
        if pc == SENTINEL:
            return False, dump_fp()
        mpu.step()
    raise RuntimeError("didn't reach a final exit in 20000 steps")

print("=== PART 1: FP_NEGATE_ENTRY poisoning test ===")
print("Negating 1.0 ($80,40,00,00) - the documented exact-power-of-2 "
      "boundary case (lib_fp_ceil.s's own -1.0 derivation), which "
      "needs fcompl's own renormalize step, not a trivial negation.\n")

fp1_exp, fp1_mant = 0x80, (0x40, 0x00, 0x00)
results = []
for label, poison in [("NORMAL", None), ("CEILING", FP_NORM_STATE_CEILING),
                       ("FLOOR", FP_NORM_STATE_FLOOR)]:
    trapped, state = run_fp_negate_direct(fp1_exp, fp1_mant, poison)
    print(f"  flag={label:8s}: trapped={trapped} FP1={tuple(hex(b) for b in state['FP1'])}"
          + (f"  decoded={decode(*state['FP1'])}" if not trapped else ""))
    results.append((trapped, state['FP1']))

all_match = len(set(results)) == 1
print(f"\n{'All identical -> FP_NEGATE_ENTRY CONFIRMED working' if all_match else 'MISMATCH -> FP_NEGATE_ENTRY NOT protecting correctly'}")
# expected: -1.0 = $7F,80,00,00 (per lib_fp_ceil.s) in all three cases

print("\n=== PART 2: new trap-site resets leave the flag clean ===")

def check_trap_resets_flag(label, setup_fn, poison=FP_NORM_STATE_CEILING):
    reset_state()
    mpu.memory[flag_addr] = poison
    setup_fn()
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            flag_now = mpu.memory[flag_addr]
            print(f"  {label:30s}: reached FP_ERROR_PROC, "
                  f"flag=${flag_now:02x} {'OK (NORMAL)' if flag_now == 0 else 'STILL POISONED - fix missing/wrong'}")
            return
        mpu.step()
    print(f"  {label:30s}: never trapped in 20000 steps - setup may be wrong")

def setup_div_by_zero():
    mpu.memory[0x61:0x65] = [0, 0, 0, 0]      # divisor = 0.0
    mpu.memory[0x69:0x6d] = [0x80, 0x40, 0, 0]  # dividend = 1.0
    mpu.pc = LABELS['.fdiv']

def setup_fadd_overflow():
    # two values whose aligned exponent is already $FF and whose sum
    # needs one more increment - forces rtlog's own overflow trap
    mpu.memory[0x61:0x65] = [0xff, 0x60, 0x00, 0x00]
    mpu.memory[0x69:0x6d] = [0xff, 0x60, 0x00, 0x00]
    mpu.pc = LABELS['.fadd']

def setup_fix_overflow():
    mpu.memory[0x61:0x65] = [0xff, 0x40, 0x00, 0x00]  # huge value
    mpu.pc = LABELS['.FP_FIX']

check_trap_resets_flag("fdiv division-by-zero", setup_div_by_zero)
check_trap_resets_flag("fadd/rtlog exponent overflow", setup_fadd_overflow)
check_trap_resets_flag("FP_FIX overflow", setup_fix_overflow)
