# ===========================================================================
# C64 / CC65 Dynamic Build System
# ===========================================================================

# ---------------------------------------------------------------------------
# Environment Detection (Xcode vs Command Line)
# ---------------------------------------------------------------------------
# If PROJECT_DIR is defined, Xcode is driving the build.
ifdef PROJECT_DIR
    # --- XCODE ENVIRONMENT ---
    # Project Targets Root Directory is defined by Xcode
    ROOT_DIR   = $(PROJECT_DIR)/$(TARGET_NAME)

    # Project Targets Build Directory is defined by Xcode
    OUT_DIR    = $(TARGET_BUILD_DIR)

    # Project Targets Shared Directory is defined by User
    SHARED_DIR = $(PROJECT_DIR)/../Shared
else
    # --- COMMAND LINE ENVIRONMENT ---
    # Terminal execution defaults to relative paths
    ROOT_DIR   = .
    OUT_DIR    = .
    SHARED_DIR = ../Shared
    PROJECT_NAME = main
    TARGET_NAME = main
endif

# ---------------------------------------------------------------------------
# Build Configurations
# ---------------------------------------------------------------------------
# CONFIGURATION: Debug (default) or Release
CONFIGURATION ?= Debug

ifeq ($(CONFIGURATION),Debug)
    DEF_FLAGS = -D DEBUG=1
else
    DEF_FLAGS = -D RELEASE=1
endif

# C64_BUILD_MODE: ASM (default), C, or HYBRID
C64_BUILD_MODE ?= ASM

