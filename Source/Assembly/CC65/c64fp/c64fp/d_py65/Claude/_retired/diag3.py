#!/usr/bin/env python3
"""
diag3.py - ALGORITHM-LEVEL validation of the proposed FMUL/FDIV
boundary fix, before any lib_fp.s edit. Once lib_fp.s is patched and
reassembled, re-run diag2.py's sweep_straddle_point()/
sanity_check_unconditional() against the REAL patched binary and
confirm every outcome matches what this model predicts. This file
is a design check, not a substitute for that hardware-truth pass -
same "simulator confirmed, hardware pending" discipline the rest of
this project already applies.
"""

FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

def classify(te1, te2):
    """Mirrors the proposed 6510 code exactly: EOR #$80 already
    applied conceptually (te1/te2 ARE the true signed exponents
    here), then a signed 8-bit add. `overflowed` models the V flag."""
    raw = te1 + te2                        # true, unwrapped sum
    wrapped = ((raw + 128) % 256) - 128     # what ADC's A register holds
    overflowed = not (-128 <= raw <= 127)   # V flag
    if wrapped != 127:
        return FP_NORM_STATE_NORMAL, raw
    return (FP_NORM_STATE_FLOOR if overflowed else FP_NORM_STATE_CEILING), raw

def proposed_norm_outcome(state, mantissa_needs_decrement):
    """Mirrors the proposed norm/norm1/rts1 patch's FP1_EXP==0 branch."""
    if state == FP_NORM_STATE_NORMAL:
        return 'unchanged'                  # pre-fix behaviour, untouched
    if not mantissa_needs_decrement:
        return 'trap' if state == FP_NORM_STATE_CEILING else 'unchanged'
    if state == FP_NORM_STATE_CEILING:
        return 'decrement_ok'
    return 'underflow_zero'                 # FP_NORM_STATE_FLOOR

def expected_correct(true_sum, mantissa_needs_decrement):
    """Independent ground truth, derived from the math directly -
    NOT from the proposed code - so this is a real check, not a
    tautology."""
    if true_sum == 127:
        return 'decrement_ok' if mantissa_needs_decrement else 'trap'
    if true_sum == -129:
        # -128 is a valid floor value, but subject to the SEPARATE,
        # already-tracked zero-collision limitation (S=-128 producing
        # FP1_EXP=$00) - deliberately out of scope for THIS fix.
        return 'underflow_zero' if mantissa_needs_decrement else 'unchanged'
    return 'unchanged'   # not a boundary case - out of this fix's scope

# ============================================================
# FDIV extension - classify_div and its own ground truth.
#
# STATUS: PRE_COMPENSATION_DIV = 0 is CONFIRMED via a real VICE
# trace (two cases: 12.0/10.0=1.2 -> .rts1, 10.0/12.0=0.8333 ->
# .norm1, both at te2-te1=0, .div1 entry FP1_EXP=$80 in both -
# see diag1.py's DIV_CASES). What is STILL unconfirmed is
# classify_div's behavior AT the straddle points themselves
# (raw=127/-129) - that needs a run_div_loop_from sweep, analogous
# to diag2.py's sweep_straddle_point, entered at .div1. The two
# traces so far only exercised raw=0, nowhere near either boundary.
# ============================================================

PRE_COMPENSATION_DIV = 0   # CONFIRMED - see STATUS above

# diag3.py - classify_div now uses the CONFIRMED constant
def classify_div(te1, te2):
    raw = te2 - te1 + PRE_COMPENSATION_DIV   # = te2 - te1, confirmed
    wrapped = ((raw + 128) % 256) - 128
    overflowed = not (-128 <= raw <= 127)
    if wrapped != 127:
        return FP_NORM_STATE_NORMAL, raw
    return (FP_NORM_STATE_FLOOR if overflowed else FP_NORM_STATE_CEILING), raw

def expected_correct_div(true_diff, mantissa_needs_decrement):
    """Ground truth for FDIV's OWN two straddle points. NOTE: unlike
    FMUL, it is not yet confirmed that FDIV's straddle points are at
    the same true_diff values (127 / -129) as FMUL's true_sum values -
    that symmetry assumption itself needs confirming once
    PRE_COMPENSATION_DIV is known, since a nonzero compensation would
    shift where the ambiguous provisional-$00 case actually falls."""
    if true_diff == 127:
        return 'decrement_ok' if mantissa_needs_decrement else 'trap'
    if true_diff == -129:
        return 'underflow_zero' if mantissa_needs_decrement else 'unchanged'
    return 'unchanged'

# WORKED EXAMPLE (hand-derived only - NOT yet py65/VICE confirmed):
# divisor 10.0 (e1=$83, te1=3), dividend 100.0 (e2=$86, te2=6)
# true quotient exponent = te2-te1 = 3 -> expect result 10.0, e=$83
# If PRE_COMPENSATION_DIV=0 this predicts provisional=$83 directly
# (no norm decrement needed at all for this particular case, since
# it's nowhere near either straddle point) - this by itself does
# NOT confirm the compensation constant, only that something not
# wildly wrong is happening for an ordinary in-range case. Deriving
# the ACTUAL constant needs a case where a decrement/no-decrement
# distinction is observable, exactly as 10*10 vs 12*(-5) distinguished
# FMUL's cases in diag1.py's own CASES list.

if __name__ == '__main__':
   
    failures = []
    for true_sum in (127, -129, 126, -130, 0, 50, -50, 128, -256):
        for needs_dec in (True, False):
            te1 = true_sum // 2
            te2 = true_sum - te1
            if not (-128 <= te1 <= 127) or not (-128 <= te2 <= 127):
                continue   # no valid single-add split - skip (fdiv's
                           # own sweep needs its own split logic anyway)
            state, raw = classify(te1, te2)
            got  = proposed_norm_outcome(state, needs_dec)
            want = expected_correct(true_sum, needs_dec)
            ok = (got == want)
            print(f"true_sum={true_sum:5d} needs_dec={str(needs_dec):5} "
                  f"state={state} got={got:14s} want={want:14s} "
                  f"{'OK' if ok else 'MISMATCH'}")
            if not ok:
                failures.append((true_sum, needs_dec, got, want))
    print()
    print(f"{len(failures)} mismatch(es)" if failures else
          "All classification/outcome pairs match derived ground truth.")
