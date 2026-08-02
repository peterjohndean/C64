
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "macros_fp.s"
.include "../fp_test_macros.s"

.export TEST_FP1CMP

.import TEST_WAIT
.import OUTPUT_BYTETODEC, OUTPUT_BYTETOHEX

.scope TestRegistry
    .import ntests
.endscope

.scope TestData
    .import test_pass, test_fail, test_check, test_title
    .import id_group, id_test
    .import ptr_expected, ptr_testmsg
    .import out_buffer
    .import fac_snapshot
.endscope

.segment "CODE"
TEST_FP1CMP = TEST_FP1CMP_PROC
.proc TEST_FP1CMP_PROC
    SHOW_CURRENT_TEST_MACRO

    FP_STORE1_MACRO TestData::fac_snapshot

    ; ── begin interrupt-protected critical section ──────────
    ; php/sei/.../plp rather than sei/.../cli: this preserves
    ; whatever interrupt state existed on entry (nested-safe)
    ; instead of unconditionally forcing IRQs back on when we're
    ; done. Protects the whole patch-and-loop window, since the
    ; patched CMP operand is reused across every iteration of y -
    ; not just the first one.
    php
    sei

    ; ── SMC patch: point the loop's CMP at the expected FP1 ──
    ; @cmp_patch points at the CMP opcode byte ($D9 = CMP absolute,Y).
    ; The two bytes immediately following an opcode are its operand,
    ; so @cmp_patch+1 = lsb of the address, @cmp_patch+2 = msb
    ; - exactly mirroring how #<label / #>label works when the
    ; address is known at ASSEMBLE time, except here we're supplying
    ; it at RUN time.
    lda TestData::ptr_expected      ; lsb of expected-FP1 address
    sta @cmp_patch+1
    lda TestData::ptr_expected+1    ; msb of expected-FP1 address
    sta @cmp_patch+2

    ldy #0
@bytecmp_loop:
    lda FP1_EXP,y

@cmp_patch:
    cmp $ffff,y             ; ← operand patched above; at runtime this
                            ; reads TRUE_ADDRESS_OF(FP1_EXP)+y, i.e.
                            ; the actual byte, not a pointer byte
    bne @test_fail

    cpy #3
    beq @test_pass          ; Both hit 4-byte terminator

    iny
    bne @bytecmp_loop       ; Branch always (loops up to 255 chars)

@test_pass:
    plp                     ; release interrupts as soon as the protected section ends

    BASIC_STROUT_MACRO TestData::test_pass
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO ' '
    KERNAL_CHROUT_MACRO '='
    KERNAL_CHROUT_MACRO ' '
    jmp @done

@test_fail:
    plp                     ; release interrupts as soon as the protected section ends

    BASIC_STROUT_MACRO TestData::test_fail
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO ' '
    KERNAL_CHROUT_MACRO '!'
    KERNAL_CHROUT_MACRO '='
    KERNAL_CHROUT_MACRO ' '

@done:

    .repeat 4, I
        ; During assembly, 'I' is replaced by 0, 1, 2, and 3 sequentially.
        lda TestData::fac_snapshot + I
        jsr OUTPUT_BYTETOHEX
    .endrep

    KERNAL_CHROUT_MACRO $0d

    jmp TEST_WAIT           ; Used jump, because the routine will return for us :)
.endproc
