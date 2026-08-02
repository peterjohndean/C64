
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "../fp_test_macros.s"

.export TEST_PASSED

.import TEST_WAIT
.import OUTPUT_BYTETODEC

.scope TestData
    .import test_pass
    .import id_group, id_test
    .import ptr_testmsg
.endscope

.segment "CODE"
TEST_PASSED = TEST_PASSED_PROC
.proc TEST_PASSED_PROC

    SHOW_CURRENT_TEST_MACRO

    BASIC_STROUT_MACRO TestData::test_pass
    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO $0d

    jmp TEST_WAIT
.endproc
