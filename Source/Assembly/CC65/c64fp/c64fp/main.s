; =============================================================================
; CC65 / CA65 Commodore 64 Boilerplate Template
; =============================================================================

; Enable special processing features and CBM-specific configuration extensions
;.features	on
;.cbm		on
.setcpu		"6502"

.include "labels_memorymap.s"
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"

.import FP_TESTS

; ---------------------------------------------------------------------------
; Usage from BASIC:
;   sys2061             ; press 'p' at the prompt for printer output,
;                       ; any other key (or just wait) defaults to screen
;
; The poke780 mechanism still exists underneath - MM_SAREG ($030C) is
; still the single flag the dispatch logic below reads - but you no
; longer need to set it yourself from BASIC first. See the PROMPT
; FOR OUTPUT DESTINATION block in main below for exactly how this
; writes to MM_SAREG on your behalf before falling into the existing,
; unmodified screen_only/want_printer logic.
;
; The old two-step usage (poke780,<0|1> then sys2061) still works
; too, if you'd rather script it from BASIC than answer the prompt -
; MM_SAREG is written EVERY time main runs, but only ever with 0 or 1,
; so nothing downstream can tell the difference between "the prompt
; set it" and "BASIC poked it" - they're the same byte.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; 1. PRG Header
; ---------------------------------------------------------------------------
.export __LOADADDR__       ; Tell ca65 to expose this symbol to the linker
.segment "LOADADDR"
__LOADADDR__:              ; Define the label at the exact start of the segment
        .word $0801

.segment "STARTUP"
stub_start:
        .word   stub_end
        .word   10
        .byte   $9e
        .byte   "2061"                  
        .byte   0                       
stub_end:
        .word   0

; -----------------------------------------------------------------------------
; INIT Segment: Mapped immediately following the STARTUP block ($080D / 2061)
; -----------------------------------------------------------------------------
.segment "INIT"

