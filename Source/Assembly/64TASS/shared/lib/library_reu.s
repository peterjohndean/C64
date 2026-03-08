; ============================================================
; PROCEDURE: REU_WAIT_EOB_PROC
; Purpose : Subroutine version of REU_WAIT_EOB_MACRO. Can be
;           called with JSR for code size optimization when
;           wait is needed in multiple places.
; Params  : None
; Returns : None (A register contains final status byte)
; Destroys: Accumulator (A register)
; Algorithm: 1. Expand REU_WAIT_EOB_MACRO inline
;            2. Return to caller via RTS
; Notes   : Use this instead of the macro when:
;           - Multiple locations need to wait for EOB
;           - Code size is more important than speed
;           - The JSR/RTS overhead (12 cycles) is acceptable
;           
;           Use the macro instead when:
;           - Maximum speed is critical
;           - Only 1-2 wait locations in entire program
;           - Inline expansion doesn't significantly increase size
;           
;           Trade-off analysis:
;           Macro: 0 call overhead, ~8 bytes per use
;           Proc:  12 cycle overhead, 3 bytes per use (JSR)
; Cycles  : Variable wait time + 12 cycles (JSR/RTS overhead)
; Example : #REU_FROM_C64 $000000, $C000, 1000
;           jsr REU_WAIT_EOB_PROC
;           ; transfer complete, safe to continue
; ============================================================
REU_WAIT_EOB_PROC .proc
    #REU_WAIT_EOB_MACRO     ; expand the macro inline
    rts                     ; return to caller
.endproc

; ============================================================
; PROCEDURE: REU_ALIASING_DETECT_PROC
; Purpose : Detect RAM Expansion Unit (REU) presence and size
;           by testing aliasing at power-of-2 boundaries.
;           More reliable than REU_QUICK_DETECT for determining
;           exact size, especially with VICE emulator.
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
; Destroys: A register, zero page $FB/$FD
; Algorithm: 1. Quick detect for presence (REU_QUICK_DETECT)
;            2. For each power-of-2 boundary:
;               a. Write $55 to bank 0, offset $0000
;               b. Write $AA to test bank, offset $0000
;               c. Read back bank 0, offset $0000
;               d. If value is $AA, aliasing detected - done
;            3. Return bank mask based on aliasing threshold
; Strategy: Write $55 to bank 0, $AA to test bank
;           Read bank 0 - if $AA, aliasing detected
; Notes   : CRITICAL - must wait for each transfer to complete!
;           Requires REU_WAIT_EOB_PROC to be defined.
;           VICE BUG: VICE 256KB REU is misdetected as 512KB
;           due to incorrect aliasing in VICE's 1764 emulation.
;           Real hardware (C64U) detects all sizes correctly.
;           See VICE_256KB_BUG.md for details.
; Cycles  : Variable - depends on REU size (more tests for larger)
; ============================================================
REU_ALIASING_DETECT_PROC .proc
    
reu_probe_banks
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
    beq reu_is_128k
    
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
    beq reu_is_256k
    
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
    beq reu_is_512k
    
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
    beq reu_is_1mb
    
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
    beq reu_is_2mb
    
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
    beq reu_is_4mb
    
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
    beq reu_is_8mb
    
    ; no aliasing detected - assume 16MB
    jmp reu_is_16mb
    
reu_is_128k
    lda #$01                ; 2 banks (0-1)
    jmp reu_done
    
reu_is_256k
    lda #$03                ; 4 banks (0-3)
    jmp reu_done
    
reu_is_512k
    lda #$07                ; 8 banks (0-7)
    jmp reu_done
    
reu_is_1mb
    lda #$0F                ; 16 banks (0-15)
    jmp reu_done
    
reu_is_2mb
    lda #$1F                ; 32 banks (0-31)
    jmp reu_done
    
reu_is_4mb
    lda #$3F                ; 64 banks (0-63)
    jmp reu_done
    
reu_is_8mb
    lda #$7F                ; 128 banks (0-127)
    jmp reu_done
    
reu_is_16mb
    lda #$FF                ; 256 banks (0-255, VICE max)
    
reu_done
    ; A now contains the bank mask
    rts
.endproc

