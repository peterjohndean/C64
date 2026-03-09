; ============================================================
; VICE REU Diagnostic - What's Really Happening?
; ============================================================
; This program tests what VICE actually does with banks
; to help us understand the behavior
; ============================================================
.cpu "6502"
* = $0801

stub_start
    .word stub_end
    .word 10
    .byte $9e
    .text format("%d", entry)
    .byte 0
stub_end:
    .word 0

; REU registers
REU_STATUS   = $DF00
REU_COMMAND  = $DF01
REU_C64_LO   = $DF02
REU_C64_HI   = $DF03
REU_REU_LO   = $DF04
REU_REU_HI   = $DF05
REU_REU_BANK = $DF06
REU_LEN_LO   = $DF07
REU_LEN_HI   = $DF08

REU_CMD_C64_TO_REU = $90
REU_CMD_REU_TO_C64 = $91
REU_STATUS_EOB = %01000000

CHROUT = $ffd2
STROUT = $ab1e

zp_bank = $fb
zp_value = $fc
zp_result = $fd

entry
    lda #$93
    jsr CHROUT   ; clear screen
    
    ; ───────────────────────────────────────
    ; Test 1: Write unique values to banks 0, 1, 4, 8
    ; ───────────────────────────────────────
    lda #<msg_test1
    ldy #>msg_test1
    jsr STROUT
    
    ; Write $B0 to bank 0
    ldx #$00
    lda #$B0
    jsr write_bank
    ; Write $B1 to bank 1
    ldx #$01
    lda #$B1
    jsr write_bank
    ; Write $B4 to bank 4
    ldx #$04
    lda #$B4
    jsr write_bank
    ; Write $B8 to bank 8
    ldx #$08
    lda #$B8
    jsr write_bank
    
    lda #<msg_done
    ldy #>msg_done
    jsr STROUT
    
    ; ───────────────────────────────────────
    ; Test 2: Read back all banks and display
    ; ───────────────────────────────────────
    lda #<msg_test2
    ldy #>msg_test2
    jsr STROUT
    
    ; Read bank 0
    lda #<msg_bank0
    ldy #>msg_bank0
    jsr STROUT
    ldx #$00
    jsr read_bank
    jsr print_hex
    jsr print_cr
    
    ; Read bank 1
    lda #<msg_bank1
    ldy #>msg_bank1
    jsr STROUT
    ldx #$01
    jsr read_bank
    jsr print_hex
    jsr print_cr
    
    ; Read bank 4
    lda #<msg_bank4
    ldy #>msg_bank4
    jsr STROUT
    ldx #$04
    jsr read_bank
    jsr print_hex
    jsr print_cr
    
    ; Read bank 8
    lda #<msg_bank8
    ldy #>msg_bank8
    jsr STROUT
    ldx #$08
    jsr read_bank
    jsr print_hex
    jsr print_cr
    
    ; ───────────────────────────────────────
    ; Analysis
    ; ───────────────────────────────────────
    lda #<msg_analysis
    ldy #>msg_analysis
    jsr STROUT
    
    ; Check bank 0
    ldx #$00
    jsr read_bank
    cmp #$B0
    bne unexpected0
    cmp #$B4
    beq aliased04
    cmp #$B8
    beq aliased08
    jmp check_bank4
    
unexpected0:
    lda #<msg_corrupt
    ldy #>msg_corrupt
    jsr STROUT
    jmp done
    
aliased04:
    lda #<msg_256k
    ldy #>msg_256k
    jsr STROUT
    jmp done
    
aliased08:
    lda #<msg_512k
    ldy #>msg_512k
    jsr STROUT
    jmp done
    
check_bank4:
    ; Bank 0 still has $B0, check if bank 4 is independent
    ldx #$04
    jsr read_bank
    cmp #$B4
    bne unexpected4
    
    ; Bank 4 has $B4 (independent), check bank 8
    ldx #$08
    jsr read_bank
    cmp #$B8
    bne unexpected8
    
    ; All banks independent
    lda #<msg_16mb
    ldy #>msg_16mb
    jsr STROUT
    jmp done
    
unexpected4:
    lda #<msg_corrupt
    ldy #>msg_corrupt
    jsr STROUT
    jmp done
    
unexpected8:
    lda #<msg_corrupt
    ldy #>msg_corrupt
    jsr STROUT

done:
    rts

; ───────────────────────────────────────
; write_bank: write A to bank X
; ───────────────────────────────────────
write_bank:
    sta zp_value
    stx zp_bank
    
    lda #<zp_value
    sta REU_C64_LO
    lda #>zp_value
    sta REU_C64_HI
    lda #$00
    sta REU_REU_LO
    sta REU_REU_HI
    lda zp_bank
    sta REU_REU_BANK
    lda #$01
    sta REU_LEN_LO
    lda #$00
    sta REU_LEN_HI
    lda #REU_CMD_C64_TO_REU
    sta REU_COMMAND
    jsr wait_eob
    rts

; ───────────────────────────────────────
; read_bank: read from bank X into A
; ───────────────────────────────────────
read_bank:
    stx zp_bank
    
    lda #<zp_result
    sta REU_C64_LO
    lda #>zp_result
    sta REU_C64_HI
    lda #$00
    sta REU_REU_LO
    sta REU_REU_HI
    lda zp_bank
    sta REU_REU_BANK
    lda #$01
    sta REU_LEN_LO
    lda #$00
    sta REU_LEN_HI
    lda #REU_CMD_REU_TO_C64
    sta REU_COMMAND
    jsr wait_eob
    
    lda zp_result
    rts

wait_eob:
    lda REU_STATUS
    and #REU_STATUS_EOB
    beq wait_eob
    rts

print_hex:
    pha
    lsr
    lsr
    lsr
    lsr
    tax
    lda hex_digits,x
    jsr CHROUT
    pla
    and #$0f
    tax
    lda hex_digits,x
    jsr CHROUT
    rts

print_cr:
    lda #$0d
    jsr CHROUT
    rts

hex_digits:
    .text "0123456789abcdef"

msg_test1:
    .text "test 1: writing unique values",$0d
    .text "  bank 0 = $b0",$0d
    .text "  bank 1 = $b1",$0d
    .text "  bank 4 = $b4",$0d
    .null "  bank 8 = $b8",$0d

msg_done:
    .null "done.",$0d,$0d

msg_test2:
    .null "test 2: reading back",$0d

msg_bank0: .null "  bank 0 = $"
msg_bank1: .null "  bank 1 = $"
msg_bank4: .null "  bank 4 = $"
msg_bank8: .null "  bank 8 = $"

msg_analysis:
    .null $0d,"analysis:",$0d

msg_256k:
    .text "  bank 0 changed to $b4",$0d
    .text "  bank 4 aliased to bank 0",$0d
    .null "  result: 256kb behavior",$0d

msg_512k:
    .text "  bank 0 changed to $b8",$0d
    .text "  bank 8 aliased to bank 0",$0d
    .null "  result: 512kb behavior (VICE BUG)",$0d

msg_16mb:
    .text "  all banks independent",$0d
    .text "  no aliasing detected",$0d
    .null "  result: full storage allocated",$0d

msg_corrupt:
    .null "  unexpected values - data corrupted",$0d
