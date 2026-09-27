.include "labels_rom_kernal.s"
.include "labels_screen.s"
.include "../inc/values.h"
.include "../inc/decomp.h"
.include "../inc/print_helpers.h"
.include "../inc/print_shared_strings.h"
.include "../inc/print_basic_strings.h"

.export print_detail_basic, print_steps_bas_fwd, print_steps_bas_rev

.import OUTPUT_BYTETOHEX

.segment "CODE"

.proc print_detail_basic
    jsr print_cr
    lda #<PrintBasic::rpt_bas_hdr
    ldy #>PrintBasic::rpt_bas_hdr
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_bytes
    ldy #>PrintShared::rpt_lbl_bytes
    jsr print_str
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_hex_bytes
    jsr print_cr

    ; sign from byte 1 top bit
    lda #<PrintShared::rpt_lbl_sign
    ldy #>PrintShared::rpt_lbl_sign
    jsr print_str
    lda LayoutValues::basic_bytes+1
    bpl @pos
    lda #'-'
    jmp @emit
@pos:
    lda #'+'
@emit:
    jsr KERNAL_CHROUT
    jsr print_cr

    lda #<PrintShared::rpt_lbl_exp
    ldy #>PrintShared::rpt_lbl_exp
    jsr print_str
    lda decomp_basic_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintShared::rpt_open_bias
    ldy #>PrintShared::rpt_open_bias
    jsr print_str
    lda #<decomp_basic_bias_str
    ldy #>decomp_basic_bias_str
    jsr print_str
    lda #<PrintShared::rpt_close_bias
    ldy #>PrintShared::rpt_close_bias
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_mant
    ldy #>PrintShared::rpt_lbl_mant
    jsr print_str
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str_cr

    lda #<PrintBasic::rpt_bas_bits
    ldy #>PrintBasic::rpt_bas_bits
    jsr print_str_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_hex_wide
    jsr print_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_bin_bytes
    jsr print_cr
    rts
.endproc

.proc print_steps_bas_fwd
    lda #<PrintBasic::bas_fwd_hdr
    ldy #>PrintBasic::bas_fwd_hdr
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str

    ; step 1
    lda #<PrintBasic::bas_fwd_s1
    ldy #>PrintBasic::bas_fwd_s1
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str
    lda #<PrintBasic::bas_fwd_s1b
    ldy #>PrintBasic::bas_fwd_s1b
    jsr print_str
    lda #<decomp_basic_bias_str
    ldy #>decomp_basic_bias_str
    jsr print_str

    ; step 2
    lda #<PrintBasic::bas_fwd_s2
    ldy #>PrintBasic::bas_fwd_s2
    jsr print_str
    lda decomp_basic_exp_byte
    jsr OUTPUT_BYTETOHEX

    ; step 3
    lda #<PrintBasic::bas_fwd_s3
    ldy #>PrintBasic::bas_fwd_s3
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT

    lda #<PrintBasic::bas_fwd_s3b
    ldy #>PrintBasic::bas_fwd_s3b
    jsr print_str
    lda LayoutValues::basic_bytes+1
    jsr OUTPUT_BYTETOHEX

    lda #<PrintBasic::bas_fwd_s3c
    ldy #>PrintBasic::bas_fwd_s3c
    jsr print_str
    lda LayoutValues::basic_bytes+2
    jsr OUTPUT_BYTETOHEX

    lda #<PrintBasic::bas_fwd_s3d
    ldy #>PrintBasic::bas_fwd_s3d
    jsr print_str
    lda LayoutValues::basic_bytes+3
    jsr OUTPUT_BYTETOHEX

    lda #<PrintBasic::bas_fwd_s3e
    ldy #>PrintBasic::bas_fwd_s3e
    jsr print_str
    lda LayoutValues::basic_bytes+4
    jsr OUTPUT_BYTETOHEX

    ; step 4
    lda #<PrintBasic::bas_fwd_s4
    ldy #>PrintBasic::bas_fwd_s4
    jsr print_str
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_hex_bytes

    lda #<PrintBasic::bas_fwd_end
    ldy #>PrintBasic::bas_fwd_end
    jsr print_str
    rts
.endproc

.proc print_steps_bas_rev
    lda #<PrintBasic::bas_rev_hdr
    ldy #>PrintBasic::bas_rev_hdr
    jsr print_str
    lda #<LayoutValues::basic_bytes
    ldy #>LayoutValues::basic_bytes
    ldx #5
    jsr print_hex_bytes

    ; step 1
    lda #<PrintBasic::bas_rev_s1
    ldy #>PrintBasic::bas_rev_s1
    jsr print_str
    lda decomp_basic_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintBasic::bas_rev_s1b
    ldy #>PrintBasic::bas_rev_s1b
    jsr print_str
    lda #<decomp_basic_bias_str
    ldy #>decomp_basic_bias_str
    jsr print_str

    ; step 2
    lda #<PrintBasic::bas_rev_s2
    ldy #>PrintBasic::bas_rev_s2
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT
    lda #<PrintBasic::bas_rev_s2b
    ldy #>PrintBasic::bas_rev_s2b
    jsr print_str
    lda LayoutValues::basic_bytes+1
    jsr OUTPUT_BYTETOHEX
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda LayoutValues::basic_bytes+2
    jsr OUTPUT_BYTETOHEX
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda LayoutValues::basic_bytes+3
    jsr OUTPUT_BYTETOHEX
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda LayoutValues::basic_bytes+4
    jsr OUTPUT_BYTETOHEX

    ; step 3
    lda #<PrintBasic::bas_rev_s3
    ldy #>PrintBasic::bas_rev_s3
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str
    lda #<PrintBasic::bas_rev_s3b
    ldy #>PrintBasic::bas_rev_s3b
    jsr print_str
    lda #<decomp_basic_bias_str
    ldy #>decomp_basic_bias_str
    jsr print_str

    ; result
    lda #<PrintBasic::bas_rev_end
    ldy #>PrintBasic::bas_rev_end
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str
    lda #<PrintBasic::bas_rev_end2
    ldy #>PrintBasic::bas_rev_end2
    jsr print_str
    rts
.endproc
