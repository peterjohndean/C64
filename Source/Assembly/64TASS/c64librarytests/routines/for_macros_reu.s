; ============================================================
; test_reu.s  —  REU Macro Library Test Suite
; ============================================================
; Assembler : 64TASS
; Target    : Commodore 64 / C64U (6510 CPU) with REU
; Emulator  : VICE (any REU size >= 512KB recommended)
;
; Purpose   : Exercises every macro defined in macros_reu.s.
;             Tests run one at a time, printing name then result:
;               t01 quick detect  pass
;               t02 from c64      pass  etc.
;
; String case note:
;   All .null strings are lowercase. On the C64 in its default
;   uppercase/graphics charset mode, lowercase PETSCII ($61-$7a)
;   maps to uppercase letters on screen. Writing lowercase in
;   source therefore produces uppercase output — no runtime
;   case conversion is needed.
;
; Buffer placement note:
;   BUF is declared with .fill at the END of this file so
;   64TASS places it after all code and string data. A fixed
;   address like $1000 would collide with the assembled binary
;   at typical load addresses, corrupting code still to execute.
;
; Usage : jsr initiate_reu_tests
; ============================================================

; ============================================================
; Constants
; ============================================================

BUF_LEN     = 8                 ; bytes per transfer in each test

PAT_A       = $a5               ; 1010 0101 — primary test pattern
PAT_B       = $5a               ; 0101 1010 — complementary (bitwise inverse)

; REU address slots — each test uses a unique 24-bit address
; so no test can accidentally read back data from another test
REU_T02     = $000000           ; FROM_C64
REU_T03     = $000100           ; TO_C64
REU_T04     = $000200           ; SWAP
REU_T05     = $000300           ; FROM_C64_B stx
REU_T06     = $000400           ; FROM_C64_B sty
REU_T07     = $010100           ; FROM_C64_B sta (bank=$01, offset=$0100)
REU_T08     = $000600           ; TO_C64_B stx
REU_T09     = $000700           ; TO_C64_B sty
REU_T10     = $020200           ; TO_C64_B sta (bank=$02, offset=$0200)
REU_T11     = $000900           ; WAIT_EOB
REU_T12     = $000a00           ; VERIFY match
REU_T13     = $000b00           ; VERIFY fault


; ============================================================
; initiate_reu_tests — entry point
; ============================================================
initiate_reu_tests
    #KERNAL_CHROUT_MACRO PETSCII_CLEAR  ; PETSCII CLR/HOME — clear screen
    #BASIC_STROUT_MACRO msg_header      ; suite title
    #BASIC_STROUT_MACRO msg_separator
    
    jsr test_t01_quick_detect
    jsr test_t02_from_c64
    jsr test_t03_to_c64
    jsr test_t04_swap
    jsr test_t05_from_c64_b_stx
    jsr test_t06_from_c64_b_sty
    jsr test_t07_from_c64_b_sta
    jsr test_t08_to_c64_b_stx
    jsr test_t09_to_c64_b_sty
    jsr test_t10_to_c64_b_sta
    jsr test_t11_wait_eob
    jsr test_t12_verify_match
    jsr test_t13_verify_fault
    jsr test_t14_detect_size
    jsr test_t15_aliasing

    #BASIC_STROUT_MACRO msg_done
    #BASIC_STROUT_MACRO msg_anykey
    
wait_key
    jsr KERNAL_GETIN            ; non-blocking keyboard read
    beq wait_key                ; loop until a key is pressed
    
    rts

; ============================================================
; T01  REU_QUICK_DETECT
; ============================================================
; Reads the REU bank register ($df06). Non-zero = REU present,
; A holds hardware size code. Zero = no REU, macro branches.
;
; Pass : A != 0 (macro did not branch — REU present)
; Fail : A = 0  (no REU detected)
; ============================================================
test_t01_quick_detect
    #BASIC_STROUT_MACRO msg_t01

    #REU_QUICK_DETECT t01_fail
    #BASIC_STROUT_MACRO msg_pass
    rts

