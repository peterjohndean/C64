#!/usr/bin/env python3
"""
diag_convert.py - convert.s / navigation.s test harness.
Reuses diag1's already-loaded MPU and label table, adds KERNAL+BASIC
ROM stubbing so commit_value's draw/message paths don't wander into
unpopulated memory.
"""
import diag1
from diag1 import _push_sentinel, SENTINEL

mpu = diag1.mpu
LABELS = diag1.LABELS

def stub_rom():
    """RTS-stub BASIC and KERNAL ROM on diag1's MPU. Idempotent."""
    for a in range(0xA000, 0xC000):
        mpu.memory[a] = 0x60
    for a in range(0xE000, 0x10000):
        mpu.memory[a] = 0x60

stub_rom()

FP1 = 0x61
FP2 = 0x69
FP_ERROR_CODE = 0xFE

def resolve(*names):
    for n in names:
        # Try the name as-given, dot-prefixed, and with any
        # 'Scope::' prefix stripped (ca65's label file emits
        # every scoped symbol flat, e.g. 'current_value' not
        # 'LayoutValues::current_value').
        variants = (n, '.' + n)
        if '::' in n:
            bare = n.rsplit('::', 1)[1]
            variants += (bare, '.' + bare)
        for key in variants:
            if key in LABELS:
                return LABELS[key]
    hints = sorted(k for k in LABELS if any(
        n.rsplit('::', 1)[-1].upper() in k.upper() for n in names))
    hint_str = f" Closest matches: {hints[:8]}" if hints else ""
    raise KeyError(
        f"none of {names!r} (or dot-prefixed) in label file.{hint_str}"
    )

#def resolve(*names):
#    for n in names:
#        for key in (n, '.' + n):
#            if key in LABELS:
#                return LABELS[key]
#    # Fuzzy hint: any label whose name contains a candidate?
#    hints = set()
#    for n in names:
#        base = n.lstrip('.').upper()
#        for k in LABELS:
#            if base in k.upper() or k.upper().lstrip('.') in base:
#                hints.add(k)
#    hint_str = f" Closest matches: {sorted(hints)}" if hints else ""
#    raise KeyError(
#        f"none of {names!r} (or dot-prefixed) in label file."
#        f"{hint_str}"
#    )

def set_fp1(exp, m0, m1, m2):
    mpu.memory[FP1:FP1+4] = [exp, m0, m1, m2]

def set_fp2(exp, m0, m1, m2):
    mpu.memory[FP2:FP2+4] = [exp, m0, m1, m2]

def get_fp1():
    return tuple(mpu.memory[FP1:FP1+4])

def _snapshot():
    return {
        'a': mpu.a, 'x': mpu.x, 'y': mpu.y,
        'c': mpu.p & 1, 'z': (mpu.p >> 1) & 1,
        'fp1': get_fp1(),
        'fp2': tuple(mpu.memory[FP2:FP2+4]),
        'fp_err': mpu.memory[FP_ERROR_CODE],
    }

def call(entry, *, a=None, x=None, y=None, max_steps=200_000,
         trap_label=None):
    mpu.sp = 0xff
    _push_sentinel()
    mpu.pc = entry
    if a is not None: mpu.a = a
    if x is not None: mpu.x = x
    if y is not None: mpu.y = y
    trap_addr = resolve(trap_label) if trap_label else None
    for _ in range(max_steps):
        pc = mpu.pc
        if trap_addr is not None and pc == trap_addr:
            return True, _snapshot()
        if pc == SENTINEL:
            return False, _snapshot()
        mpu.step()
    raise RuntimeError(
        f"timeout at ${mpu.pc:04x} SP=${mpu.sp:02x} "
        f"A=${mpu.a:02x} X=${mpu.x:02x} Y=${mpu.y:02x}"
    )
