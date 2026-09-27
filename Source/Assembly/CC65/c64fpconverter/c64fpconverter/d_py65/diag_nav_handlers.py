#!/usr/bin/env python3
"""
diag_nav_handlers.py - targeted tests for navigation.s's state machine.

Approach
========
Rather than stubbing the whole keyboard queue, this harness patches
KERNAL_GETIN ($FFE4) with a 4-byte trampoline that returns whatever
byte is in $8FFF. Each test:

  1. Sets up the desired state (nav_state, edit_buf, edit_len, ...)
  2. Writes the key byte to $8FFF
  3. Calls nav_poll once
  4. Reads back the state variables and asserts them

This exercises the real dispatch path without needing a queue driver,
and without needing to reason about GETIN's debounce behaviour.
The state machine is what we're testing; the keyboard is not.

Handlers tested (each has a [BUG FIX] comment somewhere in the
source that motivated the current behaviour):
  browse: move_down, move_up, enter_edit
  edit:   append, overwrite, cursor_left, cursor_right,
          backspace (three cases), HOME, RETURN/commit
  cross:  space handling on grouped vs ungrouped rows,
          max-length enforcement, unrecognised key passthrough
"""
import diag_convert
from diag_convert import mpu, resolve


# ============================================================
# Patch KERNAL_GETIN to return whatever is in $8FFF.
# At $FFE4: AD FF 8F 60  =  LDA $8FFF / RTS
# ============================================================
GETIN_CELL = 0x8FFF
mpu.memory[0xFFE4] = 0xAD
mpu.memory[0xFFE5] = GETIN_CELL & 0xFF
mpu.memory[0xFFE6] = GETIN_CELL >> 8
mpu.memory[0xFFE7] = 0x60


# ============================================================
# Symbol resolution
# ============================================================
NAV_POLL      = resolve('nav_poll')
NAV_STATE     = resolve('nav_state')
SELECTED_ROW  = resolve('selected_row')
EDIT_ROW      = resolve('edit_row')
EDIT_LEN      = resolve('edit_len')
EDIT_CURSOR   = resolve('edit_cursor')
EDIT_MAX      = resolve('edit_max')
EDIT_BUF      = resolve('edit_buf')
EDIT_MAX_TBL  = resolve('edit_max_table')
L_ENTRIES     = resolve('l_entries')
CUR           = resolve('LayoutValues::current_value', 'current_value')

NAV_BROWSE = 0
NAV_EDIT   = 1

# PETSCII codes (from labels_screen.s)
RETURN       = 0x0D
INSTDEL      = 0x14
HOME         = 0x13
CURSOR_LEFT  = 0x9D
CURSOR_RIGHT = 0x1D
CURSOR_DOWN  = 0x11
CURSOR_UP    = 0x91
SPACE        = 0x20


# ============================================================
# Helpers
# ============================================================
def set_key(k):
    mpu.memory[GETIN_CELL] = k


def get_buf():
    """Return edit_buf contents up to (not including) the first $00."""
    out = []
    for i in range(33):
        b = mpu.memory[EDIT_BUF + i]
        if b == 0:
            break
        out.append(b)
    return bytes(out)


def set_buf(data):
    """Write data into edit_buf and zero-terminate the remainder."""
    for i in range(33):
        mpu.memory[EDIT_BUF + i] = 0
    for i, b in enumerate(data):
        mpu.memory[EDIT_BUF + i] = b


def call_nav():
    """Call nav_poll once. max_steps is generous so @commit_edit can
    run through commit_value (which parses and calls refresh_display)."""
    diag_convert.call(NAV_POLL, max_steps=500_000,
                      trap_label='.FP_ERROR_PROC')


def reset_edit_state():
    """Reset only the edit-related BSS, not the whole CPU. Sets
    nav_state to EDIT so nav_poll goes straight to @edit_mode."""
    mpu.memory[NAV_STATE]   = NAV_EDIT
    mpu.memory[EDIT_LEN]    = 0
    mpu.memory[EDIT_CURSOR] = 0
    mpu.memory[EDIT_MAX]    = 0
    mpu.memory[EDIT_ROW]    = 0
    set_buf(b'')


PASS = 0
FAIL = 0


def T(label, got, want):
    global PASS, FAIL
    ok = (got == want)
    mark = "OK" if ok else "** FAIL **"
    print(f"  {label:52s} got={got!r:<28s} want={want!r:<28s} [{mark}]")
    if ok:
        PASS += 1
    else:
        FAIL += 1


# ============================================================
# 1. Browse mode - row movement and wrap
# ============================================================
print("--- 1. Browse: row movement ---")

mpu.memory[NAV_STATE] = NAV_BROWSE
mpu.memory[SELECTED_ROW] = 0
set_key(CURSOR_DOWN); call_nav()
T("move_down from 0 -> 1", mpu.memory[SELECTED_ROW], 1)

n = mpu.memory[L_ENTRIES]
mpu.memory[SELECTED_ROW] = n - 1
set_key(CURSOR_DOWN); call_nav()
T("move_down from last wraps to 0", mpu.memory[SELECTED_ROW], 0)