t01_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T02  REU_FROM_C64
; ============================================================
; Write BUF_LEN bytes from C64 RAM to REU, read them back,
; and verify the round-trip.
;
; Algorithm:
;   1. Fill BUF with PAT_A
;   2. REU_FROM_C64 REU_T02, BUF, BUF_LEN   <- macro under test
;   3. Zero BUF
;   4. REU_TO_C64 REU_T02, BUF, BUF_LEN     (read-back)
;   5. Verify BUF = PAT_A
; ============================================================
test_t02_from_c64
    #BASIC_STROUT_MACRO msg_t02

    ldx #BUF_LEN - 1
t02_fill
    lda #PAT_A
    sta BUF, x
    dex
    bpl t02_fill

    #REU_FROM_C64 REU_T02, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t02_zero
    lda #$00
    sta BUF, x
    dex
    bpl t02_zero

    #REU_TO_C64 REU_T02, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t02_cmp
    lda BUF, x
    cmp #PAT_A
    bne t02_fail
    dex
    bpl t02_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t02_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T03  REU_TO_C64
; ============================================================
; Seed REU with PAT_B, zero BUF, read back, verify.
;
; Pass : BUF = PAT_B after REU_TO_C64
; ============================================================
test_t03_to_c64
    #BASIC_STROUT_MACRO msg_t03

    ldx #BUF_LEN - 1
t03_seed
    lda #PAT_B
    sta BUF, x
    dex
    bpl t03_seed

    #REU_FROM_C64 REU_T03, BUF, BUF_LEN    ; seed REU

    ldx #BUF_LEN - 1
t03_zero
    lda #$00
    sta BUF, x
    dex
    bpl t03_zero

    #REU_TO_C64 REU_T03, BUF, BUF_LEN      ; macro under test

    ldx #BUF_LEN - 1
t03_cmp
    lda BUF, x
    cmp #PAT_B
    bne t03_fail
    dex
    bpl t03_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t03_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T04  REU_SWAP
; ============================================================
; The REU swap command ($92) exchanges both regions in a single
; DMA pass — no temporary buffer required. Unique to the REU.
;
; Algorithm:
;   1. Seed REU_T04 with PAT_A
;   2. Fill BUF with PAT_B
;   3. REU_SWAP REU_T04, BUF, BUF_LEN       <- macro under test
;      After: BUF = PAT_A (from REU), REU = PAT_B (from C64)
;   4. Verify BUF = PAT_A, then read REU back and verify = PAT_B
; ============================================================
test_t04_swap
    #BASIC_STROUT_MACRO msg_t04

    ldx #BUF_LEN - 1
t04_seed
    lda #PAT_A
    sta BUF, x
    dex
    bpl t04_seed

    #REU_FROM_C64 REU_T04, BUF, BUF_LEN    ; seed REU with PAT_A

    ldx #BUF_LEN - 1
t04_fill
    lda #PAT_B
    sta BUF, x
    dex
    bpl t04_fill

    #REU_SWAP REU_T04, BUF, BUF_LEN        ; macro under test

    ldx #BUF_LEN - 1
t04_cmp_c64
    lda BUF, x
    cmp #PAT_A
    bne t04_fail
    dex
    bpl t04_cmp_c64

    #REU_TO_C64 REU_T04, BUF, BUF_LEN
    ldx #BUF_LEN - 1
t04_cmp_reu
    lda BUF, x
    cmp #PAT_B
    bne t04_fail
    dex
    bpl t04_cmp_reu

    #BASIC_STROUT_MACRO msg_pass
    rts

t04_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T05  REU_FROM_C64_B  (bank in X)
; ============================================================
; The _B macros pass the store opcode as the rBank parameter
; (stx/sty/sta). The macro substitutes it directly — e.g.
; 'stx REU_REU_BANK' — avoiding a TXA+STA when the bank
; value is already in X or Y.
;
; Pass : BUF round-trips through REU bank $00, offset $0300
; ============================================================
test_t05_from_c64_b_stx
    #BASIC_STROUT_MACRO msg_t05

    ldx #BUF_LEN - 1
t05_fill
    lda #PAT_A
    sta BUF, x
    dex
    bpl t05_fill

    ldx #$00
    #REU_FROM_C64_B stx, $0300, BUF, BUF_LEN   ; macro under test

    ldx #BUF_LEN - 1
t05_zero
    lda #$00
    sta BUF, x
    dex
    bpl t05_zero

    #REU_TO_C64 REU_T05, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t05_cmp
    lda BUF, x
    cmp #PAT_A
    bne t05_fail
    dex
    bpl t05_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t05_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T06  REU_FROM_C64_B  (bank in Y)
