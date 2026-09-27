#!/usr/bin/env python3
"""
diag_mathops_sweep.py - verify apply_math_key across every function.

GOTCHAS (learned the hard way)
==============================
1. apply_math_key dispatches on PETSCII bytes, not ASCII. Source-code
   's' compiles (via ca65's charmap) to PETSCII $53 (unshifted S);
   source 'S' compiles to $D3 (shifted S). Both dispatch to @sin.
   KERNAL_GETIN also returns PETSCII. petscii_key() below converts
   source letters to the right byte for diagnostic input.

2. apply_math_key stores its result in current_value, THEN calls
   refresh_display, which clobbers FP1 with conversion scratch.
   Read the result from current_value, never from FP1 after the
   call. (Earlier versions of this file read FP1 and reported all
   zeros; that was a diagnostic bug, not a library bug.)

3. FP_SIN_FULL and friends are Taylor-series evaluations that can
   run 50,000-150,000 instructions. Use max_steps >= 200,000.

4. Trap detection: use the boolean returned by call(), NOT
   s['fp_err'] -- the snapshot is taken at FP_ERROR_PROC's entry,
   before sta FP_ERROR_CODE executes.
"""

# Observed residuals (all comfortably within approx() tolerance):
#   sin(pi/2) = 1.000004    (4e-6, systematic across ±1 sin/cos)
#   tan(pi/4) = 0.9999993   (7e-7)
#   ln(e)     = 0.9999999   (1e-7)
#   rad->deg  = 89.99998    (2e-7 relative)
# The 4e-6 sin/cos offset is larger than the library's stated
# ~1e-7 but renders as "1.0000E+00" at the UI's 5-sig-fig display
# precision. Do not tighten approx() below 1e-5 without first
# investigating that offset -- and if you do, do it as a deliberate
# investigation, not a spur-of-the-moment tolerance tweak.

import math

import diag_convert
from diag_woz import decode, encode

mpu = diag_convert.mpu
CUR = diag_convert.resolve('LayoutValues::current_value', 'current_value')
KEY = diag_convert.resolve('apply_math_key')


# ============================================================
# PETSCII key helpers
# ============================================================
def petscii_key(ch):
    """Lowercase source letter -> PETSCII byte for the unshifted key.
    's' -> $53, 'c' -> $43, 't' -> $54, 'l' -> $4C, 'g' -> $47,
    'e' -> $45, 'd' -> $44, 'r' -> $52. Verified against the
    disassembly dump of apply_math_key at $08DF."""
    c = ord(ch)
    if 0x61 <= c <= 0x7A:           # 'a'-'z'
        return c - 0x20             # -> PETSCII $41-$5A
    raise ValueError(
        f"petscii_key expects a lowercase letter, got {ch!r}"
    )


def petscii_key_shifted(ch):
    """The shifted (uppercase) variant of the same key. apply_math_key
    accepts both -- 's' and 'S' both dispatch to @sin."""
    return petscii_key(ch) + 0x80


# ============================================================
# Result extraction
# ============================================================
def read_result():
    """current_value is where apply_math_key stores its result
    (via FP_STORE1_MACRO) before refresh_display clobbers FP1."""
    b = tuple(mpu.memory[CUR:CUR + 4])
    return 0.0 if b == (0, 0, 0, 0) else decode(*b)


def approx(got, want):
    """Library is documented at ~5 sig figs; tolerance is generous
    because we're testing the pipeline, not last-bit accuracy."""
    return abs(got - want) <= max(1e-4, abs(want) * 1e-3)


# ============================================================
# Test cases
# (key_letter, input_value, expected or None=trap, description)
# ============================================================
CASES = [
    # ---- sin ----
    ('s',  0.0,          0.0,          "sin(0)"),
    ('s',  math.pi / 2,  1.0,          "sin(pi/2)"),
    ('s',  math.pi,      0.0,          "sin(pi)"),
    ('s', -math.pi / 2, -1.0,          "sin(-pi/2)"),

    # ---- cos ----
    ('c',  0.0,          1.0,          "cos(0)"),
    ('c',  math.pi / 2,  0.0,          "cos(pi/2)"),
    ('c',  math.pi,     -1.0,          "cos(pi)"),

    # ---- tan ----
    ('t',  0.0,          0.0,          "tan(0)"),
    ('t',  math.pi / 4,  1.0,          "tan(pi/4)"),

    # ---- ln (natural log) ----
    ('l',  math.e,       1.0,          "ln(e)"),
    ('l',  1.0,          0.0,          "ln(1)"),
    ('l',  0.0,          None,         "ln(0) -> trap"),
    ('l', -1.0,          None,         "ln(-1) -> trap"),

    # ---- log10 ----
    ('g',  100.0,        2.0,          "log10(100)"),
    ('g',  1.0,          0.0,          "log10(1)"),
    ('g',  0.0,          None,         "log10(0) -> trap"),

    # ---- exp (e^x) ----
    ('e',  0.0,          1.0,          "exp(0)"),
    ('e',  1.0,          math.e,       "exp(1)"),
    ('e',  100.0,        None,         "exp(100) -> trap"),

    # ---- deg -> rad ----
    ('d',  180.0,        math.pi,      "deg->rad(180)"),
    ('d',  0.0,          0.0,          "deg->rad(0)"),
    ('d', -90.0,        -math.pi / 2,  "deg->rad(-90)"),

    # ---- rad -> deg ----
    ('r',  math.pi,      180.0,        "rad->deg(pi)"),
    ('r',  0.0,          0.0,          "rad->deg(0)"),
    ('r',  math.pi / 2,  90.0,         "rad->deg(pi/2)"),
]


# ============================================================
# Runner
# ============================================================
passed = 0
failed = 0

for key_letter, val, expect, desc in CASES:
    fp = (0, 0, 0, 0) if val == 0 else encode(val)
    mpu.memory[CUR:CUR + 4] = list(fp)

    trapped, s = diag_convert.call(
        KEY,
        a=petscii_key(key_letter),
        max_steps=500_000,
        trap_label='.FP_ERROR_PROC',
    )

    if expect is None:
        ok = trapped
        status = "OK" if ok else "** NO TRAP **"
        print(f"{desc:22s} key={key_letter}  "
              f"trapped={int(trapped)}  [{status}]")
    elif trapped:
        ok = False
        print(f"{desc:22s} key={key_letter}  "
              f"** UNEXPECTED TRAP **")
    else:
        got = read_result()
        ok = approx(got, expect)
        status = "OK" if ok else "** MISMATCH **"
        print(f"{desc:22s} key={key_letter}  "
              f"got={got:+.6e} want={expect:+.6e}  [{status}]")

    if ok:
        passed += 1
    else:
        failed += 1


# ------------------------------------------------------------
# Shifted-key verification: apply_math_key accepts both 's'
# (PETSCII $53) and 'S' (PETSCII $D3) for sin. One case here to
# confirm the shifted path dispatches identically.
# ------------------------------------------------------------
print()
print("Shifted-key dispatch check:")
mpu.memory[CUR:CUR + 4] = list(encode(math.pi / 2))
_, s = diag_convert.call(
    KEY,
    a=petscii_key_shifted('s'),
    max_steps=500_000,
    trap_label='.FP_ERROR_PROC',
)
got = read_result()
ok = approx(got, 1.0)
print(f"  sin(pi/2) via SHIFT+S ($D3): got={got:+.6e}  "
      f"[{'OK' if ok else '** MISMATCH **'}]")
if ok:
    passed += 1
else:
    failed += 1


print()
print(f"Passed: {passed}  Failed: {failed}  "
      f"Total: {passed + failed}")
