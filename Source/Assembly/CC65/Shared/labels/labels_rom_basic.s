.ifndef LABELS_ROM_BASIC_S
LABELS_ROM_BASIC_S = 1

;------------------------------------------------
; C64 BASIC 2.0 ROM
; A000–BFFF 40960–49151 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
BASIC_GOCR      := $aad7    ; Output cr/lf
BASIC_STROUT    := $ab1e    ; Output zero/null terminated string at Y/A
BASIC_GIVAYF	:= $b391    ; Convert int16 (Register A/Y) → FAC1
BASIC_MOVMF     := $bba2    ; Unpack Memory (Y/A) → FAC1. Memory contains a 5-Byte C64 float
BASIC_MOVFM     := $bbd4    ; Pack FAC1 → Memory (Y/X). Memory contains a 5-Byte C64 float
BASIC_LINPRT    := $bdcd    ; Output uint16 (Register A/X) as a number in ASCII/PETSCII
BASIC_FOUT      := $bddd    ; FAC1 → ASCII string at Y/A (ready for STROUT)
.endif
