.ifndef PRINT_SHARED_STRINGS_S
PRINT_SHARED_STRINGS_S = 1

.scope PrintShared
    .segment "RODATA"

    .export no_printer_msg, tear_line
    .export rpt_banner1, rpt_banner2, rpt_banner3
    .export rpt_hdr_sum, rpt_hdr_det, rpt_hdr_steps, rpt_hr, rpt_footer
    .export rpt_lbl_dec, rpt_lbl_woz, rpt_lbl_ieee, rpt_lbl_bas
    .export rpt_lbl_bytes, rpt_lbl_sign, rpt_lbl_exp
    .export rpt_open_bias, rpt_close_bias, rpt_lbl_mant

    no_printer_msg: .asciiz "printer not ready"
    tear_line:      .asciiz "8<------------------------------------>8"

    rpt_banner1:    .asciiz "========================================"
    rpt_banner2:    .asciiz "      fp format conversion report       "
    rpt_banner3:    .asciiz "========================================"
    rpt_hdr_sum:    .asciiz "summary:"
    rpt_hdr_det:    .asciiz "detailed:"
    rpt_hdr_steps:  .asciiz "step-by-step hand conversion:"
    rpt_hr:         .asciiz "----------------------------------------"
    rpt_footer:     .asciiz "-- end of report --"

    rpt_lbl_dec:    .asciiz "decimal value:        "
    rpt_lbl_woz:    .asciiz "woz/rankin (native):  "
    rpt_lbl_ieee:   .asciiz "ieee-754 single:      "
    rpt_lbl_bas:    .asciiz "c64 basic (packed):   "

    ; These detail labels are used identically by every format's
    ; detail section, so they live in the shared module.
    rpt_lbl_bytes:  .asciiz "  bytes:    "
    rpt_lbl_sign:   .asciiz "  sign:     "
    rpt_lbl_exp:    .asciiz "  exp:      $"
    rpt_open_bias:  .asciiz " (bias "
    rpt_close_bias: .asciiz ")"
    rpt_lbl_mant:   .asciiz "  mantissa: "
.endscope

.endif
