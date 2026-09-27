from diag_convert import call, mpu, resolve

FROM_SCI = resolve('FP_FROM_ASCII_SCI_V3')
BUF = 0x9000

for label, text in [('empty',  b''),
                    ('blank',  b'   '),
                    ('just e', b'e'),
                    ('1.5',    b'1.5'),
                    ('garbage',b'zzz')]:
    for i, b in enumerate(text):
        mpu.memory[BUF + i] = b
    mpu.memory[BUF + len(text)] = 0
    trapped, s = call(FROM_SCI, a=BUF & 0xFF, y=BUF >> 8,
                      max_steps=100_000, trap_label='.FP_ERROR_PROC')
    print(f"{label:8s} '{text.decode('latin-1')}': "
          f"trapped={trapped} carry={s['c']} "
          f"FP1={[f'{b:02X}' for b in s['fp1']]}")
