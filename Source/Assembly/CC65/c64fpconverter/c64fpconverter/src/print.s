.include "labels_fp.s"
.include "labels_rom_kernal.s"
.include "labels_screen.s"
.include "macros_rom_basic.s"
.include "../inc/layout.h"
.include "../inc/values.h"
.include "../inc/row_meta.h"
.include "../inc/decomp.h"
.include "../inc/print_helpers.h"
.include "../inc/print_woz.h"
.include "../inc/print_shared_strings.h"
.include "../inc/print_woz_strings.h"
.include "../inc/print_ieee.h"
.include "../inc/print_basic.h"

.export print_key

.import prepare_message_line
;.import decomp_sign_ch, decomp_exp_byte
;.import decomp_bias_str, decomp_mant_str
.import OUTPUT_BYTETOHEX, OUTPUT_BYTETOBINARY

.segment "CODE"

; ============================================================
; FILE    : print.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; 'p'/'P' (BROWSE state only). Prints decimal/ieee754/woz-rankin/
; c64-basic - NOT binary. [REFACTOR] No longer runs any FP_TO_*
; conversion itself - reads the SAME cached data values.s already
; computed, via RowMeta::print_row_value. Previously this file had
; its own independent copy of the conversion logic - which is
; exactly how the FP_TO_BASIC trap guard got silently dropped from
; one copy and not the other. One formatter, one cached data set.
; ============================================================
PRINT_LFN    = 4
PRINT_DEVICE = 4
PRINT_SA     = 0

.proc print_key
    cmp #'p'
    beq @quick
    cmp #'P'
    beq @full
    clc
    rts

@quick:
    ; --- existing @go body, unchanged ---
    lda #0
    jsr KERNAL_SETNAM
    lda #PRINT_LFN
    ldx #PRINT_DEVICE
    ldy #PRINT_SA
    jsr KERNAL_SETLFS
    jsr KERNAL_OPEN
    bcs @not_ready
    ldx #PRINT_LFN
    jsr KERNAL_CHKOUT
    bcs @chkout_failed
    lda #0
    jsr print_row
    lda #2
    jsr print_row
    lda #3
    jsr print_row
    lda #4
    jsr print_row
    lda #<PrintShared::tear_line
    ldy #>PrintShared::tear_line
    jsr BASIC_STROUT
    lda #$0d
    jsr KERNAL_CHROUT
    jmp @close

@full:
    lda #0
    jsr KERNAL_SETNAM
    lda #PRINT_LFN
    ldx #PRINT_DEVICE
    ldy #PRINT_SA
    jsr KERNAL_SETLFS
    jsr KERNAL_OPEN
    bcs @not_ready
    ldx #PRINT_LFN
    jsr KERNAL_CHKOUT
    bcs @chkout_failed
    jsr print_report
    jmp @close

@close:
    jsr KERNAL_CLRCHN
    lda #PRINT_LFN
    jsr KERNAL_CLOSE
    sec
    rts

@chkout_failed:
    jsr KERNAL_CLRCHN
    lda #PRINT_LFN
    jsr KERNAL_CLOSE

@not_ready:
    jsr prepare_message_line
    BASIC_STROUT_MACRO PrintShared::no_printer_msg
    sec
    rts
.endproc

.proc print_report
    ; --- Banner ---
    lda #<PrintShared::rpt_banner1
    ldy #>PrintShared::rpt_banner1
    jsr print_str_cr
    lda #<PrintShared::rpt_banner2
    ldy #>PrintShared::rpt_banner2
    jsr print_str_cr
    lda #<PrintShared::rpt_banner3
    ldy #>PrintShared::rpt_banner3
    jsr print_str_cr
    jsr print_cr

    ; --- Summary ---
    jsr print_summary

    ; --- Detailed ---
    lda #<PrintShared::rpt_hdr_det
    ldy #>PrintShared::rpt_hdr_det
    jsr print_str_cr
    jsr print_detail_woz
    jsr print_detail_ieee
    jsr print_detail_basic

    ; --- Step-by-step ---
    jsr print_cr
    lda #<PrintShared::rpt_hdr_steps
    ldy #>PrintShared::rpt_hdr_steps
    jsr print_str_cr
    lda #<PrintShared::rpt_hr
    ldy #>PrintShared::rpt_hr
    jsr print_str_cr
    jsr print_steps_woz_fwd
    jsr print_steps_woz_rev
    jsr print_steps_ieee_fwd
    jsr print_steps_ieee_rev
    jsr print_steps_bas_fwd
    jsr print_steps_bas_rev

    ; --- Footer ---
    jsr print_cr
    lda #<PrintShared::rpt_footer
    ldy #>PrintShared::rpt_footer
    jsr print_str_cr
    rts
.endproc

.proc print_summary
    lda #<PrintShared::rpt_hdr_sum
    ldy #>PrintShared::rpt_hdr_sum
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_dec
    ldy #>PrintShared::rpt_lbl_dec
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_woz
    ldy #>PrintShared::rpt_lbl_woz
    jsr print_str
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_hex_bytes
    jsr print_cr

    lda #<PrintShared::rpt_lbl_ieee
    ldy #>PrintShared::rpt_lbl_ieee
    jsr print_str
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_hex_bytes
    jsr print_cr

    lda #<PrintShared::rpt_lbl_bas
    ldy #>PrintShared::rpt_lbl_bas
    jsr print_str
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_hex_bytes
    jsr print_cr
    rts
.endproc

.proc print_row
    pha
    sta CurrentEntry::e_index
    jsr CurrentEntry::CalculateAddress

    ldy #layout_struct::msg
    lda (CurrentEntry::e_ptr),y
    sta CurrentEntry::e_msgptr
    ldy #layout_struct::msg+1
    lda (CurrentEntry::e_ptr),y
    sta CurrentEntry::e_msgptr+1

    BASIC_STROUT_VECTOR_MACRO CurrentEntry::e_msgptr

    ; [BUG FIX] copy into FP_STRPTR before indirecting - see the
    ; project conversation: CurrentEntry::e_msgptr is deliberately
    ; NOT a zero-page symbol (layout.h imports it plain, only
    ; e_ptr gets .importzp), because every OTHER use of it only
    ; ever needs A/Y-loaded, never (ptr),y addressing. FP_STRPTR
    ; is this library's own designated transient scratch pointer
    ; for exactly this kind of access (see labels_fp.s) - same
    ; caveat applies here as everywhere else it's used: don't call
    ; this from the middle of an in-flight FP_FROM_ASCII_PROC/
    ; FP_TO_ASCII_PROC call.
    lda CurrentEntry::e_msgptr
    sta FP_STRPTR
    lda CurrentEntry::e_msgptr+1
    sta FP_STRPTR+1

    ldy #0
@strlen_loop:
    lda (FP_STRPTR),y
    beq @strlen_done
    iny
    jmp @strlen_loop

@strlen_done:
    tya
    sta @label_len

    lda LayoutEntries::max_msg_len
    clc
    adc #1
    sec
    sbc @label_len
    tax
    
@pad_loop:
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    dex
    bne @pad_loop

    pla
    jsr RowMeta::print_row_value

    jsr print_cr
    rts

.segment "BSS"
@label_len: .byte 0
.segment "CODE"
.endproc
