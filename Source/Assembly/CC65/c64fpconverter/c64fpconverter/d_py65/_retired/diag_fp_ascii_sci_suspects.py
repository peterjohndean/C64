"""diag_fp_ascii_sci_suspects.py  (v2 -- corrected)

Fixes v1's three bugs:
  * woz_decode called with 4 positional args (exp, m0, m1, m2).
  * No import of diag_conv_ascii_sci_widths (its module body was running).
  * ASCII output located by scanning memory for sci-notation strings,
    not by guessing a fixed buffer base.

Run:
    PYTHONPATH=src:.:../ python3 diag_fp_ascii_sci_suspects.py

Optional explicit bytes (if you'd rather use the exact patterns from
tr_conv_ascii_sci_v3.s than the encoder):
    PYTHONPATH=src:.:../ python3 diag_fp_ascii_sci_suspects.py \
        33-15=FE4B3B4C 33-16=...
"""
import sys
import re
import diag_convert
import diag_woz


# --- woz encode/decode -------------------------------------------------

def _pick(module, *names):
    for n in names:
        fn = getattr(module, n, None)
        if callable(fn):
            return fn
    return None


woz_encode = _pick(diag_woz, 'encode', 'woz_encode', 'fp_encode',
                              'encode_woz', 'float_to_woz', 'to_bytes')
woz_decode = _pick(diag_woz, 'decode', 'woz_decode', 'fp_decode',
                              'decode_woz', 'woz_to_float', 'to_float',
                              'bytes_to_float')

if woz_encode is None or woz_decode is None:
    print("diag_woz callables:", sorted(n for n in dir(diag_woz)
          if not n.startswith('_') and callable(getattr(diag_woz, n))))
    raise SystemExit(2)


def decode_bytes(bs):
    """Try every plausible calling convention for diag_woz.decode."""
    for attempt in (lambda: woz_decode(bs),
                    lambda: woz_decode(*bs),
                    lambda: woz_decode(bs[0], bs[1], bs[2], bs[3])):
        try:
            return attempt()
        except TypeError:
            continue
        except Exception as e:
            return f'(err {e})'
    return '(no matching signature)'


# --- C64 plumbing ------------------------------------------------------

mpu = diag_convert.mpu
FP_TO_ASCII_SCI = diag_convert.resolve('FP_TO_ASCII_SCI_V2')


SCI_RE = re.compile(rb'[+-]?\d+(?:\.\d+)?[Ee][+-]?\d+')
NUM_RE = re.compile(rb'[+-]?\d+(?:\.\d+)?[Ee][+-]?\d+|\d+\.\d+|\d+')


#def scan_memory_for_sci(mpu, limit=8):
#    """Walk all of memory, return (addr, text) for sci-notation strings."""
#    mem = bytes(mpu.memory)
#    hits = []
#    for m in SCI_RE.finditer(mem):
#        hits.append((m.start(), m.group().decode('ascii')))
#        if len(hits) >= limit:
#            break
#    return hits

def run_sci(fp_bytes, ndigits=2, buf=0x0500, debug=False):
    mpu.memory[0x61:0x65] = list(fp_bytes)

    # FP_TO_ASCII_SCI_V2 calling convention (from tr_ascii_sci_v3.s):
    #   A = lo(output buffer pointer)
    #   Y = hi(output buffer pointer)
    #   X = number of fractional digits
    #   FP1 = value to print
    # Without these the routine writes wherever A/Y happen to point on
    # entry, which is why the previous runs produced empty buffers.
    try:
        state = diag_convert.call(
            FP_TO_ASCII_SCI,
            a=buf & 0xFF,
            y=(buf >> 8) & 0xFF,
            x=ndigits,
            max_steps=200_000,
        )
    except TypeError:
        # diag_convert.call doesn't accept register kwargs; set them
        # directly on the mpu before the call.
        mpu.a = buf & 0xFF
        mpu.y = (buf >> 8) & 0xFF
        mpu.x = ndigits
        _, state = diag_convert.call(FP_TO_ASCII_SCI, max_steps=200_000)

    if isinstance(state, tuple):
        state = state[1] if len(state) > 1 else {}

    if debug:
        print("  state keys:", sorted(state.keys())
              if isinstance(state, dict) else type(state))
        if isinstance(state, dict):
            for k, v in state.items():
                print(f"    {k} = {v!r}")

    # Read the buffer we told the routine to use.  This is the same
    # buffer address v3 passes in TestData::out_buffer.
    raw = bytes(mpu.memory[buf:buf + 24])
    head = raw.split(bytes([0]), 1)[0]
    text = head.decode('ascii', 'replace')

    if debug:
        print(f"  buffer ${buf:04X}: {raw.hex(' ')}")
        print(f"  buffer ${buf:04X} ascii: {text!r}")

    return text, state

