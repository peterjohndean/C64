#!/usr/bin/env python3
"""
asciisci.py - Round trip verification for C64 FP1 <-> ASCII, IEEE-754,
and C64 BASIC conversions, with PROPER trap detection.

CHANGELOG
----------
- execute_routine renamed/rewritten as execute_routine_checked: now
  watches for .FP_ERROR_PROC directly, the same sentinel-style
  detection diag1.py already uses and proved reliable. The previous
  version just stepped until PC hit a $00 opcode - with NO
  FP_ERROR_INIT_MACRO recovery point ever armed, a genuine trap (e.g.
  FP_TO_BASIC on FP1_EXP=$FF, which is DOCUMENTED to trap - see
  lib_fp_basic.s's own ERROR HANDLING note) has undefined behavior
  per lib_fp_error.s's own setjmp/longjmp contract, and the all-zero
  BASIC output seen for the $FF boundary case was very likely THIS -
  execution wandering into unrelated memory after the trap, not a
  clean, intentional result.
- Actual PASS/FAIL comparisons added for IEEE-754 and BASIC, where a
  ground-truth expectation is computable (this script does NOT invent
  a "correct" BASIC/IEEE-754 encoding independently - it only checks
  round-trip self-consistency and documented trap behavior, the same
  standard the rest of this project's regression tests hold to).
- Boundary test inputs fixed: $FF,FF,FF,FF used in earlier testing is
  NOT a legitimately normalized Woz mantissa (top two bits of $FF are
  both 1 - they must DIFFER per this format's own normalization rule,
  see lib_fp.s's `norm`). Replaced with the actual format ceiling
  ($FF,7F,FF,FF, confirmed elsewhere as 3.402823466e38) and an
  analogous floor case.
"""

import argparse
from py65.devices.mpu6502 import MPU

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

def reset_state(mpu):
    mpu.memory[0x02] = 0x00
    mpu.memory[0x65:0x68] = [0, 0, 0]
    mpu.a = mpu.x = mpu.y = 0
    mpu.p = 0x20
    mpu.sp = 0xff

def set_fp1(mpu, exp, m0, m1, m2):
    mpu.memory[0x61:0x65] = [exp, m0, m1, m2]

SENTINEL = 0x1234

def execute_routine_checked(mpu, labels, start_addr, a=0, x=0, y=0, max_steps=500000):
    """Pushes a sentinel return address before running, so the
    routine's own RTS has something legitimate to land on instead
    of popping whatever happens to be on the stack (which was
    always undefined here - this script never simulated a real
    caller). Stops the instant PC reaches the sentinel, before py65
    ever fetches/decodes whatever byte sits there. Also watches for
    .FP_ERROR_PROC directly, so a genuine trap is distinguished from
    normal completion rather than assumed away."""
    mpu.a, mpu.x, mpu.y = a, x, y
    ret_addr = SENTINEL - 1   # RTS adds 1 to the popped value
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = start_addr
    error_addr = labels['.FP_ERROR_PROC']
    for _ in range(max_steps):
        if mpu.pc == error_addr:
            return True, mpu.memory[0xFE]
        if mpu.pc == SENTINEL:
            return False, None
        mpu.step()
    raise RuntimeError(f"routine at ${start_addr:04x} didn't terminate "
                        f"in {max_steps} steps")

def read_c_string(memory_space, address, encoding="ascii"):
    chars = bytearray()
    while memory_space[address] != 0x00:
        chars.append(memory_space[address])
        address += 1
    return chars.decode(encoding)

def write_c_string(memory_space, address, text, encoding="ascii"):
    data = text.encode(encoding) + b"\x00"
    for offset, byte in enumerate(data):
        memory_space[address + offset] = byte

def hex_byte(value):
    try:
        val = int(value.replace('$', '0x'), 0)
        if not (0 <= val <= 255):
            raise ValueError
        return val
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid 8-bit hex byte (00-FF).")

def is_normalized(mantissa_bytes):
    b0 = mantissa_bytes[0]
    return bool(((b0 << 1) ^ b0) & 0x80)