mpu.memory[SELECTED_ROW] = 0
set_key(CURSOR_UP); call_nav()
T("move_up from 0 wraps to last", mpu.memory[SELECTED_ROW], n - 1)

mpu.memory[SELECTED_ROW] = 2
set_key(CURSOR_UP); call_nav()
T("move_up from 2 -> 1", mpu.memory[SELECTED_ROW], 1)


# ============================================================
# 2. Browse -> Edit transition
# ============================================================
print()
print("--- 2. Browse -> Edit (@enter_edit) ---")

mpu.memory[NAV_STATE] = NAV_BROWSE
mpu.memory[SELECTED_ROW] = 2      # woz/rankin row
set_key(RETURN); call_nav()
T("@enter_edit: nav_state = EDIT", mpu.memory[NAV_STATE], NAV_EDIT)
T("@enter_edit: edit_row copied",  mpu.memory[EDIT_ROW], 2)
T("@enter_edit: edit_len = 0",     mpu.memory[EDIT_LEN], 0)
T("@enter_edit: edit_cursor = 0",  mpu.memory[EDIT_CURSOR], 0)
T("@enter_edit: edit_max from table",
  mpu.memory[EDIT_MAX], mpu.memory[EDIT_MAX_TBL + 2])
T("@enter_edit: whole buffer cleared", get_buf(), b'')
nz = sum(1 for i in range(33) if mpu.memory[EDIT_BUF + i] != 0)
T("@enter_edit: 33-byte buffer fully zeroed (nonzero count)", nz, 0)


# ============================================================
# 3. Edit: append path (typing into empty then more)
# ============================================================
print()
print("--- 3. Edit: append ---")

reset_edit_state()
mpu.memory[EDIT_ROW] = 0
mpu.memory[EDIT_MAX] = 10

set_key(ord('1')); call_nav()
T("type '1' into empty: buf",       get_buf(), b'1')
T("type '1' into empty: len",       mpu.memory[EDIT_LEN], 1)
T("type '1' into empty: cursor",    mpu.memory[EDIT_CURSOR], 1)
T("type '1' into empty: term at [1]", mpu.memory[EDIT_BUF + 1], 0)

set_key(ord('2')); call_nav()
set_key(ord('3')); call_nav()
T("type '123': buf",           get_buf(), b'123')
T("type '123': len",           mpu.memory[EDIT_LEN], 3)
T("type '123': cursor",        mpu.memory[EDIT_CURSOR], 3)
T("type '123': term at [3]",   mpu.memory[EDIT_BUF + 3], 0)


# ============================================================
# 4. Edit: max-length enforcement
# ============================================================
print()
print("--- 4. Edit: max length ---")

reset_edit_state()
mpu.memory[EDIT_ROW] = 0
mpu.memory[EDIT_MAX] = 3
set_buf(b'abc')
mpu.memory[EDIT_LEN] = 3
mpu.memory[EDIT_CURSOR] = 3

set_key(ord('z')); call_nav()
T("append at max: buf unchanged",    get_buf(), b'abc')
T("append at max: len unchanged",    mpu.memory[EDIT_LEN], 3)
T("append at max: cursor unchanged", mpu.memory[EDIT_CURSOR], 3)


# ============================================================
# 5. Edit: space handling on grouped vs ungrouped rows
# ============================================================
print()
print("--- 5. Edit: space on grouped rows ---")

# Row 0 (decimal, group_mask = 0): space accepted
reset_edit_state()
mpu.memory[EDIT_ROW] = 0
mpu.memory[EDIT_MAX] = 10
set_key(ord('1')); call_nav()
set_key(SPACE);    call_nav()
set_key(ord('2')); call_nav()
T("space on decimal row: accepted", get_buf(), b'1 2')
T("space on decimal row: len",      mpu.memory[EDIT_LEN], 3)

# Row 1 (binary, group_mask = 7): space ignored
reset_edit_state()
mpu.memory[EDIT_ROW] = 1
mpu.memory[EDIT_MAX] = 32
set_key(ord('1')); call_nav()
set_key(SPACE);    call_nav()    # should be silently dropped
set_key(ord('0')); call_nav()
T("space on binary row: ignored",    get_buf(), b'10')
T("space on binary row: len=2",      mpu.memory[EDIT_LEN], 2)
T("space on binary row: cursor=2",   mpu.memory[EDIT_CURSOR], 2)


# ============================================================
# 6. Edit: cursor left / right
# ============================================================
print()
print("--- 6. Edit: cursor movement ---")

reset_edit_state()
set_buf(b'123')
mpu.memory[EDIT_LEN] = 3
mpu.memory[EDIT_CURSOR] = 3

set_key(CURSOR_LEFT); call_nav()
T("cursor_left: 3 -> 2", mpu.memory[EDIT_CURSOR], 2)
set_key(CURSOR_LEFT); call_nav()
T("cursor_left: 2 -> 1", mpu.memory[EDIT_CURSOR], 1)
set_key(CURSOR_RIGHT); call_nav()
T("cursor_right: 1 -> 2", mpu.memory[EDIT_CURSOR], 2)

