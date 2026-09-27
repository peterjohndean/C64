
.include "labels_memorymap.s"
.include "../inc/common.h"
.include "../inc/macros.h"

.scope LayoutEntries
    .segment "RODATA"
    
    .export l_entries, l_table, max_msg_len

    ; [BUILD STRINGS]
    CREATE_ASCIIZ_PLUS_LEN_MACRO str_decimal,   "decimal"
    CREATE_ASCIIZ_PLUS_LEN_MACRO str_binary,    "binary (w/r)"
    CREATE_ASCIIZ_PLUS_LEN_MACRO str_wozrankin, "woz/rankin"
    CREATE_ASCIIZ_PLUS_LEN_MACRO str_c64basic,  "c64 basic"
    CREATE_ASCIIZ_PLUS_LEN_MACRO str_ieee754,   "ieee754"
    
    ; [BUILD ARRAY] 6-bytes per array entry
    ; (grew from 5 - see own_line above, and CalculateAddress's updated multiply below)
    l_table:
        .byte 2, 5, 10      ; Base10 Decimal
        .addr str_decimal
        .byte 0
        .byte 2, 6, 4*8     ; Binary for Woz/Rankin
        .addr str_binary
        .byte 1             ; own row (ymsg+1)
        .byte 2, 8, 4
        .addr str_wozrankin
        .byte 0
        .byte 2, 9, 5      ; C64 BASIC 2.0
        .addr str_c64basic
        .byte 0
        .byte 2, 10, 4
        .addr str_ieee754
        .byte 0
    l_table_end:

    l_entries:      .byte (* - l_table) / .sizeof(layout_struct)    ; # of entries
    max_msg_len:    .byte MAX_MSG_LEN                               ; maximum str_... size

    ; [ERROR HANDLING] Catch a struct/data mismatch
    .assert (l_table_end - l_table) .mod .sizeof(layout_struct) = 0, error, "l_table entries don't match layout_struct size - check field count in each entry"
.endscope

.scope CurrentEntry
    .exportzp e_ptr
    .export e_index, e_msgptr

;    .export CalculateOffset
    .export CalculateAddress

    ; ============================================================
    ; PROCEDURE : CalculateAddress
    ; Purpose : Compute the ABSOLUTE address of layout entry e_index
    ;           within LayoutEntries::l_table, and leave it in e_ptr
    ;           - a fixed zero-page pointer (see labels_layout.s) -
    ;           ready for (e_ptr),y indirect-indexed field access in
    ;           layout.s. Replaces the old CalculateOffset, which
    ;           only ever produced an X-register OFFSET for use with
    ;           absolute,X addressing - this produces a full 16-bit
    ;           RECORD ADDRESS instead, so callers can read struct
    ;           fields as just "layout_struct::field" off e_ptr,
    ;           without repeating LayoutEntries::l_table at every
    ;           access site.
    ;
    ; WHY A FULL 16-BIT ADD, NOT JUST A LOW-BYTE ADD
    ; -----------------------------------------------------
    ; e_index*5 fits in 8 bits for this table's 5 entries, but
    ; l_table itself lives in RODATA - almost certainly above
    ; $00FF - so adding the offset to l_table's base address CAN
    ; carry into the high byte even though the offset alone never
    ; will. Skipping the high-byte add would work by accident for
    ; a small table and break silently the moment l_table's low
    ; byte plus the offset crossed $FF - exactly the class of "not
    ; wrong until it is" bug this project has been bitten by before
    ; (see the REU 256KB aliasing case in lib_reu_detection.s).
    ; Doing the 16-bit add unconditionally costs nothing when the
    ; carry happens to be zero, and is correct on the day it isn't.
    ;
    ; Entry   : e_index = 0-based record number
    ; Exit    : e_ptr = 16-bit address of l_table + (e_index*5)
    ; Destroys: A
    ; ============================================================
    .segment "CODE"
    .proc CalculateAddress
        ; --- offset = e_index * 5  (index*4 + index) ---
        lda e_index
        asl a           ; index * 2
        sta @offset_lo  ; stash index*2 - needed again below
        asl a           ; index * 4
        clc
        adc @offset_lo  ; (index*4) + (index*2) = index*6
        sta @offset_lo
        lda #0
        sta @offset_hi  ; offset fits in 8 bits today, but keeping
                        ; a real high byte here means this stays
                        ; correct if the table ever grows past 51
                        ; entries (256/5) later

        ; --- e_ptr = l_table + offset (16-bit add) ---
        lda #<LayoutEntries::l_table
        clc
        adc @offset_lo
        sta e_ptr
        lda #>LayoutEntries::l_table
        adc @offset_hi  ; carry from the low-byte add above
                        ; propagates up automatically here
        sta e_ptr+1
        rts

    .segment "BSS"
    @offset_lo: .byte 0
    @offset_hi: .byte 0
    .endproc

;    .segment "CODE"
;    .proc CalculateOffset
;        ; Calculate offset position of an array with 5-byte entries
;        lda e_index
;        asl a           ; index x 2
;        asl a           ; index x 2 (index x 4)
;        clc
;        adc e_index     ; (index x 4) + index
;        tax             ; regX = table offset
;        rts
;    .endproc

    e_ptr = MM_MEMUSS

    .segment "BSS"
    e_index:    .res 1     ; current record number (0-based)
    e_msgptr:   .res 2     ; this record's msg string address, copied
                           ; out for BASIC_STROUT_VECTOR_MACRO - that
                           ; macro only does plain absolute lda/ldy
                           ; (see macros_rom_basic.s), no indirect
                           ; addressing, so ordinary RAM is fine here
                           ; - unlike e_ptr above, this does NOT need to be zero page

.endscope
