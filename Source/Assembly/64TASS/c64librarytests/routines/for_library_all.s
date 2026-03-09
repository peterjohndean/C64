; ============================================================
; FILE      : for_library_all.s
; Project   : Commodore 64 Library Test Suite
; Target    : Commodore 64 / 6510 CPU
; Assembler : 64TASS v1.60+
; ============================================================
; PURPOSE
; -------
; Systematic test harness for every procedure in library_*.s:
;
;   library_bitwise.s
;     BITWISE_MULTIPLY_64_PROC  — automated PASS / FAIL
;
;   library_convert.s
;     OUTPUT_BYTETOHEX_PROC     — visual (screen output only)
;     OUTPUT_BYTETOBINARY_PROC  — visual (screen output only)
;
;   library_reu.s
;     REU_WAIT_EOB_PROC         — automated PASS / FAIL
;     REU_ALIASING_DETECT_PROC  — reported (hardware-dependent)
;     REU_DETECT_SIZE_PROC      — reported (hardware-dependent)
;
; TEST STRATEGY
; -------------
; Automated : return value compared against a known constant
;             → prints PASS (green) or FAIL (red) with details
;
; Visual    : the procedure's only observable effect is screen
;             output; actual and expected strings are printed
;             side-by-side for direct human comparison
;
; Reported  : result depends on attached hardware or VICE
;             configuration; raw value is printed for the user
;             to cross-reference against labels_reu.s
;
; WORKING VARIABLES — STANDARD RAM ($0C00)
; -----------------------------------------
; All mutable state used by the test harness lives in a small
; block declared at $0C00. This is a safe, unused area on a
; stock C64 for a short program that starts at $0801.
;
; WHY NOT ZERO PAGE?
; ------------------
; An earlier version stored working variables at $61-$66.
; That range overlaps the BASIC floating-point accumulators:
;
;   FAC1  $61-$66  (exponent + mantissa + sign)
;   FAC2  $69-$6E  (second operand for arithmetic)
;
; Any call to a BASIC ROM routine — including BASIC_STROUT
; ($AB1E) — silently clobbers those locations. The symptom:
; v_tbl_idx was reset to zero on every BASIC_STROUT call,
; causing the test loop to restart from case 0 forever.
;
; None of the variables below require zero-page indirect
; addressing. They are accessed with plain lda / sta absolute
; (16-bit). Moving them to $0C00 eliminates the conflict at
; the cost of one extra cycle per access — irrelevant in a
; test harness.
;
;   v_input      — input byte for the current test case
;   v_exp_msb    — expected MSB  (bitwise automated tests)
;   v_exp_lsb    — expected LSB  (bitwise automated tests)
;   v_act_msb    — actual   MSB  returned by proc under test
;   v_act_lsb    — actual   LSB  returned by proc under test
;   v_tbl_idx    — byte offset into the bitwise test vector table
;   v_pass_count — cumulative automated PASS count
;   v_fail_count — cumulative automated FAIL count
;   v_reu_result — value returned by the REU detection procedures
;
; ZERO PAGE STILL USED BY LIBRARY PROCS
; --------------------------------------
;   $FB/$FC/$FD  — REU_DETECT_SIZE_PROC (zp_prev, zp_count,
;                  and REU_ALIASING_DETECT staging byte)
; These are private to those procedures; no conflict with the
; v_* variables which live at $0C00.
;
; INCLUDE ORDER
; -------------
; Labels and macros are included first (no code generated).
; Library files are included LAST, after all test code, string
; data, and variable storage. 64TASS resolves all JSR forward
; references in its second assembly pass.
;
; Full table: C64 Programmer's Reference Guide, Appendix E.
; ============================================================

; ── bitwise test table dimensions ─────────────────────────────
BITWISE_TEST_COUNT  = 5     ; number of test vectors in bitwise_tests
BITWISE_ROW_SIZE    = 3     ; bytes per row: [input, exp_msb, exp_lsb]

