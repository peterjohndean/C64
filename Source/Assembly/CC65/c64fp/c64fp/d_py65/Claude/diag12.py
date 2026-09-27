#!/usr/bin/env python3
"""
diag12.py - Traces FP_FROM_ASCII_SCI_V3's internal FP_FMUL calls
for "3.4028120E+38", comparing each intermediate mantissa against
diag_woz.py's independently-computed expected value, to find exactly
which multiply step introduces the ~4e-6 relative error confirmed
in asciisci.py's round-trip test (item 1) - larger than the routine's
own documented ~3e-8-per-step precision floor would predict.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state, _run_fmul_or_fdiv, SENTINEL
from diag_woz import decode

def write_c_string(memory_space, address, text):
    data = text.encode("ascii") + b"\x00"
    for offset, byte in enumerate(data):
        memory_space[address + offset] = byte

reset_state()

# --- begin ---
# Push sentinel as a fake return address for the outer call
SENTINEL_MAIN = SENTINEL + 1   # distinct from the inner sentinel (0x1234)
ret_addr = SENTINEL_MAIN - 1
mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
mpu.sp -= 1
mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
mpu.sp -= 1
#--- end ---

str_addr = 0xC000
write_c_string(mpu.memory, str_addr, "3.4028120E+38")
mpu.a = str_addr & 0xFF
mpu.x = 0
mpu.y = (str_addr >> 8) & 0xFF
mpu.pc = LABELS['.FP_FROM_ASCII_SCI_V3']

fmul_addr = LABELS['.fmul']
error_addr = LABELS['.FP_ERROR_PROC']
call_num = 0

print(f"{'call':>4} {'FP1 before':>15}    {'FP2 before':>15}  {'-> FP1 after (decoded)':>27}")
for _ in range(500000):
    pc = mpu.pc
    
    if pc == SENTINEL_MAIN:
        print("\nSUCCESS: Routine finished cleanly.")
        break
        
    if pc == error_addr:
        print(f"\nTRAPPED at call {call_num}, code={mpu.memory[0xFE]}")
        break
    
    if pc == fmul_addr:
        call_num += 1
        fp1_before = tuple(mpu.memory[0x61:0x65])
        fp2_before = tuple(mpu.memory[0x69:0x6d])
        d1 = decode(*fp1_before)
        d2 = decode(*fp2_before)
        
        # Save the stack pointer and the real return address.
        orig_sp = mpu.sp
        ret_addr = (mpu.memory[0x100 + orig_sp + 1] | (mpu.memory[0x100 + orig_sp + 2] << 8)) + 1
        
        print(f"FP1 exact bytes: {tuple(hex(b) for b in mpu.memory[0x61:0x65])}")
        print(f"FP2 exact bytes: {tuple(hex(b) for b in mpu.memory[0x69:0x6d])}")
        print(f"FP1 decoded (full precision): {decode(*mpu.memory[0x61:0x65]):.15e}")
        print(f"FP2 decoded (full precision): {decode(*mpu.memory[0x69:0x6d]):.15e}")

        trapped, outcome, state = _run_fmul_or_fdiv()
        if trapped:
            print(f"call {call_num:3d}: FP1={d1!r:>16} FP2={d2!r:>16}  -> TRAPPED")
            break
        result = decode(*state['FP1'])
        expected = d1 * d2
        rel_err = abs(result - expected) / abs(expected) if expected else 0
        flag = "  <-- suspicious" if rel_err > 1e-6 else ""
        print(f"call {call_num:3d}: FP1={d1:.6e} * FP2={d2:.6e} "
              f"-> {result:.10e} (expected {expected:.10e}, rel_err={rel_err:.2e}){flag}")
              
        # Simulate the RTS that would have returned from FP_FMUL:
        # restore PC to the instruction after the original JSR,
        # and adjust SP by +2 to discard the return address (and the
        # sentinel that _run_fmul_or_fdiv pushed).
        mpu.pc = ret_addr
        mpu.sp = orig_sp + 2
    
        #mpu.step()   # [FIX] actually execute the RTS that's sitting
                     # at the real exit _run_fmul_or_fdiv() just
                     # stopped at, so execution returns to
                     # FP_FROM_ASCII_SCI_V3's own caller of .fmul
                     # instead of stalling on the same PC forever
        
        continue
        
    mpu.step()
else:
    print("didn't finish in 500000 steps")

final = dump_fp()
print(f"\nfinal FP1 = {tuple(hex(b) for b in final['FP1'])} = {decode(*final['FP1'])}")