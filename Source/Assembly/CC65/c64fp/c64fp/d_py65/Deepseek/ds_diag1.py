#!/usr/bin/env python3
"""
ds_diag1.py - Diagnosis of FP_FMUL's LSB loss on full-mantissa
multiplies.

Investigates why FP_FMUL(1.0, pi) returns $816487EC instead of
$816487ED. The LSB of pi's mantissa ($6487ED) is lost during the
FMUL loop's final shift.

Structure:
  Part 0 - list the available trace labels (so we know which
           milestones we can actually observe)
  Part A - milestone trace of FMUL(1.0, pi): dumps state at each
           key label from fmul's entry to the final exit
  Part B - same for FMUL(1.0, 10) - the working control case
  Part C - per-iteration trace of mul1's loop, both cases
  Part D - in-simulator patch: pokes md3's ldy #$17 operand byte
           to #$16 and re-runs, without touching the source. Shows
           exactly what the count-only change does to the result.

Run:  python3 ds_diag1.py > ds_diag1.out 2>&1
"""

from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2, dump_fp
from diag_woz import decode

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------
PI_BYTES  = (0x81, 0x64, 0x87, 0xED)   # pi, full mantissa (LSB set)
ONE_BYTES = (0x80, 0x40, 0x00, 0x00)   # 1.0, sparse mantissa
TEN_BYTES = (0x83, 0x50, 0x00, 0x00)   # 10.0, sparse mantissa

SENTINEL = 0x1234

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
def push_sentinel():
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1

def snapshot():
    return {
        'PC': mpu.pc, 'A': mpu.a, 'X': mpu.x, 'Y': mpu.y,
        'P': mpu.p, 'SP': mpu.sp,
        'FP1': tuple(mpu.memory[0x61:0x65]),
        'EXT': tuple(mpu.memory[0x65:0x68]),
        'FP2': tuple(mpu.memory[0x69:0x6d]),
        'SIGN': mpu.memory[0x02],
    }

def fmt_p(p):
    flags = []
    if p & 0x80: flags.append('N')
    if p & 0x40: flags.append('V')
    if p & 0x08: flags.append('D')
    if p & 0x04: flags.append('I')
    if p & 0x02: flags.append('Z')
    if p & 0x01: flags.append('C')
    return ''.join(flags) if flags else '-'

def fmt_snap(s):
    fp1 = ' '.join(f'{b:02x}' for b in s['FP1'])
    ext = ' '.join(f'{b:02x}' for b in s['EXT'])
    fp2 = ' '.join(f'{b:02x}' for b in s['FP2'])
    return (f"PC=${s['PC']:04x} A={s['A']:02x} X={s['X']:02x} "
            f"Y={s['Y']:02x} P={s['P']:02x}[{fmt_p(s['P'])}] "
            f"SP={s['SP']:02x} FP1=[{fp1}] EXT=[{ext}] "
            f"FP2=[{fp2}] SIGN={s['SIGN']:02x}")

def resolve_label(name):
    for candidate in ('.' + name, name):
        if candidate in LABELS:
            return LABELS[candidate]
    return None

def run_until_exit(max_steps=50000):
    """Runs to FP_ERROR_PROC (trap) or SENTINEL (RTS return)."""
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(max_steps):
        pc = mpu.pc
        if pc == error_addr:
            return True,  'trapped'
        if pc == SENTINEL:
            return False, 'returned'
        mpu.step()
    return None, 'timeout'

# ---------------------------------------------------------------------
# PART 0: available labels
# ---------------------------------------------------------------------
print("=" * 72)
print("PART 0: Available trace labels")
print("=" * 72 + "\n")

interesting = ['md1', 'abswap', 'abswp1', 'swap', 'float_conv',
               'norm1', 'norm', 'zero_exponent', 'rts1',
               'fsub', 'swpalg', 'fadd', 'add', 'add1', 'addend',
               'algnsw', 'rtar', 'rtlog', 'rtlog_ok', 'rtlog1', 'ror1',
               'zero_fp1', 'fmul', 'mul1', 'mul2', 'mdend', 'normx',
               'fcompl', 'compl1', 'fdiv', 'div1', 'div2', 'div3',
               'div4', 'div_ok', 'md2', 'md3', 'ovchk',
               'fix_shift', 'fix_conv',
               'FP_NORM_ENTRY', 'FP_NEGATE_ENTRY',
               'FP_ERROR_PROC', 'fp_norm_boundary_state']
for name in interesting:
    addr = resolve_label(name)
    if addr is not None:
        print(f"  {'found':>6}  {name:<26s} = ${addr:04x}")
    else:
        print(f"  {'MISSING':>6}  {name:<26s}")

