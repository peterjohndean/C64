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
;   poke780,0:sys2061     ; 0 = screen output (default/safe if never set)
;   poke780,1:sys2061     ; 1 = printer output
;   run                 ; either poke first, then run or just run for default.
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
    ; 0. Output to Screen or Printer
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
    ; CHKOUT failed after OPEN succeeded - close the now-useless file
    ; before falling back, so it isn't left dangling.
    lda #1
    jsr KERNAL_CLOSE
    BASIC_STROUT_MACRO msg_err_redirect
    jmp msg_redirect

msg_redirect:
    BASIC_STROUT_MACRO msg_default

@wait_key:
    jsr KERNAL_GETIN        ; non-blocking keyboard read
    beq @wait_key

    jsr FP_TESTS            ; fall back to screen output
    rts

    ; -------------------------------------------------------------------
    ; screen_only: SAREG wasn't exactly 1 - run FP_TESTS exactly as the
    ; original, un-modified main.s did, with no KERNAL channel calls at
    ; all. This is intentionally the SIMPLEST path in this file: it's
    ; what runs by far the most often (every screen-output test run),
    ; and it's identical in behaviour to the version of this file that
    ; existed before printer support was added at all.
    ; -------------------------------------------------------------------
screen_only:
    jsr FP_TESTS
    rts

dummy_name:         .byte 0
msg_err_open:       .literal "ERR: OPEN", $0d, $0
msg_err_redirect:   .literal "ERR: REDIRECT", $0d, $0
msg_default:        .literal "MSG: REDIRECT TO SCREEN", $0d, $0
.endproc
