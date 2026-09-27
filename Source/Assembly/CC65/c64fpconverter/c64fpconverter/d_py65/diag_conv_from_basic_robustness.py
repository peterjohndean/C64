import random
from diag_convert import call, mpu, resolve

FROM_BASIC = resolve('FP_FROM_BASIC')
BUF = 0x9000
random.seed(42)

traps = 0
carries = 0
samples = []
N = 5000

# Structured sample: exponent sweep × mantissa patterns
inputs = []
for exp in (0x00, 0x01, 0x40, 0x7F, 0x80, 0x81, 0xC0, 0xFE, 0xFF):
    for mant in ([0x00]*4, [0xFF]*4, [0x80,0,0,0], [0x00,0x80,0,0], [0x7F]*4):
        inputs.append([exp] + mant)
# Random fill
for _ in range(N):
    inputs.append([random.randrange(256) for _ in range(5)])

for data in inputs:
    for i, b in enumerate(data):
        mpu.memory[BUF + i] = b
    trapped, s = call(FROM_BASIC, a=BUF & 0xFF, y=BUF >> 8,
                      max_steps=50_000, trap_label='.FP_ERROR_PROC')
    if trapped:
        traps += 1
        samples.append(('trap',  data, s['fp_err']))
    elif s['c']:
        carries += 1
        samples.append(('carry', data, s['fp1']))

print(f"FP_FROM_BASIC: {traps} traps, {carries} carry-set, "
      f"{len(inputs)-traps-carries} clean, of {len(inputs)} inputs")
for kind, data, extra in samples[:8]:
    print(f"  {kind}: {[f'{b:02X}' for b in data]} -> {extra}")
