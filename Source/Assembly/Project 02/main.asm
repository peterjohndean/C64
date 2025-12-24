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
	!to "/Volumes/ExternalSSD_iTunes/C64/Virtual Disk/ml", cbm          ; Output binary file (PRG format)
    !symbollist "symbols.txt"     ; Output symbol list for debugging
    
	!src "../Common/kernel.inc"		; Kernel addresses
	!src "../Common/macros.inc"		; Macros to make life a little easier
}

;!zone Main

MLEP:
	
	jsr EntryPoint
    
MLEP_END:
	rts

; ------------------------------------------------------------
; Project source code
; ------------------------------------------------------------
!src "mathematics.asm"
;!src "../Common/printbytetobinary.asm"
;!src "../Common/printcstring.a"
!src "../Common/printbytetohex.a"
