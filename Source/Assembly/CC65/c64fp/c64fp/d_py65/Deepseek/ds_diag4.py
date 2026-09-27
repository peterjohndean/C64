#!/usr/bin/env python3
"""
ds_diag4.py - Chain-FMUL diagnostic for the reverted FMUL fix.

Motivation (from the group-37 test run):
  The conditional FMUL fix validated in ds_diag3.py passed every
  isolated FMUL test, but broke composed chains in the full suite.
  sin(45 deg) returned -0.2617 instead of +0.7071, cos(0) returned
  -0.7833 instead of +1.0, tan(-30) flipped sign, ln() collapsed to
  ~0. These are not 1-ulp precision changes - they are completely
  different values, which means some intermediate in the chain is
  ending up in a state the next operation interprets differently.

Approach:
  1. List available FMUL/FADD/FP_SIN labels.
  2. Manually replay FP_SIN_PROC's Horner chain one operation at a
     time, printing every intermediate as raw bytes and decoded
     value:
         t = x*x
         p = c4
         p = p*t + c3
         p = p*t + c2
         p = p*t + c1
         p = p*t + c0
         result = x * p
  3. Do the whole chain twice: once baseline (reverted binary),
     once with the fix injected at runtime (ds_diag2-style: Y=$16,
     dec FP1_EXP, only when fp_norm_boundary_state == NORMAL).
  4. Compare step-by-step. The first divergence tells us which
     operation breaks under the fix, and what its input state was.

Run: python3 ds_diag4.py
"""

import math

from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2, dump_fp
from diag_woz import decode

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------
SENTINEL = 0x1234
FP_NORM_STATE_NORMAL = 0

# From lib_fp_sin.s Horner coefficients (known, verified):
C0 = (0x80, 0x40, 0x00, 0x00)   # +1.0
C1 = (0x7D, 0xAA, 0xAA, 0xAB)   # -1/6
C2 = (0x79, 0x44, 0x44, 0x44)   # +1/120
C3 = (0x73, 0x97, 0xF9, 0x80)   # -1/5040
C4 = (0x6D, 0x5C, 0x77, 0x8F)   # +1/362880

# rad_45 = pi/4 = 0.7853981633974483 -> $7F,$64,$87,$ED
X_45 = (0x7F, 0x64, 0x87, 0xED)

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
def push_sentinel():
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1

def resolve_label(name):
    for candidate in ('.' + name, name, '__' + name):
        if candidate in LABELS:
            return LABELS[candidate]
    return None

def hex_str(b):
    return ' '.join(f'{x:02x}' for x in b)

def decode_safe(b):
    if b is None:
        return None
    if b == (0, 0, 0, 0):
        return 0.0
    try:
        return decode(*b)
    except Exception as e:
        return f"<decode error: {e}>"

def dump_flag():
    fa = resolve_label('fp_norm_boundary_state')
    return mpu.memory[fa] if fa is not None else None

# Resolve key labels up front
CLC_ADDR = resolve_label('mul1')
if CLC_ADDR is None:
    raise SystemExit("mul1 label not found")
CLC_ADDR = CLC_ADDR - 1           # the CLC right before mul1

FLAG_ADDR = resolve_label('fp_norm_boundary_state')
if FLAG_ADDR is None:
    raise SystemExit("fp_norm_boundary_state label not found")

FMUL_ADDR = resolve_label('fmul')
FADD_ADDR = resolve_label('fadd')
ERROR_ADDR = LABELS.get('.FP_ERROR_PROC') or LABELS.get('FP_ERROR_PROC')
if ERROR_ADDR is None:
    raise SystemExit("FP_ERROR_PROC label not found")