; ============================================================
; PROCEDURE : REU_DETECT_SIZE_PROC
; Project   : Commodore 64 REU Library
; Target    : Commodore 64 / 6510 CPU
; Assembler : 64TASS v1.60+
; ============================================================
; PURPOSE
; -------
; Determines the number of independent 64KB banks in the
; installed REU by writing a unique "fingerprint" byte into
; every bank, then reading each bank back in sequence and
; counting how many return their own index in ascending order.
;
; This is the FINGERPRINT METHOD — distinct from the aliasing
; boundary method used by REU_ALIASING_DETECT_PROC. Where the
; aliasing method probes one power-of-2 boundary at a time,
; the fingerprint method writes to ALL 256 possible banks
; first, then reads them all back, letting alias behaviour
; reveal itself naturally as a broken ascending sequence.
;
; COMPARISON — fingerprint vs aliasing
; ----------------------------------------
;   REU_ALIASING_DETECT_PROC    : probes boundaries in order,
;     asks "does bank N mirror bank 0?" at $02/$04/$08/...
;     Returns a bank mask ($01/$03/$07...) not a bank count.
;
;   REU_DETECT_SIZE_PROC        : writes all 256 banks first,
;     then reads all 256 back, counting the unbroken ascending
;     run. Returns a bank count directly. Catches edge cases
;     such as the 16MB VICE configuration and the 256KB VICE bug
;     that the aliasing method does not handle reliably.
;
; HOW ALIASING EXPOSES ITSELF
; ---------------------------
; When the CPU writes fingerprint X to bank X and that bank
; aliases (maps) to an earlier physical bank, it silently
; overwrites whatever was written there before. By the time all
; 256 writes are done, only the LAST alias write to each
; physical location survives.
;
; For a 256KB REU (4 real banks, banks 0-3):
;   bank  0 maps to physical bank 0
;   bank  4 maps to physical bank 0  ← overwrites bank 0's $00
;   bank  8 maps to physical bank 0  ← overwrites again
;   ...
;   bank 252 maps to physical bank 0 ← last write, survives
;   bank 253 maps to physical bank 1
;   bank 254 maps to physical bank 2
;   bank 255 maps to physical bank 3
;
; Phase 2 reads back and checks n > prev:
;   bank 0 → reads $FC (252, NOT 0)     — fails n>prev → stop
;   confirmed count = 0? → special-case: re-read bank 0
;   bank 0 = $FC ≠ $00 → not 16MB → genuine fail?
;
;   Wait — the phase 2 loop correctly reads banks 0, 1, 2, 3
;   and gets $FC, $FD, $FE, $FF (252-255) — each > the previous
;   → counts 4 banks → zp_count = 4 → 256KB ✓
;
; RETURN VALUES
; -------------
; zp_count holds the confirmed bank count on exit.
; Multiply by 64 to obtain total kilobytes.
;
;   zp_count | Banks | Total KB | Model
;   ---------+-------+----------+--------------------------
;     $02    |     2 |  128 KB  | Commodore 1700 REU
;     $04    |     4 |  256 KB  | Commodore 1764 REU (real hw)
;     $05    |     5 |  320 KB  | VICE 256KB bug — clamped to $04
;     $08    |     8 |  512 KB  | Commodore 1750 REU
;     $FF    |   256 | 16384 KB | VICE 16MB configuration
;     $00    |     0 |      0   | Detection failure
;
; ALGORITHM
; ---------
; Phase 1 — Plant fingerprints (BASIC lines 60-65):
;   For x = 0 to 255:
;     1. Write bank index x into C64 staging byte (DMA_BYTE)
;     2. SWAP DMA_BYTE with REU[bank x, $0000]
;        → REU[x,$0000] = x            (fingerprint planted)
;        → DMA_BYTE     = old REU byte (displaced original)
;     3. Save displaced original: REU_BUF[x] = DMA_BYTE
;
; Phase 2 — Count ascending run (BASIC lines 70-110):
;   prev = 0
;   For x = 0 to 255:
;     1. Read REU[bank x, $0000] → DMA_BYTE (n)
;     2. If n ≤ prev: stop, record x as bank count
;     3. If n > prev: prev = n, continue
;   Simple exact-match (n == x) fails because aliasing causes
;   bank 0 to hold the LAST alias's index, not 0. The n > prev
;   test is immune to this: it only cares that values ascend.
;
; Phase 2 special case — 16MB detection:
;   If count = 0 on exit, bank 0 returned a value not > 0.
;   This has two causes:
;     a. Genuine failure (bank 0 aliased and got clobbered)
;     b. True 16MB: bank 0's fingerprint IS 0, which cannot
;        satisfy n > 0 (prev also starts at 0)
;   Resolution: re-read bank 0. If it still holds $00, the
;   fingerprint is intact — 256 independent banks → 16MB.
;   If it holds anything else, aliasing corrupted it → failure.
;
; Phase 3 — Restore REU contents:
;   For x = 255 downto 0:
;     1. DMA_BYTE = REU_BUF[x]      (saved original)
;     2. Write DMA_BYTE → REU[bank x, $0000]
;   Descending order is REQUIRED. If a bank aliases downward
;   (e.g. bank 4 → physical bank 0), restoring in ascending
;   order would re-clobber the lower bank's original content
;   before we have a chance to write it. Descending ensures
;   physical bank 0 is written last, so it ends up holding
;   the value from REU_BUF[0] — its own original content.
;
; VICE 256KB BUG
; --------------
; VICE's 256KB (1764) emulation misreports its aliasing
; boundary, causing this procedure to count 5 banks (320KB)
; instead of the correct 4 (256KB). The final check clamps
; zp_count from $05 to $04 before returning. Real hardware
; (C64U) is unaffected and reports the correct count.
; See VICE_256KB_BUG.md for a detailed analysis.
;
; MEMORY LAYOUT (C64 RAM)
; -----------------------
; All storage lives at the END of this .proc block, assembled
; inline immediately after the code. 64TASS .proc scoping
; keeps the labels local and invisible to other modules.
;
;   DMA_BYTE  ($+n, 1 byte)   - one-byte DMA staging window
;   REU_BUF   ($+n+1, 256 bytes) - saved originals, indexed
;                                  by bank number (REU_BUF+0
;                                  to REU_BUF+255)
;
; ZERO PAGE
; ---------
;   $FB  zp_prev  - phase 2 rolling maximum (prev / o)
;   $FC  zp_count - result: confirmed 64KB bank count
;
; REGISTER USE
; ------------
;   Entry : none required
;   A     : working register throughout all three phases
;   X     : bank loop counter (0-255 wrapping)
;   Y     : not used
;   On exit, A = zp_count (bank count), X = $FF
;
; DESTROYS  : A, X, zp_prev ($FB), zp_count ($FC)
; PRESERVES : Y
;
; DEPENDENCIES
; ------------
;   macros_reu.s must be included before this file:
;     REU_FROM_C64_B  - programs REU registers and fires DMA
;     REU_TO_C64_B    - reads one byte from REU into C64 RAM
;   library_reu.s must be included before this file:
;     REU_WAIT_EOB_PROC - polls $DF00 until bit 6 (EOB) set
;
; CYCLES    : Variable — dominated by DMA overhead × 768 calls
;             (256 SWAPs + 256 reads + 256 restores)
;             plus one or two extra reads for the 16MB check.
; EXAMPLE
; -------
;     jsr REU_FETCH_SIZE_PROC  ; run detection
;     lda zp_count             ; A = bank count (0-255/$FF)
;     ; multiply by 64 for total KB, e.g.:
;     ;   2 → 128KB   4 → 256KB   8 → 512KB   $FF → 16384KB
; ============================================================
REU_DETECT_SIZE_PROC .proc
; ── zero page aliases ────────────────────────────────────────
zp_prev         = $fb           ; phase 2 rolling maximum (prev)
zp_count        = $fc           ; result: confirmed 64KB bank count

    ; ══════════════════════════════════════════════════════════
    ; PHASE 1 — PLANT FINGERPRINTS
    ; Translated from BASIC lines 60-65.
    ;
    ; For every possible bank index (0-255), write the bank's
    ; own index value into REU[bank, $0000] using a SWAP. The
    ; SWAP command ($92) exchanges C64[DMA_BYTE] with the target
    ; REU byte atomically in a single DMA pass:
    ;
    ;   BEFORE swap: DMA_BYTE = x,   REU[x,$0000] = original
    ;   AFTER  swap: DMA_BYTE = original, REU[x,$0000] = x
    ;
    ; The displaced original lands in DMA_BYTE, from where it
    ; is immediately saved to REU_BUF[x] for phase 3 restore.
    ;
    ; WHY SWAP AND NOT A PLAIN WRITE?
    ; A plain C64→REU write ($90) would overwrite the REU byte
    ; with no way to recover the original. SWAP lets us plant
    ; the fingerprint AND retrieve the original in one DMA pass
    ; — saving one DMA call per bank compared to a
    ; read-then-write sequence.
    ;
    ; WHY WRITE ALL 256 BANKS BEFORE READING ANY BACK?
    ; If we wrote then immediately read each bank, aliased banks
    ; would appear correct because the write and read happen
    ; before any alias can overwrite the location. Writing ALL
    ; banks first lets later alias writes propagate naturally,
    ; so phase 2 reads the final settled state of each physical
    ; location — which is the only state that reliably reveals
    ; aliasing.
    ; ══════════════════════════════════════════════════════════
    ldx #$00                    ; start at bank 0, loop all 256

