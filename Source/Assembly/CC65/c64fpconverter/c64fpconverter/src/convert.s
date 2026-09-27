.macpack longbranch

.include "macros_fp.s"
.include "labels_fp.s"
.include "../inc/navigation.h"
.include "../inc/values.h"

.import FP_FROM_ASCII_SCI_V3, FP_FROM_IEEE754, FP_FROM_BASIC
.import FP_NORM
.import prepare_message_line

.export commit_value

.segment "CODE"

; ============================================================
; FILE    : convert.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Parses NavigationEdit::edit_buf per NavigationEdit::edit_row's
; format and, on success, updates LayoutValues::current_value.
;
; BINARY END-PADDING (new - see project conversation)
; -----------------------------------------------------------------
; A binary entry shorter than 32 characters (only reachable after
; HOME clears the field and fewer than 32 bits are typed) is
; copied into bit_scratch, '0'-filled for the remaining positions,
; and parsed exactly like a full 32-bit entry - so a short entry
; gets the SAME FP_NORM + validate_canonical_zero protection a
; full one already had, automatically, not as a separate code path
; that could quietly skip it.
;
; binary_from_ascii NOW TAKES A BUFFER POINTER (A/Y), NOT A FIXED
; SOURCE
; -----------------------------------------------------------------
; It used to read NavigationEdit::edit_buf directly. Generalizing
; it to accept any buffer (matching hex_bytes_from_ascii's own
; convention) is what lets both the "exactly 32 typed" and
; "padded into bit_scratch" cases share one implementation.
; ============================================================
.proc force_clean_zero
    ; If FP1_EXP landed on exactly 0 (canonical zero by this
    ; format's convention), make sure the mantissa agrees - see
    ; project conversation: FP_FROM_ASCII_SCI_V2's iterative divide-
    ; by-10 underflow path can land the exponent on 0 without going
    ; through FP_CORE_PROC's own explicit "zero everything" branch,
    ; leaving stale mantissa bits behind. Deliberately NOT the same
    ; as validate_canonical_zero (which REJECTS this combination for
    ; raw byte-injection rows) - a decimal value that legitimately
    ; underflows is correct input, not user error; it just needs
    ; cleaning up, not refusing.
    lda FP1_EXP
    bne @done
    lda #0
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
@done:
    rts
.endproc

.proc commit_value
    lda NavigationEdit::edit_row
    cmp #0
    beq @decimal
    cmp #1
    beq @binary
    cmp #4
    beq @ieee754
    cmp #2
    jeq @wozrankin
    jmp @basic

@decimal:
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @fail
    lda #<NavigationEdit::edit_buf
    ldy #>NavigationEdit::edit_buf
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    jsr force_clean_zero
    jmp @check_result

@binary:
    lda NavigationEdit::edit_len
    jeq @fail                       ; nothing typed at all: reject
    cmp #32
    beq @binary_use_typed

    ; fewer than 32 bits: copy what was typed, then '0'-fill the
    ; rest into bit_scratch - see file header
    ldx #0
@binary_copy_typed:
    cpx NavigationEdit::edit_len
    bcs @binary_pad_loop
    lda NavigationEdit::edit_buf,x
    sta bit_scratch,x
    inx
    jmp @binary_copy_typed
@binary_pad_loop:
    cpx #32
    bcs @binary_use_scratch
    lda #'0'
    sta bit_scratch,x
    inx
    jmp @binary_pad_loop
@binary_use_scratch:
    lda #<bit_scratch
    ldy #>bit_scratch
    jmp @binary_do_parse
@binary_use_typed:
    lda #<NavigationEdit::edit_buf
    ldy #>NavigationEdit::edit_buf
@binary_do_parse:
    jsr binary_from_ascii
    jcs @fail
    jsr FP_NORM
    jsr validate_canonical_zero
    jmp @check_result

@ieee754:
    lda NavigationEdit::edit_len
    cmp #8
    jne @fail
    lda #<NavigationEdit::edit_buf
    ldy #>NavigationEdit::edit_buf
    ldx #4
    jsr hex_bytes_from_ascii
    bcs @fail
    ldx #3
@copy_ieee:
    lda hex_scratch,x
    sta FP1_EXP,x
    dex
    bpl @copy_ieee
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @fail
    jsr FP_FROM_IEEE754
    FP_ERROR_CLEAR_MACRO
    clc
    jmp @check_result

@wozrankin:
    lda NavigationEdit::edit_len
    cmp #8
    bne @fail
    lda #<NavigationEdit::edit_buf
    ldy #>NavigationEdit::edit_buf
    ldx #4
    jsr hex_bytes_from_ascii
    bcs @fail
    ldx #3
@copy_woz:
    lda hex_scratch,x
    sta FP1_EXP,x
    dex
    bpl @copy_woz
    jsr FP_NORM
    jsr validate_canonical_zero
    jmp @check_result

@basic:
    lda NavigationEdit::edit_len
    cmp #10
    bne @fail
    lda #<NavigationEdit::edit_buf
    ldy #>NavigationEdit::edit_buf
    ldx #5
    jsr hex_bytes_from_ascii
    bcs @fail
    lda #<hex_scratch
    ldy #>hex_scratch
    jsr FP_FROM_BASIC
    clc
    jmp @check_result

@check_result:
    bcs @fail
    FP_STORE1_MACRO LayoutValues::current_value
    jsr LayoutValues::refresh_display
    rts

@fail:
    jsr LayoutValues::draw_values
    rts
.endproc

.proc validate_canonical_zero
    lda FP1_EXP
    bne @ok
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    beq @ok
    sec
    rts
@ok:
    clc
    rts
.endproc

.proc hex_nibble
    cmp #'0'
    bcc @bad
    cmp #'9'+1
    bcc @digit
    ; uppercase-fold lowercase a-f (and A-F stays as-is)
    and #$DF
    cmp #$41    ; 'A'
    bcc @bad
    cmp #$47    ; 'F'+1
    bcs @bad
    sec
    sbc #$41-10 ;#'A'-10
    clc
    rts
@digit:
    sec
    sbc #'0'
    clc
    rts
@bad:
    sec
    rts
.endproc

;.proc hex_nibble
;    cmp #'0'
;    bcc @bad
;    cmp #'9'+1
;    bcc @digit
;    cmp #$41    ;#'A'
;    bcc @bad
;    cmp #$47    ;#'F'+1
;    bcs @bad
;    sec
;    sbc #$41-10 ;#'A'-10
;    clc
;    rts
;@digit:
;    sec
;    sbc #'0'
;    clc
;    rts
;@bad:
;    sec
;    rts
;.endproc

.proc hex_bytes_from_ascii
    sta FP_STRPTR
    sty FP_STRPTR+1
    ldy #0
    stx @count
    ldx #0
@byte_loop:
    lda (FP_STRPTR),y
    jsr hex_nibble
    bcs @fail
    asl a
    asl a
    asl a
    asl a
    sta @hi_nibble
    iny

    lda (FP_STRPTR),y
    jsr hex_nibble
    bcs @fail
    ora @hi_nibble
    sta hex_scratch,x
    iny
    inx

    cpx @count
    bne @byte_loop
    clc
    rts
@fail:
    sec
    rts

.segment "BSS"
@count:     .byte 0
@hi_nibble: .byte 0
.segment "CODE"
.endproc

; ============================================================
; PROCEDURE : binary_from_ascii
; Purpose : Parse 32 ASCII '0'/'1' characters from a caller-
;           supplied buffer directly into FP1's own 4 raw bytes.
; Entry   : A = buffer addr lo, Y = buffer addr hi (32 chars)
; Exit    : carry clear + FP1 populated on success
;           carry set if any character wasn't '0' or '1'
; Destroys: A, X, Y
; ============================================================
.proc binary_from_ascii
    sta FP_STRPTR
    sty FP_STRPTR+1
    ldy #0
    ldx #0

@byte_loop:
    lda #0
    sta @acc
    stx @out_index
    ldx #8

@bit_loop:
    lda (FP_STRPTR),y
    cmp #'0'
    beq @bit_zero
    cmp #'1'
    beq @bit_one
    sec
    rts

@bit_zero:
    asl @acc
    jmp @bit_next

@bit_one:
    asl @acc
    inc @acc
    
@bit_next:
    iny
    dex
    bne @bit_loop

    ldx @out_index
    lda @acc
    sta FP1_EXP,x
    inx
    cpx #4
    bne @byte_loop

    clc
    rts

.segment "BSS"
@acc:       .byte 0
@out_index: .byte 0
.segment "CODE"
.endproc

.segment "BSS"
hex_scratch: .res 5,0
bit_scratch: .res 32,0
.segment "CODE"
