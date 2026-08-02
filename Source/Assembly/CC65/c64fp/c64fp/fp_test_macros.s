
.macro SHOW_CURRENT_TEST_MACRO
    lda TestData::id_group
    ldx #$20
    jsr OUTPUT_BYTETODEC

    KERNAL_CHROUT_MACRO '-'
    
    lda TestData::id_test
    ldx #$00
    jsr OUTPUT_BYTETODEC
.endmacro

; ============================================================
; MACRO: SET_TESTDATA_SCOPE_MACRO
; Purpose: To prepare setup information for the intended test routine.
; Parameters:
; - test_num:       test id or number.
; - test_msg:       message associated with the test. Vector to the c-style string.
; - test_expects:   optional, vector to match the test result.
; Returns:          whatever the test routine outputs.
; ============================================================
.macro SET_TESTDATA_SCOPE_MACRO test_num, test_msg, test_expects
    .if .paramcount < 2
		.error  "Too few parameters for macro SET_TESTDATA_SCOPE_MACRO"
	.endif
    ;
    lda #test_num
    sta TestData::id_test
    ;
    lda #<test_msg
    sta TestData::ptr_testmsg
    lda #>test_msg
    sta TestData::ptr_testmsg+1
    ;
    .ifnblank test_expects
    lda #<test_expects
    sta TestData::ptr_expected
    lda #>test_expects
    sta TestData::ptr_expected+1
    .endif
    ;
.endmacro

; ============================================================
; MACRO: TEST_FP1CMP_MACRO
; Purpose : Compare FP1 against a 4-byte expected value; print
;           PASS/FAIL.
; Params  : test_num  - compile-time constant test number
;           test_msg  - test message string
;           expected  - label of a 4-byte expected float value
; ============================================================
.macro TEST_FP1CMP_MACRO test_num, test_msg, test_expects
    .if .paramcount <> 3
		.error  "Too few parameters for macro TEST_FP1CMP_MACRO"
	.endif
    SET_TESTDATA_SCOPE_MACRO test_num, test_msg, test_expects
    jsr TEST_FP1CMP
.endmacro

; ============================================================
; MACRO: TEST_STRCMP_MACRO
; Purpose : Compare the null-terminated string in out_buf against a
;           compile-time-known expected string; print PASS/FAIL.
; Params  : test_num  - compile-time constant test number
;           test_msg - associated test message (c-style)
;           test_expects - expected result string (c-style)
; ============================================================
.macro TEST_STRCMP_MACRO_V2 test_num, test_msg, test_expects
    .if .paramcount <> 3
		.error  "Too few parameters for macro TEST_STRCMP_MACRO"
	.endif
    SET_TESTDATA_SCOPE_MACRO test_num, test_msg, test_expects
    jsr TEST_STRCMP
.endmacro

.macro TEST_PASSED_MACRO_V2 test_num, test_msg
    .if .paramcount <> 2
		.error  "Too few parameters for macro TEST_PASSED_MACRO"
	.endif
    SET_TESTDATA_SCOPE_MACRO test_num, test_msg
    jsr TEST_PASSED
.endmacro

.macro TEST_FAILED_MACRO_V2 test_num, test_msg
    .if .paramcount <> 2
		.error  "Too few parameters for macro TEST_FAILED_MACRO"
	.endif
    SET_TESTDATA_SCOPE_MACRO test_num, test_msg
    jsr TEST_FAILED
.endmacro

; ============================================================
; MACRO: TEST_CHECK_MACRO_V2
; Purpose : Print a test number and FP1's raw bytes for manual
;           comparison, also includes human readable of result
; ============================================================
.macro TEST_CHECK_MACRO_V2 test_num, test_msg, test_digits
    .if .paramcount < 2
		.error  "Too few parameters for macro TEST_CHECK_MACRO"
	.endif
    SET_TESTDATA_SCOPE_MACRO test_num, test_msg
    .ifblank test_digits
        lda #4
    .else
        lda #test_digits
    .endif
    sta TestData::fractional_digits
    jsr TEST_CHECK
.endmacro

