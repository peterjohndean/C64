.include "lib_str_editor.h"
.include "macros_rom_basic.s"
.include "macros_rom_kernal.s"
.include "labels_screen.s"

.import STRING_EDITOR_PROC
.export test_editor

.segment "CODE"
.proc test_editor
    ; 1. Setup the Zero Page String Pointer
    lda #<@str_msg
    sta StringEditState::zp_str_ptr
    lda #>@str_msg
    sta StringEditState::zp_str_ptr+1

    ; 2. Setup PLOT x/y
    lda #5
    sta StringEditState::plotx
    sta StringEditState::ploty

    ; Clear the screen to give us a clean workspace
    KERNAL_CHROUT_MACRO PETSCII_CLEAR

    ; 3. Setup Cursor
    lda #1
    sta StringEditState::edit_cursor

    ; 4. Setup String Max Length
    ; Give the editor exactly 24 characters of capacity
    lda #24
    sta StringEditState::str_len_max

    ;
    ; Print the final edited string on a new line to prove it saved
    KERNAL_PLOT_SET_MACRO 20, 5
    BASIC_STROUT_VECTOR_MACRO StringEditState::zp_str_ptr

    ; Run the Editor
    jsr STRING_EDITOR_PROC

    ; Print the final edited string on a new line to prove it saved
    KERNAL_PLOT_SET_MACRO 5, 7
    BASIC_STROUT_VECTOR_MACRO StringEditState::zp_str_ptr

    rts

@str_msg:   
    .byte "this is a test", 0  ; The initial string
    .res 10, 0                 ; PLUS 10 blank bytes of buffer space!
.endproc

