reu_init
    ; display header
    #BASIC_STROUT_MACRO msg_header
    
    ; detect reu presence and size
    #REU_DETECT no_reu_found
    
    ; A register now contains bank mask
    ; save it for later use
    sta detected_size
    
    ; display success message
    #BASIC_STROUT_MACRO msg_detected
    
    ; convert mask to KB and display
    jsr display_size
    
    ; show bank mask in hex
    #BASIC_STROUT_MACRO msg_mask
    lda detected_size
    jsr Output_ByteToHex
    
    #BASIC_STROUT_MACRO msg_complete
    rts

; ────────────────────────────────────────────────────────────
; no reu found handler
; ────────────────────────────────────────────────────────────
no_reu_found
    #BASIC_STROUT_MACRO msg_no_reu
    rts

; ────────────────────────────────────────────────────────────
; display_size: convert bank mask to KB and print
; input: detected_size contains bank mask
; ────────────────────────────────────────────────────────────
display_size
    lda detected_size

    ; check for each known size (largest to smallest)
    cmp #$FF
    beq size_16mb
    cmp #$7F
    beq size_8mb
    cmp #$3F
    beq size_4mb
    cmp #$1F
    beq size_2mb
    cmp #$0F
    beq size_1mb
    cmp #$07
    beq size_512k
    cmp #$03
    beq size_256k
    cmp #$01
    beq size_128k
    
    ; unknown size
    #BASIC_STROUT_MACRO msg_unknown
    rts
    
size_128k
    #BASIC_STROUT_MACRO msg_128k
    rts
    
size_256k
    #BASIC_STROUT_MACRO msg_256k
    rts
    
size_512k
    #BASIC_STROUT_MACRO msg_512k
    rts
    
size_1mb
    #BASIC_STROUT_MACRO msg_1mb
    rts
    
size_2mb
    #BASIC_STROUT_MACRO msg_2mb
    rts
    
size_4mb
    #BASIC_STROUT_MACRO msg_4mb
    rts
    
size_8mb
    #BASIC_STROUT_MACRO msg_8mb
    rts
    
size_16mb
    #BASIC_STROUT_MACRO msg_16mb
    rts

; ────────────────────────────────────────────────────────────
; data section
; ────────────────────────────────────────────────────────────
detected_size   .byte 0
msg_header      .null "reu detection test",13,13
msg_detected    .null "reu detected!",13,"size "
msg_mask        .null 13,"bank mask: $"
msg_complete    .null 13,13,"test complete.",13
msg_no_reu      .null "no reu detected!",13,13
msg_128k        .null "128 kb (1700)"
msg_256k        .null "256 kb (1764)"
msg_512k        .null "512 kb (1750)"
msg_1mb         .null "1 mb"
msg_2mb         .null "2 mb"
msg_4mb         .null "4 mb"
msg_8mb         .null "8 mb"
msg_16mb        .null "16 mb (vice/c64u max)"
msg_unknown     .null "unknown"