; ============================================================
test_t06_from_c64_b_sty
    #BASIC_STROUT_MACRO msg_t06

    ldx #BUF_LEN - 1
t06_fill
    lda #PAT_B
    sta BUF, x
    dex
    bpl t06_fill

    ldy #$00
    #REU_FROM_C64_B sty, $0400, BUF, BUF_LEN   ; macro under test

    ldx #BUF_LEN - 1
t06_zero
    lda #$00
    sta BUF, x
    dex
    bpl t06_zero

    #REU_TO_C64 REU_T06, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t06_cmp
    lda BUF, x
    cmp #PAT_B
    bne t06_fail
    dex
    bpl t06_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t06_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T07  REU_FROM_C64_B  (sta variant)
; ============================================================
; When 'sta' is passed as rBank, A holds the HIGH BYTE of
; rOffset by the time 'sta REU_REU_BANK' executes — the macro
; has already overwritten A with the offset setup loads.
;
;   Constraint : effective bank = high byte of rOffset
;   This test  : offset $0100 -> >$0100 = $01 -> bank $01 ok
;   REU address: $010100
; ============================================================
test_t07_from_c64_b_sta
    #BASIC_STROUT_MACRO msg_t07

    ldx #BUF_LEN - 1
t07_fill
    lda #PAT_A
    sta BUF, x
    dex
    bpl t07_fill

    lda #$01                    ; illustrative — clobbered by macro
    #REU_FROM_C64_B sta, $0100, BUF, BUF_LEN   ; macro under test

    ldx #BUF_LEN - 1
t07_zero
    lda #$00
    sta BUF, x
    dex
    bpl t07_zero

    #REU_TO_C64 REU_T07, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t07_cmp
    lda BUF, x
    cmp #PAT_A
    bne t07_fail
    dex
    bpl t07_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t07_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T08  REU_TO_C64_B  (bank in X)
; ============================================================
; Mirror of T05 but reading from REU into C64.
; Seed uses the absolute-address REU_FROM_C64 so the seed
; step is independent of the macro under test.
;
; Pass : BUF = PAT_B after REU_TO_C64_B
; ============================================================
test_t08_to_c64_b_stx
    #BASIC_STROUT_MACRO msg_t08

    ldx #BUF_LEN - 1
t08_seed
    lda #PAT_B
    sta BUF, x
    dex
    bpl t08_seed

    #REU_FROM_C64 REU_T08, BUF, BUF_LEN    ; seed REU_T08 with PAT_B

    ldx #BUF_LEN - 1
t08_zero
    lda #$00
    sta BUF, x
    dex
    bpl t08_zero

    ldx #$00
    #REU_TO_C64_B stx, $0600, BUF, BUF_LEN ; macro under test

    ldx #BUF_LEN - 1
t08_cmp
    lda BUF, x
    cmp #PAT_B
    bne t08_fail
    dex
    bpl t08_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t08_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T09  REU_TO_C64_B  (bank in Y)
; ============================================================
test_t09_to_c64_b_sty
    #BASIC_STROUT_MACRO msg_t09

    ldx #BUF_LEN - 1
t09_seed
    lda #PAT_A
    sta BUF, x
    dex
    bpl t09_seed

    #REU_FROM_C64 REU_T09, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t09_zero
    lda #$00
    sta BUF, x
    dex
    bpl t09_zero

    ldy #$00
    #REU_TO_C64_B sty, $0700, BUF, BUF_LEN ; macro under test

    ldx #BUF_LEN - 1
t09_cmp
    lda BUF, x
    cmp #PAT_A
    bne t09_fail
    dex
    bpl t09_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t09_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T10  REU_TO_C64_B  (sta variant)
; ============================================================
; Same offset-bank constraint as T07.
;   offset $0200 -> >$0200 = $02 -> bank $02 ok
;   REU address = $020200
; ============================================================
test_t10_to_c64_b_sta
    #BASIC_STROUT_MACRO msg_t10

    ldx #BUF_LEN - 1
t10_seed
    lda #PAT_B
    sta BUF, x
    dex
    bpl t10_seed

    #REU_FROM_C64 REU_T10, BUF, BUF_LEN

    ldx #BUF_LEN - 1
