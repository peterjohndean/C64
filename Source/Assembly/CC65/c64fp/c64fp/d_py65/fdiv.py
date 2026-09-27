#!/usr/bin/env python3

import argparse
from diag1 import mpu, LABELS, reset_state, run_fdiv, set_fp1
from diag_woz import decode

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
    raise RuntimeError(f"routine at ${start_addr:04x} didn't terminate in {max_steps} steps")

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

def get_fp1(mpu):
    return tuple(mpu.memory[0x61:0x65])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FDIV using PY65.")

    parser.add_argument(
        'dividend', 
        metavar='DIVIDEND', 
        type=str, 
        help="The dividend as a number string (e.g., '12.5')."
    )

    parser.add_argument(
        'divisor',
        metavar='DIVISOR',
        type=str,
        help="The divisor as a number string (e.g., '3.14')."
    )

    args = parser.parse_args()

    # Assign the parsed command-line inputs to string variables
    divisor_str = args.divisor
    dividend_str = args.dividend

    write_c_string(mpu.memory, 0xC000, divisor_str)
    write_c_string(mpu.memory, 0xC010, dividend_str)

    # Convert the strings to FP1 and FP2 using the C64 routines
    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_FROM_ASCII_SCI_V3'], a=0x00, x=0, y=0xC0)
    fp1 = get_fp1(mpu)

    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_FROM_ASCII_SCI_V3'], a=0x10, x=0, y=0xC0)
    fp2 = get_fp1(mpu)

    # Reset the state before running FDIV
    reset_state()
    trapped, outcome, state = run_fdiv(fp1, fp2)
    fp1 = get_fp1(mpu)
    
    if trapped:
        print(f"FP2 (dividend) bytes: {tuple(hex(b) for b in fp2)}")
        print(f"FP1 (divisor) bytes: {tuple(hex(b) for b in fp1)}")
        print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")
        print(f"decoded={decode(*state['FP1'])}")

    reset_state()
    set_fp1(*fp1)
    trapped, code = execute_routine_checked(mpu, LABELS, LABELS['.FP_TO_ASCII_SCI_V2'], a=0x20, x=7, y=0xC0)
    result = read_c_string(mpu.memory, 0xC020)

    print(f"{tuple(hex(b) for b in fp2)} / {tuple(hex(b) for b in fp1)} = {tuple(hex(b) for b in state['FP1'])}")
    print(f"{dividend_str} / {divisor_str} = {result}")
