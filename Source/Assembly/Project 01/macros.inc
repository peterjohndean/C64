; ------------------------------------------------------------
; CMP16 zp1, zp2
; ------------------------------------------------------------
; Compares two 16-bit values stored at zero-page addresses zp1 and zp2.
;
; Affected flags:
;   Z = 1 if equal, 0 if not equal
;   C = 1 if zp1 >= zp2, 0 if zp1 < zp2  (unsigned)
;   N, V reflect signed comparison result
;   A modified, X/Y unchanged
;
; Usage examples:
;   value1 !word $1234
;   value2 !word $5678
;
; For UNSIGNED comparisons (0–65535):
;   +CMP16 value1, value2
;   bcc value1_lower      ; C=0 → value1 < value2
;   bcs value1_higher_eq  ; C=1 → value1 ≥ value2
;   beq values_equal      ; Z=1 → equal
;   bne values_not_equal  ; Z=0 → not equal
;
; For SIGNED comparisons (−32768 to +32767):
;   +CMP16 value1, value2
;   bvc no_overflow       ; V=0 → no overflow
;   bvs overflow          ; V=1 → overflow occurred
;   bmi less_than         ; (N⊕V)=1 → value1 < value2
;   bpl greater_or_equal  ; (N⊕V)=0 → value1 ≥ value2
;
; Internal operation:
;   A = A - M - (1 - C), where M = byte from zp2/zp2+1
; ------------------------------------------------------------
!macro CMP16 zp1, zp2 {
    lda zp1		; load LSB of zp1
    cmp zp2		; compare with LSB of zp2, sets C
    lda zp1+1	; load MSB of zp1
    sbc zp2+1	; subtract MSB with borrow
}
