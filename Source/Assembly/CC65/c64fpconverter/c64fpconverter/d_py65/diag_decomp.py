import diag_convert
mpu = diag_convert.mpu
CUR = diag_convert.resolve('LayoutValues::current_value', 'current_value')
RECOMP = diag_convert.resolve('recompute_decomp')

CASES = [
    # (bytes,                want_sign, want_exp, want_mant, comment)
    # +1.0: exp=$80, mantissa $400000 -> (1.0 * 2^22) = 1.0
    ([0x80, 0x40, 0x00, 0x00], ord('+'), 0x80, b"1.000000",
     "+1.0"),

    # -1.0: exp=$7F, mantissa $800000. NOTE the magnitude is 2.0,
    # NOT 1.0 -- the normalized negative range is [-2.0, -1.0], and
    # -1.0 sits at its top edge. -1.0 = -2.0 * 2^-1. This is
    # correct; do not "fix" it to 1.000000.
    ([0x7F, 0x80, 0x00, 0x00], ord('-'), 0x7F, b"2.000000",
     "-1.0 (mantissa is 2.0, see comment)"),

    # pi-ish: mantissa $490FDB = 4788187 -> 4788187/2^22 = 1.14159268
    ([0x82, 0x49, 0x0F, 0xDB], ord('+'), 0x82, b"1.141592",
     "~4.56 (mantissa ~1.141592)"),

    # Canonical zero: early-out path in recompute_decomp writes
    # neutral strings directly, bypassing FP work entirely.
    ([0x00, 0x00, 0x00, 0x00], ord('+'), 0x00, b"0.000000",
     "canonical zero"),

    # Positive floor: exp=$01, mantissa $400000
    ([0x01, 0x40, 0x00, 0x00], ord('+'), 0x01, b"1.000000",
     "positive floor (2^-127)"),
]

for fp, want_sgn, want_exp, want_mant, comment in CASES:
    mpu.memory[CUR:CUR+4] = list(fp)
    diag_convert.call(RECOMP, max_steps=200_000)
    sign_ch = mpu.memory[diag_convert.resolve('decomp_sign_ch')]
    exp_byte = mpu.memory[diag_convert.resolve('decomp_exp_byte')]
    mant_str = bytes(mpu.memory[diag_convert.resolve('decomp_mant_str'):][:16]).split(b'\0')[0]
    ok = (sign_ch == want_sgn and exp_byte == want_exp and mant_str == want_mant)
    print(f"{[f'{b:02X}' for b in fp]}  {comment:38s}  "
          f"sign={chr(sign_ch)} exp=${exp_byte:02X} mant={mant_str!r}  "
          f"[{'OK' if ok else '** MISMATCH **'}]")
