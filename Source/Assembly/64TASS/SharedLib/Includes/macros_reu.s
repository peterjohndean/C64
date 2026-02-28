; ============================================================
; MACRO: REU_QUICK_DETECT
; Purpose : Detect presence of a RAM Expansion Unit (REU)
;           by probing the REU bank register ($DF06).
;           Branches to the given label if no REU is found.
; Params  : label  - branch target if REU is not detected
; Destroys: Accumulator (A register)
; Notes   : REU_REU_BANK returns $00 when no REU is present.
;           A non-zero result also encodes installed RAM size:
;           $01=128KB, $03=256KB, $07=512KB, $0F=1MB, etc.
; Cycles  : ~30 cycles (branch not taken / REU present)
; ============================================================
REU_QUICK_DETECT .macro label
    ; ensure registers are in known state first
    lda #$00
    sta REU_REU_LO      ; clear reu address low
    sta REU_REU_HI      ; clear reu address mid
    sta REU_REU_BANK    ; clear reu address high
    
    ; read back the bank register
    lda REU_REU_BANK
    
    ; Check if zero (no REU)
    ; On systems without REU, this address reads as $00
    ; or sometimes $ff depending on bus state
    beq \label      ; branch if zero (no REU detected)
    
    ; If we reach here, REU is present
    ; A register contains the REU size value
.endmacro

; ============================================================
; MACRO: REU_DETECT
; Purpose : Detect RAM Expansion Unit (REU) presence and size
;           Tests aliasing at power-of-2 boundaries
; Params  : label  - branch target if REU is not detected
; Returns : A register contains bank mask on success:
;             $01 →  128 KB (1700) - 2 banks
;             $03 →  256 KB (1764) - 4 banks
;             $07 →  512 KB (1750) - 8 banks
;             $0F →    1 MB        - 16 banks
;             $1F →    2 MB        - 32 banks
;             $3F →    4 MB        - 64 banks
;             $7F →    8 MB        - 128 banks
;             $FF →   16 MB (VICE) - 256 banks
; Destroys: A register, zero page $FB-$FD
; Strategy: 1. Quick detect for presence and real hardware
;           2. Write $55 to bank 0, $AA to test bank
;           3. Read bank 0 - if $AA, aliasing detected
; Note    : CRITICAL - must wait for each transfer to complete!
; ============================================================
REU_DETECT .macro label
    ; ────────────────────────────────────────────────────────
    ; step 1: quick presence check using REU_QUICK_DETECT
    ; ────────────────────────────────────────────────────────
    #REU_QUICK_DETECT \label
    
    ; ────────────────────────────────────────────────────────
    ; step 2: check if we got a valid size value
    ; ────────────────────────────────────────────────────────
    
    ; real hardware returns: $01, $03, $07, $0F
    ; vice emulator returns: $F8 (broken)
    cmp #$F8
    beq reu_probe_banks\@   ; vice detected, need to probe
    
    ; if A = $01, $03, $07, or $0F, trust it
    cmp #$10
    bcc reu_done\@          ; if < $10, likely valid, use it
    
reu_probe_banks\@
    ; ────────────────────────────────────────────────────────
    ; step 3: test for aliasing at each power-of-2 boundary
    ; write $55 to bank 0, then $AA to test address
    ; if bank 0 becomes $AA, aliasing detected
    ; ────────────────────────────────────────────────────────
    
    ; test 128KB - does $020000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $020000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_128k\@
    
    ; test 256KB - does $040000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $040000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_256k\@
    
    ; test 512KB - does $080000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $080000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_512k\@
    
    ; test 1MB - does $100000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $100000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_1mb\@
    
    ; test 2MB - does $200000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $200000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_2mb\@
    
    ; test 4MB - does $400000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $400000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_4mb\@
    
    ; test 8MB - does $800000 alias to $000000?
    lda #$55
    sta $FB
    #REU_FROM_C64 $000000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    lda #$AA
    sta $FB
    #REU_FROM_C64 $800000, $FB, 1
    jsr REU_WAIT_EOB_PROC
    #REU_TO_C64 $000000, $FD, 1
    jsr REU_WAIT_EOB_PROC
    lda $FD
    cmp #$AA
    beq reu_is_8mb\@
    
    ; no aliasing detected - assume 16MB
    jmp reu_is_16mb\@
    
reu_is_128k\@
    lda #$01                ; 2 banks (0-1)
    jmp reu_done\@
    
reu_is_256k\@
    lda #$03                ; 4 banks (0-3)
    jmp reu_done\@
    
reu_is_512k\@
    lda #$07                ; 8 banks (0-7)
    jmp reu_done\@
    
reu_is_1mb\@
    lda #$0F                ; 16 banks (0-15)
    jmp reu_done\@
    
reu_is_2mb\@
    lda #$1F                ; 32 banks (0-31)
    jmp reu_done\@
    
reu_is_4mb\@
    lda #$3F                ; 64 banks (0-63)
    jmp reu_done\@
    