mpu.memory[EDIT_CURSOR] = 3
set_key(CURSOR_RIGHT); call_nav()
T("cursor_right at end: stays 3", mpu.memory[EDIT_CURSOR], 3)

mpu.memory[EDIT_CURSOR] = 0
set_key(CURSOR_LEFT); call_nav()
T("cursor_left at 0: stays 0", mpu.memory[EDIT_CURSOR], 0)


# ============================================================
# 7. Edit: overwrite at cursor
# ============================================================
print()
print("--- 7. Edit: overwrite ---")

reset_edit_state()
set_buf(b'12345')
mpu.memory[EDIT_LEN] = 5
mpu.memory[EDIT_CURSOR] = 2
set_key(ord('9')); call_nav()
T("overwrite at 2: buf",    get_buf(), b'12945')
T("overwrite at 2: len",    mpu.memory[EDIT_LEN], 5)
T("overwrite at 2: cursor", mpu.memory[EDIT_CURSOR], 3)


# ============================================================
# 8. Edit: backspace (three cases)
# ============================================================
print()
print("--- 8. Edit: backspace ---")

# Case A: at cursor 0, nothing to delete
reset_edit_state()
set_buf(b'123')
mpu.memory[EDIT_LEN] = 3
mpu.memory[EDIT_CURSOR] = 0
set_key(INSTDEL); call_nav()
T("bs at 0: buf unchanged", get_buf(), b'123')
T("bs at 0: len unchanged", mpu.memory[EDIT_LEN], 3)
T("bs at 0: cursor unchanged", mpu.memory[EDIT_CURSOR], 0)

# Case B: at end, remove last char
reset_edit_state()
set_buf(b'123')
mpu.memory[EDIT_LEN] = 3
mpu.memory[EDIT_CURSOR] = 3
set_key(INSTDEL); call_nav()
T("bs at end: buf='12'",       get_buf(), b'12')
T("bs at end: len=2",          mpu.memory[EDIT_LEN], 2)
T("bs at end: cursor=2",       mpu.memory[EDIT_CURSOR], 2)
T("bs at end: term at [2]",    mpu.memory[EDIT_BUF + 2], 0)

# Case C: in middle, shift left
reset_edit_state()
set_buf(b'12345')
mpu.memory[EDIT_LEN] = 5
mpu.memory[EDIT_CURSOR] = 3
set_key(INSTDEL); call_nav()
T("bs mid: buf='1245'",        get_buf(), b'1245')
T("bs mid: len=4",             mpu.memory[EDIT_LEN], 4)
T("bs mid: cursor=2",          mpu.memory[EDIT_CURSOR], 2)
T("bs mid: term at [4]",       mpu.memory[EDIT_BUF + 4], 0)


# ============================================================
# 9. Edit: HOME clears
# ============================================================
print()
print("--- 9. Edit: HOME ---")

reset_edit_state()
set_buf(b'98765')
mpu.memory[EDIT_LEN] = 5
mpu.memory[EDIT_CURSOR] = 3
set_key(HOME); call_nav()
T("HOME: buf empty",  get_buf(), b'')
T("HOME: len=0",      mpu.memory[EDIT_LEN], 0)
T("HOME: cursor=0",   mpu.memory[EDIT_CURSOR], 0)
nz = sum(1 for i in range(33) if mpu.memory[EDIT_BUF + i] != 0)
T("HOME: entire 33-byte buffer zeroed", nz, 0)


# ============================================================
# 10. Edit: commit (RETURN)
# ============================================================
print()
print("--- 10. Edit: commit ---")

reset_edit_state()
mpu.memory[EDIT_ROW] = 0
mpu.memory[EDIT_MAX] = 10
mpu.memory[CUR:CUR + 4] = [0x80, 0x40, 0x00, 0x00]   # seed current_value = 1.0

set_key(ord('2')); call_nav()
set_key(ord('.')); call_nav()
set_key(ord('0')); call_nav()
T("pre-commit: buf='2.0'",  get_buf(), b'2.0')
T("pre-commit: len=3",      mpu.memory[EDIT_LEN], 3)

set_key(RETURN); call_nav()
T("commit: nav_state back to BROWSE",  mpu.memory[NAV_STATE], NAV_BROWSE)
T("commit: edit_cursor reset to 0",    mpu.memory[EDIT_CURSOR], 0)
# Woz 2.0 = exponent $81, mantissa $40 00 00
T("commit: current_value = 2.0",
  tuple(mpu.memory[CUR:CUR + 4]), (0x81, 0x40, 0x00, 0x00))


# ============================================================
# 11. Browse: unrecognised key returns key in A (for main.s's 'q')
# ============================================================
print()
print("--- 11. Browse: unrecognised key passthrough ---")

mpu.memory[NAV_STATE] = NAV_BROWSE
mpu.memory[SELECTED_ROW] = 0
set_key(ord('q'))
_, s = diag_convert.call(NAV_POLL, max_steps=200_000)
T("browse 'q' returns 'q' in A", s['a'], ord('q'))


# ============================================================
print()
print(f"Passed: {PASS}  Failed: {FAIL}  Total: {PASS + FAIL}")
