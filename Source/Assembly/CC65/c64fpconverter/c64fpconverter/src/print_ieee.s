.include "labels_rom_kernal.s"
.include "labels_screen.s"
.include "../inc/values.h"
.include "../inc/decomp.h"
.include "../inc/print_helpers.h"
.include "../inc/print_shared_strings.h"
.include "../inc/print_ieee_strings.h"

.export print_detail_ieee, print_steps_ieee_fwd, print_steps_ieee_rev

.import OUTPUT_BYTETOHEX

.segment "CODE"

.proc print_detail_ieee
    jsr print_cr
    lda #<PrintIeee::rpt_ieee_hdr
    ldy #>PrintIeee::rpt_ieee_hdr
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_bytes
    ldy #>PrintShared::rpt_lbl_bytes
    jsr print_str
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_hex_bytes
    jsr print_cr

    lda #<PrintShared::rpt_lbl_sign
    ldy #>PrintShared::rpt_lbl_sign
    jsr print_str
    lda decomp_ieee_sign_ch
    jsr KERNAL_CHROUT
    jsr print_cr

    lda #<PrintShared::rpt_lbl_exp
    ldy #>PrintShared::rpt_lbl_exp
    jsr print_str
    lda decomp_ieee_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintShared::rpt_open_bias
    ldy #>PrintShared::rpt_open_bias
    jsr print_str
    lda #<decomp_ieee_bias_str
    ldy #>decomp_ieee_bias_str
    jsr print_str
    lda #<PrintShared::rpt_close_bias
    ldy #>PrintShared::rpt_close_bias
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_mant
    ldy #>PrintShared::rpt_lbl_mant
    jsr print_str
    lda #<decomp_ieee_mant_str
    ldy #>decomp_ieee_mant_str
    jsr print_str_cr

    lda #<PrintIeee::rpt_ieee_bits
    ldy #>PrintIeee::rpt_ieee_bits
    jsr print_str_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_hex_wide
    jsr print_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_bin_bytes
    jsr print_cr
    rts
.endproc

.proc print_steps_ieee_fwd
    ; --- hdr + input ---
    lda #<PrintIeee::ieee_fwd_hdr
    ldy #>PrintIeee::ieee_fwd_hdr
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str

    ; --- step 1: branch the header on exp field == 0 ---
    lda LayoutValues::ieee754_bytes+0
    and #$7F
    bne @s1_hdr_normal
    lda LayoutValues::ieee754_bytes+1
;    bpl s1_hdr_normal
    bmi @s1_hdr_normal

    ; subnormal
    lda #<PrintIeee::ieee_fwd_s1_sub
    ldy #>PrintIeee::ieee_fwd_s1_sub
    jmp @s1_hdr_done
@s1_hdr_normal:
    lda #<PrintIeee::ieee_fwd_s1
    ldy #>PrintIeee::ieee_fwd_s1
@s1_hdr_done:
    jsr print_str
    lda decomp_ieee_sign_ch
    jsr KERNAL_CHROUT

    lda #<decomp_ieee_mant_str
    ldy #>decomp_ieee_mant_str
    jsr print_str
    lda #<PrintIeee::ieee_fwd_s1b
    ldy #>PrintIeee::ieee_fwd_s1b
    jsr print_str
    lda #<decomp_ieee_bias_str
    ldy #>decomp_ieee_bias_str
    jsr print_str

    ; --- step 2 ---
    lda #<PrintIeee::ieee_fwd_s2
    ldy #>PrintIeee::ieee_fwd_s2
    jsr print_str
    lda #<decomp_ieee_bias_str
    ldy #>decomp_ieee_bias_str
    jsr print_str
    lda #<PrintIeee::ieee_fwd_s2b
    ldy #>PrintIeee::ieee_fwd_s2b
    jsr print_str
    lda decomp_ieee_exp_byte
    jsr OUTPUT_BYTETOHEX

    ; --- step 3 ---
    lda #<PrintIeee::ieee_fwd_s3
    ldy #>PrintIeee::ieee_fwd_s3
    jsr print_str
    lda decomp_ieee_sign_ch
    jsr KERNAL_CHROUT

    lda #<PrintIeee::ieee_fwd_s3b
    ldy #>PrintIeee::ieee_fwd_s3b
    jsr print_str
    lda LayoutValues::ieee754_bytes+0
    jsr OUTPUT_BYTETOHEX

    lda #<PrintIeee::ieee_fwd_s3c
    ldy #>PrintIeee::ieee_fwd_s3c
    jsr print_str
    lda LayoutValues::ieee754_bytes+1
    jsr OUTPUT_BYTETOHEX

    lda #<PrintIeee::ieee_fwd_s3d
    ldy #>PrintIeee::ieee_fwd_s3d
    jsr print_str
    lda LayoutValues::ieee754_bytes+2
    jsr OUTPUT_BYTETOHEX

    lda #<PrintIeee::ieee_fwd_s3e
    ldy #>PrintIeee::ieee_fwd_s3e
    jsr print_str
    lda LayoutValues::ieee754_bytes+3
    jsr OUTPUT_BYTETOHEX

    ; --- step 4 ---
    lda #<PrintIeee::ieee_fwd_s4
    ldy #>PrintIeee::ieee_fwd_s4
    jsr print_str
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_hex_bytes

    lda #<PrintIeee::ieee_fwd_end
    ldy #>PrintIeee::ieee_fwd_end
    jsr print_str
    rts