phase1_loop

    ; --- plant fingerprint: DMA_BYTE = bank index x -----------
    stx DMA_BYTE                ; stage the fingerprint value

    ; --- SWAP: C64[DMA_BYTE] ↔ REU[bank x, $0000] ------------
    ; REU_FROM_C64_B with tCommand=$92 performs the SWAP.
    ; No dedicated REU_SWAP_B macro is needed — the optional
    ; tCommand parameter of REU_FROM_C64_B handles this.
    ; BASIC used $B2 (swap + FF00/Kernal-fire mode); assembly
    ; uses $92 (swap + immediate-fire, no Kernal involvement).
    #REU_FROM_C64_B stx, $0000, DMA_BYTE, 1, $92
    jsr REU_WAIT_EOB_PROC       ; wait for DMA to complete

    ; --- save displaced original to REU_BUF[x] ---------------
    ; after the swap, DMA_BYTE holds the old REU byte that was
    ; at REU[bank x, $0000] before we planted our fingerprint.
    ; BASIC equivalent: poke s+1+b, peek(s)
    lda DMA_BYTE                ; old REU byte (displaced by swap)
    sta REU_BUF,x               ; REU_BUF+x = saved original

    inx                         ; advance to next bank
    bne phase1_loop             ; repeat until x wraps $FF→$00

    ; ══════════════════════════════════════════════════════════
    ; PHASE 2 — COUNT ASCENDING FINGERPRINT RUN
    ; Translated from BASIC lines 70-110.
    ;
    ; Read back REU[bank x, $0000] for each x = 0..255 and
    ; count how many consecutive values satisfy n > prev.
    ; The first value that fails (n ≤ prev) terminates the count.
    ;
    ; WHY n > prev AND NOT n == x?
    ; For a real 256KB REU (banks 0-3), all 256 phase 1 writes
    ; aliased into just 4 physical locations. The LAST write to
    ; reach each physical bank determines its final value:
    ;
    ;   physical bank 0 ← last alias = bank 252 → holds $FC
    ;   physical bank 1 ← last alias = bank 253 → holds $FD
    ;   physical bank 2 ← last alias = bank 254 → holds $FE
    ;   physical bank 3 ← last alias = bank 255 → holds $FF
    ;
    ; Reading back in order gives: $FC, $FD, $FE, $FF — each
    ; strictly greater than the last. The n > prev test counts
    ; all four and stops at bank 4 (where the cycle repeats
    ; from $FC, which is NOT > $FF). Result: 4 banks = 256KB ✓
    ;
    ; An exact match (cmp bank_index) would fail immediately
    ; on bank 0, because bank 0 holds $FC, not $00.
    ; ══════════════════════════════════════════════════════════
    ldx #$00                    ; start at bank 0
    txa                         ; A = $00, initialise prev = 0
    sta zp_prev                 ; BASIC: o = 0

