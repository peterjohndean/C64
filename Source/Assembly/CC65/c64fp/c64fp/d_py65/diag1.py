#!/usr/bin/env python3
"""
py65-based instruction-level simulator for FP_CORE_PROC's FMUL/FDIV
exponent-boundary fix. Loads a real, linked C64 .prg file directly -
using ITS OWN embedded load address.

CHANGELOG (most recent first)
------------------------------
- _run_fmul_or_fdiv: REMOVED the early-stop-at-.rts1/.zero_exponent
  logic entirely. CONFIRMED via diag25.py's clean single-instruction
  trace: arrival at .rts1's ADDRESS is NOT always a final, terminal
  state - .rts1's OWN code can run several more instructions and
  THEN decide to jmp FP_ERROR (the CEILING label's "already
  normalized, no rescue occurred -> genuine overflow" sub-case,
  documented in lib_fp.s's own header as ~2% of boundary cases).
  The old harness stopped the INSTANT pc==rts1_addr, silently
  snapshotting FP1's PRE-DECISION state and reporting a false
  "trapped=False, succeeded" result for cases that actually go on to
  trap. This affected diag23.py's INVALID one-past-ceiling trace AND
  diag2.py's "one past ceiling" sanity check, and very likely
  affected some fraction of the ORIGINAL FMUL/FDIV CEILING sweep
  results too (same bug exists in diag2.py's run_mul_loop_from - see
  that file's own changelog). The ONLY two genuinely terminal
  conditions are now: reaching FP_ERROR_PROC (a real trap), or
  reaching the pushed SENTINEL via an actual RTS (a real, complete
  return) - both confirmed reliable across every case tested
  tonight, including the FLOOR-side @force_underflow path.
- Outcome labels simplified to 'trapped'/'returned' - the harness no
  longer claims to know (or needs to know) WHICH internal label
  (.rts1, .zero_exponent, @force_underflow's sentinel-return, etc.)
  a non-trapping call passed through, since that information was
  precisely what caused the false-positive above. Any diagnostic
  wanting to know the internal path should trace it directly (see
  diag19/20/23/25.py for that style), not infer it from the exit
  detection.
- Sentinel push (SENTINEL=0x1234): still required. None of this
  script's entry points simulate a real outer caller of .fmul/.fdiv,
  so any exit path ending in a plain RTS (confirmed: the FLOOR
  boundary's @force_underflow, and now also normal completion in
  general) would otherwise pop garbage from an empty/foreign stack.
- load_prg replaces load_binary - a real .prg's first two bytes ARE
  the load address, always, written by the linker itself.
- CASES/DIV_CASES: exp_outcome checks removed (no longer meaningful
  given the outcome-label simplification above) - correctness is
  now checked purely via trapped/not-trapped plus exp_bytes.
"""

from py65.devices.mpu6502 import MPU
from diag_woz import decode

def load_labels(filename):
    labels = {}
    with open(filename) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3:
                addr = int(parts[1], 16)
                labels[parts[2]] = addr
    return labels

def load_prg(mpu, path):
    """Load a real C64 .prg file directly, using ITS OWN embedded
    load address. Returns the load address actually used."""
    with open(path, 'rb') as f:
        data = f.read()
    if len(data) < 2:
        raise ValueError(f"{path} is too short to be a valid .prg")
    load_addr = data[0] | (data[1] << 8)
    payload = data[2:]
    for i, b in enumerate(payload):
        mpu.memory[load_addr + i] = b
    print(f"[load_prg] loaded {len(payload)} bytes at "
          f"${load_addr:04x}-${load_addr+len(payload)-1:04x}, from {path}")
    return load_addr

LABELS = load_labels('c64fp-lbl.txt')
mpu = MPU()
load_addr = load_prg(mpu, 'c64fp.prg')

_expected_low = min(LABELS.values())
if abs(_expected_low - load_addr) > 0x1000:
    print(f"[WARNING] label file's lowest address (${_expected_low:04x}) "
          f"is far from the .prg's own load address (${load_addr:04x}) - "
          f"labels and binary may be from different builds")

def set_fp1(exp, m0, m1, m2):
    mpu.memory[0x61:0x65] = [exp, m0, m1, m2]

def set_fp2(exp, m0, m1, m2):
    mpu.memory[0x69:0x6d] = [exp, m0, m1, m2]

def dump_fp():
    return {
        'FP1': tuple(mpu.memory[0x61:0x65]),
        'FP_EXT': tuple(mpu.memory[0x65:0x68]),
        'FP2': tuple(mpu.memory[0x69:0x6d]),
        'FP_SIGN': mpu.memory[0x02],
    }

