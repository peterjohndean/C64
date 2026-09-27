.include "labels_rom_kernal.s"
.include "labels_screen.s"
.include "../inc/values.h"
.include "../inc/decomp.h"
.include "../inc/print_helpers.h"
.include "../inc/print_shared_strings.h"
.include "../inc/print_woz_strings.h"

.export print_detail_woz, print_steps_woz_fwd, print_steps_woz_rev

.import OUTPUT_BYTETOHEX

.segment "CODE"

.proc print_detail_woz
    jsr print_cr
    lda #<PrintWoz::rpt_woz_hdr
    ldy #>PrintWoz::rpt_woz_hdr
    jsr print_str_cr

    lda #<PrintShared::rpt_lbl_bytes
    ldy #>PrintShared::rpt_lbl_bytes
    jsr print_str
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_hex_bytes
    jsr print_cr

    lda #<PrintShared::rpt_lbl_sign
    ldy #>PrintShared::rpt_lbl_sign
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT
    jsr print_cr

    lda #<PrintShared::rpt_lbl_exp
    ldy #>PrintShared::rpt_lbl_exp
    jsr print_str
    lda decomp_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintShared::rpt_open_bias
    ldy #>PrintShared::rpt_open_bias
    jsr print_str
    lda #<decomp_bias_str
    ldy #>decomp_bias_str
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

    lda #<PrintWoz::rpt_woz_bits
    ldy #>PrintWoz::rpt_woz_bits
    jsr print_str_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_hex_wide
    jsr print_cr

    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_bin_bytes
    jsr print_cr
    rts
.endproc

; ============================================================
; Woz forward — every static block includes its trailing CR,
; so no print_str_cr call is needed. Each block ends with the
; prefix of the dynamic value that follows it.
; ============================================================
.proc print_steps_woz_fwd
    ; --- hdr + input ---
    lda #<PrintWoz::woz_fwd_hdr
    ldy #>PrintWoz::woz_fwd_hdr
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str

    ; --- step 1 ---
    lda #<PrintWoz::woz_fwd_s1
    ldy #>PrintWoz::woz_fwd_s1
    jsr print_str
    lda decomp_sign_ch              ; NEW
    jsr KERNAL_CHROUT
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str
    lda #<PrintWoz::woz_fwd_s1b
    ldy #>PrintWoz::woz_fwd_s1b
    jsr print_str
    lda #<decomp_bias_str
    ldy #>decomp_bias_str
    jsr print_str

    ; --- step 2 ---
    lda #<PrintWoz::woz_fwd_s2
    ldy #>PrintWoz::woz_fwd_s2
    jsr print_str
    lda #<decomp_bias_str
    ldy #>decomp_bias_str
    jsr print_str
    lda #<PrintWoz::woz_fwd_s2b
    ldy #>PrintWoz::woz_fwd_s2b
    jsr print_str
    lda decomp_exp_byte
    jsr OUTPUT_BYTETOHEX

    ; --- step 3 ---
    lda #<PrintWoz::woz_fwd_s3
    ldy #>PrintWoz::woz_fwd_s3
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT

    lda #<PrintWoz::woz_fwd_s3b
    ldy #>PrintWoz::woz_fwd_s3b
    jsr print_str
    lda LayoutValues::current_value+1
    jsr OUTPUT_BYTETOHEX

    lda #<PrintWoz::woz_fwd_s3c
    ldy #>PrintWoz::woz_fwd_s3c
    jsr print_str
    lda LayoutValues::current_value+2
    jsr OUTPUT_BYTETOHEX

    lda #<PrintWoz::woz_fwd_s3d
    ldy #>PrintWoz::woz_fwd_s3d
    jsr print_str
    lda LayoutValues::current_value+3
    jsr OUTPUT_BYTETOHEX

    ; --- step 4 ---
    lda #<PrintWoz::woz_fwd_s4
    ldy #>PrintWoz::woz_fwd_s4
    jsr print_str
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_hex_bytes

    lda #<PrintWoz::woz_fwd_end
    ldy #>PrintWoz::woz_fwd_end
    jsr print_str
    rts
.endproc

.proc print_steps_woz_rev
    lda #<PrintWoz::woz_rev_hdr
    ldy #>PrintWoz::woz_rev_hdr
    jsr print_str
    lda #<LayoutValues::current_value
    ldy #>LayoutValues::current_value
    ldx #4
    jsr print_hex_bytes

    lda #<PrintWoz::woz_rev_s1
    ldy #>PrintWoz::woz_rev_s1
    jsr print_str
    lda decomp_exp_byte
    jsr OUTPUT_BYTETOHEX
    lda #<PrintWoz::woz_rev_s1b
    ldy #>PrintWoz::woz_rev_s1b
    jsr print_str
    lda #<decomp_bias_str
    ldy #>decomp_bias_str
    jsr print_str

    lda #<PrintWoz::woz_rev_s2
    ldy #>PrintWoz::woz_rev_s2
    jsr print_str
    ; mantissa bytes 1..3, space-separated
    lda LayoutValues::current_value+1
    jsr OUTPUT_BYTETOHEX
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda LayoutValues::current_value+2
    jsr OUTPUT_BYTETOHEX
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    lda LayoutValues::current_value+3
    jsr OUTPUT_BYTETOHEX

    lda #<PrintWoz::woz_rev_s2b
    ldy #>PrintWoz::woz_rev_s2b
    jsr print_str
    lda decomp_sign_ch
    jsr KERNAL_CHROUT

        ; --- step 3: reconstruct ---
    lda #<PrintWoz::woz_rev_s3
    ldy #>PrintWoz::woz_rev_s3
    jsr print_str
    ; hex mantissa bytes, concatenated
    lda LayoutValues::current_value+1
    jsr OUTPUT_BYTETOHEX
    lda LayoutValues::current_value+2
    jsr OUTPUT_BYTETOHEX
    lda LayoutValues::current_value+3
    jsr OUTPUT_BYTETOHEX
    lda #<PrintWoz::woz_rev_s3a
    ldy #>PrintWoz::woz_rev_s3a
    jsr print_str
    ; decimal integer
    lda #<decomp_mant_int_str
    ldy #>decomp_mant_int_str
    jsr print_str
    lda #<PrintWoz::woz_rev_s3b
    ldy #>PrintWoz::woz_rev_s3b
    jsr print_str
    lda decomp_sign_ch              ; NEW
    jsr KERNAL_CHROUT
    ; mantissa fraction
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str
    lda #<PrintWoz::woz_rev_s3c
    ldy #>PrintWoz::woz_rev_s3c
    jsr print_str
    lda decomp_sign_ch              ; NEW
    jsr KERNAL_CHROUT
    ; mantissa again for the VALUE line
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    jsr print_str
    lda #<PrintWoz::woz_rev_s3d
    ldy #>PrintWoz::woz_rev_s3d
    jsr print_str
    ; bias
    lda #<decomp_bias_str
    ldy #>decomp_bias_str
    jsr print_str

    ; --- result ---
    lda #<PrintWoz::woz_rev_end
    ldy #>PrintWoz::woz_rev_end
    jsr print_str
    lda #<LayoutValues::decimal_str
    ldy #>LayoutValues::decimal_str
    jsr print_str
    lda #<PrintWoz::woz_rev_end2
    ldy #>PrintWoz::woz_rev_end2
    jsr print_str
    rts
.endproc
