
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "macros_fp.s"
.include "../fp_test_macros.s"

.export TEST_FAILED

.import TEST_WAIT
.import OUTPUT_BYTETODEC, OUTPUT_BYTETOHEX

.scope TestData
    .import test_fail, test_spacer_got1, test_spacer_got2
    .import id_group, id_test
    .import ptr_testmsg
    .import fac_snapshot
.endscope

.segment "CODE"
TEST_FAILED = TEST_FAILED_PROC
.proc TEST_FAILED_PROC

    SHOW_CURRENT_TEST_MACRO

    FP_STORE1_MACRO TestData::fac_snapshot

    BASIC_STROUT_MACRO TestData::test_fail
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO $0d
    jsr TEST_WAIT

    ; Output incorrect value
    BASIC_STROUT_MACRO TestData::test_spacer_got1
    .repeat 4, I
        ; During assembly, 'I' is replaced by 0, 1, 2, and 3 sequentially.
        lda TestData::fac_snapshot + I
        jsr OUTPUT_BYTETOHEX
    .endrep
    BASIC_STROUT_MACRO TestData::test_spacer_got2

    KERNAL_CHROUT_MACRO $0d

    jmp TEST_WAIT           ; Used jump, because the routine will return for us :)
.endproc
