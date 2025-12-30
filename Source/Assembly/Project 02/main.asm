; ------------------------------------------------------------
;  Synosis:
;	Learning C64 assembly language by revealing BASIC's
;	& custom floating-point routines.
; ------------------------------------------------------------
; Machine Language Entry point (called from BASIC: SYS 49152)
; ------------------------------------------------------------

!zone Target {

	* = $C000				; SYS49152 or SYS12*4096
						
    !cpu 6510				; Target processor
	!to "/Volumes/ExternalSSD_iTunes/C64/Virtual Disk/testmr.ml", cbm
    !symbollist "symbols.txt"     ; Output symbol list for debugging
    
	!src "../Common/kernel.inc"		; Kernel addresses
	!src "../Common/macros.inc"		; Macros to make life a little easier
}

!zone Main {

; Machine language entry point
MLEP:

	; Parameter #1
	jsr BASIC_CHKCOM	; Skip passed ','
	jsr BASIC_FRMEVL	; Ugh, FAC1
	jsr FLOATTOUINT8	; Convert FAC1 to UInt8
	sta ParameterOption
	
	; Fetch remaining parameters
	jsr FetchOptionParameters
	
	; Process the chosen option
	jsr ProcessOption
	
    
; Machine language exit point
MLEP_END:
	rts
}

; Constants
MAX_OPTIONS = 4-1		; Maximum Options. eg. 2 available options, thus 0..1, so 2-1 = 0..1

!address {
;;
;; Global Integer References
;MATH_DIVIDEND	= MM_TAPE1BUF	; [$033C-$033D]
;MATH_DIVISOR	= MM_TAPE1BUF+2	; [$033E-$033F]
;MATH_REMAINDER	= MM_TAPE1BUF+4	; [$0340-$0341]
;MATH_SIGN		= MM_TAPE1BUF+6	; [$0342]

;
; Workspace
;FP_VALUE: !byte $00, $00, $00, $00, $00;	Holds the original SYS value
;FP_NEW: !byte $00, $00, $00, $00, $00;	Holds the newly Float to Int to Float value

;
; Constants
Help:	!pet "help",13
		!pet "usage:",13
		!pet "sys49152,0,1",13
		!pet "sys49152,1,1",13
		!pet "sys49152,2,1,v%",13
		!pet "sys49152,3,1,v%",13,13
		!pet "option:",13
		!pet " 0, unpacked float to ascii hex",13
		!pet " 1,   packed float to ascii hex",13
		!pet " 2, float to int8 to var%",13
		!pet " 3, float to int16 to var%",13,13,0
		
;Header: !pet "[ee] m4 m3 m2 m1 sg  [ee] m4 m3 m2 m1", 13, 0
;Spacer: !pet "....", 0
;PF_N0002:	!byte $82,$80,$00,$00,$00	; -2.0
;PF_P0000:	!byte $00,$00,$00,$00,$00	;  0.0
;PF_P0001:	!byte $81,$00,$00,$00,$00	;  1.0
;PF_P0002:	!byte $82,$00,$00,$00,$00	;  2.0  
;PF_P0007:	!byte $83,$60,$00,$00,$00	;  7.0
;PF_P0010:	!byte $84,$20,$00,$00,$00	; 10.0
;PF_P0063:	!byte $86,$7c,$00,$00,$00	; 63.0

ParameterOption:	!byte $00						; Parameter test option
ParameterValue1:	!byte $00, $00, $00, $00, $00	; Parameter value
ParameterVarPtr1:	!word $0000						; Parameter variable location
CustomValue:		!byte $00, $00, $00, $00, $00	; Conversion value
ZPVector = <MM_FREKZP								; Temporary vector, used by various routines
}

; ------------------------------------------------------------
; Project source code
; ------------------------------------------------------------
!src "../Common/fp.asm"
!src "../Common/integer.asm"
!src "floattohex.asm"
!src "processparameters.asm"
!src "processoptions.asm"
;!src "../Common/printbytetobinary.asm"
;!src "../Common/printcstring.a"
!src "../Common/printbytetohex.a"
