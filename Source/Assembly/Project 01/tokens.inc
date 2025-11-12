; ============================================================
;  Commodore BASIC Token Definitions
;  Covering all major BASIC releases across Commodore systems
; ============================================================
;  Format: BASIC_TOKEN_{KEYWORD} = ${HEX_VALUE}
;  Structure: [2-byte link pointer] [2-byte line number] [tokenized text ...] {EOL} {EOP}
;
;
;  Memory Line Structure (All Versions):
;   [ Link Ptr Lo, Link Ptr Hi ] → Next BASIC line address
;   [ Line Number Lo, Line Number Hi ]
;   [ Tokenized Text Bytes ... ]
;   [ $00 ] → End of Line (EOL)
;   [ $0000 ] → End of Program (EOP)
;
;  Notes:
;   • The EOL ($00) terminator is identical across all versions.
;   • The EOP ($0000) null link pointer marks the final line.
;   • Only token tables and command sets differ between versions.
;
; Example (Basic (C64)):
;	10 PRINT "HELLO"
;	20 GOTO 10
;
; Example (Assembly):
;┌──────────────┬──────────────────────┬─────────────────────────────────────────────┐
;│ Address      │ Bytes (hex)          │ Description                                 │
;├──────────────┼──────────────────────┼─────────────────────────────────────────────┤
;│ $0801-$0802  │ 0E 08                │ Link to next line ($080E)                   │
;│ $0803-$0804  │ 0A 00                │ Line number 10                              │
;│ $0805        │ 99                   │ Token: PRINT                                │
;│ $0806-$080C  │ 22 48 45 4C 4C 4F 22 │ “HELLO” (quoted PETSCII string)             │
;│ $080D        │ 00                   │ End Of Line                                 │
;│ $080E-$080F  │ 17 08                │ Link to next line ($0817)                   │
;│ $0810-$0811  │ 14 00                │ Line number 20                              │
;│ $0812        │ 88                   │ Token: GOTO                                 │
;│ $0813-$0815  │ 20 31 30             │ “ GOTO 10” argument text                    │
;│ $0816        │ 00                   │ End Of Line                                 │
;│ $0817-$0818  │ 00 00                │ End Of Program (null link pointer)          │
;└──────────────┴──────────────────────┴─────────────────────────────────────────────┘
; ============================================================

!zone BasicTokens {
; ============================================================
;  Commodore BASIC Token Definitions
;  For All Commodore Computers
;  Format: BASIC_TOKEN_{KEYWORD} = ${HEX_VALUE}
; ============================================================
BASIC_EOP_MARKER    	= $0000   ; End of Program (null next-line link pointer)
BASIC_EOL_MARKER     	= $00     ; End of Line (text terminator)
}

!zone Basic20Tokens {
; ============================================================
;  Commodore BASIC 2.0 Token Definitions
;  For VIC-20 and C64 (identical token table)
;  Format: BASIC_TOKEN_{KEYWORD} = ${HEX_VALUE}
; ============================================================
BASIC_TOKEN_END        = $80
BASIC_TOKEN_FOR        = $81
BASIC_TOKEN_NEXT       = $82
BASIC_TOKEN_DATA       = $83
BASIC_TOKEN_INPUTHASH  = $84    ; INPUT#
BASIC_TOKEN_INPUT      = $85
BASIC_TOKEN_DIM        = $86
BASIC_TOKEN_READ       = $87
BASIC_TOKEN_LET        = $88
BASIC_TOKEN_GOTO       = $89
BASIC_TOKEN_RUN        = $8A
BASIC_TOKEN_IF         = $8B
BASIC_TOKEN_RESTORE    = $8C
BASIC_TOKEN_GOSUB      = $8D
BASIC_TOKEN_RETURN     = $8E
BASIC_TOKEN_REM        = $8F
BASIC_TOKEN_STOP       = $90
BASIC_TOKEN_ON         = $91
BASIC_TOKEN_WAIT       = $92
BASIC_TOKEN_LOAD       = $93
BASIC_TOKEN_SAVE       = $94
BASIC_TOKEN_VERIFY     = $95
BASIC_TOKEN_DEF        = $96
BASIC_TOKEN_POKE       = $97
BASIC_TOKEN_PRINTHASH  = $98    ; PRINT#
BASIC_TOKEN_PRINT      = $99
BASIC_TOKEN_CONT       = $9A
BASIC_TOKEN_LIST       = $9B
BASIC_TOKEN_CLR        = $9C
BASIC_TOKEN_CMD        = $9D
BASIC_TOKEN_SYS        = $9E
BASIC_TOKEN_OPEN       = $9F
BASIC_TOKEN_CLOSE      = $A0
BASIC_TOKEN_GET        = $A1
BASIC_TOKEN_NEW        = $A2
BASIC_TOKEN_TAB        = $A3    ; TAB(
BASIC_TOKEN_TO         = $A4
BASIC_TOKEN_FN         = $A5
BASIC_TOKEN_SPC        = $A6    ; SPC(
BASIC_TOKEN_THEN       = $A7
BASIC_TOKEN_NOT        = $A8
BASIC_TOKEN_STEP       = $A9

; --- Operators ---
BASIC_TOKEN_PLUS       = $AA
BASIC_TOKEN_MINUS      = $AB
BASIC_TOKEN_MULT       = $AC
BASIC_TOKEN_DIV        = $AD
BASIC_TOKEN_POWER      = $AE    ; ↑
BASIC_TOKEN_AND        = $AF
BASIC_TOKEN_OR         = $B0
BASIC_TOKEN_GT         = $B1    ; >
BASIC_TOKEN_EQ         = $B2    ; =
BASIC_TOKEN_LT         = $B3    ; <

; --- Functions ---
BASIC_TOKEN_SGN        = $B4
BASIC_TOKEN_INT        = $B5
BASIC_TOKEN_ABS        = $B6
BASIC_TOKEN_USR        = $B7
BASIC_TOKEN_FRE        = $B8
BASIC_TOKEN_POS        = $B9
BASIC_TOKEN_SQR        = $BA
BASIC_TOKEN_RND        = $BB
BASIC_TOKEN_LOG        = $BC
BASIC_TOKEN_EXP        = $BD
BASIC_TOKEN_COS        = $BE
BASIC_TOKEN_SIN        = $BF
BASIC_TOKEN_TAN        = $C0
BASIC_TOKEN_ATN        = $C1
BASIC_TOKEN_PEEK       = $C2
BASIC_TOKEN_LEN        = $C3
BASIC_TOKEN_STRS       = $C4    ; STR$
BASIC_TOKEN_VAL        = $C5
BASIC_TOKEN_ASC        = $C6
BASIC_TOKEN_CHRS       = $C7    ; CHR$
BASIC_TOKEN_LEFTS      = $C8    ; LEFT$
BASIC_TOKEN_RIGHTS     = $C9    ; RIGHT$
BASIC_TOKEN_MIDS       = $CA    ; MID$
BASIC_TOKEN_GO         = $CB

; --- Constants ---
BASIC_TOKEN_PI         = $FF    ; π constant
}
; ============================================================
;  End of BASIC 2.0 Token Definitions
; ============================================================