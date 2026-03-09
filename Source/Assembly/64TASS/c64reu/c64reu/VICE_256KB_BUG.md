# VICE 256KB REU Detection Issue

## Problem

When VICE is configured with a 256KB (1764) REU, the detection routine incorrectly reports **512KB** instead of 256KB.

**Tested configurations:**
- ✅ Real hardware (C64U): All sizes detect correctly
- ✅ VICE 128KB: Detects correctly
- ❌ VICE 256KB: **Detects as 512KB** (bug)
- ✅ VICE 512KB: Detects correctly
- ✅ VICE 1MB+: Detects correctly

## Technical Analysis

The detection works by testing aliasing at power-of-2 boundaries:

```assembly
; For 256KB REU (banks 0-3), bank 4 should alias to bank 0
Write $55 to $000000 (bank 0)
Write $AA to $040000 (bank 4)
Read  $000000 (bank 0)
→ Should read $AA (aliasing detected) ✓

; But VICE 256KB doesn't show aliasing until bank 8
Write $55 to $000000 (bank 0)
Write $AA to $080000 (bank 8)
Read  $000000 (bank 0)
→ Reads $AA (aliasing detected) ✗ Wrong boundary!
```

### Expected Behavior (Real Hardware)

**256KB REU (1764)** - 4 banks (0-3):
- Bank 4 ($040000) aliases to bank 0
- Bank 5 ($050000) aliases to bank 1
- Bank 6 ($060000) aliases to bank 2
- Bank 7 ($070000) aliases to bank 3

### Actual Behavior (VICE 256KB)

VICE appears to provide independent storage for banks 0-7, only showing aliasing at bank 8. This suggests VICE is emulating the address decoder as if it has 512KB of RAM, even when configured for 256KB.

## Workarounds

### Option 1: Accept VICE Limitation
Document that VICE 256KB detection is unreliable and recommend users verify manually:

```assembly
#REU_DETECT no_reu_found

; On VICE with 256KB configured, this returns $07 (512KB)
; Users should manually check VICE settings if unexpected
```

### Option 2: Add VICE-Specific Heuristic
Test if the REU returns $F8 from the bank register (VICE signature):

```assembly
#REU_QUICK_DETECT no_reu_found
cmp #$F8
bne not_vice        ; Real hardware, trust detection

; VICE detected - warn user about potential 256KB misconfiguration
; Could check both $040000 and $080000 and report ambiguity
```

### Option 3: Test Intermediate Banks
Add an extra test specifically for VICE 256KB to check if banks 4-7 are truly independent:

```assembly
; After failing $040000 test, before $080000 test:
; Write different values to banks 4, 5, 6, 7
; Read them back - if they're independent, it's really 512KB
; If they show patterns of aliasing, might be VICE 256KB bug
```

## Recommended Approach

**For production code:**
Accept the limitation and add a note in your documentation that VICE 256KB REU may be misdetected as 512KB due to emulator behavior. Real hardware detection is accurate.

**For development:**
Use VICE with 512KB, 1MB, or 16MB settings which detect correctly. Avoid the 256KB setting in VICE.

**For VICE developers:**
This appears to be an address decoding bug in VICE's 1764 (256KB) REU emulation. The bank register wrapping should occur at bank 4 ($040000), not bank 8 ($080000).

## Testing Results Summary

| Platform | Config | Expected | Detected | Status |
|----------|--------|----------|----------|--------|
| C64U     | 128KB  | $01      | $01      | ✅     |
| C64U     | 256KB  | $03      | $03      | ✅     |
| C64U     | 512KB  | $07      | $07      | ✅     |
| VICE     | 128KB  | $01      | $01      | ✅     |
| VICE     | 256KB  | $03      | **$07**  | ❌ BUG |
| VICE     | 512KB  | $07      | $07      | ✅     |
| VICE     | 1MB    | $0F      | $0F      | ✅     |
| VICE     | 2MB    | $1F      | $1F      | ✅     |
| VICE     | 4MB    | $3F      | $3F      | ✅     |
| VICE     | 8MB    | $7F      | $7F      | ✅     |
| VICE     | 16MB   | $FF      | $FF      | ✅     |

## Code Comments to Add

```assembly
; NOTE: VICE emulator bug - 256KB REU configuration will be
; detected as 512KB due to incorrect aliasing boundary in
; VICE's 1764 emulation. Real hardware (C64U) detects correctly.
; This is a known VICE issue, not a problem with this code.
```

## Reporting to VICE Project

Consider reporting this to the VICE development team:
- **Issue**: 256KB (1764) REU emulation has incorrect bank aliasing
- **Expected**: Bank 4 ($040000) should alias to bank 0 ($000000)
- **Actual**: Bank 8 ($080000) aliases to bank 0, banks 4-7 are independent
- **Impact**: REU size detection code incorrectly identifies 256KB as 512KB
- **Workaround**: None needed for real hardware

## References

- REU Hardware: Commodore 1700 (128KB), 1764 (256KB), 1750 (512KB)
- Bank aliasing is due to incomplete address decoding in hardware
- VICE: https://vice-emu.sourceforge.io/
- Report bugs: https://sourceforge.net/p/vice-emu/bugs/
