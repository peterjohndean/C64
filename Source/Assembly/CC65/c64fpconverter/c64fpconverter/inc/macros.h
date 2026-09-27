.macro CREATE_ASCIIZ_PLUS_LEN_MACRO label, msg
    .if .paramcount < 2
        .error "Too few parameters for macro CREATE_ASCIIZ_PLUS_LEN_MACRO"
    .endif

label:
    .asciiz msg

    ; --- build a NEW identifier "<label>_LEN" ---
    .ident(.concat(.string(label), "_LEN")) = * - label - 1

    ; --- fold this string's length into a running max ---
    .ifndef MAX_MSG_LEN
        MAX_MSG_LEN .set * - label - 1      ; first call: seed it
    .else
        .if (* - label - 1) > MAX_MSG_LEN
            MAX_MSG_LEN .set * - label - 1  ; new longest so far
        .endif
    .endif
.endmacro
