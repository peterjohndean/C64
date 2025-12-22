;===========================================================
; Macro: Load Integer Immediate (Fixed Number)
; Usage: +KERNEL_CHROUT_IMM '?'
; eg. A = $3f
;===========================================================
!macro KERNEL_CHROUT_IMM REF2A {
	lda #REF2A
    jsr KERNEL_CHROUT
}