# ---------------------------------------------------------------------
# Milestone trace
# ---------------------------------------------------------------------
MILESTONES = ['md1', 'abswap', 'abswp1', 'swap',
              'md2', 'md3', 'mul1', 'mul2',
              'mdend', 'normx', 'norm', 'norm1',
              'rts1', 'zero_exponent']

def milestone_trace(name, fp1, fp2):
    print("\n" + "=" * 72)
    print(f"Milestone trace: {name}")
    print("=" * 72 + "\n")

    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = LABELS['.fmul']

    targets = {}
    for m in MILESTONES:
        addr = resolve_label(m)
        if addr is not None and addr not in targets:
            targets[addr] = m

    print(f"  initial      : {fmt_snap(snapshot())}")

    error_addr = LABELS['.FP_ERROR_PROC']
    seen = set()
    for _ in range(50000):
        pc = mpu.pc
        if pc in targets and targets[pc] not in seen:
            seen.add(targets[pc])
            print(f"  @{targets[pc]:<13s}: {fmt_snap(snapshot())}")
        if pc == error_addr:
            print(f"  ** TRAPPED at FP_ERROR_PROC **")
            break
        if pc == SENTINEL:
            print(f"  ** RETURNED via sentinel **")
            break
        mpu.step()
    else:
        print(f"  ** TIMEOUT **")

    final = snapshot()
    print(f"  final        : {fmt_snap(final)}")
    if final['FP1'] != (0, 0, 0, 0):
        try:
            print(f"  decoded FP1  : {decode(*final['FP1'])}")
        except Exception as e:
            print(f"  decoded FP1  : <decode error: {e}>")

# ---------------------------------------------------------------------
# PART A / B
# ---------------------------------------------------------------------
milestone_trace("A: FMUL(1.0, pi)  -- FAILING case", ONE_BYTES, PI_BYTES)
milestone_trace("B: FMUL(1.0, 10)  -- working control", ONE_BYTES, TEN_BYTES)

# ---------------------------------------------------------------------
# PART C: per-iteration mul1 trace
# ---------------------------------------------------------------------
def mul1_iteration_trace(name, fp1, fp2, max_iterations=30):
    print("\n" + "=" * 72)
    print(f"mul1 iteration trace: {name}")
    print("=" * 72 + "\n")

    mul1_addr = resolve_label('mul1')
    if mul1_addr is None:
        print("  [mul1 label not found - skipping]")
        return

    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = LABELS['.fmul']

    error_addr = LABELS['.FP_ERROR_PROC']
    iteration = 0
    for _ in range(200000):
        pc = mpu.pc
        if pc == mul1_addr:
            s = snapshot()
            fp1h = ' '.join(f'{b:02x}' for b in s['FP1'])
            exth = ' '.join(f'{b:02x}' for b in s['EXT'])
            print(f"  iter {iteration:2d} @mul1: "
                  f"Y={s['Y']:02x} P={s['P']:02x}[{fmt_p(s['P'])}] "
                  f"FP1=[{fp1h}] EXT=[{exth}]")
            iteration += 1
            if iteration > max_iterations:
                print(f"  ... (truncated at {max_iterations} iterations)")
                break
        if pc == error_addr:
            print(f"  ** TRAPPED **")
            break
        if pc == SENTINEL:
            print(f"  ** RETURNED **")
            break
        mpu.step()

    final = snapshot()
    if final['FP1'] != (0, 0, 0, 0):
        try:
            print(f"  final FP1 = {final['FP1']}  decoded = "
                  f"{decode(*final['FP1'])}")
        except Exception:
            pass

mul1_iteration_trace("C1: FMUL(1.0, pi)", ONE_BYTES, PI_BYTES)
mul1_iteration_trace("C2: FMUL(1.0, 10)", ONE_BYTES, TEN_BYTES)

# ---------------------------------------------------------------------
# PART D: in-simulator patch of md3's iteration count
# ---------------------------------------------------------------------
print("\n" + "=" * 72)
print("PART D: in-simulator md3 patch test")
print("=" * 72 + "\n")

md3_addr = resolve_label('md3')
if md3_addr is None:
    print("  [md3 label not found - cannot patch]")
