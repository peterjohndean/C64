.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "macros_fp.s"

.include "../fp_test_macros.s"

.import OUTPUT_BYTETOHEX
.import OUTPUT_BYTETODEC

.scope TestRegistry
    .import ntests
.endscope

.scope TestValue
    .import val_1billion, val_100, val_12, val_7, val_1
    .import val_0_5, val_0_1, val_0
    .import val_neg5, val_neg42, val_neg60
    .import val_pi, val_2pi
    .import rad_neg30
    .import rad_0, rad_30, rad_45, rad_60, rad_90
    .import rad_120, rad_180, rad_200, rad_270
    .import rad_300, rad_400
    .import ieee754_pi, ieee754_2pi
    .import ieee754_0_1
    .import ieee754_neg5
.endscope

.scope TestData
    .import id_group, id_test
    .import fractional_digits
    .import ptr_expected, ptr_testmsg
    .import out_buffer
    .import fac_snapshot
.endscope
