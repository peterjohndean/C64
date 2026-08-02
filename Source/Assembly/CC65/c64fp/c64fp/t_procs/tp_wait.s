.include "labels_memorymap.s"
.include "labels_screen.s"

.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"

.export TEST_WAIT

.import OUTPUT_BYTETODEC

.scope TestRegistry
    .import ntests
.endscope

.scope TestData
    .import test_title
.endscope


TEST_WAIT_LINE = 22             ; Wait at line 22
TEST_WAIT = TEST_WAIT_FOR_KEY

.proc TEST_WAIT_FOR_KEY
    ; Check row position
    lda MM_TBLX
    cmp #TEST_WAIT_LINE
    bcc @nowait                 ; <= TEST_WAIT_LINE

@wait_key:
    jsr KERNAL_GETIN            ; non-blocking keyboard read
    beq @wait_key

    ;
    ; Clear screen, output test title
    ;
    KERNAL_CHROUT_MACRO PETSCII_CLEAR
    BASIC_STROUT_MACRO TestData::test_title
    lda TestRegistry::ntests
    ldx #$00
    jsr OUTPUT_BYTETODEC
    KERNAL_CHROUT_MACRO $0d

@nowait:
    rts
.endproc
