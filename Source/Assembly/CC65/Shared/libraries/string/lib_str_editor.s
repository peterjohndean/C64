.include "labels_rom_kernal.s"
.include "labels_screen.s"

.macpack longbranch
.export STRING_EDITOR_PROC

.scope StringEditState
    .exportzp zp_str_ptr
    .export edit_cursor
    .export plotx, ploty, str_len_max

    .segment "ZEROPAGE"
    zp_str_ptr:     .res 2  ; zp vector to ram string

    .segment "BSS"
    plotx:          .res 1  ; kernal PLOT x
    ploty:          .res 1  ; kernal PLOT y
    edit_cursor:    .res 1  ; solid cursor on/off
    str_len_max:    .res 1  ; maximum c-string length
.endscope

; ---------------------------------------------------------------------------
; PROCEDURE: STRING_EDITOR_PROC
; Purpose: Edits a null-terminated string using a stateless redraw loop.
;          The visible edit cursor is drawn with reverse video, so exit paths
;          repaint the field once without the cursor before returning.
; Returns: Carry Flag CLEAR if accepted (Enter), SET if rejected (Back).
; ---------------------------------------------------------------------------
.segment "CODE"
.proc STRING_EDITOR_PROC
    ; 1. Initialization: Measure current string length
    ldy #$00
@len_loop:
    lda (StringEditState::zp_str_ptr),y
    beq @len_done
    iny
    cpy StringEditState::str_len_max
    bcc @len_loop
@len_done:
    sty current_len
    lda #$00            ; Cursor starting position
    sta cursor_pos

redraw_field:
    lda #$01
    sta draw_cursor
    jsr draw_field
    jmp get_key

    ; -----------------------------------------------------------------------
    ; DRAW FIELD
    ; Clears and redraws the entire string. The cursor is only highlighted
    ; when both the caller's edit_cursor flag and local draw_cursor are nonzero.
    ; Exit paths set draw_cursor to zero for one final plain redraw, which
    ; removes the reverse-video cursor cell before control returns to caller.
    ; -----------------------------------------------------------------------
draw_field:
    ; Position the hardware cursor at the start of the field
    clc
    ldy StringEditState::plotx  ; KERNAL PLOT: Column in Y
    ldx StringEditState::ploty  ; KERNAL PLOT: Row in X
    jsr KERNAL_PLOT

    ldy #$00
@draw_loop:
    cpy StringEditState::str_len_max
    bcs @draw_done              ; Stop drawing when we hit the max width

    ; Check if we should draw the reverse-video cursor here
    lda draw_cursor
    beq @no_highlight
    lda StringEditState::edit_cursor
    beq @no_highlight
    cpy cursor_pos
    bne @no_highlight
    lda #PETSCII_RVSON          ; Turn Reverse Video ON
    jsr KERNAL_CHROUT

@no_highlight:
    ; Fetch character from RAM, or use SPACE if past string length
    cpy current_len
    bcs @print_space
    lda (StringEditState::zp_str_ptr),y
    bne @print_char             ; Safety check against nulls
@print_space:
    lda #PETSCII_SPACE
@print_char:
    jsr KERNAL_CHROUT
    
    lda #PETSCII_RVSOFF         ; Always safely turn Reverse Video OFF
    jsr KERNAL_CHROUT
    
    iny
    jmp @draw_loop

@draw_done:
    rts

    ; -----------------------------------------------------------------------
    ; INPUT LOOP
    ; -----------------------------------------------------------------------
get_key:
    jsr KERNAL_GETIN
    beq get_key                 ; Wait continuously for a key

    cmp #PETSCII_RETURN
    jeq done_accept

    cmp #PETSCII_BACK
    jeq done_reject

    cmp #PETSCII_CURSOR_LEFT
    jeq do_left

    cmp #PETSCII_CURSOR_RIGHT
    jeq do_right

    cmp #PETSCII_INSTDEL
    jeq do_delete

    ; Standard Printable Characters
    cmp #PETSCII_SPACE
    bcc get_key                 ; Ignore control characters below $20

    ; Overwrite vs Append Logic
    pha                         ; Safely stash the typed character
    ldy cursor_pos
    cpy current_len
    bcc @overwrite              ; If cursor < length, we overwrite

@append:
    cpy StringEditState::str_len_max
    bcs @ignore_key             ; Block typing if at max capacity
    
    pla                         ; Restore character
    sta (StringEditState::zp_str_ptr),y
    inc current_len
    
    ldy current_len
    lda #$00                    ; Safely advance the null terminator
    sta (StringEditState::zp_str_ptr),y
    
    inc cursor_pos
    jmp redraw_field

@overwrite:
    pla                         ; Restore character
    sta (StringEditState::zp_str_ptr),y
    inc cursor_pos
    jmp redraw_field

@ignore_key:
    pla                         ; Clean up stack
    jmp get_key

    ; -----------------------------------------------------------------------
    ; NAVIGATION & EDITING LOGIC
    ; -----------------------------------------------------------------------
do_left:
    lda cursor_pos
    beq get_key                 ; Cannot move left from 0
    dec cursor_pos
    jmp redraw_field

do_right:
    lda cursor_pos
    cmp current_len
    bcs get_key                 ; Cannot move right past current length
    inc cursor_pos
    jmp redraw_field

do_delete:
    lda cursor_pos
    beq get_key                 ; Cannot backspace at position 0
    dec cursor_pos
    
    ; Shift all characters to the right of the cursor leftward
    ldy cursor_pos
@shift_loop:
    cpy current_len
    bcs @shift_done
    iny
    lda (StringEditState::zp_str_ptr),y
    dey
    sta (StringEditState::zp_str_ptr),y
    iny
    jmp @shift_loop

@shift_done:
    dec current_len
    ldy current_len
    lda #$00                    ; Safely terminate the newly shortened string
    sta (StringEditState::zp_str_ptr),y
    jmp redraw_field

    ; -----------------------------------------------------------------------
    ; EXIT STATES
    ; -----------------------------------------------------------------------
done_accept:
    lda #$00
    sta draw_cursor
    jsr draw_field
    clc                     
    rts

done_reject:
    lda #$00
    sta draw_cursor
    jsr draw_field
    sec
    rts

    ; -----------------------------------------------------------------------
    ; LOCAL VARIABLES
    ; -----------------------------------------------------------------------
current_len: .byte 0
cursor_pos:  .byte 0
draw_cursor: .byte 0
.endproc
