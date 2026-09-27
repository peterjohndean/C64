#!/usr/bin/env python3
"""
diag_ieee_subnormal.py

Direct tests for FP_TO_IEEE754 and FP_FROM_IEEE754 subnormal handling.
Uses diag_convert's already-loaded MPU + ROM stubs.
"""
import diag_convert
from diag_convert import set_fp1, get_fp1, resolve, call

FP_TO_IEEE   = resolve('FP_TO_IEEE754_PROC',   'FP_TO_IEEE754')
FP_FROM_IEEE = resolve('FP_FROM_IEEE754_PROC', 'FP_FROM_IEEE754')

def woz_to_ieee(b):
    set_fp1(*b)
    call(FP_TO_IEEE, max_steps=10_000)
    return list(get_fp1())

def ieee_to_woz(b):
    set_fp1(*b)
    trapped, snap = call(FP_FROM_IEEE, max_steps=10_000,
                         trap_label='FP_ERROR_PROC')
    # trap code is passed in A to FP_ERROR (lda #4 / lda #5 / jmp)
    return trapped, list(snap['fp1']), snap['a']

FORWARD = [
    ([0x01,0x40,0x00,0x00], [0x00,0x40,0x00,0x00], "2^-127"),
    ([0x01,0x40,0x3E,0xCB], [0x00,0x40,0x3E,0xCB], "5.8999E-39"),
    ([0x01,0x7F,0xFF,0xFF], [0x00,0x7F,0xFF,0xFF], "just below 2^-126"),
    ([0x01,0xC0,0x00,0x00], [0x80,0x40,0x00,0x00], "-2^-127"),
    ([0x02,0x40,0x00,0x00], [0x00,0x80,0x00,0x00], "smallest normal"),
    ([0x80,0x40,0x00,0x00], [0x3F,0x80,0x00,0x00], "+1.0 existing"),
    ([0x00,0x00,0x00,0x00], [0x00,0x00,0x00,0x00], "zero existing"),
]

REVERSE = [
    ([0x00,0x40,0x00,0x00], [0x01,0x40,0x00,0x00], "2^-127"),
    ([0x00,0x40,0x3E,0xCB], [0x01,0x40,0x3E,0xCB], "5.8999E-39"),
    ([0x00,0x7F,0xFF,0xFF], [0x01,0x7F,0xFF,0xFF], "just below 2^-126"),
    ([0x80,0x40,0x00,0x00], [0x01,0xC0,0x00,0x00], "-2^-127"),
    ([0x00,0x80,0x00,0x00], [0x02,0x40,0x00,0x00], "smallest normal"),
    ([0x00,0x00,0x00,0x01], [0x00,0x00,0x00,0x00], "underflow F=1"),
    ([0x00,0x3F,0xFF,0xFF], [0x00,0x00,0x00,0x00], "underflow F<2^22"),
    ([0x3F,0x80,0x00,0x00], [0x80,0x40,0x00,0x00], "+1.0 existing"),
    ([0x00,0x00,0x00,0x00], [0x00,0x00,0x00,0x00], "zero existing"),
]

TRAPS = [
    ([0x7F,0x80,0x00,0x00], 4, "Inf"),
    ([0x7F,0xC0,0x00,0x00], 5, "NaN"),
]

def roundtrip_samples():
    # Per PROJECT.txt: Woz exp byte $01 with |M| in [2^22, 2^23 - 1].
    # Positive mantissas: 0x400000..0x7FFFFF.
    # Negative mantissas (2's comp of |M|): 0x800001..0xC00000.
    pos = [0x400000,0x480000,0x500000,0x580000,0x600000,
           0x680000,0x700000,0x780000,0x7F0000,0x7FFFFF]
    neg = [0x800001,0x880000,0x900000,0x980000,0xA00000,
           0xA80000,0xB00000,0xB80000,0xBF0000,0xC00000]
    for v in pos + neg:
        yield [0x01, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]

def main():
    fails = 0

    print("=== Forward (Woz -> IEEE) ===")
    for woz, want, label in FORWARD:
        got = woz_to_ieee(woz)
        ok = got == want
        print(f"{'ok  ' if ok else 'FAIL'} [{label}] {woz} -> {got}"
              + ('' if ok else f'  want {want}'))
        fails += not ok

    print()
    print("=== Reverse (IEEE -> Woz) ===")
    for ieee, want, label in REVERSE:
        trapped, got, code = ieee_to_woz(ieee)
        ok = (not trapped) and got == want
        extra = f" trapped code={code}" if trapped else ""
        print(f"{'ok  ' if ok else 'FAIL'} [{label}] {ieee} -> {got}{extra}"
              + ('' if ok else f'  want {want}'))
        fails += not ok

    print()
    print("=== Traps (Inf / NaN) ===")
    for ieee, want_code, label in TRAPS:
        trapped, got, code = ieee_to_woz(ieee)
        ok = trapped and code == want_code
        print(f"{'ok  ' if ok else 'FAIL'} [{label}] {ieee} -> "
              f"trapped={trapped} code={code}"
              + ('' if ok else f'  want code {want_code}'))
        fails += not ok

    print()
    print("=== Round-trip (exp byte $01, |M| in [2^22, 2^23) ) ===")
    for orig in roundtrip_samples():
        mid = woz_to_ieee(orig)
        trapped, back, code = ieee_to_woz(mid)
        ok = (not trapped) and back == orig
        print(f"{'ok  ' if ok else 'FAIL'} {orig} -> {mid} -> {back}"
              + ('' if ok else f'  want {orig}'))
        fails += not ok

    print()
    print(f"{fails} failure(s)")
    return 1 if fails else 0

if __name__ == "__main__":
    raise SystemExit(main())
