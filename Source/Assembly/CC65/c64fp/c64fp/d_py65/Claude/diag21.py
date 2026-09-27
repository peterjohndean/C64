#!/usr/bin/env python3
"""
diag21.py - Distinguishes two competing theories for T19's failure:

THEORY A (poisoning): T18's trap leaves fp_norm_boundary_state dirty,
and T19 inherits that stale state from an unrelated prior call.

THEORY B (classify design flaw): T19's OWN classify block, using ITS
OWN operands, correctly computes true_diff=-129 and sets FLOOR - but
FDIV's $FF collision (unlike FMUL's $00 collision) has NO genuine
"rescue" case on the true_diff=-129 side: that side is UNCONDITIONALLY
invalid (one full step below the real floor), regardless of mantissa,
so deferring to norm's mantissa-dependent decision (as the FLOOR label
does) is itself wrong - it should force zero immediately, not defer.

Tests:
  1. T19 in isolation (fresh reset, nothing run before it) - if it
     STILL produces the wrong $FF,40,00,00 result, Theory A is ruled
     out (nothing to poison from) and Theory B is supported.
  2. T18 then T19 back-to-back (matching the real test suite's
     execution order) - to see whether running T18 first changes
     T19's outcome at all.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state, run_fdiv
from diag_woz import decode

T18_DIVISOR  = (0x40, 0x40, 0x00, 0x00)
T18_DIVIDEND = (0xc0, 0x40, 0x00, 0x00)
T19_DIVISOR  = (0xc1, 0x40, 0x00, 0x00)
T19_DIVIDEND = (0x40, 0x40, 0x00, 0x00)

flag_addr = LABELS['.fp_norm_boundary_state']

print("=== Test 1: T19 in COMPLETE isolation (nothing run before it) ===")
trapped, outcome, state = run_fdiv(T19_DIVISOR, T19_DIVIDEND)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    print(f"decoded={decode(*state['FP1'])}  (expected: 0.0)")
print(f"flag after={mpu.memory[flag_addr]:02x}")

print("\n=== Test 2: T18 then T19, back-to-back (matches real suite order) ===")
trapped18, outcome18, state18 = run_fdiv(T18_DIVISOR, T18_DIVIDEND)
print(f"T18: trapped={trapped18} outcome={outcome18}")
print(f"flag right after T18's trap={mpu.memory[flag_addr]:02x}")

trapped19, outcome19, state19 = run_fdiv(T19_DIVISOR, T19_DIVIDEND)
print(f"T19: trapped={trapped19} outcome={outcome19} FP1={tuple(hex(b) for b in state19['FP1'])}")
if not trapped19:
    print(f"decoded={decode(*state19['FP1'])}  (expected: 0.0)")

print("\n=== Conclusion ===")
if not trapped and state['FP1'] != (0, 0, 0, 0):
    print("Test 1 ALSO fails in isolation -> Theory A (poisoning) REFUTED.")
    print("The bug is in T19's own classify logic (Theory B), not inherited state.")
else:
    print("Test 1 succeeds in isolation but Test 2 fails -> Theory A (poisoning) CONFIRMED.")