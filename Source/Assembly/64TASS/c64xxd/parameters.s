; Process SYS passed parameters
sysParameters .proc
;
; Description:  Count SYSxxxxx parameters
; Parameters:   None
; Returns:      Parameter count (Register A)
;
count
    ; Save TXTPTR
    lda BASIC_TXTPTR
    pha
    lda BASIC_TXTPTR+1
    pha
    
    ; Initialise
    ldx #0                  ; Parameter counter
    stx _flagQuote          ; Reset
    
    ; Initial character, after SYSxxxx
    jsr BASIC_CHRGOT
    cmp #0
    beq _done               ; Is EOL (end of line)?
    cmp #':'
    beq _done               ; Is EOS (end of statement)?
    
    cmp #','
    bne _cloop              ; Comma?
    inx                     ; If yes, parameter found
    
_cloop
    ; Next character
    jsr BASIC_CHRGET
    
    ; Check for EOL/EOS
    cmp #0
    beq _done               ; Is end of line?
    cmp #':'
    beq _done               ; Is end of statement?

    cmp #'"'                ; Is quote?
    beq _toggleQuote
    cmp #','                ; Is comma?
    beq _isComma
    
    gne _cloop
    
 _isComma:
    bit _flagQuote          ; Is part of string?
    bmi _cloop              ; If bit 7 set, we are in quotes. Ignore comma.
    inx
    jmp _cloop

_toggleQuote:
    lda _flagQuote
    eor #$80                ; Toggle bit 7 (High bit)
    sta _flagQuote
    jmp _cloop
    
_done
    ; Restore TXTPTR
    pla
    sta BASIC_TXTPTR+1
    pla
    sta BASIC_TXTPTR
    
;    txa
;    clc
;    adc #$30                ; Convert number to PETSCII digit (0-9 only for demo)
;    sta $0400
    
    txa
    rts

_flagQuote  .byte   $00     ; Localised variable

;
; Description:  Parse SYSxxxxx parameters
; Format:       SYSxxxxx,"filename"
; Parameters:   None
; Returns:      None
; Modifies:     ZPVector2, file.input.{name|len}
;
parse
    jsr BASIC_CHKCOM
    jsr BASIC_FRMEVL
    bit BASIC_VALTYP    ; Is String?
    bmi _isString
    rts
    
_isString
    ; Store length
    sta file.input.len
    tay
    
    ; Set destination
    lda #<file.input.name   ; lsb
    sta ZPVector2
    lda #>file.input.name+1 ; msb
    sta ZPVector2+1

    ; Store filename
_cpyloop
    lda (BASIC_INDEX),y
    sta (ZPVector2),y
    dey
    bpl _cpyloop            ; Is positive?
    
    ; Cleanup
    jmp BASIC_FRESTR
    
.endproc
