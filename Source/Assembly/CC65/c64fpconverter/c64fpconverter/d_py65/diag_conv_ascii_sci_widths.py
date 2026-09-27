from diag_convert import call, mpu, resolve
from diag_woz import encode, decode

TBL_EDIT = resolve('RowMeta::edit_max_table',
                   'edit_max_table')
TBL_DISP = resolve('RowMeta::display_width_table',
                   'display_width_table')
names = ['decimal','binary','wozrankin','basic','ieee754']

print("Row        edit_max  display_width")
for i, n in enumerate(names):
    print(f"{n:10s} {mpu.memory[TBL_EDIT+i]:8d}  {mpu.memory[TBL_DISP+i]:13d}")

# Now find the longest string FP_TO_ASCII_SCI can actually produce
ASCII_SCI = resolve('FP_TO_ASCII_SCI_V2')
OUT = 0x9000
probes = [
    ('max+',   (0xFF, 0x7F, 0xFF, 0xFF)),   # ~3.4e38, near ceiling
    ('max-',   (0xFF, 0xFF, 0xFF, 0xFF)),   # ~-3.4e38 (sign flip handled by decode)
    ('min+',   (0x01, 0x40, 0x00, 0x00)),   # 2^-127 exactly
    ('min-',   (0x01, 0x80, 0x00, 0x00)),   # -2^-126 exactly
    ('1',      encode( 1.0)),               # these are fine as-is
    ('-1',     encode(-1.0)),
    ('0',      (0, 0, 0, 0)),
]

longest = 0
for name, fp in probes:
    mpu.memory[0x61:0x65] = list(fp)
    # X's meaning? mimic the caller in values.s, which uses X=4.
    for i in range(40):
        mpu.memory[OUT+i] = 0
    trapped, s = call(ASCII_SCI, a=OUT & 0xFF, y=OUT >> 8, x=4,
                      max_steps=200_000, trap_label='.FP_ERROR_PROC')
    s_bytes = []
    for i in range(40):
        b = mpu.memory[OUT+i]
        if b == 0: break
        s_bytes.append(b)
    txt = bytes(s_bytes).decode('latin-1')
    longest = max(longest, len(txt))
    print(f"FP_TO_ASCII_SCI({name:4s}): '{txt}' ({len(txt)} chars) "
          f"trapped={trapped} carry={s['c']}")

print(f"\nLongest observed: {longest} chars")
em0 = mpu.memory[TBL_EDIT]
dw0 = mpu.memory[TBL_DISP]
if longest > dw0:
    print(f"** BUG ** display_width_table[0]={dw0}, but "
          f"FP_TO_ASCII_SCI produced {longest} chars")
if longest > em0:
    print(f"** BUG ** edit_max_table[0]={em0}, but "
          f"FP_TO_ASCII_SCI produced {longest} chars")
