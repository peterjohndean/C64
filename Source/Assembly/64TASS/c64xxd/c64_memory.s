;
; Zero-Page/0-Page Address
;
;D6510           = $0000 ; 6510 On-Chip Data-Direction Register
R6510           = $0001 ; 6510 On-Chip 8-Bit Input/Output Register
;
BASIC_VALTYP    = $000d ; Flag: Data Type: $FF = String, $00 = Numeric
;BASIC_INTFLG    = $000e ; Flag: Data Type: $80 = Integer, $00 = Floating
BASIC_INDEX     = $0022 ; Miscellaneous Temporary Pointers and Save Area ($0022-$0025)
BASIC_CHRGET    = $0073 ; ROM routine: get next char (skips spaces), alters TXTPTR
BASIC_CHRGOT    = $0079 ; ROM routine: get current char (skips spaces)
BASIC_TXTPTR    = $007a ; Pointer: Current Byte of BASIC Text [$007a-$007b]
;
KERNAL_STATUS   = $0090 ; Kernal I/O Status Word (ST)
;
USER_FREKZP     = $00fb ; Free 0/Zero-Page Space for User Programs ($00fb-$00fe)
;
;BASIC_BUF       = $0200 ; BASIC Line Editor Input Buffer
