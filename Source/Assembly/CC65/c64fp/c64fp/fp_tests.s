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
    .import test_pass, test_fail    ; [REGRESSION TEST] needed by the
                                    ; unexpected_trap IRQ check below -
                                    ; same pass/fail strings tp_fp1cmp.s
                                    ; and tp_strcmp.s already use, reused
                                    ; here rather than duplicating them
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
.import tr_ascii_sci    ; scientific-notation FP<->ASCII round trip -
                        ; see lib_fp_to_ascii_sci.s/lib_fp_from_ascii_sci.s
.import tr_basicfac
.import tr_trap_irq     ; [REGRESSION TEST] see test_vectors below -
                        ; MUST be the last entry in that table, not
                        ; just imported

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
        .word tr_ascii_sci
        ;
        ; -----------------------------------------------------------
        ; [REGRESSION TEST] tr_trap_irq - deliberately provokes a trap
        ; from inside a php/sei-protected critical section, using its
        ; OWN local FP_ERROR_INIT_MACRO guard (armed before the
        ; php/sei, matching the exact vulnerable shape), to verify
        ; lib_fp_error.s's FP_ERROR_PROC re-enables interrupts on
        ; unwind even when a pending plp was skipped over. Unlike an
        ; earlier version of this test, it returns normally via
        ; TEST_WAIT - it does NOT rely on or exercise fp_tests.s's own
        ; shared guard/unexpected_trap below, so there's no ordering
        ; constraint here; it can sit anywhere in this list. (The IRQ
        ; check in unexpected_trap below is kept anyway, as a general
        ; safety net for any trap that reaches IT specifically - the
        ; two checks are independent of each other.)
        .word tr_trap_irq

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
    ; -----------------------------------------------------------------
    ; [REGRESSION TEST] Confirm interrupts are enabled at this recovery
    ; point, before anything else runs.
    ;
    ; WHY THIS CHECK LIVES HERE, NOT IN A SEPARATE TEST PROC
    ; -----------------------------------------------------------------
    ; This label is FP_TESTS's own top-level FP_ERROR_INIT_MACRO
    ; recovery point (armed above, before @loop even starts) - EVERY
    ; trap in this whole suite that isn't caught by a more local guard
    ; funnels through here, including ones that fire while execution
    ; happens to be inside a php/sei-protected critical section
    ; elsewhere in the suite (see tp_fp1cmp.s/tp_strcmp.s for that
    ; pattern, used throughout the SMC-patched comparison tests).
    ;
    ; FP_ERROR_PROC's unwind (lib_fp_error.s) is a raw stack-pointer
    ; restore, not an ordinary RTS chain - by design, it discards
    ; EVERYTHING pushed above the depth FP_ERROR_INIT_MACRO recorded,
    ; not just return addresses. If that includes a php-pushed status
    ; byte from a critical section the trap happened to occur inside
    ; of, the matching plp is never reached, and whatever sei preceded
    ; it is never undone - interrupts stay disabled for the rest of
    ; the program's life (not scoped to this .proc or even this SYS
    ; call). FP_ERROR_PROC now forces interrupts back on unconditionally
    ; via CLI specifically to close this gap - see that file's own
    ; [BUG FIX] comment for the full mechanism and why an unconditional
    ; CLI there is safe, not just a workaround.
    ;
    ; Checking it HERE means this check applies to every trap this
    ; suite ever exercises, not just tr_trap_irq (the test written
    ; specifically to provoke this scenario - see test_vectors above).
    ; If FP_ERROR_PROC's CLI is ever accidentally removed or regresses,
    ; ANY trapped test - not just the dedicated one - reports this
    ; failure, which is exactly what a shared recovery point should
    ; provide: this checks the mechanism itself, not one code path
    ; that happens to exercise it today.
    ;
    ; HOW THE CHECK WORKS
    ; ----------------------
    ; PHP followed by PLA is the standard 6502 idiom for reading the
    ; processor status register into a general register - there's no
    ; direct "read flags into A" instruction, so this pushes status
    ; onto the stack and immediately pulls it back into A instead of
    ; discarding it. Bit 2 of that byte is the I (interrupt disable)
    ; flag; ANDing it off in isolation and testing for zero reports
    ; whether interrupts are enabled (bit clear) or disabled (bit
    ; set), independent of every other flag currently set.
    ; -----------------------------------------------------------------
    php
    pla
    and #%00000100           ; isolate the I (interrupt disable) flag
    beq @irq_ok              ; zero: I flag clear, interrupts enabled

    BASIC_STROUT_MACRO TestData::test_fail
    jmp @irq_checked
@irq_ok:
    BASIC_STROUT_MACRO TestData::test_pass
@irq_checked:
    BASIC_STROUT_MACRO msg_irq_check
    KERNAL_CHROUT_MACRO $0d

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
msg_irq_check:  .asciiz     " irq enabled after trap"
.endproc
