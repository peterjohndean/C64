#!/usr/bin/env python3
"""Dump apply_math_key's dispatch table and trace its first step
with each candidate key byte. Answers: does the routine see our
key, and which byte does it compare against?"""
import diag_convert
from diag1 import _push_sentinel, SENTINEL
from diag_woz import encode

mpu = diag_convert.mpu
KEY = diag_convert.resolve('apply_math_key')
CUR = diag_convert.resolve('LayoutValues::current_value', 'current_value')

print(f"apply_math_key = ${KEY:04X}")

# ---------- 1. Disassembly dump (first 64 bytes) ----------
print("\nCompiled bytes:")
for i in range(0, 64, 8):
    row = mpu.memory[KEY + i : KEY + i + 8]
    print(f"  ${KEY+i:04X}: " + " ".join(f"{b:02X}" for b in row))
print()
print("Look for C9 xx / F0 yy pairs. The xx values are what each")
print("'cmp #letter' compiled to. If xx is $53, source 's' went")
print("through the charmap. If $73, the charmap wasn't applied.")
print()

# ---------- 2. Try every plausible byte for 's' ----------
# 0x53 = uppercase 'S' ASCII = lowercase 's' after charmap swap
# 0x73 = lowercase 's' ASCII = uppercase 'S' after charmap swap
print("Testing 's'-family bytes against apply_math_key:")
print()
for label, key_byte in [("'s' raw ($73)", 0x73), ("'S' raw ($53)", 0x53)]:
    # Seed with pi/2
    fp = encode(1.5707963267948966)
    mpu.memory[CUR:CUR+4] = list(fp)

    # Call
    mpu.sp = 0xff
    _push_sentinel()
    mpu.pc = KEY
    mpu.a = key_byte

    # Single-step, count steps taken to reach SENTINEL
    steps = 0
    for _ in range(20_000):
        if mpu.pc == SENTINEL:
            break
        mpu.step()
        steps += 1
    else:
        print(f"  {label}: HANG")
        continue

    carry = mpu.p & 1
    got = tuple(mpu.memory[CUR:CUR+4])
    changed = (got != tuple(fp))
    print(f"  {label}: steps={steps}  carry={carry}  "
          f"cval={[f'{b:02X}' for b in got]}  "
          f"changed={changed}")
