
.ifndef LAYOUT_STRUCT_S
    LAYOUT_STRUCT_S = 1
    .struct layout_struct
        xmsg        .byte   ; screen column
        ymsg        .byte   ; screen row
        field_len   .byte   ; width of the associated input field
        msg         .addr   ; pointer to a null-terminated PETSCII string
        own_line    .byte   ; 0 = value shares ymsg, drawn at the shared xval column (xmsg + max_msg_len + 1)
                            ; 1 = value is drawn on its OWN row (ymsg+1),
                            ; left-aligned to xmsg instead - needed when field_len is too wide to share a line with
                            ; any label column see the binary row's 32-char field and the 40-column screen limit.
    .endstruct
.endif
