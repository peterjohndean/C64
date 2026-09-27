import diag_convert
mpu = diag_convert.mpu

COMMIT = diag_convert.resolve('commit_value')
BUF    = diag_convert.resolve('NavigationEdit::edit_buf', 'edit_buf')
LEN    = diag_convert.resolve('NavigationEdit::edit_len', 'edit_len')
ROW    = diag_convert.resolve('NavigationEdit::edit_row', 'edit_row')
CUR    = diag_convert.resolve('LayoutValues::current_value', 'current_value')

CASES = [
    # (row, text, expect_trap, description)
    (0, b"3.14159",  False, "decimal pi"),
    (0, b"-1.5",     False, "decimal negative"),
    (0, b"1e38",     False, "decimal max-ish"),
    (0, b"4e38",     True,  "decimal overflow -> trap (V3 calls FP_ERROR)"),
    (0, b"",         False, "decimal empty -> @fail (draw_values)"),
    (0, b"garbage",  False, "decimal garbage -> @fail"),

    (1, b"1"*32,     False, "binary all-ones"),
    (1, b"1"+b"0"*31,False, "binary 1.0 in Woz"),
    (1, b"0"*32,     False, "binary zero -> canonical"),
    (1, b"2"+b"0"*31, False, "binary bad digit -> @fail"),

    # woz/rankin: 8 hex chars, no spaces
    (2, b"80400000", False, "woz 1.0"),
    (2, b"82490FDB", False, "woz pi-ish"),
    (2, b"8040000",  False, "woz wrong length -> @fail"),
    (2, b"80 40 00 00", False, "woz with spaces -> @fail"),

    # basic: 10 hex chars
    (3, b"8100000000", False, "basic 1.0"),
    (3, b"81490FDAA2", False, "basic pi-ish"),
    (3, b"81000000",   False, "basic wrong length -> @fail"),

    # ieee754: 8 hex chars
    (4, b"3F800000", False, "ieee 1.0"),
    (4, b"40490FDB", False, "ieee pi"),
    (4, b"7F800000", True,  "ieee +Inf -> trap"),
    (4, b"FFC00000", True,  "ieee NaN -> trap"),
    (4, b"00000000", False, "ieee zero"),
]

for row, text, expect_trap, desc in CASES:
    # Clear buffer (33 bytes)
    for i in range(33):
        mpu.memory[BUF + i] = 0
    # Seed buffer
    for i, b in enumerate(text):
        mpu.memory[BUF + i] = b
    mpu.memory[LEN] = len(text)
    mpu.memory[ROW] = row

    trapped, s = diag_convert.call(
        COMMIT,
        max_steps=500_000,
        trap_label='.FP_ERROR_PROC',
    )
    committed = bytes(mpu.memory[CUR:CUR+4])
    status = "OK" if trapped == expect_trap else "** MISMATCH **"
    print(f"row={row} {desc:32s} "
          f"len={len(text):2d} trap={int(trapped)} "
          f"expect={int(expect_trap)} cval={committed.hex()}  [{status}]")