; ============================================================
; MAIN ENTRY
; ============================================================
initiate_test_library .proc
    lda #$00
    sta v_pass_count            ; reset cumulative PASS tally
    sta v_fail_count            ; reset cumulative FAIL tally

    #KERNAL_CHROUT_MACRO PETSCII_RETURN ; clear the screen
    #KERNAL_CHROUT_MACRO PETSCII_WHITE  ; reset text colour to white
    #BASIC_STROUT_MACRO msg_header      ; suite title
    #BASIC_STROUT_MACRO msg_separator
    
    jsr test_bitwise            ; automated: BITWISE_MULTIPLY_64_PROC
    jsr test_hex                ; visual:    OUTPUT_BYTETOHEX_PROC
    jsr test_binary             ; visual:    OUTPUT_BYTETOBINARY_PROC
    jsr test_reu                ; reported:  REU procs (skipped if no REU)

    ; ── print automated test totals ───────────────────────────
    #BASIC_STROUT_MACRO msg_pass_lbl    ; "PASS: "
    lda v_pass_count
    jsr OUTPUT_BYTETOHEX_PROC           ; two-digit hex count
    #BASIC_STROUT_MACRO msg_fail_lbl    ; "  FAIL: "
    lda v_fail_count
    jsr OUTPUT_BYTETOHEX_PROC
    #KERNAL_CHROUT_MACRO PETSCII_RETURN
    #BASIC_STROUT_MACRO msg_anykey

wait_key
    jsr KERNAL_GETIN            ; non-blocking keyboard read
    beq wait_key                ; loop until a key is pressed
    rts                         ; return to BASIC

; ============================================================
; TEST 1 : BITWISE_MULTIPLY_64_PROC  (automated)
; ============================================================
; PURPOSE
; -------
; Iterates BITWISE_TEST_COUNT known input/output pairs. Each
; call is checked against pre-computed expected values. A PASS
; or FAIL line is printed per case; failing cases also show the
; expected value to aid diagnosis.
;
; OUTPUT FORMAT (40 columns)
; --------------------------
;   " $05 X64=$0140 PASS"
;   " $05 X64=$0000 FAIL EXP=$0140"
;
; TEST TABLE FORMAT (BITWISE_ROW_SIZE = 3 bytes per row)
; -------------------------------------------------------
;   offset 0 : input byte
;   offset 1 : expected MSB  (bits 15-8 of input × 64)
;   offset 2 : expected LSB  (bits  7-0 of input × 64)
;
; REGISTER USE
; ------------
; Y is used as a temporary index into bitwise_tests. Because
; BASIC_STROUT destroys Y (the string address is passed in A/Y),
; the table position is kept in v_tbl_idx (standard RAM) and
; reloaded into Y at the top of every iteration.
; ============================================================
test_bitwise .proc

    #BASIC_STROUT_MACRO msg_bitwise_hdr

    lda #$00
    sta v_tbl_idx               ; start at the first row (byte offset 0)

loop
    ; ── load one test case from the table ─────────────────────
    ; Y is a temporary byte index into bitwise_tests.
    ; It is loaded from v_tbl_idx (RAM) each iteration because
    ; BASIC_STROUT_MACRO overwrites Y on every call.
    ldy v_tbl_idx

    lda bitwise_tests,y         ; col 0: 8-bit input value
    sta v_input
    iny
    lda bitwise_tests,y         ; col 1: expected MSB (bits 15-8)
    sta v_exp_msb
    iny
    lda bitwise_tests,y         ; col 2: expected LSB (bits 7-0)
    sta v_exp_lsb
    iny
    sty v_tbl_idx               ; commit the incremented index to RAM
                                ; BEFORE any BASIC_STROUT_MACRO call

    ; ── call the procedure under test ─────────────────────────
    lda v_input
    jsr BITWISE_MULTIPLY_64_PROC
    ; on return: A = MSB (bits 15-8),  X = LSB (bits 7-0)

    sta v_act_msb               ; save actual MSB
    stx v_act_lsb               ; save actual LSB

    ; ── print:  " $IN X64=$RESULT " ───────────────────────────
    #KERNAL_CHROUT_MACRO ' '
    #KERNAL_CHROUT_MACRO '$'
    lda v_input
    jsr OUTPUT_BYTETOHEX_PROC
    #BASIC_STROUT_MACRO  msg_x64eq          ; " X64=$"
    lda v_act_msb
    jsr OUTPUT_BYTETOHEX_PROC               ; high byte of product
    lda v_act_lsb
    jsr OUTPUT_BYTETOHEX_PROC               ; low  byte of product
    #KERNAL_CHROUT_MACRO ' '

    ; ── compare MSB ───────────────────────────────────────────
    lda v_act_msb
    cmp v_exp_msb
    bne fail

    ; ── compare LSB ───────────────────────────────────────────
    lda v_act_lsb
    cmp v_exp_lsb
    bne fail

    ; ── PASS ──────────────────────────────────────────────────
    #KERNAL_CHROUT_MACRO PETSCII_GREEN
    #BASIC_STROUT_MACRO  msg_pass
    #KERNAL_CHROUT_MACRO PETSCII_WHITE
    inc v_pass_count
    jmp next

