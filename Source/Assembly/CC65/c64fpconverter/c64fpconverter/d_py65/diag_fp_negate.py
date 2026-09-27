import diag_convert
mpu = diag_convert.mpu
FP_NEGATE = diag_convert.resolve('FP_NEGATE')
from diag_woz import decode

CASES = [
    # (input,        description,             expected hex)
    ([0x80, 0x40, 0x00, 0x00], "+1.0",   [0x7F, 0x80, 0x00, 0x00]),
    ([0x7F, 0x80, 0x00, 0x00], "-1.0",   [0x80, 0x40, 0x00, 0x00]),
    ([0x83, 0x60, 0x00, 0x00], "+12.0",  [0x83, 0xA0, 0x00, 0x00]),
    ([0x83, 0xA0, 0x00, 0x00], "-12.0",  [0x83, 0x60, 0x00, 0x00]),
    ([0xFF, 0x7F, 0xFF, 0xFE], "+max",   None),
    ([0xFF, 0x80, 0x00, 0x02], "-max",   None),
]

for bytes_in, label, expected in CASES:
    mpu.memory[0x61:0x65] = bytes_in
    _, s = diag_convert.call(FP_NEGATE, max_steps=10_000)
    got = list(s['fp1'])
    line = f"FP_NEGATE({label:5s}) in={[f'{b:02X}' for b in bytes_in]} " \
           f"out={[f'{b:02X}' for b in got]}"
    if expected is not None:
        line += f"  expect={[f'{b:02X}' for b in expected]}  " \
                f"{'OK' if got == expected else '** MISMATCH **'}"
    else:
        # Print the decoded value so we can see WHAT the routine
        # actually produced at the boundary, and cross-check with
        # what -in should be
        line += f"  decoded={decode(*got):.6e}"
    print(line)