# --- Dynamic Mode Switching & Main Project Recursion ---
# We use POSIX `find` to seamlessly support unlimited subdirectories in ROOT_DIR
ifeq ($(C64_BUILD_MODE),ASM)
    #PROJECT_SRCS = $(shell find $(ROOT_DIR) -type f -name "*.s")
    PROJECT_SRCS = $(wildcard $(ROOT_DIR)/*.s)
    CONFIG       = $(ROOT_DIR)/c64-asm.cfg
    LD_LIBS      = 
else ifeq ($(C64_BUILD_MODE),C)
    PROJECT_SRCS = $(shell find $(ROOT_DIR) -type f -name "*.c")
    CONFIG       = $(ROOT_DIR)/c64-hybrid.cfg
    LD_LIBS      = c64.lib
else ifeq ($(C64_BUILD_MODE),HYBRID)
    PROJECT_SRCS = $(shell find $(ROOT_DIR) -type f \( -name "*.c" -o -name "*.s" \))
    CONFIG       = $(ROOT_DIR)/c64-hybrid.cfg
    LD_LIBS      = c64.lib
else
    $(error Invalid C64_BUILD_MODE: $(C64_BUILD_MODE). Must be ASM, C, or HYBRID)
endif

# ---------------------------------------------------------------------------
# Main Project Object Mapping & vpath
# ---------------------------------------------------------------------------
# Map all discovered main project sources into flattened .o paths in the OUT_DIR
PROJECT_OBJS = $(addprefix $(OUT_DIR)/, $(addsuffix .o, $(basename $(notdir $(PROJECT_SRCS)))))

# Dynamically extract all subdirectories containing source files in ROOT_DIR.
# This registers every project subdirectory with vpath so Make can find the source files
# when building the flattened target objects.
PROJECT_SRCDIRS = $(sort $(dir $(PROJECT_SRCS)))
vpath %.c $(PROJECT_SRCDIRS)
vpath %.s $(PROJECT_SRCDIRS)

# explicitly tell Make to ignore dynamic targets as the default goal
.DEFAULT_GOAL := all

# ---------------------------------------------------------------------------
# Dynamic Library Generation (One .lib per Subdirectory)
# ---------------------------------------------------------------------------
# Find all immediate subdirectories inside the shared libraries folder
LIB_DIRS := $(shell find $(SHARED_DIR)/libraries -mindepth 1 -maxdepth 1 -type d)

ALL_LIBS :=

define MAKE_LIBRARY_TEMPLATE
# $(1) represents the evaluated directory path (e.g., ../Shared/libraries/math)
LIB_NAME_$(1) := $$(notdir $(1))

# Find all assembly source files specifically inside this library subdirectory
SRCS_$(1) := $$(wildcard $(1)/*.s)

# Create unique object paths in OUT_DIR, prefixed by the library name (e.g., math_init.o)
# This prevents namespace collisions between identical filenames in different library folders
OBJS_$(1) := $$(addprefix $$(OUT_DIR)/$$(LIB_NAME_$(1))_, $$(notdir $$(SRCS_$(1):.s=.o)))

# Define the final path for this static library archive
ARCHIVE_$(1) := $$(OUT_DIR)/$$(LIB_NAME_$(1)).lib

# Register this newly defined archive to our master ALL_LIBS list
ALL_LIBS += $$(ARCHIVE_$(1))

# Generate the archiving rule for this specific .lib
$$(ARCHIVE_$(1)): $$(OBJS_$(1))
	@echo "Archiving library: $$(LIB_NAME_$(1)).lib..."
	@rm -f $$@
	$$(AR) a $$@ $$^
	@echo "Cleaning up temporary library objects..."
	@rm -f $$^

# Generate the explicit compilation pattern rule for this specific folder.
# By explicitly mapping $(1)/%.s to $(OUT_DIR)/$(LIB_NAME)_%.o, we bypass the need 
# for vpath entirely for libraries, avoiding cross-directory bleeding.
$$(OUT_DIR)/$$(LIB_NAME_$(1))_%.o: $(1)/%.s
	@echo "Assembling library component: $$<..."
	#$$(AS) $$(ASFLAGS) -l $$(OUT_DIR)/$$(LIB_NAME_$(1))_$$*-lst.txt $$< -o $$@
	$$(AS) $$(ASFLAGS) $$< -o $$@
endef

# Iterate over every discovered library directory and evaluate the template into memory
$(foreach dir,$(LIB_DIRS),$(eval $(call MAKE_LIBRARY_TEMPLATE,$(dir))))

# ---------------------------------------------------------------------------
# Toolchain Setup
# ---------------------------------------------------------------------------
export CC65_HOME = $(HOME)/Applications/CC65/share/cc65

CC  = $(HOME)/Applications/CC65/bin/cc65
AS  = $(HOME)/Applications/CC65/bin/ca65
LD  = $(HOME)/Applications/CC65/bin/ld65
CL  = $(HOME)/Applications/CC65/bin/cl65
AR  = $(HOME)/Applications/CC65/bin/ar65

TARGET      = $(OUT_DIR)/$(TARGET_NAME).prg
TARGETMAP   = $(OUT_DIR)/$(TARGET_NAME)-map.txt
TARGETLBL   = $(OUT_DIR)/$(TARGET_NAME)-lbl.txt
TARGETLST   = $(OUT_DIR)/$(TARGET_NAME)-lst.txt

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
# Dynamically append all discovered library subdirectories as include paths
# so you can `.include "some_math_macro.s"` without hardcoding paths.
INCLUDES = -I $(SHARED_DIR) -I $(SHARED_DIR)/labels -I $(SHARED_DIR)/macros \
			$(addprefix -I , $(LIB_DIRS))

CFLAGS  = -t c64 -O $(DEF_FLAGS) $(INCLUDES) --add-source
ASFLAGS = $(INCLUDES) -g -t c64 $(DEF_FLAGS)
LDFLAGS = -C $(CONFIG) -m $(TARGETMAP) -Ln $(TARGETLBL)

# ---------------------------------------------------------------------------
# Build Rules
# ---------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET)

# Link everything using the dynamically assigned LD_LIBS and ALL_LIBS archives.
# $^ expands to include $(PROJECT_OBJS) and all archives in $(ALL_LIBS).
$(TARGET): $(PROJECT_OBJS) $(ALL_LIBS)
	@echo "Linking $(TARGET_NAME) in $(C64_BUILD_MODE) mode..."
	$(LD) $(LDFLAGS) -o $@ $^ $(LD_LIBS)

	@echo "Cleaning up temporary main objects..."
	rm -f $(OUT_DIR)/*.o

# Compile C files -> Object files (for main project)
$(OUT_DIR)/%.o: %.c
	@echo "Compiling C source $<..."
	$(CC) $(CFLAGS) $< -o $(OUT_DIR)/$*.s
	$(AS) $(ASFLAGS) -l $(OUT_DIR)/$*.lst $(OUT_DIR)/$*.s -o $@
	@cat $(OUT_DIR)/$*.lst >> $(TARGETLST)
	@rm $(OUT_DIR)/$*.lst

# Assemble pure Assembly files -> Object files (for main project)
$(OUT_DIR)/%.o: %.s
	@echo "Assembling main project file $<..."
	$(AS) $(ASFLAGS) -l $(OUT_DIR)/$*.lst $< -o $@
	@cat $(OUT_DIR)/$*.lst >> $(TARGETLST)
	@rm $(OUT_DIR)/$*.lst

clean:
	@echo "Cleaning build artifacts in $(OUT_DIR)..."
	rm -f $(PROJECT_OBJS) $(ALL_LIBS) $(TARGET) $(TARGETMAP) $(TARGETLBL) $(TARGETLST)
	rm -f $(OUT_DIR)/*.o $(OUT_DIR)/*-lst.txt
	#rm -f $(OUT_DIR)/*.o $(OUT_DIR)/*.s $(OUT_DIR)/*-lst.txt