t10_zero
    lda #$00
    sta BUF, x
    dex
    bpl t10_zero

    lda #$02                    ; illustrative — clobbered by macro
    #REU_TO_C64_B sta, $0200, BUF, BUF_LEN ; macro under test

    ldx #BUF_LEN - 1
t10_cmp
    lda BUF, x
    cmp #PAT_B
    bne t10_fail
    dex
    bpl t10_cmp

    #BASIC_STROUT_MACRO msg_pass
    rts

t10_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T11  REU_WAIT_EOB_MACRO
; ============================================================
; Transparent DMA halts the CPU via AEC until done. EOB
; (bit 6 of REU_STATUS) is set before 'sta REU_COMMAND'
; returns, so the macro exits on its first status poll.
; A hang here means a hardware fault.
;
; Note: reading REU_STATUS clears it — read-once.
;
; Pass : code reaches msg_pass (macro returned, did not hang)
; ============================================================
test_t11_wait_eob
    #BASIC_STROUT_MACRO msg_t11

    ldx #BUF_LEN - 1
t11_fill
    lda #PAT_A
    sta BUF, x
    dex
    bpl t11_fill

    #REU_FROM_C64 REU_T11, BUF, BUF_LEN    ; sets EOB flag

    #REU_WAIT_EOB_MACRO                     ; macro under test

    #BASIC_STROUT_MACRO msg_pass
    rts


; ============================================================
; T12  VERIFY — data matches  (FAULT bit must stay 0)
; ============================================================
; REU command $93 compares C64 RAM vs REU RAM byte-by-byte.
;   Match    : FAULT bit (bit 5 of REU_STATUS) stays 0
;   Mismatch : FAULT bit is set to 1
;
; IMPORTANT: reading REU_STATUS clears all bits in one read.
;
; Pass : FAULT bit = 0 (data matched)
; ============================================================
test_t12_verify_match
    #BASIC_STROUT_MACRO msg_t12

    ldx #BUF_LEN - 1
t12_seed
    lda #PAT_A
    sta BUF, x
    dex
    bpl t12_seed

    #REU_FROM_C64 REU_T12, BUF, BUF_LEN    ; seed REU with PAT_A
    ; BUF still = PAT_A — intentional match

    #REU_FROM_C64 REU_T12, BUF, BUF_LEN, $93 ; verify command

    lda REU_STATUS                          ; read-once — clears register
    and #REU_STATUS_FAULT                   ; isolate bit 5
    bne t12_fail

    #BASIC_STROUT_MACRO msg_pass
    rts

t12_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T13  VERIFY — data differs  (FAULT bit must be 1)
; ============================================================
; Seed with PAT_A, verify against PAT_B — deliberate mismatch.
; PASSES when FAULT = 1 (mismatch correctly detected).
; ============================================================
test_t13_verify_fault
    #BASIC_STROUT_MACRO msg_t13

    ldx #BUF_LEN - 1
t13_seed
    lda #PAT_A
    sta BUF, x
    dex
    bpl t13_seed

    #REU_FROM_C64 REU_T13, BUF, BUF_LEN    ; seed REU with PAT_A

    ldx #BUF_LEN - 1
t13_mismatch
    lda #PAT_B                              ; $5a != $a5 — deliberate
    sta BUF, x
    dex
    bpl t13_mismatch

    #REU_FROM_C64 REU_T13, BUF, BUF_LEN, $93 ; verify — must fault

    lda REU_STATUS
    and #REU_STATUS_FAULT
    beq t13_fail                            ; fault NOT set = bug

    #BASIC_STROUT_MACRO msg_pass
    rts

