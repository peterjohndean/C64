
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "../fp_test_macros.s"

.export TEST_ROUTINE_HEADER

.import TEST_WAIT

.scope TestData
    .import ptr_testmsg
.endscope

TEST_ROUTINE_HEADER = TEST_ROUTINE_HEADER_PROC

.segment "CODE"
.proc TEST_ROUTINE_HEADER_PROC

;    BASIC_STROUT_MACRO @tearline
    KERNAL_CHROUT_MACRO $0d
    jsr TEST_WAIT

    BASIC_STROUT_VECTOR_MACRO TestData::ptr_testmsg
    KERNAL_CHROUT_MACRO $0d
    jsr TEST_WAIT

    BASIC_STROUT_MACRO @tearline
    KERNAL_CHROUT_MACRO $0d
    jmp TEST_WAIT

.segment "RODATA"
@tearline:  .asciiz "---------------------------------------"
.endproc
