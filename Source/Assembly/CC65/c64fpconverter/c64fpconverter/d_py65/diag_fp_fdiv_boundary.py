import diag_convert
mpu = diag_convert.mpu
from diag_woz import decode

FDIV = diag_convert.resolve('FP_FDIV')
from diag_convert import set_fp1, set_fp2

# Test: 3.4e38 / 10 → expect ~3.4e37
set_fp1(0x83, 0x50, 0x00, 0x00)   # FP1 = 10 (divisor)
set_fp2(0xFF, 0x7F, 0xFF, 0xFE)   # FP2 = +3.4e38 (dividend)
mpu.sp = 0xff
from diag1 import _push_sentinel, SENTINEL
_push_sentinel()
mpu.pc = FDIV
for step in range(50_000):
    if mpu.pc == SENTINEL: break
    mpu.step()
else:
    print("FP_FDIV hung")
    raise SystemExit()
got = list(mpu.memory[0x61:0x65])
print(f"FDIV result: {[f'{b:02X}' for b in got]}  "
      f"decoded={decode(*got):.6e}  (expect ~3.4e+37)")