fail
    ; ── FAIL — print expected value for diagnosis ─────────────
    #KERNAL_CHROUT_MACRO PETSCII_RED
    #BASIC_STROUT_MACRO  msg_fail
    #KERNAL_CHROUT_MACRO PETSCII_WHITE
    #BASIC_STROUT_MACRO  msg_exp_prefix     ; " EXP=$"
    lda v_exp_msb
    jsr OUTPUT_BYTETOHEX_PROC
    lda v_exp_lsb
    jsr OUTPUT_BYTETOHEX_PROC
    inc v_fail_count

next
    #KERNAL_CHROUT_MACRO PETSCII_RETURN

    ; ── end-of-table check ────────────────────────────────────
    lda v_tbl_idx
    cmp #(BITWISE_TEST_COUNT * BITWISE_ROW_SIZE)    ; 5 × 3 = 15
    bne loop
    rts

; ── test vectors ──────────────────────────────────────────────
; Formula for any input n:  MSB = n >> 2,  LSB = (n << 6) & $FF
; Total shift count = 2 + 6 = 8 = bit width of the input.
;
;   n    n×64    $hex    MSB   LSB
;   0       0  $0000    $00   $00
;   1      64  $0040    $00   $40
;   5     320  $0140    $01   $40   ← worked example in library header
;  10     640  $0280    $02   $80
; 255   16320  $3FC0    $3F   $C0   ← maximum 8-bit input
;
bitwise_tests
    .byte $00, $00, $00
    .byte $01, $00, $40
    .byte $05, $01, $40
    .byte $0a, $02, $80
    .byte $ff, $3f, $c0

.endproc

