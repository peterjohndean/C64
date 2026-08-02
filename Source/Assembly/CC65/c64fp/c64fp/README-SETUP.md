# c64fp - C64 CC65 Project

Built with the **CC65** toolchain (`ca65`, `ld65`, `cc65`, `ar65`) and the
**VICE** C64 emulator.

The build is driven by `/usr/bin/make` and the target-local `Makefile`, with
toolchain paths and build modes defined in Make rather than direct assembler
arguments in Xcode.

---

## Requirements

| Tool | Default path | Purpose |
|------|--------------|---------|
| CC65 | `~/Applications/CC65` | Assembler, compiler, linker and C64 runtime files |
| VICE | `/Applications/vice-arm64-gtk3-3.10/bin/x64sc` | Run the generated `.prg` from Xcode |
| Make | `/usr/bin/make` | Build driver used by Xcode legacy targets |

The template expects this CC65 layout:

```text
~/Applications/CC65/
├── bin/
│   ├── ar65
│   ├── ca65
│   ├── cc65
│   ├── cl65
│   └── ld65
└── share/
    └── cc65/
        ├── cfg/
        ├── include/
        ├── lib/
        └── target/
```

To verify the install:

```sh
~/Applications/CC65/bin/ca65 --version
~/Applications/CC65/bin/ld65 --version
```

---

## Usage

The project is configured for Xcode's standard build and run commands.

| Command | Action |
|---------|--------|
| Cmd+B | Build the selected target |
| Cmd+R | Build, then launch the generated `.prg` in VICE |
| Cmd+. | Stop the running VICE process |

Press **Cmd+R** after creating a project or target to build and launch it.

---

## What Gets Built

Build products are written to Xcode's `$(TARGET_BUILD_DIR)` in DerivedData.
Use **Product > Show Build Folder in Finder** to open the exact folder.

```text
<DerivedData>/Build/Products/<Config>-<Platform>/
├── ___PACKAGENAME___.prg       # C64 executable
├── ___PACKAGENAME___-lbl.txt   # VICE monitor labels from ld65 -Ln
├── ___PACKAGENAME___-lst.txt   # Combined ca65 assembly listings
├── ___PACKAGENAME___-map.txt   # Linker map from ld65 -m
└── <library>.lib               # Temporary shared library archives, when present
```

Temporary object files are removed after a successful build.

---

## Build Settings

The Xcode template creates a legacy external-build target that runs:

```sh
/usr/bin/make -w -f "$(PROJECT_DIR)/$(TARGET_NAME)/Makefile" -C "$(PROJECT_DIR)/$(TARGET_NAME)"
```

Xcode passes build settings into the Makefile environment.

| Setting | Default | Purpose |
|---------|---------|---------|
| `C64_BUILD_MODE` | `ASM` | Selects `ASM`, `C`, or `HYBRID` build rules |
| `C64_EMULATOR` | `/Applications/vice-arm64-gtk3-3.10/bin/x64sc` | Intended VICE executable path |
| `C64_PRG` | `$(TARGET_BUILD_DIR)/$(TARGET_NAME).prg` | Program passed to VICE by the shared scheme |
| `C64_LABELS` | `$(TARGET_BUILD_DIR)/$(TARGET_NAME)-lbl.txt` | Label file passed to VICE by the shared scheme |

The Makefile also defines the CC65 tool paths:

```make
export CC65_HOME = $(HOME)/Applications/CC65/share/cc65

CC = $(HOME)/Applications/CC65/bin/cc65
AS = $(HOME)/Applications/CC65/bin/ca65
LD = $(HOME)/Applications/CC65/bin/ld65
CL = $(HOME)/Applications/CC65/bin/cl65
AR = $(HOME)/Applications/CC65/bin/ar65
```

If CC65 moves, update these paths in the generated target's `Makefile`.

---

## Build Modes

`C64_BUILD_MODE` controls source discovery, linker configuration and runtime
libraries.

| Mode | Sources | Linker config | Libraries | Best use |
|------|---------|---------------|-----------|----------|
| `ASM` | `*.s` in the target folder | `c64-asm.cfg` | Shared `.lib` archives only | Pure CA65 assembly projects |
| `C` | `*.c` under the target folder | `c64-hybrid.cfg` | `c64.lib` plus shared `.lib` archives | C-only projects using the CC65 C runtime |
| `HYBRID` | `*.c` and `*.s` under the target folder | `c64-hybrid.cfg` | `c64.lib` plus shared `.lib` archives | Mixed C and assembly projects |