def run_all_conversions(LABELS, mpu, fp1_initial, label=""):
    fp1_initial_hex = f"({', '.join(f'${b:02X}' for b in fp1_initial)})"
    print(f"\n--- {label or fp1_initial_hex} ---")

    if not is_normalized(fp1_initial[1:]):
        print(f"  [WARNING] {fp1_initial_hex}'s mantissa is NOT normalized "
              f"(top two bits of ${fp1_initial[1]:02X} match, must differ) - "
              f"this is not a value FP_CORE_PROC would ever legitimately "
              f"produce; results below may be meaningless.")

    str_address = 0xC000

    # 1. FP1 -> ASCII
    reset_state(mpu)
    set_fp1(mpu, *fp1_initial)
    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_TO_ASCII_SCI_V2'], a=0x00, x=7, y=0xC0)
    if trapped:
        print(f"  ASCII Scientific : TRAPPED (code {code})")
        ascii_result_1 = None
    else:
        ascii_result_1 = read_c_string(mpu.memory, str_address)
        print(f"  ASCII Scientific : -> '{ascii_result_1}'")

    # 2. ASCII -> FP1
    fp1_parsed = None
    if ascii_result_1 is not None:
        write_c_string(mpu.memory, str_address, ascii_result_1)
        reset_state(mpu)
        trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_FROM_ASCII_SCI_V3'], a=0x00, x=0x00, y=0xC0)
        if trapped:
            print(f"  ASCII -> FP1     : TRAPPED (code {code})")
        else:
            fp1_parsed = tuple(mpu.memory[0x61:0x65])
            match = "OK" if fp1_parsed == fp1_initial else "MISMATCH"
            print(f"  ASCII -> FP1     : -> ({', '.join(f'${b:02X}' for b in fp1_parsed)})  {match}")

    # 3. FP1 -> IEEE-754
    reset_state(mpu)
    set_fp1(mpu, *fp1_initial)
    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_TO_IEEE754'])
    if trapped:
        print(f"  IEEE-754         : TRAPPED (code {code})")
    else:
        ieee_bytes = tuple(mpu.memory[0x61:0x65])
        print(f"  IEEE-754         : -> ({', '.join(f'${b:02X}' for b in ieee_bytes)})")
        # round trip back, since that's the one thing we CAN check
        # without independently re-deriving IEEE-754 bit layout math
        trapped2, code2 = execute_routine_checked(mpu, LABELS, LABELS['.FP_FROM_IEEE754'])
        if trapped2:
            print(f"  IEEE-754 -> FP1  : TRAPPED (code {code2})")
        else:
            fp1_back = tuple(mpu.memory[0x61:0x65])
            match = "OK" if fp1_back == fp1_initial else "MISMATCH"
            print(f"  IEEE-754 -> FP1  : -> ({', '.join(f'${b:02X}' for b in fp1_back)})  {match}")

    # 4. FP1 -> C64 BASIC (5-byte FAC)
    reset_state(mpu)
    set_fp1(mpu, *fp1_initial)
    basic_dest_addr = 0xC100
    a_reg = basic_dest_addr & 0xFF
    y_reg = (basic_dest_addr >> 8) & 0xFF
    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_TO_BASIC'], a=a_reg, x=0x00, y=y_reg)
    if trapped:
        print(f"  C64 BASIC (FAC)  : TRAPPED (code {code})")
    else:
        basic_bytes = tuple(mpu.memory[basic_dest_addr:basic_dest_addr + 5])
        print(f"  C64 BASIC (FAC)  : -> ({', '.join(f'${b:02X}' for b in basic_bytes)})")
        reset_state(mpu)
        trapped2, code2 = execute_routine_checked(mpu, LABELS, LABELS['.FP_FROM_BASIC'], a=basic_dest_addr & 0xFF, x=0x00, y=(basic_dest_addr >> 8) & 0xFF)
        if trapped2:
            print(f"  BASIC -> FP1     : TRAPPED (code {code2})")
        else:
            fp1_back = tuple(mpu.memory[0x61:0x65])
            match = "OK" if fp1_back == fp1_initial else "MISMATCH"
            print(f"  BASIC -> FP1     : -> ({', '.join(f'${b:02X}' for b in fp1_back)})  {match}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert C64 FP1 to ASCII, IEEE-754, and C64 BASIC using PY65.")
    parser.add_argument('bytes', metavar='BYTE', type=hex_byte, nargs='*',
                        help="Four 8-bit hex bytes (e.g., 83 50 00 00). "
                             "If omitted, runs a fixed set of boundary cases.")
    args = parser.parse_args()

    LABELS = load_labels('c64fp-lbl.txt')
    mpu = MPU()
    load_prg(mpu, 'c64fp.prg')

    if args.bytes:
        run_all_conversions(LABELS, mpu, tuple(args.bytes))
    else:
        # legitimately normalized boundary cases, replacing the
        # earlier $FF,FF,FF,FF input which was never a valid mantissa
        run_all_conversions(LABELS, mpu, (0xff, 0x7f, 0xff, 0xff), "MAX: 3.402823466e38")
        run_all_conversions(LABELS, mpu, (0x00, 0x40, 0x00, 0x00), "MIN (nonzero): 2^-128")
        run_all_conversions(LABELS, mpu, (0x7f, 0x80, 0x00, 0x00), "-1.0 (existing regression)")