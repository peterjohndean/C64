from diag_convert import call, mpu, resolve

BIN = resolve('binary_from_ascii')
BUF = 0x9000

CASES = [
    (b'0'*32,                         (0x00,0x00,0x00,0x00)),
    (b'1'*32,                         (0xFF,0xFF,0xFF,0xFF)),
    (b'10000000' + b'0'*24,           (0x80,0x00,0x00,0x00)),
    (b'01111111' + b'1'*24,           (0x7F,0xFF,0xFF,0xFF)),
    (b'10101010' + b'01010101'*3,     (0xAA,0x55,0x55,0x55)),
]
for bits, want in CASES:
    mpu.memory[BUF:BUF+32] = list(bits)
    trapped, s = call(BIN, a=BUF & 0xFF, y=BUF >> 8)
    status = "OK" if s['fp1'] == want else "** MISMATCH **"
    print(f"{bits[:8].decode()}...: FP1={[f'{b:02X}' for b in s['fp1']]}  "
          f"want={[f'{b:02X}' for b in want]}  [{status}]")