For `ASM` mode, source discovery currently uses:

```make
PROJECT_SRCS = $(wildcard $(ROOT_DIR)/*.s)
```

That keeps the default assembly project simple and predictable. If you want
recursive assembly source discovery, the Makefile already includes a commented
`find` version beside it.

---

## Debug and Release Defines

The Makefile maps Xcode's `CONFIGURATION` to CA65/CC65 defines:

| Xcode configuration | Defines |
|---------------------|---------|
| Debug | `-D DEBUG=1` |
| Release | `-D RELEASE=1` |

Assembly code can use these with CA65 conditionals:

```asm
.ifdef DEBUG
    ; debug-only assembly
.endif
```

C code can use them with the preprocessor:

```c
#ifdef DEBUG
/* debug-only C code */
#endif
```

---

## Shared Code Layout

The Makefile expects shared code one level above the Xcode project directory:

```text
Workspace/
├── Shared/
│   ├── labels/
│   ├── macros/
│   └── libraries/
│       ├── math/
│       │   └── *.s
│       └── text/
│           └── *.s
└── ___PACKAGENAME___/
    ├── ___PACKAGENAME___.xcodeproj/
    └── ___PACKAGENAME___/
        ├── Makefile
        ├── c64-asm.cfg
        ├── c64-hybrid.cfg
        ├── main.s
        └── README-SETUP.md
```

Include paths are generated from:

```make
INCLUDES = -I $(SHARED_DIR) -I $(SHARED_DIR)/labels -I $(SHARED_DIR)/macros \
           $(addprefix -I , $(LIB_DIRS))
```

Every immediate folder under `Shared/libraries` is assembled into its own
temporary `.lib` archive with `ar65` and linked into the final program.

---

## VICE Monitor

The shared scheme launches VICE with:

```text
-moncommands $(C64_LABELS)
-autoload $(C64_PRG)
```

When VICE runs, press **Option+H** to open the monitor. Labels generated by
`ld65 -Ln` are loaded automatically.

Useful monitor commands:

```text
break main
break $0810
delete 1
step
next
continue
registers
mem $0400 $07e7
disass $0810 $0850
al
al main
```

---

## Adding Another Target

Use the **CC65 Target** template to add another C64 target to an existing
project. Each target receives its own folder, Makefile, linker configs, source
file and shared Xcode scheme.

Xcode only scans shared schemes when a project is loaded. If a newly added
target is not visible under **Product > Scheme**, close and reopen the project.

---

## Troubleshooting

### CC65 tools are not found

- Confirm `~/Applications/CC65/bin/ca65` exists.
- If CC65 is installed elsewhere, update `CC65_HOME`, `CC`, `AS`, `LD`, `CL`
  and `AR` in the generated target `Makefile`.
- Build again with **Cmd+B** and check the Xcode build log for the exact path
  Make attempted to run.

### Missing `c64.lib`

- Confirm `~/Applications/CC65/share/cc65/lib/c64.lib` exists.
- This only affects `C` and `HYBRID` modes. Pure `ASM` mode does not link
  `c64.lib`.

### Missing include files

- Confirm the file lives under `Shared`, `Shared/labels`, `Shared/macros`, or
  an immediate subfolder of `Shared/libraries`.
- Add another `-I` entry to `INCLUDES` in the target `Makefile` if the include
  belongs somewhere else.

### VICE does not launch on Cmd+R

- Confirm the scheme executable points to
  `/Applications/vice-arm64-gtk3-3.10/bin/x64sc`.
- Confirm `$(TARGET_NAME).prg` exists in `$(TARGET_BUILD_DIR)` after a
  successful build.
- Check the Run action arguments include `-autoload $(C64_PRG)` and
  `-moncommands $(C64_LABELS)`.

### VICE launches but labels are missing

- Confirm `$(TARGET_NAME)-lbl.txt` exists next to the `.prg`.
- Check the linker command includes `-Ln $(TARGETLBL)`.
- If labels changed but VICE still shows old names, stop VICE and run again.

### Linker configuration errors

- Use `c64-asm.cfg` for pure assembly mode.
- Use `c64-hybrid.cfg` for C or mixed C/assembly mode.
- Make sure source files use segments declared by the active linker config,
  such as `LOADADDR`, `STARTUP`, `CODE`, `RODATA`, `DATA`, `BSS`, and
  `ZEROPAGE`.

---

Happy C64 coding.
