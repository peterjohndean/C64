#!/usr/bin/env python3
"""
diag_print_dispatch.py - verify 'p' vs 'P' route to different
printer code paths.

Strategy: patch every KERNAL entry print_key touches with a jump
to a shared hook that increments a counter and returns carry
clear. Then count CHROUT/OPEN/CLOSE calls for 'p' vs 'P' -- the
full report has many more lines, so the count should be roughly
4x the quick path's.

Cannot verify *content* this way; that needs a real printer or
VICE with printer emulation.
"""
import diag_convert
from diag1 import _push_sentinel, SENTINEL

mpu = diag_convert.mpu
PRINT_KEY = diag_convert.resolve('print_key')

HOOK    = 0x9000
COUNTER = 0x8FF0

# --- Shared hook: increment counter, clear carry, RTS ---
mpu.memory[HOOK + 0] = 0xEE   # INC $8FF0
mpu.memory[HOOK + 1] = COUNTER & 0xFF
mpu.memory[HOOK + 2] = COUNTER >> 8
mpu.memory[HOOK + 3] = 0x18   # CLC
mpu.memory[HOOK + 4] = 0x60   # RTS

# --- Redirect every KERNAL entry print_key uses to the hook ---
# JMP $9000 = 4C 00 90
for vec in (0xFFC0,   # OPEN
            0xFFC3,   # CLOSE
            0xFFC9,   # CHKOUT
            0xFFCC,   # CLRCHN
            0xFFD2,   # CHROUT
            0xFFBD,   # SETNAM
            0xFFBA):  # SETLFS
    mpu.memory[vec + 0] = 0x4C
    mpu.memory[vec + 1] = HOOK & 0xFF
    mpu.memory[vec + 2] = HOOK >> 8

def count_calls(key_byte):
    mpu.memory[COUNTER] = 0
    diag_convert.call(PRINT_KEY, a=key_byte, max_steps=500_000)
    return mpu.memory[COUNTER]

c_quick = count_calls(0x50)   # PETSCII 'p'
c_full  = count_calls(0xD0)   # PETSCII 'P' (shift-P)

print(f"'p' (quick): {c_quick} KERNAL calls")
print(f"'P' (full):  {c_full} KERNAL calls")
print()
if c_full > c_quick:
    print("[OK] full report dispatches to a longer code path")
else:
    print("[** FAIL **] both keys took the same path")
