#!/usr/bin/env python3
"""
diag4.py - Automated instruction-level watch for FP_SIGN ($02)
corruption during FP_FMUL(12.0, -5.0).

No manual stepping. This steps the ALREADY-VALIDATED py65 simulator
(same mpu/LABELS/load_prg as diag1.py - loading is confirmed correct)
one instruction at a time from .fmul's entry, recording every PC
visited and the value of $02 at each step. It then reports the EXACT
instruction where $02 changes value, with a few instructions of
context on either side - no scrolling through a full trace by hand.

Run: PYTHONPATH=src python3 diag4.py
"""

from diag1 import mpu, LABELS, load_prg, reset_state

FP_SIGN_ADDR = 0x02

def set_fp1(exp, m0, m1, m2):
    mpu.memory[0x61:0x65] = [exp, m0, m1, m2]

def set_fp2(exp, m0, m1, m2):
    mpu.memory[0x69:0x6d] = [exp, m0, m1, m2]

def dump_fp():
    return {
        'FP1': tuple(mpu.memory[0x61:0x65]),
        'FP_EXT': tuple(mpu.memory[0x65:0x68]),
        'FP2': tuple(mpu.memory[0x69:0x6d]),
        'FP_SIGN': mpu.memory[FP_SIGN_ADDR],
    }

def watch_fp_sign(fp1, fp2, entry_label='.fmul', exit_labels=('.rts1', '.zero_exponent'),
                   max_steps=20000, context=3):
    """Steps one instruction at a time from entry_label, recording PC
    and FP_SIGN at every step. Reports the exact instruction where
    FP_SIGN changes, with `context` steps of history before and after.
    Returns the full trace list for further inspection if needed."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    mpu.pc = LABELS[entry_label]
    exit_addrs = {LABELS[n] for n in exit_labels}

    trace = []
    last_sign = mpu.memory[FP_SIGN_ADDR]
    changes = []

    for step_num in range(max_steps):
        pc_before = mpu.pc
        sign_before = mpu.memory[FP_SIGN_ADDR]
        opcode = mpu.memory[pc_before]

        mpu.step()

        sign_after = mpu.memory[FP_SIGN_ADDR]
        trace.append({
            'step': step_num,
            'pc': pc_before,
            'opcode': opcode,
            'sign_before': sign_before,
            'sign_after': sign_after,
        })

        if sign_after != sign_before:
            changes.append(step_num)

        if pc_before in exit_addrs:
            break
    else:
        raise RuntimeError(f"didn't reach exit in {max_steps} steps")

    return trace, changes
    
def watch_with_pc_trace(fp1, fp2, entry_label='.fmul',
                          exit_labels=('.rts1', '.zero_exponent'),
                          max_steps=20000):
    """Logs FP_SIGN and FP1_MANT (sign bit) at EVERY step, unconditionally
    - not just on change - for the first N steps after entry, so we can
    see directly whether abswap's negative branch is ever taken at all."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    mpu.pc = LABELS[entry_label]
    exit_addrs = {LABELS[n] for n in exit_labels}
    log = []
    for step_num in range(max_steps):
        pc = mpu.pc
        log.append((step_num, pc, mpu.memory[0x02], mpu.memory[0x69], mpu.memory[0x6a]))
        mpu.step()
        if pc in exit_addrs:
            break
    return log

def report(trace, changes, context=3):
    if not changes:
        print("FP_SIGN never changed during this run - no corruption "
              "detected on this path.")
        return
    print(f"FP_SIGN changed {len(changes)} time(s), at step(s): {changes}\n")
    for idx in changes:
        lo = max(0, idx - context)
        hi = min(len(trace), idx + context + 1)
        print(f"--- change at step {idx} ---")
        for i in range(lo, hi):
            t = trace[i]
            marker = ' <-- CHANGE' if i == idx else ''
            print(f"  step {t['step']:5d}  PC=${t['pc']:04x}  "
                  f"opcode=${t['opcode']:02x}  "
                  f"FP_SIGN {t['sign_before']:02x}->{t['sign_after']:02x}{marker}")
        print()

if __name__ == '__main__':
    reset_state()
    set_fp1(0x83,0x60,0x00,0x00)
    set_fp2(0x82,0x88,0x00,0x00)
    mpu.pc = LABELS['.fmul']
    mdend_addr = LABELS['.mdend']
    reached = False
    for _ in range(20000):
        pc = mpu.pc
        if pc == mdend_addr:
            reached = True
        if reached:
            print(f"PC=${pc:04x}  opcode=${mpu.memory[pc]:02x}  "
                  f"A={mpu.a:02x} P={mpu.p:02x} SP={mpu.sp:02x}")
        mpu.step()
        if reached and mpu.pc not in range(mdend_addr, mdend_addr+30):
            break

