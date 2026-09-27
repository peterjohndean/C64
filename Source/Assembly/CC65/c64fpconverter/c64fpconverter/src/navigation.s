.macpack longbranch

.include "labels_screen.s"
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "../inc/layout.h"
.include "../inc/values.h"
.include "../inc/row_meta.h"

.export nav_init, nav_poll
.export edit_row, edit_buf, edit_len

.import commit_value
.import apply_math_key
.import print_key

.segment "CODE"

; ============================================================
; FILE    : navigation.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Browse/highlight + friendlier editing: entering edit mode now
; HOLDS the current value (via RowMeta::load_edit_buffer) instead
; of blanking it; CRSR LEFT/RIGHT move a real cursor within it;
; typing OVERWRITES the character under the cursor (or appends at
; the end); DEL removes the character left of the cursor and
; shifts everything after it left (a real delete, not "always
; remove the last char"); HOME ($13) explicitly clears the field
; back to empty. Hex/binary rows keep their displayed grouping
; (spaces every 2/8 characters) live while editing - see
; redraw_edit_field's own header for how that's done in one pass
; rather than a separate position-formula.
; ============================================================

NAV_STATE_BROWSE = 0
NAV_STATE_EDIT   = 1

.segment "BSS"
selected_row:  .byte 0
reverse:       .byte 0
nav_state:     .byte 0
edit_row:      .byte 0
edit_len:      .byte 0
edit_max:      .byte 0
edit_cursor:   .byte 0
edit_buf:      .res 33,0
edit_marker_x: .byte 0
edit_marker_y: .byte 0
.segment "CODE"

; ============================================================
; PROCEDURE : draw_label
; ============================================================
.proc draw_label
    sta CurrentEntry::e_index
    jsr CurrentEntry::CalculateAddress

    ldy #layout_struct::xmsg
    lda (CurrentEntry::e_ptr),y
    sta @col
    ldy #layout_struct::ymsg
    lda (CurrentEntry::e_ptr),y
    sta @row
    ldy #layout_struct::msg
    lda (CurrentEntry::e_ptr),y
    sta CurrentEntry::e_msgptr
    ldy #layout_struct::msg+1
    lda (CurrentEntry::e_ptr),y
    sta CurrentEntry::e_msgptr+1

    ldy @col
    ldx @row
    clc
    jsr KERNAL_PLOT

    lda reverse
    beq @plain
    KERNAL_CHROUT_MACRO PETSCII_RVSON
@plain:
    BASIC_STROUT_VECTOR_MACRO CurrentEntry::e_msgptr

    lda reverse
    beq @done
    KERNAL_CHROUT_MACRO PETSCII_RVSOFF
@done:
    rts

.segment "BSS"
@col: .byte 0
@row: .byte 0
.segment "CODE"
.endproc

; ============================================================
; PROCEDURE : nav_init
; ============================================================
.proc nav_init
    lda #0
    sta selected_row
    sta nav_state
    lda #1
    sta reverse
    lda selected_row
    jsr draw_label
    rts
.endproc

; ============================================================
; PROCEDURE : redraw_edit_field
; Purpose : Blank the field, then print edit_buf[0..edit_len-1]
;           with row-appropriate grouping spaces, positioning the
;           terminal cursor at edit_cursor's screen column - same
;           as before, PLUS: the character actually under
;           edit_cursor is drawn in REVERSE VIDEO (or, if the
;           cursor sits past the last typed character - appending
;           at the end - a reverse-video BLANK stands in, since
;           there's no real character there yet to highlight).
;           This is a persistent visual marker independent of the
;           terminal's own blinking cursor, which is easy to miss
;           against a screen full of digits.
; Entry   : none (reads edit_row/edit_buf/edit_len/edit_cursor)
; Destroys: A, X, Y
; ============================================================
.proc redraw_edit_field
    ldy LayoutValues::value_xval
    ldx LayoutValues::value_yval
    clc
    jsr KERNAL_PLOT
    ldx edit_row
    lda RowMeta::display_width_table,x
    tax
@blank_loop:
    lda #' '
    jsr KERNAL_CHROUT
    dex
    bne @blank_loop

    ldy LayoutValues::value_xval
    ldx LayoutValues::value_yval
    clc
    jsr KERNAL_PLOT

    ldx edit_row
    lda RowMeta::group_mask_table,x
    sta @group_mask

    lda LayoutValues::value_xval
    sta @running_col
    lda #0
    sta @cursor_col_set
    sta @i

@print_loop:
    lda @i
    cmp edit_len
    bcs @after_loop

    lda @i
    cmp edit_cursor
    bne @not_cursor_pos

    ; --- cursor is HERE: remember the column, and print this one
    ;     character in reverse video instead of plain ---
    lda @running_col
    sta @cursor_col
    lda #1
    sta @cursor_col_set
    ldy @i
    lda edit_buf,y
    sta @char_to_print
    KERNAL_CHROUT_MACRO PETSCII_RVSON
    lda @char_to_print
    jsr KERNAL_CHROUT
    KERNAL_CHROUT_MACRO PETSCII_RVSOFF
    jmp @char_done

@not_cursor_pos:
    ldy @i
    lda edit_buf,y
    jsr KERNAL_CHROUT

@char_done:
    inc @running_col
    inc @i

    lda @group_mask
    beq @print_loop
    lda @i
    and @group_mask
    bne @print_loop
    lda @i
    cmp edit_len
    beq @print_loop
    lda #' '
    jsr KERNAL_CHROUT
    inc @running_col
    jmp @print_loop

@after_loop:
    lda @cursor_col_set
    bne @have_cursor_col

    lda @running_col
    sta @cursor_col

    ; [BUG FIX] only draw the reverse-video "empty slot" marker if
    ; the field actually HAS an empty slot left. When the field is
    ; completely full (edit_len == edit_max), @running_col already
    ; sits ONE COLUMN PAST the field's own display_width - drawing
    ; a reverse block there leaks onto whatever's immediately after
    ; the field, and no later redraw ever clears it, since every
    ; redraw only ever blanks the field's OWN declared width, never
    ; one column beyond it (see project conversation for the trace
    ; that found this).
    ldx edit_row
    lda RowMeta::display_width_table,x
    clc
    adc LayoutValues::value_xval
    sta @field_boundary          ; first column OUTSIDE the field
    lda @running_col
    cmp @field_boundary
    bcs @have_cursor_col         ; running_col >= boundary: no room,
                                 ; skip drawing - just record the
                                 ; (off-field) column for PLOT below

    KERNAL_CHROUT_MACRO PETSCII_RVSON
    lda #' '
    jsr KERNAL_CHROUT
    KERNAL_CHROUT_MACRO PETSCII_RVSOFF
@have_cursor_col:

    ldy @cursor_col
    ldx LayoutValues::value_yval
    clc
    jsr KERNAL_PLOT
    rts

.segment "BSS"
@group_mask:     .byte 0
@running_col:    .byte 0
@cursor_col:     .byte 0
@cursor_col_set: .byte 0
@i:              .byte 0
@char_to_print:  .byte 0
@field_boundary: .byte 0
.segment "CODE"
.endproc

; ============================================================
; PROCEDURE : nav_poll
; ============================================================
.proc nav_poll
    jsr KERNAL_GETIN
    jeq @return_as_is

    ldx nav_state
    cpx #NAV_STATE_EDIT
    jeq @edit_mode

; ---------------- BROWSE STATE ----------------
@browse_mode:
    cmp #PETSCII_CURSOR_DOWN
    jeq @move_down
    cmp #PETSCII_CURSOR_UP
    jeq @move_up
    cmp #PETSCII_RETURN
    jeq @enter_edit
    jsr apply_math_key
    jcs @return_zero
    jsr print_key
    jcs @return_zero
    jmp @return_as_is

@move_down:
    lda selected_row
    sta @old_row
    clc
    adc #1
    cmp LayoutEntries::l_entries
    jcc @store_down
    lda #0
@store_down:
    sta selected_row
    jsr @redraw_selection
    jmp @return_zero

@move_up:
    lda selected_row
    sta @old_row
    jne @dec_ok
    lda LayoutEntries::l_entries
    sec
    sbc #1
    jmp @store_up
@dec_ok:
    sec
    sbc #1
@store_up:
    sta selected_row
    jsr @redraw_selection
    jmp @return_zero

@enter_edit:
    lda selected_row
    sta edit_row
    lda #0
    sta edit_len
    sta edit_cursor
    jsr @clear_edit_buf ; [BUG FIX] clear the WHOLE buffer, not just position 0 - see project conversation:
                        ; this is what let stale digits from a PREVIOUS, longer entry survive between edits

    ldx selected_row
    lda RowMeta::edit_max_table,x
    sta edit_max

    lda selected_row
    sta CurrentEntry::e_index
    jsr CurrentEntry::CalculateAddress
    jsr LayoutValues::CalculatePosition

    lda LayoutValues::value_xval
    sec
    sbc #1
    sta edit_marker_x
    lda LayoutValues::value_yval
    sta edit_marker_y
    ldy edit_marker_x
    ldx edit_marker_y
    clc
    jsr KERNAL_PLOT
    lda #'>'
    jsr KERNAL_CHROUT

    jsr redraw_edit_field

    lda #NAV_STATE_EDIT
    sta nav_state
    jmp @return_zero

; ---------------- EDIT STATE ----------------
@edit_mode:
    cmp #PETSCII_RETURN
    jeq @commit_edit
    cmp #PETSCII_INSTDEL
    jeq @edit_backspace
    cmp #PETSCII_HOME
    jeq @edit_clear
    cmp #PETSCII_CURSOR_LEFT
    jeq @edit_cursor_left
    cmp #PETSCII_CURSOR_RIGHT
    jeq @edit_cursor_right

    ; typing: overwrite at cursor, or append if cursor is at the end
    sta @typed_char

    ; [FIX] ignore a literal space keypress on a GROUPED (hex/binary)
    ; row - the displayed spacing is entirely automatic; typing one
    ; yourself would otherwise insert a real space into edit_buf,
    ; which no parser accepts as a valid hex/bit digit.
    cmp #' '
    bne @not_space
    ldx edit_row
    lda RowMeta::group_mask_table,x
    beq @not_space
    jmp @return_zero
@not_space:

    lda edit_cursor
    cmp edit_len
    jcc @overwrite

    ldx edit_len
    cpx edit_max
    jcs @return_zero                ; field full: ignore
    ldy edit_len
    lda @typed_char
    sta edit_buf,y
    inc edit_len
    ldy edit_len
    lda #0
    sta edit_buf,y  ; [BUG FIX] moved here from @overwrite below -
                    ; This is the branch that actually runs when typing into an empty/cleared field (cursor
                    ; always starts equal to edit_len), so this is where re-termination was actually needed -
                    ; see project conversation for the full trace
    inc edit_cursor
    jmp @redraw_after_edit

@overwrite:
    ldy edit_cursor
    lda @typed_char
    sta edit_buf,y
    inc edit_cursor
    jmp @redraw_after_edit

@edit_clear:
    lda #0
    sta edit_len
    sta edit_cursor
    jsr @clear_edit_buf     ; [BUG FIX] same reasoning as @enter_edit
    jmp @redraw_after_edit

@edit_cursor_left:
    lda edit_cursor
    jeq @return_zero
    dec edit_cursor
    jmp @redraw_after_edit

@edit_cursor_right:
    lda edit_cursor
    cmp edit_len
    jcs @return_zero
    inc edit_cursor
    jmp @redraw_after_edit

@edit_backspace:
    lda edit_cursor
    jeq @return_zero                ; nothing to the left
    dec edit_cursor                 ; index of the char being removed
    lda edit_len
    sec
    sbc #1
    sta @limit                      ; last valid destination index
    ldy edit_cursor
@bs_shift_loop:
    cpy @limit
    jcs @bs_shift_done
    iny
    lda edit_buf,y
    dey
    sta edit_buf,y
    iny
    jmp @bs_shift_loop
@bs_shift_done:
    dec edit_len
    ldy edit_len
    lda #0
    sta edit_buf,y      ; [BUG FIX] same reasoning as the append case above - deleting
                        ; shrinks the logical string but never moved the terminator to
                        ; match without this
    jmp @redraw_after_edit

@redraw_after_edit:
    jsr redraw_edit_field
    jmp @return_zero

@commit_edit:
    lda #NAV_STATE_BROWSE
    sta nav_state
    lda #0
    sta edit_cursor

    ldy edit_marker_x
    ldx edit_marker_y
    clc
    jsr KERNAL_PLOT
    lda #' '
    jsr KERNAL_CHROUT

    jsr commit_value
    jmp @return_zero

@clear_edit_buf:
    ldx #0
    lda #0
@ceb_loop:
    sta edit_buf,x
    inx
    cpx #33
    bne @ceb_loop
    rts
    
; ---------------- shared return paths ----------------
@return_zero:
    lda #0
@return_as_is:
    rts

@redraw_selection:
    lda #0
    sta reverse
    lda @old_row
    jsr draw_label
    lda #1
    sta reverse
    lda selected_row
    jsr draw_label
    rts

.segment "BSS"
@old_row:    .byte 0
@typed_char: .byte 0
@limit:      .byte 0
.segment "CODE"
.endproc