def run_until(*names, max_steps=50000):
    """Still provided for scripts that want RAW label-arrival
    detection for TRACING purposes (diag19/20/23/25.py's style) -
    NOT to be used as a correctness/exit-detection primitive, since
    arrival at a label is not necessarily terminal (see CHANGELOG)."""
    targets = {LABELS[n] for n in names}
    for _ in range(max_steps):
        if mpu.pc in targets:
            return next(n for n in names if LABELS[n] == mpu.pc)
        mpu.step()
    raise RuntimeError(f"didn't reach {names} in {max_steps} steps")

def reset_state():
    mpu.memory[0x02] = 0x00
    mpu.memory[0x65:0x68] = [0, 0, 0]
    mpu.a = mpu.x = mpu.y = 0
    mpu.p = 0x20
    mpu.sp = 0xff

SENTINEL = 0x1234   # arbitrary non-code address; only ever checked
                     # against, never actually fetched/decoded

def _push_sentinel():
    ret_addr = SENTINEL - 1   # RTS adds 1 to the popped value
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1

def _run_fmul_or_fdiv(max_steps=50000):
    """Runs from wherever mpu.pc currently is to the REAL final exit.
    Only two terminal conditions exist: reaching FP_ERROR_PROC (a
    real trap), or reaching the pushed SENTINEL via an actual RTS (a
    real, complete return). See CHANGELOG above for why .rts1/
    .zero_exponent are deliberately NOT treated as terminal."""
    _push_sentinel()
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(max_steps):
        pc = mpu.pc
        if pc == error_addr:
            return True, 'trapped', dump_fp()
        if pc == SENTINEL:
            return False, 'returned', dump_fp()
        mpu.step()
    raise RuntimeError(f"didn't reach a final exit in {max_steps} steps")

def run_fmul(fp1, fp2):
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    mpu.pc = LABELS['.fmul']
    return _run_fmul_or_fdiv()

def run_fdiv(fp1, fp2):
    """FP_FDIV entry: FP1=divisor, FP2=dividend."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    mpu.pc = LABELS['.fdiv']
    return _run_fmul_or_fdiv()

def provisional_exponent(e1, e2):
    """md3's own arithmetic: S = e1+e2+1 mod 256, then EOR $80.
    CONFIRMED against a real 12.0*10.0 trace (prov_exp == 0x87)."""
    s = (e1 + e2 + 1) & 0xff
    return s ^ 0x80

# --- FDIV pre-compensation offset - CONFIRMED via live VICE trace:
#     the raw biased difference, no added compensation term. ---
PRE_COMPENSATION_DIV = 0

DIV_CASES = [
    ("12.0/10.0=1.2",    (0x83,0x50,0x00,0x00), (0x83,0x60,0x00,0x00), False, None),
    ("10.0/12.0=0.8333", (0x83,0x60,0x00,0x00), (0x83,0x50,0x00,0x00), False, None),
]

CASES = [
    ("10*10", (0x83,0x50,0x00,0x00), (0x83,0x50,0x00,0x00), False, (0x86,0x64,0x00,0x00)),
    ("12*-7.5", (0x83,0x60,0x00,0x00), (0x82,0x88,0x00,0x00), False, (0x86,0xa6,0x00,0x00)),
    ("boundary_1.0", (0xc0,0x40,0x00,0x00), (0xbf,0x40,0x00,0x00), False, (0xff,0x40,0x00,0x00)),
    ("unnorm_at_floor", (0x00,0x60,0x00,0x00), (0xbf,0x60,0x00,0x00), False,  None),
]

def _check_case(name, trapped, outcome, state, exp_trap, exp_bytes):
    ok = (trapped == exp_trap)
    if exp_bytes is not None:
        ok = ok and (state['FP1'] == exp_bytes)
    detail = ''
    if not ok and not trapped and state.get('FP1'):
        detail = f"  decoded={decode(*state['FP1'])}"
    print(f"{name}: trapped={trapped} outcome={outcome} "
          f"{'OK' if ok else 'MISMATCH'}  {state}{detail}")
    return ok

if __name__ == '__main__':
    prov_exp = provisional_exponent(0x83, 0x83)
    assert prov_exp == 0x87, f"expected $87, got ${prov_exp:02x}"

    print("=== FDIV cases ===")
    all_ok = True
    for name, fp1, fp2, exp_trap, exp_bytes in DIV_CASES:
        trapped, outcome, state = run_fdiv(fp1, fp2)
        all_ok &= _check_case(name, trapped, outcome, state, exp_trap, exp_bytes)

    print("\n=== FMUL cases ===")
    for name, a, b, exp_trap, exp_bytes in CASES:
        trapped, outcome, state = run_fmul(a, b)
        all_ok &= _check_case(name, trapped, outcome, state, exp_trap, exp_bytes)

    print(f"\n{'ALL CASES PASSED' if all_ok else 'SOME CASES FAILED - see above'}")