; ============================================================
; TEST 2 : OUTPUT_BYTETOHEX_PROC  (visual)
; ============================================================
; PURPOSE
; -------
; Outputs three byte values through the procedure and prints
; the expected string alongside for direct visual comparison.
;
; SELECTED TEST VALUES
; --------------------
;   $00  — both nibbles zero; both BCC branches taken (0-9 path)
;   $4F  — high nibble 4 (BCC taken); low nibble F (ADC#$06 fires)
;   $FF  — both nibbles exercise the A-F ADC #$06 adjustment path
;
; OUTPUT FORMAT
; -------------
;   $00: 00  (EXPECT: 00)
;   $4F: 4F  (EXPECT: 4F)
;   $FF: FF  (EXPECT: FF)
; ============================================================
test_hex .proc

    #BASIC_STROUT_MACRO msg_hex_hdr

    ; ── $00 → "00" ────────────────────────────────────────────
    #BASIC_STROUT_MACRO msg_hex_pfx00
    lda #$00
    jsr OUTPUT_BYTETOHEX_PROC
    #BASIC_STROUT_MACRO msg_hex_exp00

    ; ── $4F → "4F" ────────────────────────────────────────────
    ; high nibble 4: $30+$04=$34='4', BCC taken (no ADC)
    ; low  nibble F: $30+$0F=$3F, CMP→C=1 → ADC#$06+C=$46='F'
    #BASIC_STROUT_MACRO msg_hex_pfx4f
    lda #$4f
    jsr OUTPUT_BYTETOHEX_PROC
    #BASIC_STROUT_MACRO msg_hex_exp4f

    ; ── $FF → "FF" ────────────────────────────────────────────
    #BASIC_STROUT_MACRO msg_hex_pfxff
    lda #$ff
    jsr OUTPUT_BYTETOHEX_PROC
    #BASIC_STROUT_MACRO msg_hex_expff

    rts
.endproc

; ============================================================
; TEST 3 : OUTPUT_BYTETOBINARY_PROC  (visual)
; ============================================================
; PURPOSE
; -------
; Outputs three byte values through the procedure and prints
; the expected 8-character binary string alongside.
;
; SELECTED TEST VALUES
; --------------------
;   $00  — all bits zero; every ASL→carry=0 → output '0'
;   $4F  — %01001111: mixed bits, verifies each ASL→carry path
;   $FF  — all bits set; every ASL→carry=1 → output '1'
;
; OUTPUT FORMAT
; -------------
;   $00: 00000000  (EXPECT: 00000000)
;   $4F: 01001111  (EXPECT: 01001111)
;   $FF: 11111111  (EXPECT: 11111111)
; ============================================================
test_binary .proc

    #BASIC_STROUT_MACRO msg_bin_hdr

    ; ── $00 → "00000000" ──────────────────────────────────────
    #BASIC_STROUT_MACRO msg_bin_pfx00
    lda #$00
    jsr OUTPUT_BYTETOBINARY_PROC
    #BASIC_STROUT_MACRO msg_bin_exp00

    ; ── $4F → "01001111" ──────────────────────────────────────
    #BASIC_STROUT_MACRO msg_bin_pfx4f
    lda #$4f
    jsr OUTPUT_BYTETOBINARY_PROC
    #BASIC_STROUT_MACRO msg_bin_exp4f

    ; ── $FF → "11111111" ──────────────────────────────────────
    #BASIC_STROUT_MACRO msg_bin_pfxff
    lda #$ff
    jsr OUTPUT_BYTETOBINARY_PROC
    #BASIC_STROUT_MACRO msg_bin_expff

    rts
.endproc

; ============================================================
; TEST 4 : REU LIBRARY PROCS  (automated + reported)
; ============================================================
; PURPOSE
; -------
; Tests all three REU procedures. REU_QUICK_DETECT at the top
; skips the entire section with a clear message if no REU is
; attached.
;
; REU_WAIT_EOB_PROC — automated
;   A 1-byte C64→REU transparent DMA is fired first. Transparent
;   DMA halts the CPU until the transfer is complete, so the EOB
;   flag in $DF00 bit 6 is already set by the time the CPU
;   resumes. REU_WAIT_EOB_PROC should return on its very first
;   poll. Reaching the PASS message proves it did not hang.
;
; REU_ALIASING_DETECT_PROC — reported
;   Returns a bank MASK in A:
;     $01=128KB  $03=256KB  $07=512KB  $0F=1MB
;     $1F=2MB    $3F=4MB    $7F=8MB    $FF=16MB (VICE)
;
; REU_DETECT_SIZE_PROC — reported
;   Returns confirmed 64KB bank COUNT in A. Multiply by 64 for
;   total KB. Also gives REU_WAIT_EOB_PROC an extensive workout
;   via its 768 internal DMA calls (256 SWAPs + 256 reads +
;   256 restores).
; ============================================================
test_reu .proc

    #BASIC_STROUT_MACRO msg_reu_hdr

    ; ── REU presence check ────────────────────────────────────
    ; Writes $00 to the REU address registers, reads back
    ; REU_REU_BANK ($DF06). Without an REU the bus floats → $00
    ; → beq branches to no_reu, skipping all REU tests.
    #REU_QUICK_DETECT no_reu

    ; ── TEST: REU_WAIT_EOB_PROC ───────────────────────────────
    ; v_input is in standard RAM ($0C00) — a valid 16-bit C64
    ; address, usable directly as the DMA source for a 1-byte
    ; C64→REU transfer.
    lda #$a5                    ; arbitrary test pattern
    sta v_input
    #REU_FROM_C64 $000000, v_input, 1
    ; CPU was halted during transparent DMA; EOB flag is now set

    jsr REU_WAIT_EOB_PROC       ; polls $DF00 bit 6 — returns immediately

    ; reaching here proves the proc returned (did not loop)
    #BASIC_STROUT_MACRO  msg_wait_eob_lbl   ; "WAIT EOB: "
    #KERNAL_CHROUT_MACRO PETSCII_GREEN
    #BASIC_STROUT_MACRO  msg_pass
    #KERNAL_CHROUT_MACRO PETSCII_WHITE
    #KERNAL_CHROUT_MACRO PETSCII_RETURN
    inc v_pass_count

    ; ── TEST: REU_ALIASING_DETECT_PROC ───────────────────────
    jsr REU_ALIASING_DETECT_PROC
    sta v_reu_result

    #BASIC_STROUT_MACRO  msg_aliasing_lbl   ; "ALIASING MASK: $"
    lda v_reu_result
    jsr OUTPUT_BYTETOHEX_PROC
    #KERNAL_CHROUT_MACRO PETSCII_RETURN

    ; ── TEST: REU_DETECT_SIZE_PROC ───────────────────────────
    jsr REU_DETECT_SIZE_PROC
    sta v_reu_result

    #BASIC_STROUT_MACRO  msg_size_lbl       ; "DETECT SIZE: $"
    lda v_reu_result
    jsr OUTPUT_BYTETOHEX_PROC
    #BASIC_STROUT_MACRO  msg_banks          ; " BANKS"
    #KERNAL_CHROUT_MACRO PETSCII_RETURN

    jmp done

no_reu
    #BASIC_STROUT_MACRO msg_no_reu

done
    rts
.endproc

; ============================================================
; STRING DATA
; ============================================================
; Null-terminated strings consumed by BASIC_STROUT_MACRO.
; Control bytes are embedded as hex literals.
; UPPERCASE throughout for the C64 default charset.
; ============================================================

msg_header  .null "c64 library test suite", $0d
msg_separator   .null "========================"

msg_pass        .null "pass"
msg_fail        .null "fail"
msg_x64eq       .null " x64=$"
msg_exp_prefix  .null " exp=$"
msg_pass_lbl    .null "pass: "
msg_fail_lbl    .null "  fail: "
msg_anykey      .null "press any key..."

msg_bitwise_hdr .null $0d, "--- bitwise multiply 64 proc ---", $0d
msg_hex_hdr     .null $0d, "--- output bytetohex proc ---", $0d
msg_hex_pfx00   .null " $00: "
msg_hex_exp00   .null "  (expect: 00)", $0d
msg_hex_pfx4f   .null " $4f: "
msg_hex_exp4f   .null "  (expect: 4f)", $0d
msg_hex_pfxff   .null " $ff: "
msg_hex_expff   .null "  (expect: ff)", $0d

msg_bin_hdr     .null $0d, "--- output bytetobinary proc ---", $0d
msg_bin_pfx00   .null " $00: "
msg_bin_exp00   .null "  (expect: 00000000)", $0d
msg_bin_pfx4f   .null " $4f: "
msg_bin_exp4f   .null "  (expect: 01001111)", $0d
msg_bin_pfxff   .null " $ff: "
msg_bin_expff   .null "  (expect: 11111111)", $0d
msg_reu_hdr     .null $0d, "--- reu library ---", $0d

msg_wait_eob_lbl    .null "wait eob: "
msg_aliasing_lbl    .null "aliasing mask: $"
msg_size_lbl        .null "detect size: $"
msg_banks           .null " banks"
msg_no_reu          .null "no reu detected - skipping", $0d

; ============================================================
; WORKING VARIABLES
; ============================================================
; Declared as .byte directives so 64TASS allocates the bytes
; explicitly at the stated address, making the layout visible
; in the listing file and preventing silent overlaps.
; ============================================================
v_input         .byte $00   ; input value for the current test case
v_exp_msb       .byte $00   ; expected MSB  (bitwise automated tests)
v_exp_lsb       .byte $00   ; expected LSB  (bitwise automated tests)
v_act_msb       .byte $00   ; actual   MSB  returned by proc under test
v_act_lsb       .byte $00   ; actual   LSB  returned by proc under test
v_tbl_idx       .byte $00   ; byte offset into bitwise_tests table
v_pass_count    .byte $00   ; cumulative automated PASS count
v_fail_count    .byte $00   ; cumulative automated FAIL count
v_reu_result    .byte $00   ; value returned by REU detection procs
.endproc
