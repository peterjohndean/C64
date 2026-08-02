.include "labels_screen.s"

.scope TestValue
    .export val_1billion, val_100, val_12, val_7, val_1
    .export val_0_5, val_0_1, val_0
    .export val_neg5, val_neg42, val_neg60
    .export val_pi, val_2pi
    .export ieee754_pi, ieee754_2pi
    .export ieee754_0_1
    .export ieee754_neg5

    .segment "RODATA"
    val_1billion:   .byte $9d,$77,$35,$94   ; 1,000,000,000.0
    val_100:        .byte $86,$64,$00,$00   ; 100.0
    val_12:         .byte $83,$60,$00,$00   ; 12
    val_7:          .byte $82,$70,$00,$00   ; 7
    val_1:          .byte $80,$40,$00,$00   ; 1.0
    val_0_5:        .byte $7f,$40,$00,$00   ; 0.5
    val_0_1:        .byte $7c,$66,$66,$66   ; ~0.1 (not exactly representable)
    val_0:          .byte $00,$00,$00,$00   ; 0
    val_neg5:       .byte $82,$b0,$00,$00   ; -5
    val_neg42:      .byte $85,$ac,$00,$00   ; -42
    val_neg60:      .byte $85,$88,$00,$00   ; -60

    val_2pi:        .byte $82,$64,$87,$ed   ; 2pi
    val_pi:         .byte $81,$64,$87,$ed   ; pi

    ; ieee754 values
    ieee754_2pi:    .byte $40,$c9,$0f,$db   ; 2pi
    ieee754_pi:     .byte $40,$49,$0f,$db   ; 3.1415926536
    ieee754_0_1:    .byte $3d,$cc,$cc,$cd   ; ~0.1
    ieee754_neg5:   .byte $c0,$a0,$00,$00   ; -5
    
;    1000000000		4e6e6b28	; 1B
;    100				42c80000
;    12				41400000
;    7				40e00000
;    1				3f800000
;    0.5				3f000000
;    0.1				3dcccccd
;    0				00000000
;    -1				bf800000
;    -5				c0a00000
;    -42				c2280000
;    -60				c2700000
;
;    1.4142136		3fb504f4	; sqrt(2)
;    0.69314718		3f317218	; ln(2)
;    0.4342945		3ede5bd9	; 1/ln(10)
;    0.0174532925	3c8efa35	; pi/180
;    1.5707963268	3fc90fdb	; pi/2
;    3.1415926536	40490fdb	; pi
;    4.7123889804	4096cbe4	; 3pi/2
;    6.2831853072	40c90fdb	; 2pi
;    57.2957795		42652ee1	; 180/pi
.endscope

.scope TestData
    .export test_pass, test_fail, test_check, test_title
    .export test_spacer_got1, test_spacer_got2, test_spacer
    .export id_group, id_test
    .export fractional_digits
    .export ptr_expected, ptr_testmsg
    .export out_buffer
    .export fac_snapshot

    .segment "RODATA"
    test_title:         .asciiz     "group tests to be performed: "
    test_pass:          .literal    ":", PETSCII_GREEN, "P", PETSCII_LIGHT_BLUE, ":", $0
    test_fail:          .literal    ":", PETSCII_RED, "F", PETSCII_LIGHT_BLUE, ":", $0
    test_check:         .literal    ":", PETSCII_YELLOW, "C", PETSCII_LIGHT_BLUE, ":", $0
    test_spacer_got1:   .literal    "   ", PETSCII_RED, "-> ", $0
    test_spacer_got2:   .literal    PETSCII_LIGHT_BLUE, $0
    test_spacer:        .literal    "   -> ", $0

    .segment "BSS"
    id_group:           .byte   0   ; Group number
    id_test:            .byte   0   ; Test number

    fractional_digits:  .byte   0   ; Number of fractional digits to output for TO_ASCII/ASCII24

    ptr_expected:       .res 2      ; Vector to result source, typically C-String
    ptr_testmsg:        .res 2

    out_buffer:         .res 16,0   ; scratch buffer for FP_TO_ASCII_PROC/FP_TO_ASCII24_PROC
                                    ; output (16 bytes comfortably covers a sign, up to 7
                                    ; integer digits, '.', and a couple of fractional digits)
    fac_snapshot:       .res 4,0    ; FP1 snapshot taken before any
                                    ; BASIC_STROUT. Basically clobbers fac1
.endscope
