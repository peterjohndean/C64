#!/usr/bin/env python3
"""
Phase 2 sweep: characterizes FP_CORE_PROC's FMUL/FDIV exponent-
boundary fix across a range of mantissa values, at the straddle
points where the outcome is genuinely mantissa-dependent.

CHANGELOG
----------
- run_mul_loop_from: had the SAME early-stop-at-.rts1/.norm1 bug
  diag1.py's _run_fmul_or_fdiv had (see that file's own changelog,
  found via diag25.py's clean trace). This function bypasses the
  classify block entirely (entering at .mul1 directly), so it
  cannot rely on diag1.py's shared _run_fmul_or_fdiv() as-is - it
  needs its own sentinel push, but now uses the SAME fix: only
  error_addr (trap) and SENTINEL (real return) are terminal. This
  means the ORIGINAL FMUL OVERFLOW STRADDLE sweep's "100% .rts1"
  result may have silently included some fraction of the documented
  ~2% "already normalized, genuine overflow" cases that actually
  trap under CEILING - those would have been mis-reported as clean
  successes by the old stop-at-.rts1 logic. Re-run this sweep after
  this fix to get the TRUE percentage breakdown.
- is_valid_result() (from diag_woz.py) used everywhere a mantissa
  result is checked, instead of bare is_normalized() - the latter
  mislabels canonical zero as "not normalized" even when zero is
  the correct answer, a false positive found and fixed twice
  tonight before being centralized in diag_woz.py for good.
"""

import random
from diag1 import mpu, LABELS, dump_fp, reset_state, run_fmul, run_fdiv, provisional_exponent
from diag1 import SENTINEL, _push_sentinel
from diag_woz import is_valid_result, is_normalized

FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

FP_NORM_BOUNDARY_STATE_ADDR = LABELS['.fp_norm_boundary_state']

def classify_state_for(te_sum):
    """Mirrors the ca65 classify block's OWN decision for a given
    true combined exponent - needed because run_mul_loop_from enters
    past the point in .fmul where the classify block normally runs."""
    if te_sum == 127:
        return FP_NORM_STATE_CEILING
    if te_sum == -129:
        return FP_NORM_STATE_FLOOR
    return FP_NORM_STATE_NORMAL

def run_mul_loop_from(fp1_exp, multiplier_mant, multiplicand_mant, te_sum, iterations=0x17):
    """Enters directly at .mul1, bypassing the classify block -
    fp_norm_boundary_state is poked explicitly to match what the
    real classify code would have set for this te_sum. Exit
    detection: ONLY error_addr (trap) or SENTINEL (real return) are
    terminal - see file header CHANGELOG for why .rts1/.norm1
    arrival is NOT a safe stopping point on its own."""
    reset_state()
    mpu.memory[0x61] = fp1_exp
    mpu.memory[0x62:0x65] = [0, 0, 0]
    mpu.memory[0x65:0x68] = list(multiplier_mant)
    mpu.memory[0x6a:0x6d] = list(multiplicand_mant)
    mpu.memory[FP_NORM_BOUNDARY_STATE_ADDR] = classify_state_for(te_sum)
    mpu.y = iterations
    _push_sentinel()
    mpu.pc = LABELS['.mul1']
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(50000):
        pc = mpu.pc
        if pc == error_addr:
            return True, 'trapped', dump_fp()
        if pc == SENTINEL:
            return False, 'returned', dump_fp()
        mpu.step()
    raise RuntimeError("run_mul_loop_from: didn't reach a final exit in 50000 steps")

def split_exponents(te_sum):
    te1 = te_sum // 2
    te2 = te_sum - te1
    if not (-128 <= te1 <= 127) or not (-128 <= te2 <= 127):
        raise ValueError(f"te_sum={te_sum} has no valid balanced split")
    return (te1 + 128) & 0xff, (te2 + 128) & 0xff

