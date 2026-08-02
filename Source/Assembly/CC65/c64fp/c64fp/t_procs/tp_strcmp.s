
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "../fp_test_macros.s"

.export TEST_STRCMP

.import TEST_WAIT
.import OUTPUT_BYTETODEC

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
TEST_STRCMP = TEST_STRCMP_PROC
.proc TEST_STRCMP_PROC

    SHOW_CURRENT_TEST_MACRO

    ; ── begin interrupt-protected critical section ──────────
    ; php/sei/.../plp rather than sei/.../cli: this preserves
    ; whatever interrupt state existed on entry (nested-safe)
    ; instead of unconditionally forcing IRQs back on when we're
    ; done. Protects the whole patch-and-loop window, since the
    ; patched CMP operand is reused across every iteration of y -
    ; not just the first one.
    php
    sei

    ; ── SMC patch: point the loop's CMP at the expected string ──
    ; TestData::ptr_expected holds the ADDRESS of the string we
    ; want to compare against (set by TEST_STRCMP_MACRO_V2 just
    ; before this JSR). We can't use (ptr),y because that mode
    ; requires the pointer to live in zero page, and ptr_expected
    ; is ordinary BSS RAM. Instead of copying it into a zero-page
    ; scratch pointer, we write it straight into the operand bytes
    ; of the CMP instruction below - patching the CODE itself.
    ;
    ; @cmp_patch points at the CMP opcode byte ($D9 = CMP absolute,Y).
    ; The two bytes immediately following an opcode are its operand,
    ; so @cmp_patch+1 = low byte of the address, @cmp_patch+2 = high
    ; byte - exactly mirroring how #<label / #>label works when the
    ; address is known at ASSEMBLE time, except here we're supplying
    ; it at RUN time.
    lda TestData::ptr_expected      ; low  byte of expected-string address
    sta @cmp_patch+1                ; ...becomes the CMP instruction's
                                    ; low-byte operand
    lda TestData::ptr_expected+1    ; high byte of expected-string address
    sta @cmp_patch+2                ; ...becomes the CMP instruction's
                                    ; high-byte operand

    ldy #0
@strcmp_loop:
    lda TestData::out_buffer,y
    
@cmp_patch:
    cmp $ffff,y                 ; ← operand patched above; at runtime this
                                ; reads TRUE_ADDRESS_OF(str_test59)+y, i.e.
                                ; the actual character, not a pointer byte
    bne @test_fail

    lda TestData::out_buffer,y
    beq @test_pass              ; Both hit NULL terminator

    iny
    bne @strcmp_loop            ; Branch always (loops up to 255 chars)

@test_pass:
    plp                         ; restore interrupts BEFORE the
                                ; BASIC_STROUT calls below - no
                                ; need to hold IRQs off any longer
                                ; once @cmp_patch is done being read

    BASIC_STROUT_MACRO TestData::test_pass
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO ' '
    KERNAL_CHROUT_MACRO '='
    KERNAL_CHROUT_MACRO ' '
    jmp @done

@test_fail:
    plp                         ; release interrupts as soon as the protected section ends

    BASIC_STROUT_MACRO TestData::test_fail
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO ' '
    KERNAL_CHROUT_MACRO '!'
    KERNAL_CHROUT_MACRO '='
    KERNAL_CHROUT_MACRO ' '

@done:
    ; Print the actual output buffer
    BASIC_STROUT_MACRO TestData::out_buffer
    KERNAL_CHROUT_MACRO $0d
    
    jmp TEST_WAIT               ; Used jump, because the routine will return for us :)
.endproc