def dump_buffer(label):
    print("  zp $00-$0F:")
    mem = bytes(mpu.memory[0x00:0x10])
    print(f"    {mem.hex(' ')}")
    for base in (0x0200, 0x0300, 0x0400, 0x0500):
        mem = bytes(mpu.memory[base:base + 24])
        head = mem.split(bytes([0]), 1)[0]
        text = head.decode('ascii', 'replace')
        print(f"    ${base:04X}: {mem.hex(' ')}   {text!r}")


# --- cases -------------------------------------------------------------

CASES = [
    ('33-15',  1.9e38,   'near ceiling'),
    ('33-16', -9.99e-39, 'neg near underflow'),
]

OVERRIDES = {}
for arg in sys.argv[1:]:
    if arg == '--debug':
        continue
    if '=' in arg:
        cid, hexstr = arg.split('=', 1)
        hexstr = hexstr.replace(' ', '').replace(',', '').strip()
        if len(hexstr) != 8:
            print(f"bad override {arg!r}: need 8 hex digits")
            raise SystemExit(2)
        OVERRIDES[cid] = [int(hexstr[i:i+2], 16) for i in (0, 2, 4, 6)]

DEBUG = '--debug' in sys.argv

# --- run ---------------------------------------------------------------

print(f"{'id':6} {'label':>12}  {'input bytes':>14}  {'woz decodes to':>18}  "
      f"{'C64 sci strings in mem':>34}  status")
print('-' * 100)

for cid, label_val, note in CASES:
    if cid in OVERRIDES:
        bs = OVERRIDES[cid]
        src = 'override'
    else:
        try:
            bs = [b & 0xFF for b in woz_encode(label_val)]
        except Exception as e:
            print(f"{cid:6} {label_val:>12.4g}  encoder error: {e}")
            continue
        src = 'encoder'

    if len(bs) != 4:
        print(f"{cid:6} {label_val:>12.4g}  encoder gave {len(bs)}B: {bs}")
        continue

    bs_hex = ' '.join(f'{b:02X}' for b in bs)
    decoded = decode_bytes(bs)

    try:
        text, state = run_sci(bs, debug=DEBUG)
    except RuntimeError as e:
        print(f"{cid:6} {label_val:>12.4g}  {bs_hex:>14}  "
              f"{str(decoded):>18}  HANG: {e}")
        continue

    if not text:
        print(f"{cid:6} {label_val:>12.4g}  {bs_hex:>14}  "
              f"{str(decoded):>18}  (empty buffer)  --")
        continue

    try:
        parsed = float(text.replace('E', 'e'))
    except ValueError:
        parsed = None

    if parsed is None or not isinstance(decoded, (int, float)):
        status = f'UNPARSED ({text!r})'
    else:
        ref = float(decoded)
        if ref == 0:
            status = 'OK' if parsed == 0 else f'** MISMATCH ** {parsed}'
        else:
            rel = abs(parsed - ref) / abs(ref)
            if rel < 1e-5:
                status = 'OK'
            elif rel < 1e-3:
                status = f'** ROUNDING ** rel={rel:.2e}'
            else:
                status = f'** MISMATCH ** rel={rel:.2e}'

    print(f"{cid:6} {label_val:>12.4g}  {bs_hex:>14}  "
          f"{str(decoded):>18}  {text:>14}  {str(parsed):>14}  "
          f"{status}  [{src}, {note}]")

print()
print("Interpretation:")
print("  * 'woz decodes to' is the ground-truth value of the input bytes.")
print("  * Compare each sci string in the C64 hit list against it.")
print("  * The FIRST hit after the routine returns should be the output.")
print("  * If extra hits appear, they are leftovers from earlier calls --")
print("    re-run with --debug to see addresses and state, and I can pin")
print("    the output buffer down exactly.")
print()
print("If the v3 labels disagree with the ground-truth decode of the same")
print("bytes, the labels are hints, not expectations, and the test file")
print("is misleading rather than the routine being wrong.")
