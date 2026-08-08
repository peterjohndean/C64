.include "labels_memorymap.s"
.include "labels_screen.s"

.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"

.export TEST_WAIT

.import OUTPUT_BYTETODEC

.scope TestRegistry
    .import ntests
.endscope

.scope TestData
    .import test_title
.endscope


TEST_WAIT_LINE = 22             ; Wait at line 22
TEST_WAIT = TEST_WAIT_FOR_KEY

.proc TEST_WAIT_FOR_KEY
    ; -----------------------------------------------------------------
    ; [BUG FIX] Skip pagination entirely when output isn't going to the
    ; screen.
    ;
    ; WHY THIS IS NEEDED (this was the actual "hang")
    ; -------------------------------------------------
    ; The row check below reads MM_TBLX ($D6), the KERNAL's own record
    ; of the SCREEN cursor's current row - it's only ever updated by
    ; real screen output. Printer output goes straight out over the
    ; serial/IEC bus via KERNAL_CHROUT and never touches it. So when
    ; output is redirected to the printer, MM_TBLX isn't "wherever the
    ; print job currently is" - it's simply STALE, frozen at whatever
    ; the last SCREEN write left it at.
    ;
    ; That's harmless on a fresh boot/load, where MM_TBLX starts low
    ; and a printer-only run never pushes it up - the row check always
    ; takes @nowait and everything looks fine, repeatedly. But run a
    ; SCREEN test first (which prints enough lines to drive MM_TBLX up
    ; past TEST_WAIT_LINE, as normal screen output naturally does),
    ; then a PRINTER run right after: the very first TEST_WAIT call in
    ; that printer run reads that stale, already-high MM_TBLX value,
    ; takes the @wait_key branch, and blocks on KERNAL_GETIN waiting
    ; for a keypress nobody watching an unattended print job is going
    ; to provide - indistinguishable from a genuine hang from the
    ; outside (confirmed via VICE monitor: PC sat at $F13E, the real
    ; KERNAL GETIN entry, not stuck inside any of our own code).
    ;
    ; There's a second bug bundled in here too, worth fixing at the
    ; same time since it's the same root cause: even if a key WAS
    ; pressed at that point, the post-wait code below (PETSCII_CLEAR +
    ; reprinting the title) would fire straight through whatever
    ; output channel is CURRENTLY active - sending a clear-screen
    ; control code and the title text out to the printer as garbage,
    ; since none of this logic is aware which device is active.
    ;
    ; THE FIX
    ; --------
    ; main.s already knows which device is active - it reads MM_SAREG
    ; ($030C, peek(780)) exactly once at entry and never modifies it
    ; for the rest of the run (see main.s's own header comment: 0 =
    ; screen, 1 = printer). Reusing that same flag here, rather than
    ; inventing new shared state, means this check can never disagree
    ; with what main.s itself decided - if we're in the printer path,
    ; skip pagination unconditionally; MM_TBLX has no meaningful
    ; relationship to "how far through the print job are we" anyway,
    ; so there's no substitute check to add here, just a reason to
    ; skip this one entirely.
    ; -----------------------------------------------------------------
    lda MM_SAREG
    cmp #1
    beq @nowait                 ; printer output: pagination doesn't
                                ; apply, and MM_TBLX would be stale/
                                ; meaningless here regardless

    ; Check row position
    lda MM_TBLX
    cmp #TEST_WAIT_LINE
    bcc @nowait                 ; <= TEST_WAIT_LINE

@wait_key:
    jsr KERNAL_GETIN            ; non-blocking keyboard read
    beq @wait_key

    ;
    ; Clear screen, output test title
    ;
    KERNAL_CHROUT_MACRO PETSCII_CLEAR
    BASIC_STROUT_MACRO TestData::test_title
    lda TestRegistry::ntests
    ldx #$00
    jsr OUTPUT_BYTETODEC
    KERNAL_CHROUT_MACRO $0d

@nowait:
    rts
.endproc
