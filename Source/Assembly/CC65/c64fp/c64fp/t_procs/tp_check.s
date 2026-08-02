
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "macros_fp.s"
.include "../fp_test_macros.s"

.export TEST_CHECK

.import FP_TO_ASCII24
.import TEST_WAIT
.import OUTPUT_BYTETODEC, OUTPUT_BYTETOHEX

.scope TestRegistry
    .import ntests
.endscope

.scope TestData
    .import test_check, test_title
    .import id_group, id_test
    .import test_spacer
    .import fractional_digits
    .import ptr_testmsg
    .import out_buffer
    .import fac_snapshot
.endscope

.segment "CODE"
TEST_CHECK = TEST_CHECK_PROC
.proc TEST_CHECK_PROC
    SHOW_CURRENT_TEST_MACRO

    ; Before BASIC_STROUT clobbers FAC1/FAC2
    FP_STORE1_MACRO TestData::fac_snapshot

    BASIC_STROUT_MACRO TestData::test_check
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO $0d
    jsr TEST_WAIT

    ; On a newline
    ; -> xxxxxxxx, 12345678.123
    BASIC_STROUT_MACRO TestData::test_spacer

    ; Show FP1 as hex
    .repeat 4, I
        ; During assembly, 'I' is replaced by 0, 1, 2, and 3 sequentially.
        lda TestData::fac_snapshot + I
        jsr OUTPUT_BYTETOHEX
    .endrep

    ; Show FP1 as string
    ; --------------------------------------------------------
    ; [BUG FIX] This used to call FP_TO_ASCII (16-bit integer-part
    ; ceiling, 65,535) with no error guard at all. A result like
    ; tan(90 deg) ~= 1,048,580 (see the tr_tan.s T04 asymptote test
    ; this was found through) sails straight past that ceiling and
    ; hits FP_TO_ASCII's own documented "uncaught, out of scope"
    ; trap during THIS conversion - not during whatever test
    ; actually computed the value. Two changes:
    ;
    ;   1. FP_TO_ASCII -> FP_TO_ASCII24 raises the integer-part
    ;      ceiling to 8,388,607 (see lib_fp_to_ascii24.s), which
    ;      comfortably covers this case and any similarly large
    ;      but not astronomical result.
    ;
    ;   2. A guard is armed around the conversion itself, because
    ;      TEST_CHECK is a SHARED utility called by every test in
    ;      the suite - it can't assume every future test's result
    ;      stays under even the wider 8,388,607 ceiling (an
    ;      FP_EXP_PROC result, for instance, could still exceed
    ;      it). Without this, any test whose result is too big to
    ;      render would corrupt the stack here, exactly like the
    ;      very first bug this whole suite uncovered - except
    ;      buried inside the shared display routine instead of an
    ;      individual test, so it would have kept happening for
    ;      every test after it that hit this same condition.
    ; --------------------------------------------------------
    FP_LOAD1_MACRO TestData::fac_snapshot

    FP_ERROR_INIT_MACRO ascii_overflow_recover
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx TestData::fractional_digits
    jsr FP_TO_ASCII24
    FP_ERROR_CLEAR_MACRO
    jmp ascii_done
ascii_overflow_recover:
    ; only reached if the value was too large even for
    ; FP_TO_ASCII24's wider ceiling - print a placeholder instead
    ; of an undefined out_buffer (the conversion trapped partway
    ; through, so out_buffer was never actually written - printing
    ; it here would show stale/garbage bytes from whatever the
    ; previous test happened to leave behind)
    KERNAL_CHROUT_MACRO ','
    KERNAL_CHROUT_MACRO ' '
    BASIC_STROUT_MACRO ascii_overflow_msg
    jmp print_done          ; skip the normal out_buffer print below -
                            ; there is nothing valid in it this time
ascii_done:

    KERNAL_CHROUT_MACRO ','
    KERNAL_CHROUT_MACRO ' '
    BASIC_STROUT_MACRO TestData::out_buffer

print_done:
    KERNAL_CHROUT_MACRO $0d

    jmp TEST_WAIT           ; Used jump, because the routine will return for us :)

.segment "RODATA"
ascii_overflow_msg: .asciiz "<value too large to display>"
.endproc
