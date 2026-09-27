import diag_convert
from diag1 import _push_sentinel, SENTINEL

mpu = diag_convert.mpu
BIN = diag_convert.resolve('binary_from_ascii')

# --- Sanity: can we write/read FP1 and FP_STRPTR at all? ---
mpu.memory[0x61] = 0xAA
mpu.memory[0xFB] = 0xBB
print(f"write/read $61: ${mpu.memory[0x61]:02X}  (want $AA)")
print(f"write/read $FB: ${mpu.memory[0xFB]:02X}  (want $BB)")
mpu.memory[0x61] = 0x00

# --- Trace with all-'A' input (should bail via SEC/RTS) ---
BUF = 0x9200
mpu.memory[BUF:BUF+32] = list(b'A' * 32)

mpu.sp = 0xff
_push_sentinel()
mpu.pc = BIN
mpu.a = BUF & 0xFF
mpu.y = BUF >> 8

print(f"\nstart: pc=${mpu.pc:04X} a=${mpu.a:02X} y=${mpu.y:02X} "
      f"sp=${mpu.sp:02X}")
print(f"FP_STRPTR before: ${mpu.memory[0xFB]:02X}${mpu.memory[0xFC]:02X}")
print()

for step in range(40):
    pc = mpu.pc
    if pc == SENTINEL:
        print(f"\nstep {step}: SENTINEL reached")
        print(f"  P=${mpu.p:02X}  C={mpu.p & 1}")
        print(f"  FP_STRPTR after: "
              f"${mpu.memory[0xFB]:02X}${mpu.memory[0xFC]:02X}")
        print(f"  FP1 after: "
              f"{[f'{b:02X}' for b in mpu.memory[0x61:0x65]]}")
        break
    op = mpu.memory[pc]
    print(f"step {step:2d}: pc=${pc:04X} op=${op:02X}  "
          f"a=${mpu.a:02X} x=${mpu.x:02X} y=${mpu.y:02X}  "
          f"p=${mpu.p:02X}")
    mpu.step()
else:
    print("did not reach sentinel in 40 steps")
