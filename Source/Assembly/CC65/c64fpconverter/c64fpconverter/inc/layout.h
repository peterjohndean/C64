
.include "common.h"

.scope LayoutEntries
    .import l_entries, l_table, max_msg_len
.endscope

.scope CurrentEntry
    .import CalculateAddress
    .import e_index, e_msgptr
    .importzp e_ptr
.endscope