phase2_loop

    ; --- read REU[bank x, $0000] → DMA_BYTE (n) --------------
    ; BASIC used $B1 (reu→c64 + FF00 mode); assembly uses $91
    ; (reu→c64 + immediate, the REU_TO_C64_B default).
    #REU_TO_C64_B stx, $0000, DMA_BYTE, 1
    jsr REU_WAIT_EOB_PROC       ; wait for read to complete

    ; --- n > prev check: is the sequence still ascending? -----
    ; BASIC: if n > o then o = n : b = b + 1 : goto 80
    lda DMA_BYTE                ; n = value just read from REU
    cmp zp_prev                 ; compare n with prev (unsigned)
    bcc phase2_done             ; n < prev → sequence broken, done
    beq phase2_done             ; n = prev → sequence stalled, done

    ; n > prev: genuine new bank, update rolling maximum
    sta zp_prev                 ; prev = n  (BASIC: o = n)
    inx                         ; bank count + 1
    bne phase2_loop             ; loop until x wraps (all 256 read)

phase2_done

    stx zp_count                ; record however many banks passed

    ; ── special case: 16MB detection ─────────────────────────
    ; If zp_count = 0, the very first read failed (bank 0
    ; returned a value not > prev=0). Two possible causes:
    ;
    ;   a. ALIASED REU  : bank 0 holds the last alias index
    ;      (not zero), but that value is still ≤ 0? Impossible
    ;      — any non-zero value would satisfy n > 0. So a count
    ;      of 0 here actually means bank 0 READ BACK AS ZERO.
    ;
    ;   b. 16MB REU     : 256 fully independent banks, each
    ;      holding its own fingerprint intact. Bank 0 planted
    ;      fingerprint $00 and still holds $00. Because prev
    ;      is also initialised to $00, n == prev triggers beq
    ;      phase2_done on the first iteration → count = 0.
    ;
    ; Resolution: re-read bank 0. If it still holds exactly $00,
    ; the fingerprint survived untouched → no aliasing occurred
    ; → all 256 banks are independent → 16MB confirmed.
    ; Any other value indicates aliasing or hardware failure.
    lda zp_count
    bne phase2_end              ; non-zero result: skip 16MB check

    ldx #$00                    ; re-read bank 0 to diagnose
    #REU_TO_C64_B stx, $0000, DMA_BYTE, 1
    jsr REU_WAIT_EOB_PROC

    lda DMA_BYTE                ; what did bank 0 return?
    bne phase2_end              ; non-zero: not 16MB, leave count=0

    ; bank 0 returned $00 exactly — fingerprint is intact,
    ; confirming 256 independent banks = 16MB total
    lda #$ff                    ; $FF encodes 256 banks
    sta zp_count

