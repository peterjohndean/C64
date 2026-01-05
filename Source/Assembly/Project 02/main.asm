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
	jsr BASIC_FRMEVL	; Convert to Float (FAC1)
	jsr FLOATTOUINT8	; Convert FAC1 to UInt8
	sta ParameterOption
	
	; Fetch remaining parameters
	jsr ProcessParameters
	
	; Process the chosen option
	jsr ProcessOption
	
    
; Machine language exit point
MLEP_END:
	rts
}

;
; SETTINGS
;
MAX_OPTIONS 		= 4-1	; Maximum Options. eg. 2 available options, thus 0..1, so 2-1 = 0..1
FLOAT_SIZE_PACKED 	= $05	; Float packed memory size
FLOAT_SIZE_UNPACKED = $06	; Float unpacked memory size

!address {
;;
;; Global Integer References
;MATH_DIVIDEND	= MM_TAPE1BUF	; [$033C-$033D]
;MATH_DIVISOR	= MM_TAPE1BUF+2	; [$033E-$033F]
;MATH_REMAINDER	= MM_TAPE1BUF+4	; [$0340-$0341]
;MATH_SIGN		= MM_TAPE1BUF+6	; [$0342]

;
; MEMORY CONSTANTS
;
Help:	
		!pet "usage:",13
		!pet "sys49152, followed by;",13
		!pet "option,value,string$",13
		!pet "option,value,variable%",13,13
		!pet "option(s):",13
		!pet "string$ must exist with length. 12/10 bytes.",13
		!pet " 0, unpacked float to ascii hex in string$(12)",13
		!pet " 1,   packed float to ascii hex in string$(10)",13
		!pet " 2, float to int8 to variable%",13
		!pet " 3, float to int16 to variable%",13,13,0
		
;
; MEMORY VARIABLES
;
FloatMemorySize:	!byte $00						; Packed = 5 bytes, Unpacked = 6 bytes
ParameterOption:	!byte $00						; Parameter SYS option
ParameterValue1:	!byte $00, $00, $00, $00, $00	; Parameter SYS value
ParameterVarPtr1:	!word $0000						; Parameter BASIC variable address

ZPVector = <MM_FREKZP								; 0-Page Vector, used by various routines
ZPVector2 = <MM_FREKZP+2							; 0-Page Vector, used by various routines
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
!src "../Common/bytetohex.asm"
