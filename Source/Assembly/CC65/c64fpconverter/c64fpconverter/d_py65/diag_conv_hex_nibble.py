from diag_convert import call, resolve

HEX_NIBBLE = resolve('hex_nibble')

CASES = [
    (ord('0'), 0x0, 0), (ord('9'), 0x9, 0),
    (ord('A'), 0xA, 0), (ord('F'), 0xF, 0),
    (ord('a'), 0xA, 0),   # <-- expected FAIL
    (ord('f'), 0xF, 0),   # <-- expected FAIL
    (ord('G'), None, 1), (ord('g'), None, 1),
    (ord(' '), None, 1), (ord('@'), None, 1),
]
for ch, want_val, want_c in CASES:
    trapped, s = call(HEX_NIBBLE, a=ch)
    got_c = s['c']
    status = "OK" if got_c == want_c else "** BUG **"
    print(f"hex_nibble('{chr(ch)}'/${ch:02X}): "
          f"carry={got_c} nibble=${s['a']:02X}  [{status}]")
