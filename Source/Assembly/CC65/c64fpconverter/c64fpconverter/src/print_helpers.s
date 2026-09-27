.include "labels_rom_kernal.s"
.include "labels_rom_basic.s"
.include "labels_screen.s"
.include "labels_fp.s"

.export print_cr, print_str, print_str_cr
.export print_hex_bytes, print_bin_bytes, print_hex_wide

.import OUTPUT_BYTETOHEX, OUTPUT_BYTETOBINARY

.segment "CODE"
.proc print_cr
    lda #PETSCII_RETURN
    jmp KERNAL_CHROUT
.endproc

.proc print_str
    jmp BASIC_STROUT
.endproc

.proc print_str_cr
    jsr BASIC_STROUT
    lda #PETSCII_RETURN
    jmp KERNAL_CHROUT
.endproc

; Print N bytes at (A,Y) as "XX XX XX ..."
; Entry: A = ptr lo, Y = ptr hi, X = byte count
.proc print_hex_bytes
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx @remaining
    ldy #0
@loop:
    lda (FP_STRPTR),y
    jsr OUTPUT_BYTETOHEX
    iny
    cpy @remaining
    bcs @done
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    jmp @loop
@done:
    rts
.segment "BSS"
@remaining: .byte 0
.segment "CODE"
.endproc

; Same, but binary with a space between bytes
.proc print_bin_bytes
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx @remaining
    ldy #0
@loop:
    lda (FP_STRPTR),y
    jsr OUTPUT_BYTETOBINARY
    iny
    cpy @remaining
    bcs @done
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    jmp @loop
@done:
    rts
.segment "BSS"
@remaining: .byte 0
.segment "CODE"
.endproc

.proc print_hex_wide
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx @remaining
    ldy #0
@loop:
    lda (FP_STRPTR),y
    jsr OUTPUT_BYTETOHEX
    iny
    cpy @remaining
    bcs @done                   ; last byte: no padding, no separator
    ldx #6
@pad:
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    dex
    bne @pad
    lda #PETSCII_SPACE
    jsr KERNAL_CHROUT
    jmp @loop
@done:
    rts
.segment "BSS"
@remaining: .byte 0
.segment "CODE"
.endproc
