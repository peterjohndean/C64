.include "labels_rom_kernal.s"
.include "../inc/box.h"

.export prepare_message_line

.segment "CODE"

; ============================================================
; FILE    : message.s
; PURPOSE
; -------
; A dedicated line (BoxLayout::MSG_ROW) for FP_ERROR_PROC's own
; trapped-error text to land on safely - see the project
; conversation for the full diagnosis. Call this immediately
; before ARMING every FP_ERROR_INIT_MACRO guard in this project
; (not just before the risky call - the trap can fire from deep
; inside it, well after any cursor movement of its own), so
; wherever the unwind lands, the cursor is already parked
; somewhere harmless. Also clears any stale message left behind
; by a PREVIOUS trap, since nothing else ever redraws this line.
;
; A trap's own trailing carriage return moves the cursor onto
; LEGEND_ROW1 afterward - harmless, since every subsequent print
; in this program starts with its own explicit KERNAL_PLOT rather
; than trusting wherever the cursor happens to be.
; ============================================================
.proc prepare_message_line
    ldy #0
    ldx #BoxLayout::MSG_ROW
    clc
    jsr KERNAL_PLOT
    ldx #40
@blank_loop:
    lda #' '
    jsr KERNAL_CHROUT
    dex
    bne @blank_loop

    ldy #0
    ldx #BoxLayout::MSG_ROW
    clc
    jsr KERNAL_PLOT
    rts
.endproc