#if __name__ == '__main__':
#     reset_state()
#     set_fp1(0x83,0x60,0x00,0x00)
#     set_fp2(0x82,0x88,0x00,0x00)
#     mpu.pc = LABELS['.fmul']
#     rts1_addr = LABELS['.rts1']
#     last_sign = mpu.memory[0x02]
#     print(f"start: FP_SIGN={last_sign:02x}")
#     for step in range(20000):
#         pc = mpu.pc
#         mpu.step()
#         s = mpu.memory[0x02]
#         if s != last_sign:
#             print(f"step {step:5d}  PC=${pc:04x} -> ${mpu.pc:04x}  "
#                   f"FP_SIGN {last_sign:02x}->{s:02x}")
#             last_sign = s
#         if pc == rts1_addr:
#             print(f"reached final .rts1 at step {step}, FP_SIGN={mpu.memory[0x02]:02x}")
#             # keep running a bit further to see what happens after
#         if step > 0 and pc == rts1_addr and mpu.pc not in range(rts1_addr, rts1_addr+40):
#             break
#     print(f"end: FP_SIGN={mpu.memory[0x02]:02x}")

# if __name__ == '__main__':
#     reset_state()
#     set_fp1(0x83,0x60,0x00,0x00)
#     set_fp2(0x82,0x88,0x00,0x00)
#     mpu.pc = LABELS['.fmul']
#     fcompl_addr = LABELS['.fcompl']
#     rts_final = None
#     for _ in range(20000):
#         pc = mpu.pc
#         if pc == fcompl_addr:
#             sp = mpu.sp
#             stack_bytes = mpu.memory[0x100+sp+1:0x100+sp+5]
#             print(f"AT .fcompl: SP={sp:02x} stack(top4)={[hex(b) for b in stack_bytes]}")
#         if pc == LABELS['.rts1']:
#             sp = mpu.sp
#             stack_bytes = mpu.memory[0x100+sp+1:0x100+sp+5]
#             print(f"AT .rts1:   SP={sp:02x} stack(top4)={[hex(b) for b in stack_bytes]}")
#         mpu.step()
#         if pc == LABELS['.rts1']:
#             break

# if __name__ == '__main__':
#     reset_state()
#     set_fp1(0x83,0x60,0x00,0x00)
#     set_fp2(0x82,0x88,0x00,0x00)
#     mpu.pc = LABELS['.fmul']
#     rts1_addr = LABELS['.rts1']
#     seen_rts1 = False
#     for _ in range(20000):
#         pc = mpu.pc
#         if pc == rts1_addr:
#             seen_rts1 = True
#         if seen_rts1:
#             print(f"PC=${pc:04x}  opcode=${mpu.memory[pc]:02x}  "
#                   f"A={mpu.a:02x} X={mpu.x:02x} Y={mpu.y:02x} SP={mpu.sp:02x}")
#         mpu.step()
#         if seen_rts1 and mpu.pc not in range(rts1_addr, rts1_addr+40):
#             break  # left the rts1 block
            
# if __name__ == '__main__':
#     log = watch_with_pc_trace((0x83,0x60,0x00,0x00), (0x82,0x88,0x00,0x00))
#     interesting = {LABELS[n]: n for n in ('.fmul','.md1','.abswap','.abswp1','.fcompl','.swap','.mdend','.mul1','.norm','.norm1','.rts1')}
#     for step_num, pc, sign, fp2exp, fp2mant in log:
#         if pc in interesting:
#             print(f"step {step_num:5d}  {interesting[pc]:12s}  "
#                   f"FP_SIGN={sign:02x}  FP2_EXP={fp2exp:02x}  FP2_MANT0={fp2mant:02x}")
                  
# if __name__ == '__main__':
#     print("=== Watching FP_SIGN during FP_FMUL(12.0, -5.0) ===\n")
#     fp1 = (0x83, 0x60, 0x00, 0x00)   # 12.0
#     fp2 = (0x82, 0x88, 0x00, 0x00)   # -5.0
#     trace, changes = watch_fp_sign(fp1, fp2)
#     report(trace, changes)
# 
#     final = dump_fp()
#     print("Final state:", final)
# 
#     print("\n=== Control: same watch on FP_FMUL(10.0, 10.0) - both "
#           "positive, FP_SIGN should never change ===\n")
#     trace2, changes2 = watch_fp_sign((0x83,0x50,0x00,0x00), (0x83,0x50,0x00,0x00))
#     report(trace2, changes2)
#     
#     log = watch_with_pc_trace((0x83,0x60,0x00,0x00), (0x82,0x88,0x00,0x00))
#     # print only steps where PC lands on a label we care about
#     interesting = {LABELS[n]: n for n in ('.fmul','.md1','.abswap','.abswp1','.fcompl','.swap','.mdend')}
#     for step_num, pc, sign, fp2exp, fp2mant in log:
#         if pc in interesting:
#             print(f"step {step_num:5d}  {interesting[pc]:12s}  "
#                   f"FP_SIGN={sign:02x}  FP2_EXP={fp2exp:02x}  FP2_MANT0={fp2mant:02x}")

    