else:
    # md3 body (from lib_fp.s):
    #   eor #$80          49 80    (2 bytes)
    #   sta FP1_EXP       85 61    (2 bytes, zero page)
    #   ldy #$17          A0 17    (2 bytes)
    #   rts               60       (1 byte)
    # So the ldy operand byte is at md3_addr + 5.
    opcode_addr = md3_addr + 4
    operand_addr = md3_addr + 5
    opcode = mpu.memory[opcode_addr]
    operand = mpu.memory[operand_addr]

    print(f"  md3 @ ${md3_addr:04x}")
    print(f"    opcode  @ ${opcode_addr:04x} = ${opcode:02x} "
          f"({'A0 = LDY immediate' if opcode == 0xA0 else 'UNEXPECTED'})")
    print(f"    operand @ ${operand_addr:04x} = ${operand:02x} "
          f"({'17 = 23 (current)' if operand == 0x17 else 'UNEXPECTED'})")

    if opcode != 0xA0 or operand != 0x17:
        print("\n  [md3 layout differs from expectation - skipping patch]")
    else:
        mpu.memory[operand_addr] = 0x16
        print(f"\n  Patched operand to $16 (22, giving 23 iterations)")
        print(f"  NOTE: this only changes the iteration count; it does NOT")
        print(f"        add the dec FP1_EXP compensation.\n")

        # Test A: FMUL(1.0, pi) with patch
        reset_state()
        set_fp1(*ONE_BYTES)
        set_fp2(*PI_BYTES)
        push_sentinel()
        mpu.pc = LABELS['.fmul']
        trapped, outcome = run_until_exit()
        final = snapshot()
        print(f"  patched FMUL(1.0, pi) : {outcome}")
        print(f"    {fmt_snap(final)}")
        if final['FP1'] != (0, 0, 0, 0):
            try:
                print(f"    decoded = {decode(*final['FP1'])}")
            except Exception:
                pass
        print(f"    baseline (unpatched) result   = $81 64 87 EC")
        print(f"    correct result                = $81 64 87 ED")
        print(f"    if iteration count is the only fix needed: expect ED")
        print(f"    if exponent compensation is also needed:   expect $82 xx xx xx")

        # Test B: FMUL(10, 10) with patch - should still work
        reset_state()
        set_fp1(0x83, 0x50, 0x00, 0x00)
        set_fp2(0x83, 0x50, 0x00, 0x00)
        push_sentinel()
        mpu.pc = LABELS['.fmul']
        trapped, outcome = run_until_exit()
        final = snapshot()
        print(f"\n  patched FMUL(10, 10)  : {outcome}")
        print(f"    {fmt_snap(final)}")
        if final['FP1'] != (0, 0, 0, 0):
            try:
                print(f"    decoded = {decode(*final['FP1'])}")
            except Exception:
                pass
        print(f"    baseline result = $86 64 00 00 (correct, sparse mantissas)")

        # Test C: FDIV(pi, pi) with patch - this is the crucial one
        reset_state()
        set_fp1(*PI_BYTES)
        set_fp2(*PI_BYTES)
        push_sentinel()
        mpu.pc = LABELS['.fdiv']
        trapped, outcome = run_until_exit()
        final = snapshot()
        print(f"\n  patched FDIV(pi, pi)  : {outcome}")
        print(f"    {fmt_snap(final)}")
        if final['FP1'] != (0, 0, 0, 0):
            try:
                print(f"    decoded = {decode(*final['FP1'])}")
            except Exception:
                pass
        print(f"    baseline result = $80 40 00 00 (== 1.0, correct)")
        print(f"    if this changed, md3 is shared between FMUL and FDIV")
        print(f"    and the patch is not FMUL-specific")

        # Restore
        mpu.memory[operand_addr] = 0x17
        print(f"\n  restored operand to ${mpu.memory[operand_addr]:02x}")

print("\n" + "=" * 72)
print("DONE")
print("=" * 72)
print("""
INTERPRETATION GUIDE
--------------------
Part A/B milestones: compare the FAILING (1.0*pi) and WORKING (1.0*10)
traces side by side. They should be structurally identical up to the
mul1 loop. Any divergence before mul1 tells us the operand-load or
normalization path is different for the two inputs. Any divergence
INSIDE mul1 or after tells us where the LSB is being lost.

Part C iterations: watch for the iteration where pi's register is
shifted and the LSB is dropped. The failing case will show a bit
disappearing from EXT+2 (the last byte) that never appears anywhere
else. The working case's LSB is 0, so nothing to lose.

Part D patch: shows what happens if only the iteration count changes
with no exponent compensation. Three outcomes matter:
  - FMUL(1.0,pi) -> correct (ED) and FMUL(10,10) still correct and
    FDIV(pi,pi) still 1.0: the iteration count alone was the fix,
    and md3 is NOT actually shared for this path.
  - FMUL(1.0,pi) -> correct but FDIV changed: md3 IS shared, and
    a per-path patch (FMUL only) is required.
  - FMUL(1.0,pi) -> off by a factor of 2: the exponent compensation
    (dec FP1_EXP) is genuinely required along with the count change.
""")