.proc main
;    .org 2061
    ; -----------------------------------------------------------------
    ; [BUG FIX] Unconditional CLRCHN before doing anything else.
    ;
    ; WHY THIS IS NEEDED
    ; -------------------
    ; KERNAL_CLRCHN ($FFCC) resets the CURRENT input/output device
    ; back to the defaults (keyboard in, screen out). It's cheap - if
    ; the channels are already default, this is a harmless no-op - so
    ; there's no downside to calling it defensively every time this
    ; routine starts, regardless of which branch (screen or printer)
    ; is about to run.
    ;
    ; The reason it matters here: if a PREVIOUS invocation took the
    ; printer path and KERNAL_CHKOUT failed partway (device not
    ; responding on the serial/IEEE bus), the output channel was left
    ; pointed at the printer - see the chkout_failed fix below for the
    ; other half of this bug. Without this line, a fresh SYS call
    ; would inherit that dangling channel state and could itself hang
    ; trying to talk to the printer through KERNAL_CHROUT (e.g. via
    ; screen_only's call into FP_TESTS), even though the user asked
    ; for screen output this time. Resetting channels unconditionally
    ; at entry means every run starts from a known-good state, no
    ; matter what the previous run left behind.
    ;
    ; Reference: C64 Programmer's Reference Guide, KERNAL CLRCHN
    ; ($FFCC); also see the KERNAL_CLRCHN entry in
    ; labels_rom_kernal.s.
    ; -----------------------------------------------------------------
    jsr KERNAL_CLRCHN

    ; -----------------------------------------------------------------
    ; PROMPT FOR OUTPUT DESTINATION
    ;
    ; WHY A PROMPT INSTEAD OF JUST READING MM_SAREG DIRECTLY
    ; -----------------------------------------------------------------
    ; The dispatch logic immediately below this block (step "0.") has
    ; not changed AT ALL - it still just reads MM_SAREG ($030C, "peek
    ; 780") and branches on whether it's exactly 1. What changed is
    ; WHO sets that byte: previously the user had to type
    ; "poke780,1:sys2061" from BASIC themselves before running; now
    ; this block asks the question directly on screen and WRITES
    ; MM_SAREG itself, so the existing branch below sees exactly the
    ; same byte it always did and needs no changes whatsoever - this
    ; is precisely the "coexistence" approach used everywhere else in
    ; this project (new behaviour added alongside proven code, rather
    ; than modifying the proven code to accommodate it).
    ;
    ; WHY KERNAL_GETIN (NON-BLOCKING) IN A BUSY-WAIT LOOP, NOT
    ; KERNAL_CHRIN
    ; -----------------------------------------------------------------
    ; KERNAL_GETIN ($FFE4) reads ONE character from the keyboard
    ; buffer and returns immediately, with A=$00 if nothing has been
    ; typed yet - it does not wait, and it does not require the user
    ; to press RETURN afterward (unlike KERNAL_CHRIN, which is
    ; designed for line-based input and blocks until a full line is
    ; entered). Looping on GETIN until it returns something non-zero
    ; is the standard C64 idiom for "wait for a single keypress" - the
    ; exact same pattern this file's own screen_only/chkout_failed
    ; paths already use for their own "press any key" wait, below.
    ;
    ; KNOWN LIMITATION: A LEFTOVER BUFFERED KEYSTROKE
    ; -----------------------------------------------------------------
    ; If the user's RETURN keypress that submitted the "sys2061"
    ; command line is still sitting in the keyboard buffer when this
    ; runs, GETIN could return that RETURN character immediately
    ; instead of waiting for a fresh keypress. This is a pre-existing
    ; characteristic of every GETIN-based wait elsewhere in this file
    ; (see msg_redirect's own @wait_key loop below) - not something
    ; unique to this new prompt - and is not defended against here
    ; for the same reason: clearing the keyboard buffer defensively
    ; would need its own justification (there's no KERNAL call to
    ; "flush" it short of reading and discarding NDX/$C6 characters
    ; one at a time) and hasn't been a problem in practice for the
    ; existing prompts this file already has.
    ; -----------------------------------------------------------------
    BASIC_STROUT_MACRO msg_prompt_output

@wait_choice:
    jsr KERNAL_GETIN            ; non-blocking: A = key, or $00 if
                                ; nothing has been typed yet
    beq @wait_choice            ; $00: no key yet, keep waiting

    ; PETSCII note: the C64's default character set returns 'P' (not
    ; 'p') for an unshifted press of the P key - lowercase-looking
    ; PETSCII codes are a SHIFTED input in the default mode, and mean
    ; something else entirely in the alternate (lower-case) charset.
    ; Checking both avoids depending on which charset mode the screen
    ; happens to be in when this runs, at the cost of also accepting
    ; a shifted 'p' - harmless, since either one clearly means
    ; "printer" to a human typing at the prompt.
    cmp #'p'
    beq @choose_printer
    cmp #'P'
    beq @choose_printer

    lda #0                       ; any other key: default to screen
    jmp @store_choice

@choose_printer:
    lda #1

@store_choice:
    sta MM_SAREG                 ; poke780,<0 or 1> - identical effect
                                 ; to the BASIC poke this prompt
                                 ; replaces; everything below this
                                 ; point is completely unmodified
    KERNAL_CHROUT_MACRO $0d      ; newline, so the chosen key doesn't
                                 ; sit awkwardly at the end of the
                                 ; prompt line before FP_TESTS' own
                                 ; screen-clear (screen_only path) or
                                 ; the printer banner (want_printer
                                 ; path) runs
    ; -----------------------------------------------------------------

    ; 0. Output to Screen (default)/Printer
    lda MM_SAREG            ; peek(780), 0 = screen, 1 = printer
    cmp #1
    beq want_printer
    jmp screen_only         ; anything other than exactly 1: screen

want_printer:
    ; 1. Set filename (none required for basic printer output)
    lda #0          ; Filename length = 0
    ldx #<dummy_name
    ldy #>dummy_name
    jsr KERNAL_SETNAM

    ; 2. Set up logical file, device number, and secondary address
    lda #1          ; Logical file number (1)
    ldx #4          ; Device number (4 = printer)
    ldy #7          ; Secondary address (7 = unformatted/text mode)
    jsr KERNAL_SETLFS

    ; 3. Open the file/device
    jsr KERNAL_OPEN
    bcs open_failed ; If carry set, an error occurred

    ; 4. Direct output channel to the printer (logical file 1)
    ldx #1
    jsr KERNAL_CHKOUT
    jsr KERNAL_READST
    bne chkout_failed

    ; 5. All output goes to the printer
    jsr FP_TESTS
    KERNAL_CHROUT_MACRO $0d     ; newline
    KERNAL_CHROUT_MACRO $0c     ; form feed

    ; 6. Restore I/O channels (back to screen/keyboard)
    jsr KERNAL_CLRCHN

    ; 7. Close logical file 1
    lda #1
    jsr KERNAL_CLOSE

    ; 8. Exit
    rts

open_failed:
    BASIC_STROUT_MACRO msg_err_open
    jmp msg_redirect

chkout_failed:
    ; -----------------------------------------------------------------
    ; [BUG FIX] CLRCHN must come BEFORE anything that prints, and
    ; before (or after - order relative to CLOSE doesn't matter here,
    ; unlike the success path - see note below) closing the file.
    ;
    ; WHY THIS WAS THE ACTUAL HANG
    ; -----------------------------
    ; KERNAL_CHKOUT ($FFC9) doesn't just flip a flag - it performs a
    ; real LISTEN + secondary-address handshake with the target device
    ; over the serial/IEEE bus. When that handshake fails (which is
    ; exactly the case we're in here - READST came back non-zero), the
    ; KERNAL's CURRENT OUTPUT DEVICE has already been changed to
    ; device 4, even though the device isn't actually able to receive
    ; data. KERNAL_CLOSE only removes the logical file from the
    ; LAT/FAT/SAT tables ($0259-$0276) - it does NOT touch the current
    ; output device. So immediately after KERNAL_CLOSE below, CHROUT
    ; (which BASIC_STROUT_MACRO uses internally) was STILL trying to
    ; send characters to the unresponsive printer, over a bus that had
    ; just failed to complete a handshake - which is what actually
    ; hung, not the CLOSE or the file table.
    ;
    ; ORDER: CLRCHN then CLOSE, mirroring the success path (steps 6-7
    ; above) - restore the channel to something known-good FIRST, then
    ; do bus-touching cleanup (CLOSE also talks to the device to tell
    ; it the file is done) with a sane output channel already in
    ; place, then print. Printing before CLRCHN, in either order
    ; relative to CLOSE, would still hang - it's the channel state,
    ; not the close, that gates whether CHROUT can succeed.
    ; -----------------------------------------------------------------
    jsr KERNAL_CLRCHN       ; [BUG FIX] restore output to the screen
                            ; BEFORE anything below tries to print
    lda #1
    jsr KERNAL_CLOSE        ; close the now-useless logical file
    BASIC_STROUT_MACRO msg_err_redirect   ; now safely reaches the screen
    jmp msg_redirect

msg_redirect:
    BASIC_STROUT_MACRO msg_default

@wait_key:
    jsr KERNAL_GETIN        ; non-blocking keyboard read
    beq @wait_key

    ; fall-through

screen_only:
    jsr FP_TESTS
    rts

dummy_name:         .byte 0
msg_prompt_output:  .literal "PRESS 'P' FOR PRINTER", $0d, "ANY OTHER KEY FOR SCREEN", $0d, $0
msg_err_open:       .literal "ERR: OPEN", $0d, $0
msg_err_redirect:   .literal "ERR: REDIRECT", $0d, $0
msg_default:        .literal "MSG: REDIRECT TO SCREEN", $0d, $0
.endproc