t13_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T14  REU_DETECT_SIZE_PROC — with decimal KB display
; ============================================================
; Calls the library procedure which returns the number of
; 64KB banks as a plain count (e.g. 2, 4, 8, 16...).
;
; Size in KB = bank_count * 64. BASIC_LINPRT prints a 16-bit
; decimal value from A (high byte) and X (low byte). We split
; bank_count * 64 across A:X using shifts:
;
;   low  byte = bank_count << 6  (multiply low part by 64)
;   high byte = bank_count >> 2  (carry the upper bits)
;
; Example: bank_count = 8 (512KB)
;   8 << 6 = 512 in 16-bit = $0200 -> A=$02, X=$00 -> prints 512
;
; sei/cli protect the internal ZP probe buffers from the
; KERNAL interrupt which fires every ~1/60s.
;
; Pass : A != 0 on return (REU found and sized)
; ============================================================
test_t14_detect_size
    #BASIC_STROUT_MACRO msg_t14

    sei
    jsr REU_DETECT_SIZE_PROC
    cli

    beq t14_fail                ; A = $00 means no REU

    pha
    #BASIC_STROUT_MACRO msg_pass
    #BASIC_STROUT_MACRO mask_kb_prefix
    pla
    
    ; --- print decimal KB size using BASIC_LINPRT ---
    ; A = bank count. compute bank_count * 64 as a 16-bit value:
    ;   low  byte = (bank_count << 6) — build in X via 6 x asl
    ;   high byte = (bank_count >> 2) — rebuild in A via 2 x lsr
    ; BASIC_LINPRT expects: A = high byte, X = low byte
    jsr BITWISE_MULTIPLY_64_PROC
    jsr BASIC_LINPRT            ; print as decimal e.g. "512"

    #BASIC_STROUT_MACRO msg_kb
    
    rts

t14_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; T15  REU_ALIASING_DETECT_PROC — with hex bank mask display
; ============================================================
; The aliasing probe writes $55 then $AA at successive power-
; of-2 boundaries. When bank 0 reads back $AA, the addresses
; alias — the boundary is the installed size.
;
; Returns A = bank mask:
;   $01 = 128KB (2 banks)
;   $03 = 256KB (4 banks)
;   $07 = 512KB (8 banks)
;   $0f = 1MB   (16 banks)
;   ...
;
; After the pass/fail result we print the raw bank mask as a
; two-digit hex value using print_hex_nibble (defined above).
;
; Pass : A != 0 on return (aliasing boundary detected)
; ============================================================
test_t15_aliasing
    #BASIC_STROUT_MACRO msg_t15

    sei
    jsr REU_ALIASING_DETECT_PROC
    cli

    beq t15_fail

    ; --- print hex bank mask, e.g. "mask: $07" ---
    ; save A across the string print, then extract nibbles
    pha
    #BASIC_STROUT_MACRO msg_pass
    #BASIC_STROUT_MACRO msg_mask_prefix ; "  mask: $"
    pla

    jsr OUTPUT_BYTETOHEX_PROC
    
    #BASIC_STROUT_MACRO msg_cr
    
    rts

t15_fail
    #BASIC_STROUT_MACRO msg_fail
    rts


; ============================================================
; Strings — PETSCII, null-terminated via .null
; ============================================================
; Lowercase here = uppercase on screen in C64 default charset.
; Test name strings end with two spaces so pass/fail result
; sits neatly separated on the same line.
; Result strings include a carriage return ($0d) to advance
; to the next row after each test.
msg_header      .null "c64 macro reu test suite", $0d
msg_separator   .null "========================", $0d
msg_anykey      .null "press any key..."
msg_done        .null 13,"all tests complete",13
msg_pass        .null PETSCII_GREEN, "pass", PETSCII_LIGHT_BLUE, PETSCII_RETURN
msg_fail        .null PETSCII_RED, "fail", PETSCII_LIGHT_BLUE, PETSCII_RETURN
mask_kb_prefix  .null "  size: "
msg_kb          .null "kb", 13             ; printed between size and pass
msg_mask_prefix .null "  mask: $"          ; printed before hex bank value
msg_cr          .null 13                   ; carriage return only

msg_t01     .null "t01 quick detect  "
msg_t02     .null "t02 from c64      "
msg_t03     .null "t03 to c64        "
msg_t04     .null "t04 swap          "
msg_t05     .null "t05 from c64 b stx"
msg_t06     .null "t06 from c64 b sty"
msg_t07     .null "t07 from c64 b sta"
msg_t08     .null "t08 to c64 b stx  "
msg_t09     .null "t09 to c64 b sty  "
msg_t10     .null "t10 to c64 b sta  "
msg_t11     .null "t11 wait eob      "
msg_t12     .null "t12 verify match  "
msg_t13     .null "t13 verify fault  "
msg_t14     .null "t14 detect size   "
msg_t15     .null "t15 aliasing      "

; ============================================================
; BUF — scratch buffer, declared LAST so 64TASS places it
; after all code and string data. Never use a fixed address.
; ============================================================
BUF         .fill 16, 0        ; 16-byte scratch buffer (only 8 used)