def split_exponents_div(te_diff):
    base_te1 = max(-128, min(127, -te_diff // 2))
    te2 = base_te1 + te_diff
    if not (-128 <= base_te1 <= 127) or not (-128 <= te2 <= 127):
        raise ValueError(f"te_diff={te_diff} has no valid split "
                          f"(tried base_te1={base_te1}, te2={te2})")
    return (base_te1 + 128) & 0xff, (te2 + 128) & 0xff

def random_mantissa():
    while True:
        b0 = random.randint(0, 255)
        if is_normalized((b0, 0, 0)):
            return (b0, random.randint(0, 255), random.randint(0, 255))

def sweep_straddle_point(te_sum, label, n_random=200, seed=0):
    random.seed(seed)
    e1, e2 = split_exponents(te_sum)
    prov_exp = provisional_exponent(e1, e2)

    fixed_mantissas = [
        ("1.0",  (0x40, 0x00, 0x00)),
        ("1.25", (0x50, 0x00, 0x00)),
        ("1.5",  (0x60, 0x00, 0x00)),
        ("near_max", (0x7f, 0xff, 0xff)),
    ]

    results = {}
    def record(outcome, m1, m2, state):
        if outcome == 'returned' and not is_valid_result(state['FP1']):
            outcome = 'RETURNED_BUT_INVALID'
        results[outcome] = results.get(outcome, 0) + 1

    print(f"\n=== {label} (te1+te2={te_sum}) ===")

    for name, m in fixed_mantissas:
        trapped, outcome, state = run_mul_loop_from(prov_exp, m, m, te_sum)
        record(outcome, m, m, state)

    for i in range(n_random):
        m1 = random_mantissa()
        m2 = random_mantissa()
        trapped, outcome, state = run_mul_loop_from(prov_exp, m1, m2, te_sum)
        record(outcome, m1, m2, state)

    total = sum(results.values())
    for outcome, count in sorted(results.items()):
        pct = 100 * count / total
        print(f"  {outcome:20s}: {count:4d}/{total} ({pct:5.1f}%)")
    return results

def sweep_fdiv_straddle_point(te_diff, label, n_random=200, seed=0):
    random.seed(seed)
    e1, e2 = split_exponents_div(te_diff)

    fixed_mantissas = [
        ("1.0",  (0x40, 0x00, 0x00)),
        ("1.25", (0x50, 0x00, 0x00)),
        ("1.5",  (0x60, 0x00, 0x00)),
        ("near_max", (0x7f, 0xff, 0xff)),
    ]

    results = {}
    def record(outcome, state):
        if outcome == 'returned' and not is_valid_result(state['FP1']):
            outcome = 'RETURNED_BUT_INVALID'
        results[outcome] = results.get(outcome, 0) + 1

    print(f"\n=== FDIV {label} (te2-te1={te_diff}) ===")

    for name, m in fixed_mantissas:
        divisor = (e1,) + m
        dividend = (e2,) + m
        trapped, outcome, state = run_fdiv(divisor, dividend)
        record(outcome, state)

    for i in range(n_random):
        m1 = random_mantissa()
        m2 = random_mantissa()
        divisor = (e1,) + m1
        dividend = (e2,) + m2
        trapped, outcome, state = run_fdiv(divisor, dividend)
        record(outcome, state)

    total = sum(results.values())
    for outcome, count in sorted(results.items()):
        pct = 100 * count / total
        print(f"  {outcome:20s}: {count:4d}/{total} ({pct:5.1f}%)")
    return results

def sanity_check_unconditional(te_sum, expect_trap, label):
    e1, e2 = split_exponents(te_sum)
    print(f"\n=== sanity: {label} (te1+te2={te_sum}) ===")
    mantissas = [(0x40,0x00,0x00), (0x60,0x00,0x00), (0x7f,0xff,0xff)]
    all_ok = True
    for m in mantissas:
        trapped, outcome, state = run_fmul((e1,)+m, (e2,)+m)
        ok = trapped == expect_trap
        all_ok &= ok
        print(f"  mantissa={m}: trapped={trapped} {'OK' if ok else 'MISMATCH'}")
    print(f"  {label}: {'PASS' if all_ok else 'FAIL - investigate!'}")
    return all_ok

def sanity_check_fdiv_unconditional(te_diff, expect_trap, label):
    e1, e2 = split_exponents_div(te_diff)
    print(f"\n=== FDIV sanity: {label} (te2-te1={te_diff}) ===")
    mantissas = [(0x40,0x00,0x00), (0x60,0x00,0x00), (0x7f,0xff,0xff)]
    all_ok = True
    for m in mantissas:
        divisor = (e1,) + m
        dividend = (e2,) + m
        trapped, outcome, state = run_fdiv(divisor, dividend)
        ok = trapped == expect_trap
        all_ok &= ok
        print(f"  mantissa={m}: trapped={trapped} {'OK' if ok else 'MISMATCH'}")
    print(f"  {label}: {'PASS' if all_ok else 'FAIL - investigate!'}")
    return all_ok

if __name__ == '__main__':
    trapped, outcome, state = run_mul_loop_from(0x87, (0x60,0x00,0x00), (0x50,0x00,0x00), te_sum=126)
    assert not trapped, f"run_mul_loop_from regression: expected no trap, got trapped"
    print("run_mul_loop_from validated against real 12*10 trace: OK\n")

    sweep_straddle_point(127, "OVERFLOW STRADDLE")
    sweep_straddle_point(-129, "UNDERFLOW STRADDLE")

    sanity_check_unconditional(128, expect_trap=True, label="one past overflow ceiling")
    sanity_check_unconditional(126, expect_trap=False, label="one below overflow ceiling")
    sanity_check_unconditional(-130, expect_trap=False, label="one past underflow floor")
    sanity_check_unconditional(-128, expect_trap=False, label="one above underflow floor")

    sweep_fdiv_straddle_point(127, "CEILING STRADDLE")
    sweep_fdiv_straddle_point(-129, "FLOOR STRADDLE")
    sweep_fdiv_straddle_point(-128, "VALID FLOOR (2nd collision)")
    sweep_fdiv_straddle_point(128, "INVALID one-past-ceiling (2nd collision)")

    sanity_check_fdiv_unconditional(126, expect_trap=False, label="one below ceiling")
    sanity_check_fdiv_unconditional(-130, expect_trap=False, label="one past floor")
    # NOTE: te2-te1=128 and -128 are NO LONGER unconditional-trap/no-
    # trap sanity checks now that the second collision's fix is
    # applied - they are mantissa-dependent (see the new sweep
    # entries above instead). The old sanity_check_fdiv_unconditional
    # calls for 128/-128 are deliberately REMOVED here, not just
    # left to fail - keeping them would document a wrong invariant.
