;
; Requirement: Self-Modifying Code (SMC) architecture.
; Dynamically updating the operand bytes of a dummy jsr instruction right before
; it test vector executes, this suite strictly requires execution from RAM.
;
.include "labels_memorymap.s"
.include "labels_screen.s"
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "macros_fp.s"

.include "fp_test_macros.s"

.export FP_TESTS

.scope TestData
    .import id_group
    .import test_title
.endscope

;
; Test routines
;
.import tr_fadd, tr_fsub, tr_fmul, tr_fdiv, tr_fmod, tr_log, tr_exp
.import tr_fp_precision
.import tr_swap, tr_clearfac
.import tr_trunc, tr_floor, tr_ceil
.import tr_compare
.import tr_int8, tr_int16, tr_int24
.import tr_uint8, tr_uint16, tr_uint24
.import tr_ieee754
.import tr_sin, tr_sin_full, tr_cos, tr_tan, tr_deg_rad
.import tr_ascii16, tr_ascii24
.import tr_basicfac

.import OUTPUT_BYTETOHEX
.import OUTPUT_BYTETODEC
.import FP_CLEANUP_FAC1FAC2
.import TEST_WAIT

;.macpack longbranch

.scope TestRegistry
    .export ntests
    .segment "RODATA"
    test_vectors:
        ;
        ; Mathematics
        ;
        .word tr_fadd, tr_fsub
        .word tr_fmul, tr_fp_precision
        .word tr_fdiv, tr_fmod
        .word tr_log
        .word tr_exp
        ;
        ; Trigonometry
        ;
        .word tr_sin, tr_sin_full
        .word tr_cos
        .word tr_tan
        .word tr_deg_rad
        ;
        ; Rounding
        ;
        .word tr_trunc, tr_floor, tr_ceil
        ;
        .word tr_compare
        ;
        .word tr_swap
        .word tr_clearfac
        ;
        ; Conversions
        ;
        .word tr_int8, tr_int16, tr_int24
        .word tr_uint8, tr_uint16, tr_uint24
        .word tr_ieee754
        .word tr_basicfac
        .word tr_ascii16, tr_ascii24

    ; Dynamically calculate the number of tests:
    ; (Current Memory Address - Start of Array) / 2 bytes per pointer
    ntests: .byte (* - test_vectors) / 2
;    ntests: .byte 1
.endscope

.segment "CODE"
.proc FP_TESTS
    ;
    KERNAL_CHROUT_MACRO PETSCII_CLEAR ; screen clear/home
    BASIC_STROUT_MACRO TestData::test_title
    lda TestRegistry::ntests
    ldx #$00
    jsr OUTPUT_BYTETODEC
    KERNAL_CHROUT_MACRO $0d

    ; Setup FP Error Trap
    FP_ERROR_INIT_MACRO unexpected_trap

    lda #0
    sta TestData::id_group  ; Start at test index 0

@loop:
    lda TestData::id_group
    asl
    tax                     ; Multiply by 2 for the 16-bit array offset

    ; --- 1. Patch the Dummy JSR ---
    ; Read from the scoped array using the :: operator
    lda TestRegistry::test_vectors,x
    sta @smc_test+1
    lda TestRegistry::test_vectors+1,x
    sta @smc_test+2

    ; --- 2. Execute ---
@smc_test:
    jsr $FFFF               ; Dummy address, dynamically overwritten above

    ; --- 3. Evaluate Loop ---
    inc TestData::id_group
    lda TestData::id_group
    cmp TestRegistry::ntests  ; Check against our scoped constant
    bne @loop

    ; Cleanup (no trap)
    FP_ERROR_CLEAR_MACRO
    jsr FP_CLEANUP_FAC1FAC2
    rts

unexpected_trap:
    BASIC_STROUT_MACRO msg_unexpected
    lda #98
    jsr OUTPUT_BYTETOHEX

    lda FP_ERROR_CODE
    jsr OUTPUT_BYTETOHEX
    KERNAL_CHROUT_MACRO $0d

    ; Cleanup (with trap)
    jsr FP_CLEANUP_FAC1FAC2
    rts
    
.segment "RODATA"
msg_unexpected: .asciiz     "unexpected error: "
.endproc
