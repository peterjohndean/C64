.macpack longbranch

.include "macros_fp.s"
.include "labels_fp.s"
.include "../inc/values.h"

.import FP_SIN_FULL, FP_COS, FP_TAN, FP_LOG, FP_LOG10, FP_EXP
.import FP_DEG_TO_RAD, FP_RAD_TO_DEG
.import prepare_message_line

.export apply_math_key

.segment "CODE"

; ============================================================
; FILE    : mathops.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Single-key shortcuts (BROWSE state only - see navigation.s's
; call site) applying a transcendental function to current_value
; in place, then redrawing all five rows. Pure wiring - every
; routine called here (FP_SIN_FULL, FP_COS, etc.) is already
; proven on hardware; nothing new is computed by this file.
;
; KEY MAPPING
; -----------
;   S sin(x)   C cos(x)   T tan(x)   L ln(x)   G log10(x)
;   E e^x      D deg->rad R rad->deg
;
; WHY EVERY CALL IS GUARDED (unlike commit_value, where only
; ieee754 needed one)
; -----------------------------------------------------------------
; log(x<=0) is a domain error a user WILL hit deliberately (typing
; a negative value then pressing L); tan/exp can overflow near
; their own documented edge cases. Same "reject and revert" policy
; as commit_value throughout this project: a trap leaves
; current_value untouched, and redrawing from it just restores
; what was already on screen.
; ============================================================
.proc apply_math_key
    cmp #'s'
    jeq @sin
    cmp #'S'
    jeq @sin

    cmp #'c'
    jeq @cos
    cmp #'C'
    jeq @cos

    cmp #'t'
    jeq @tan
    cmp #'T'
    jeq @tan

    cmp #'l'
    jeq @ln
    cmp #'L'
    jeq @ln

    cmp #'g'
    jeq @log10
    cmp #'G'
    jeq @log10

    cmp #'e'
    jeq @exp
    cmp #'E'
    jeq @exp

    cmp #'d'
    jeq @deg
    cmp #'D'
    jeq @deg

    cmp #'r'
    jeq @rad
    cmp #'R'
    jeq @rad

    clc                      ; not a math key - tell the caller so
    rts                      ; it can fall through to its own
                             ; unhandled-key path (see navigation.s)

@sin:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_SIN_FULL
    jmp @commit
    
@cos:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_COS
    jmp @commit

@tan:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_TAN
    jmp @commit

@ln:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_LOG
    jmp @commit

@log10:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_LOG10
    jmp @commit

@exp:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_EXP
    jmp @commit

@deg:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_DEG_TO_RAD
    jmp @commit

@rad:
    FP_LOAD1_MACRO LayoutValues::current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @done
    jsr FP_RAD_TO_DEG
    jmp @commit

@commit:
    FP_ERROR_CLEAR_MACRO
    FP_STORE1_MACRO LayoutValues::current_value
    jsr LayoutValues::refresh_display
    sec
    rts

@done:
    ; a trap lands directly HERE (skipping @commit above entirely,
    ; via FP_ERROR_PROC's own stack-unwind - see lib_fp_error.s) -
    ; current_value is untouched, so this path correctly stays as
    ; draw_values alone: redraw what's still cached, don't
    ; recompute from a value that was never actually changed
    jsr LayoutValues::draw_values
    sec
    rts
.endproc
