#!/usr/bin/env python3
"""Dump binary_from_ascii's compiled code and probe it with known input."""
import diag_convert
mpu = diag_convert.mpu

BIN = diag_convert.resolve('binary_from_ascii')
print(f"binary_from_ascii = ${BIN:04X}")

# 1. Compiled machine code, first 48 bytes.
print("\nCompiled bytes:")
for i in range(0, 48, 8):
    row = mpu.memory[BIN + i : BIN + i + 8]
    print(f"  ${BIN+i:04X}: " + " ".join(f"{b:02X}" for b in row))

# 2. Verify the buffer write works (this is outside the routine).
BUF = 0x9000
mpu.memory[BUF:BUF+32] = list(b'1' * 32)
print("\nBuffer check (should be 31 31 31 ...):")
print(f"  ${BUF:04X}: " + " ".join(f"{b:02X}" for b in mpu.memory[BUF:BUF+8]))

# 3. Single-shot probe, all ones.
BUF2 = 0x9100
mpu.memory[BUF2:BUF2+32] = list(b'1' * 32)
_, s = diag_convert.call(BIN, a=BUF2 & 0xFF, y=BUF2 >> 8)
print(f"\nAll-ones input: FP1={[f'{b:02X}' for b in s['fp1']]} "
      f"carry={s['c']}  (expect FP1=FF FF FF FF, carry=0)")

# 4. Probe with 'A'*32 (deliberately invalid).
BUF3 = 0x9200
mpu.memory[BUF3:BUF3+32] = list(b'A' * 32)
_, s = diag_convert.call(BIN, a=BUF3 & 0xFF, y=BUF3 >> 8)
print(f"All-A input:    FP1={[f'{b:02X}' for b in s['fp1']]} "
      f"carry={s['c']}  (expect carry=1)")

# 5. Probe with a single one-bit pattern (one '1', 31 '0's).
BUF4 = 0x9300
mpu.memory[BUF4:BUF4+32] = list(b'1' + b'0' * 31)
_, s = diag_convert.call(BIN, a=BUF4 & 0xFF, y=BUF4 >> 8)
print(f"'1'+31*'0':     FP1={[f'{b:02X}' for b in s['fp1']]} "
      f"carry={s['c']}  (expect FP1=80 00 00 00, carry=0)")