.endproc

.proc print_steps_ieee_rev
    ; --- hdr + input ---
    lda #<PrintIeee::ieee_rev_hdr
    ldy #>PrintIeee::ieee_rev_hdr
    jsr print_str
    lda #<LayoutValues::ieee754_bytes
    ldy #>LayoutValues::ieee754_bytes
    ldx #4
    jsr print_hex_bytes

    ; --- step 1 ---
    lda #<PrintIeee::ieee_rev_s1
    ldy #>PrintIeee::ieee_rev_s1
    jsr print_str
    lda decomp_ieee_sign_ch
    jsr KERNAL_CHROUT

    ; --- step 2 ---
    lda #<PrintIeee::ieee_rev_s2
    ldy #>PrintIeee::ieee_rev_s2
    jsr print_str
    lda decomp_ieee_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintIeee::ieee_rev_s2b
    ldy #>PrintIeee::ieee_rev_s2b
    jsr print_str
    lda #<decomp_ieee_bias_str
    ldy #>decomp_ieee_bias_str
    jsr print_str

    ; --- step 3: branch the header and the leading digit on
    ;     exp field == 0 (subnormal has no implicit 1)
    lda LayoutValues::ieee754_bytes+0
    and #$7F
    bne @s3_normal
    lda LayoutValues::ieee754_bytes+1
;    bpl @s3_normal
    bmi @s3_normal

    ; subnormal
    lda #<PrintIeee::ieee_rev_s3_sub
    ldy #>PrintIeee::ieee_rev_s3_sub
    jsr print_str
    jmp @s3_sig
@s3_normal:
    lda #<PrintIeee::ieee_rev_s3
    ldy #>PrintIeee::ieee_rev_s3
    jsr print_str
    lda #'1'
    jsr KERNAL_CHROUT
@s3_sig:
    lda #<PrintIeee::ieee_rev_s3b
    ldy #>PrintIeee::ieee_rev_s3b
    jsr print_str
    lda #<decomp_ieee_mant_str
    ldy #>decomp_ieee_mant_str
    jsr print_str

    ; --- step 4 ---
    lda #<PrintIeee::ieee_rev_s4
    ldy #>PrintIeee::ieee_rev_s4
    jsr print_str
    lda decomp_ieee_sign_ch         ; NEW
    jsr KERNAL_CHROUT
    lda #<decomp_ieee_mant_str
    ldy #>decomp_ieee_mant_str
    jsr print_str
    lda #<PrintIeee::ieee_rev_s4b
    ldy #>PrintIeee::ieee_rev_s4b
    jsr print_str
    lda #<decomp_ieee_bias_str
    ldy #>decomp_ieee_bias_str
    jsr print_str

    ; --- result ---
    lda #<PrintIeee::ieee_rev_end
    ldy #>PrintIeee::ieee_rev_end
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str
    lda #<PrintIeee::ieee_rev_end2
    ldy #>PrintIeee::ieee_rev_end2
    jsr print_str
    rts
.endproc