reu_is_8mb\@
    lda #$7F                ; 128 banks (0-127)
    jmp reu_done\@
    
reu_is_16mb\@
    lda #$FF                ; 256 banks (0-255, VICE max)
    
reu_done\@
    ; A now contains the bank mask
.endmacro

; ============================================================
; MACRO: REU_FROM_C64
; Purpose : Copy data FROM C64 RAM -> TO REU RAM
; Params  : rAddress - 24-bit REU  destination address
;           cAddress - 16-bit C64  source address
;           tLength  - 16-bit number of bytes to transfer (1-65536)
; Destroys: Accumulator (A register)
; Cycles  : ~20 cycles + REU DMA time
; ============================================================
REU_FROM_C64 .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 SOURCE address ---
    lda #<\cAddress        ; Low  byte of C64 address
    sta REU_C64_LO
    lda #>\cAddress        ; High byte of C64 address
    sta REU_C64_HI

    ; --- Step 2: Set the REU DESTINATION address (24-bit) ---
    lda #<\rAddress        ; Low  byte of REU address (bits  0-7)
    sta REU_REU_LO
    lda #>\rAddress        ; High byte of REU address (bits  8-15)
    sta REU_REU_HI
    lda #`\rAddress        ; Bank byte of REU address (bits 16-23)
    sta REU_REU_BANK        ; Use ` operator in 64tass for byte 2

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength         ; Low  byte of length
    sta REU_LEN_LO
    lda #>\tLength         ; High byte of length (0 for <256 bytes)
    sta REU_LEN_HI

    ; --- Step 4: Execute! Writing the command register starts the DMA ---
    ; The CPU is halted by the REU during the transfer (transparent DMA)
    lda #REU_CMD_C64_TO_REU ; $90 - Execute + C64->REU
    sta REU_COMMAND         ; GO! CPU stalls until done
.endmacro

; ============================================================
; MACRO: REU_TO_C64
; Purpose : Copy data FROM REU RAM -> TO C64 RAM
; Params  : rAddress - 24-bit REU  source address
;           cAddress - 16-bit C64  destination address
;           tLength  - 16-bit number of bytes to transfer
; Destroys: Accumulator (A register)
; ============================================================
REU_TO_C64 .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 DESTINATION address ---
    lda #<\cAddress
    sta REU_C64_LO
    lda #>\cAddress
    sta REU_C64_HI

    ; --- Step 2: Set the REU SOURCE address (24-bit) ---
    lda #<\rAddress
    sta REU_REU_LO
    lda #>\rAddress
    sta REU_REU_HI
    lda #`\rAddress        ; Bank byte using 64tass ` operator
    sta REU_REU_BANK

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength
    sta REU_LEN_LO
    lda #>\tLength
    sta REU_LEN_HI

    ; --- Step 4: Execute! ---
    lda #REU_CMD_REU_TO_C64 ; $91 - Execute + REU->C64
    sta REU_COMMAND         ; GO! CPU stalls until done
.endmacro

; ============================================================
; MACRO: REU_SWAP
; Purpose : SIMULTANEOUSLY swap blocks between C64 and REU
;           This is the REU's killer feature - true atomic swap!
;           Neither buffer needs a temporary area.
; Params  : rAddress - 24-bit REU  address
;           cAddress - 16-bit C64  address
;           tLength  - 16-bit number of bytes to swap
; Destroys: Accumulator (A register)
; Note    : After swap, C64 has REU data, REU has C64 data
; ============================================================
REU_SWAP .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 address (source AND destination) ---
    lda #<\cAddress
    sta REU_C64_LO
    lda #>\cAddress
    sta REU_C64_HI

    ; --- Step 2: Set the REU address (source AND destination) ---
    lda #<\rAddress
    sta REU_REU_LO
    lda #>\rAddress
    sta REU_REU_HI
    lda #`\rAddress
    sta REU_REU_BANK

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength
    sta REU_LEN_LO
    lda #>\tLength
    sta REU_LEN_HI

    ; --- Step 4: Execute! ---
    lda #REU_CMD_SWAP       ; $92 - Execute + Swap
    sta REU_COMMAND         ; GO! Both regions exchanged simultaneously
.endmacro

; ============================================================
; MACRO: REU_WAIT_EOB_MACRO
; Purpose : Busy-wait (poll) until transfer completes
; Use     : Call immediately after triggering a transfer
; Caution : This is a blocking loop - consider interrupt
;           driven approach for time critical code
; ============================================================
REU_WAIT_EOB_MACRO .macro
reu_wait_loop\@
    lda REU_STATUS      ; Read status (clears on read!)
    and #REU_STATUS_EOB ; Test bit 6
    beq reu_wait_loop\@ ; Loop until End of Block set
.endmacro

REU_WAIT_EOB_PROC .proc
    #REU_WAIT_EOB_MACRO
    rts
.endproc