phase2_end

    ; phase 3 must iterate x = 255 downto 0. Without this
    ; initialisation, X holds $00 from the 16MB re-read path,
    ; which would cause phase 3 to restore only bank 0.
    ldx #$ff

    ; ══════════════════════════════════════════════════════════
    ; PHASE 3 — RESTORE ORIGINAL REU CONTENTS
    ; Translated from BASIC lines 120-130 (step -1).
    ;
    ; Write each REU[bank x, $0000] back from REU_BUF[x] so
    ; that the REU is left in the state it was found in.
    ;
    ; WHY DESCEND FROM BANK 255 TO BANK 0?
    ; Consider a 256KB REU where banks 4..255 alias to banks
    ; 0..3. When restoring in ASCENDING order:
    ;
    ;   restore bank 0 → physical bank 0 = REU_BUF[0] ✓
    ;   restore bank 4 → physical bank 0 = REU_BUF[4] ✗ (clobbers bank 0)
    ;   ...
    ;   restore bank 252 → physical bank 0 = REU_BUF[252] ✗
    ;   restore bank 256 → ... physical bank 0 ends with wrong value
    ;
    ; In DESCENDING order:
    ;
    ;   restore bank 255 → physical bank 3 = REU_BUF[255]
    ;   ...
    ;   restore bank 4   → physical bank 0 = REU_BUF[4]
    ;   restore bank 3   → physical bank 3 = REU_BUF[3]  ✓
    ;   restore bank 2   → physical bank 2 = REU_BUF[2]  ✓
    ;   restore bank 1   → physical bank 1 = REU_BUF[1]  ✓
    ;   restore bank 0   → physical bank 0 = REU_BUF[0]  ✓ (last write wins)
    ;
    ; Bank 0 is written last, guaranteeing its physical location
    ; ends up with REU_BUF[0] — the original pre-detection value.
    ; ══════════════════════════════════════════════════════════

phase3_loop

    ; --- reload saved original into DMA_BYTE -----------------
    ; BASIC: poke s, peek(s+1+b)
    lda REU_BUF,x               ; REU_BUF[x] = saved original byte
    sta DMA_BYTE                ; stage it for DMA

    ; --- write DMA_BYTE → REU[bank x, $0000] -----------------
    ; plain C64→REU transfer ($90, the default tCommand)
    #REU_FROM_C64_B stx, $0000, DMA_BYTE, 1
    jsr REU_WAIT_EOB_PROC       ; wait for write to complete

    dex                         ; next bank downwards
    cpx #$ff                    ; did x wrap $00 → $FF?
    bne phase3_loop             ; no: keep restoring

    ; ── VICE 256KB bug clamp ─────────────────────────────────
    ; VICE's 1764 emulation incorrectly reports 5 banks (320KB)
    ; instead of the correct 4 (256KB). No such product existed.
    ; Clamp $05 → $04 so callers receive the canonical value.
    ; Real hardware (C64U) never triggers this branch.
    lda zp_count
    cmp #$05                    ; 5 banks = 320KB: VICE bug only
    bne bank_count_ok
    dec zp_count                ; clamp: $05 → $04 (256KB)

bank_count_ok
    ; ── return confirmed bank count in A ─────────────────────
    ; caller multiplies by 64 to obtain total kilobytes
    lda zp_count
    rts

; ── local data storage ───────────────────────────────────────
DMA_BYTE    .byte $00           ; 1-byte DMA staging window
REU_BUF     .fill 256, $00     ; phase 1 save buffer: REU_BUF[0..255]
                                ; index x = original REU[bank x, $0000]
.endproc
