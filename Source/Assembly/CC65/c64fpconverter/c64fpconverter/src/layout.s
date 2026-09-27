.include "labels_screen.s"
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"

.include "../inc/layout.h"

.export draw_layouts

.segment "CODE"

; ============================================================
; PROCEDURE : draw_layouts
; Purpose : Walk LayoutEntries::l_table and, for every record,
;           move the cursor to (xmsg,ymsg) and print its message
;           string via BASIC_STROUT.
;
; WHY FIELDS ARE READ INTO LOCALS BEFORE KERNAL_PLOT IS CALLED
; -----------------------------------------------------------------
; Each (CurrentEntry::e_ptr),y read below needs Y to hold the
; STRUCT FIELD OFFSET (layout_struct::xmsg, ::ymsg, ...). But
; KERNAL_PLOT_SET_MACRO's underlying convention (see
; macros_rom_kernal.s) needs Y to hold the CURSOR COLUMN and X to
; hold the CURSOR ROW - two completely different meanings for the
; same register, needed one right after the other. Going straight
; from "read xmsg via Y" to "Y is now the column" doesn't work: the
; very next field read (ymsg) would have to reuse Y for its OWN
; offset first, clobbering the column value before it's ever used.
; The fix is the same rule this project's own FP_TO_ASCII_PROC
; already follows for its out_pos byte (see lib_fp_to_ascii.s): don't
; leave a value you still need sitting in a register across a call
; or access that might repurpose that same register - stash it in
; memory first, THEN load registers fresh for whatever actually
; needs them.
; ============================================================
.proc draw_layouts
    lda #0
    sta CurrentEntry::e_index

@loop:
    lda CurrentEntry::e_index
    cmp LayoutEntries::l_entries
    bcs @done

    jsr CurrentEntry::CalculateAddress  ; e_ptr -> this record

    ; --- read every field this iteration needs, into memory,
    ;     before touching X/Y for anything else ---
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

    ; --- now it's safe to load X/Y for the PLOT call ---
    ldy @col                         ; Y = column (PLOT's own
                                      ; X=row/Y=column convention -
                                      ; see macros_rom_kernal.s)
    ldx @row                         ; X = row
    clc                              ; carry clear = PLOT "set" mode
    jsr KERNAL_PLOT

    BASIC_STROUT_VECTOR_MACRO CurrentEntry::e_msgptr

    inc CurrentEntry::e_index
    jmp @loop

@done:
    rts

; ── LOCAL VARIABLES ──────────────────────────────────────
.segment "BSS"
@col: .byte 0
@row: .byte 0
.endproc