# ---------------------------------------------------------------------
# Low-level runners
# ---------------------------------------------------------------------
def run_fmul(fp1, fp2, apply_fix=False):
    """Run one FMUL call. Returns (trapped, fp1_result, info)
    where info is a dict with the CLC-intercept state."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = FMUL_ADDR

    patched = False
    info = {'state_at_clc': None,
            'exp_before_patch': None,
            'exp_after_patch': None}

    for _ in range(50000):
        pc = mpu.pc
        if pc == CLC_ADDR and not patched:
            info['state_at_clc'] = mpu.memory[FLAG_ADDR]
            info['exp_before_patch'] = mpu.memory[0x61]
            if apply_fix and info['state_at_clc'] == FP_NORM_STATE_NORMAL:
                mpu.y = 0x16
                mpu.memory[0x61] = (mpu.memory[0x61] - 1) & 0xFF
                patched = True
            info['exp_after_patch'] = mpu.memory[0x61]
        if pc == ERROR_ADDR:
            return True, dump_fp()['FP1'], info
        if pc == SENTINEL:
            return False, dump_fp()['FP1'], info
        mpu.step()
    return None, dump_fp()['FP1'], info

def run_fadd(fp1, fp2):
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = FADD_ADDR
    for _ in range(50000):
        pc = mpu.pc
        if pc == ERROR_ADDR:
            return True, dump_fp()['FP1']
        if pc == SENTINEL:
            return False, dump_fp()['FP1']
        mpu.step()
    return None, dump_fp()['FP1']

# ---------------------------------------------------------------------
# Chain replay
# ---------------------------------------------------------------------
def step_fmul(label, a, b, apply_fix, results):
    trapped, out, info = run_fmul(a, b, apply_fix=apply_fix)
    decoded = decode_safe(out)
    flag_str = ('-' if info['state_at_clc'] is None
                else f"state@clc={info['state_at_clc']}")
    exp_info = ''
    if (info['exp_before_patch'] is not None
            and info['exp_before_patch'] != info['exp_after_patch']):
        exp_info = (f"  EXP ${info['exp_before_patch']:02x}"
                    f"->${info['exp_after_patch']:02x}")
    print(f"    {label:22s} {hex_str(a)}  x  {hex_str(b)}")
    print(f"      -> {hex_str(out)}  {flag_str}{exp_info}")
    print(f"         decoded = {decoded}")
    results.append((label, out, decoded))
    return out if not trapped else None

def step_fadd(label, a, b, results):
    trapped, out = run_fadd(a, b)
    decoded = decode_safe(out)
    print(f"    {label:22s} {hex_str(a)}  +  {hex_str(b)}")
    print(f"      -> {hex_str(out)}")
    print(f"         decoded = {decoded}")
    results.append((label, out, decoded))
    return out if not trapped else None

def full_chain(x, apply_fix, title):
    print()
    print("=" * 72)
    print(f"{title}")
    print("=" * 72)
    print(f"  x = {hex_str(x)}  ({decode_safe(x)})")
    print()

    results = []

    # t = x*x
    t = step_fmul("t = x*x", x, x, apply_fix, results)
    if t is None:
        return None, results

    # p = c4
    p = C4
    print(f"    {'p = c4':22s} (constant)")
    print(f"      -> {hex_str(p)}")
    print(f"         decoded = {decode_safe(p)}")
    results.append(("p = c4", p, decode_safe(p)))

    # p = p*t + c3
    p = step_fmul("p = p*t", p, t, apply_fix, results)
    p = step_fadd("p = p + c3", p, C3, results)
    # p = p*t + c2
    p = step_fmul("p = p*t", p, t, apply_fix, results)
    p = step_fadd("p = p + c2", p, C2, results)
    # p = p*t + c1
    p = step_fmul("p = p*t", p, t, apply_fix, results)
    p = step_fadd("p = p + c1", p, C1, results)
    # p = p*t + c0
    p = step_fmul("p = p*t", p, t, apply_fix, results)
    p = step_fadd("p = p + c0", p, C0, results)

    # result = x * p
    result = step_fmul("result = x*p", x, p, apply_fix, results)
    return result, results

# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
print("=" * 72)
print("ds_diag4.py - Chain-FMUL divergence diagnostic")
print("=" * 72)
print()
print(f"  fmul    @ ${FMUL_ADDR:04x}")
print(f"  fadd    @ ${FADD_ADDR:04x}")
print(f"  clc     @ ${CLC_ADDR:04x}  (intercept for fix injection)")
print(f"  flag    @ ${FLAG_ADDR:04x}  (fp_norm_boundary_state)")
print(f"  error   @ ${ERROR_ADDR:04x}  (FP_ERROR_PROC)")
print()
print(f"  FP_SIN label lookup:",
      "not needed (chain replayed manually)")

# Sanity check: verify the CLC operand
opc = mpu.memory[CLC_ADDR]
print()
print(f"  sanity: byte @ ${CLC_ADDR:04x} = ${opc:02x}  "
      f"({'CLC - OK' if opc == 0x18 else 'UNEXPECTED - check label offset'})")

# Run the chain baseline and fixed
baseline_result, baseline_steps = full_chain(
    X_45, apply_fix=False, title="BASELINE CHAIN (reverted binary)")
fixed_result, fixed_steps = full_chain(
    X_45, apply_fix=True, title="FIXED CHAIN (runtime fix injection)")

# Side-by-side divergence table
print()
print("=" * 72)
print("DIVERGENCE TABLE")
print("=" * 72)
print(f"  {'step':24s} {'baseline':22s} {'fixed':22s} {'differs?':10s}")
print(f"  {'-'*24} {'-'*22} {'-'*22} {'-'*10}")
for (bl_lbl, bl_out, bl_dec), (fx_lbl, fx_out, fx_dec) in zip(baseline_steps, fixed_steps):
    if bl_out != fx_out:
        diff = "YES"
    else:
        diff = "no"
    bl_s = ' '.join(f'{b:02x}' for b in bl_out)
    fx_s = ' '.join(f'{b:02x}' for b in fx_out)
    print(f"  {bl_lbl:24s} {bl_s:22s} {fx_s:22s} {diff:10s}")

print()
print(f"  Baseline sin(45) = {decode_safe(baseline_result)}")
print(f"  Fixed    sin(45) = {decode_safe(fixed_result)}")
print(f"  True     sin(45) = {math.sin(math.pi/4)}")
print()
print("=" * 72)
print("INTERPRETATION")
print("=" * 72)
print("""
  The divergence table shows, per step, whether baseline and fixed
  binaries produced the same bytes. The FIRST row marked YES is the
  operation where the fix diverges. That operation's input state is
  the key: look at the fixed run's trace for that step to see
  state@clc and the EXP before/after the patch.

  If the first divergence is at a step where state@clc = NORMAL,
  the fix was applied there and something about that specific input
  (exponent, mantissa pattern) is interacting badly. The decoded
  values will show whether the result is off by a factor or a
  completely different magnitude.

  If the first divergence is at a step where state@clc != NORMAL,
  the fix was correctly skipped - and yet the result differs, which
  would mean the fix's effect on the PREVIOUS step's exponent leaked
  into this one's classify block somehow.

  If no rows show YES, the chain reproduces the isolated-test
  behaviour and the divergence must come from something outside the
  Horner sequence (range reduction, quadrant selection, sign
  handling) - in which case the next diagnostic should trace
  FP_SIN_FULL, not FP_SIN.
""")
