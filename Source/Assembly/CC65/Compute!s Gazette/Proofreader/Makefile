# -------------------------------------------------------------------------
# Makefile for Proofreader v2 and v3 (ca65/ld65 toolchain)
# -------------------------------------------------------------------------

# --- Variables ---
AS = cl65
TARGET = c64

# -g:   Include debug information (required for VICE labels)
# -t:   Set target architecture
CFLAGS = -g -t $(TARGET)

# --- Default Target ---
.PHONY: all
all: v2 v3

# -------------------------------------------------------------------------
# Build Targets
# -------------------------------------------------------------------------

.PHONY: v2
v2: pr-v2.bin

pr-v2.bin: pr-v2.s pr-v2.cfg
	$(AS) $(CFLAGS) -C pr-v2.cfg \
	-Ln pr-v2-vice.txt \
	-m pr-v2-map.txt \
	-l pr-v2-list.txt \
	pr-v2.s -o pr-v2.bin

.PHONY: v3
v3: pr-v3.bin

pr-v3.bin: pr-v3.s pr-v3.cfg
	$(AS) $(CFLAGS) -C pr-v3.cfg \
	-Ln pr-v3-vice.txt \
	-m pr-v3-map.txt \
	-l pr-v3-list.txt \
	pr-v3.s -o pr-v3.bin

# -------------------------------------------------------------------------
# Clean Target
# -------------------------------------------------------------------------
.PHONY: clean
clean:
	rm -f pr-v2.bin pr-v3.bin
	rm -f pr-v2-vice.txt pr-v3-vice.txt
	rm -f pr-v2-map.txt pr-v3-map.txt
	rm -f pr-v2-list.txt pr-v3-list.txt
	rm -f *.o
	