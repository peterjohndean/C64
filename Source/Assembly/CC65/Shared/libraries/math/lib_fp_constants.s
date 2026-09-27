
.scope LIBFP_CONSTANTS
    .export one_const, ten_const
    .export neg_one_const
    .export half_pi_const, pi_const, three_half_pi_const, two_pi_const
    .export deg_to_rad_const, rad_to_deg_const
    .segment "RODATA"
    ;
    ten_const:          .byte $83,$50,$00,$00   ; 10.0
    one_const:          .byte $80,$40,$00,$00   ; 1.0
    neg_one_const:      .byte $7f,$80,$00,$00   ; -1.0

    ; pi
    half_pi_const:          .byte $80,$64,$87,$ed   ; pi/2 = 1.5707963268
    pi_const:               .byte $81,$64,$87,$ed   ; pi   = 3.1415926536
    three_half_pi_const:    .byte $82,$4b,$65,$f2   ; 3pi/2= 4.7123889804
    two_pi_const:           .byte $82,$64,$87,$ed   ; 2pi  = 6.2831853072

    ; trig
    deg_to_rad_const:   .byte $7a,$47,$7d,$1b   ; pi/180 = 0.0174532925
    rad_to_deg_const:   .byte $85,$72,$97,$70   ; 180/pi = 57.2957795
.endscope


