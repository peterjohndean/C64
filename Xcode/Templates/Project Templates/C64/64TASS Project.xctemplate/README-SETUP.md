# ___PACKAGENAME___ - C64 Assembly Project

Built with **64TASS** assembler and **VICE** emulator.

---

## 🎮 Usage

The project is fully configured and ready to use immediately.

| Command | Action |
|---------|--------|
| **⌘B** | Build (assemble only) |
| **⌘R** | Build + Run in VICE |
| **⌘.** | Stop VICE |

Press **⌘R** now to build and launch your program in VICE.

---

## 📊 What Gets Built

After **⌘B** or **⌘R**, output files are written to Xcode's standard
**DerivedData** build directory (`$(TARGET_BUILD_DIR)`). You can find the
exact path in the build log, or navigate there via:

> **Product → Show Build Folder in Finder**

The three output files produced per build are:

```
<DerivedData>/Build/Products/<Config>-<Platform>/
├── ___PACKAGENAME___.prg       ← C64 executable
├── ___PACKAGENAME____lbl.txt   ← VICE monitor labels
└── ___PACKAGENAME____lst.txt   ← Assembly listing
```

> **Note:** Output is no longer written into the source subdirectory.
> `C64_BUILD_DIR` is set to `$(TARGET_BUILD_DIR)`, so all three files land
> in Xcode's DerivedData folder alongside any other build products.

---

## 🔧 Customizing Build Settings

All paths and flags are defined as named build settings, editable directly
from within Xcode without touching the argument string.

1. Select the **project root** in the Project Navigator
2. Go to the **Build Settings** tab
3. Type `C64` in the search box
4. Double-click any value to edit

| Setting | Default | Purpose |
|---------|---------|---------|
| `C64_ASM_TOOL` | `/Users/peter/Applications/64tass` | Assembler path |
| `C64_VICE_TOOL` | `/Applications/vice-arm64-gtk3-3.10/bin/x64sc` | Emulator path |
| `C64_BUILD_DIR` | `$(TARGET_BUILD_DIR)` | Output directory for all build artifacts |
| `C64_SHARED_LIB` | `-I ../shared/inc -I ../shared/lib -I ../shared/mac` | Shared include directories (passed directly to assembler) |
| `C64_SOURCE` | `$(TARGET_NAME)/main.s` | Input source file, per-target subdirectory |
| `C64_PRG` | `$(C64_BUILD_DIR)/$(TARGET_NAME).prg` | Output binary |
| `C64_LABELS` | `$(C64_BUILD_DIR)/$(TARGET_NAME)_lbl.txt` | VICE label file |
| `C64_LIST` | `$(C64_BUILD_DIR)/$(TARGET_NAME)_lst.txt` | Assembly listing |
| `C64_ASM_DEFAULT_FLAGS` | See below | Base assembler flags, shared across configurations |
| `C64_ASM_FLAGS` | `$(C64_ASM_DEFAULT_FLAGS)` | Effective flags passed to the assembler (overridden per configuration — see below) |

> **Note:** `C64_ASM_FLAGS` is what the build system actually passes to the
> assembler. In the shared (non-configuration-specific) setting it simply
> expands to `$(C64_ASM_DEFAULT_FLAGS)`. The Debug and Release configurations
> each override it to prepend their own defines — see **Debug / Release
> Configurations** below.

### Assembler Flags Reference

`C64_ASM_DEFAULT_FLAGS` expands to:

```
$(C64_SHARED_LIB) -o $(C64_PRG) --vice-labels --labels=$(C64_LABELS)
--long-branch -Wunused -Wshadow -Woptimize -Wlong-branch -Wcase-symbol
-L $(C64_LIST) --case-sensitive -a $(C64_SOURCE)
```

| Flag | Purpose |
|------|---------|
| `$(C64_SHARED_LIB)` | Expands to one or more `-I <path>` flags; adds shared directories to `.include` search path |
| `-a $(C64_SOURCE)` | Input source file |
| `-o $(C64_PRG)` | Output `.prg` file |
| `--vice-labels` | Emit labels in VICE monitor format |
| `--labels=$(C64_LABELS)` | Write label file to specified path |
| `--long-branch` | Auto-promote out-of-range branches to JMP sequences |
| `-L $(C64_LIST)` | Write full assembly listing to specified path |
| `--case-sensitive` | Treat label names as case-sensitive |
| `-Wunused` | Warn on labels defined but never referenced |
| `-Wshadow` | Warn when a local label shadows an outer scope label |
| `-Woptimize` | Warn when a longer instruction form could be shorter |
| `-Wlong-branch` | Warn when `--long-branch` promotes a branch |
| `-Wcase-symbol` | Warn on case mismatches against `--case-sensitive` labels |

### Debug / Release Configurations

The Debug and Release configurations each override `C64_ASM_FLAGS` to prepend
preprocessor defines before the shared base flags:

| Configuration | `C64_ASM_FLAGS` value |
|---------------|-----------------------|
| **Debug** | `-D DEBUG=1 -D RELEASE=0 $(C64_ASM_DEFAULT_FLAGS)` |
| **Release** | `-D DEBUG=0 -D RELEASE=1 $(C64_ASM_DEFAULT_FLAGS)` |

This lets you conditionally assemble code in your source files:

```asm
.if DEBUG
    ; extra debug output, breakpoints, etc.
    jsr print_debug_info
.endif
```

> To add your own conditional defines, edit `C64_ASM_FLAGS` for the relevant
> configuration in Build Settings, inserting additional `-D KEY=VALUE` entries
> before `$(C64_ASM_DEFAULT_FLAGS)`.

---

## 💡 Assembly Tips

### Including Shared Code

`C64_SHARED_LIB` passes three `-I` search paths to the assembler, so `.include`
finds files across all three shared directories automatically:

```asm
.include "macros.s"        ; resolved from ../shared/mac
.include "constants.s"     ; resolved from ../shared/inc
```

To add or change a search path, edit `C64_SHARED_LIB` in Build Settings —
append another `-I <path>` entry.

### Multi-Target Projects

Each target has its own subdirectory at `$(SOURCE_ROOT)/$(TARGET_NAME)/` containing
its own `main.s`. All build outputs (`.prg`, labels, listing) are written into
`$(TARGET_BUILD_DIR)`, which Xcode scopes per-target automatically — they never
collide.

---

## 📚 Project Structure

```
Workspace/
├── shared/                        ← shared code, searched by C64_SHARED_LIB
│   ├── inc/                       ← constants, system labels
│   ├── lib/                       ← reusable routines
│   └── mac/                       ← macros
│
└── ___PACKAGENAME___/
    ├── ___PACKAGENAME___.xcodeproj/
    │   └── xcshareddata/
    │       └── xcschemes/
    │           └── ___PACKAGENAME___.xcscheme   ← pre-configured Run scheme
    │
    └── ___PACKAGENAME___/         ← target subdirectory (source only)
        └── main.s                 ← your code starts here
```

Build outputs are written to Xcode's DerivedData directory (`$(TARGET_BUILD_DIR)`),
not into the source tree:

```
~/Library/Developer/Xcode/DerivedData/<Project>/Build/Products/<Config>/
├── ___PACKAGENAME___.prg
├── ___PACKAGENAME____lbl.txt
└── ___PACKAGENAME____lst.txt
```

For a project with multiple targets:

```
MyProject/
├── MyProject.xcodeproj/
│   └── xcshareddata/
│       └── xcschemes/
│           ├── Demo1.xcscheme
│           └── Demo2.xcscheme     ← one scheme per target, all shared
│
├── Demo1/
│   └── main.s
└── Demo2/
    └── main.s
```

Each target's outputs land in their own `$(TARGET_BUILD_DIR)` subdirectory
inside DerivedData and are fully isolated from one another.

---

## 🐛 VICE Monitor (Debugger)

When VICE runs, press **Alt+H** (or **⌥H** on Mac) to open the monitor.
Your labels from `$(TARGET_NAME)_lbl.txt` are loaded automatically — use them
instead of raw addresses.

### Essential Commands

```
; Breakpoints
break .start              ; break at label
break $0810               ; break at address
delete 1                  ; remove breakpoint 1

; Execution
step                      ; execute one instruction
next                      ; step over subroutines
continue                  ; resume execution
goto $0810                ; jump to address

; Memory & Registers
print .message            ; show memory at label
disass $0810 $0850        ; disassemble range
registers                 ; show CPU registers
mem $0400 $07e7           ; dump screen memory

; Labels
al                        ; list all loaded labels
al start                  ; search labels containing "start"
```

---

## 🆘 Troubleshooting

### New target scheme not visible in Product → Scheme
- This is expected behaviour. Xcode only scans `xcshareddata/xcschemes/` at
  project load time; schemes written by the template during target creation are
  not picked up until the next load.
- **Fix:** Close the project (`⌘⇧W`) and reopen it. The new target's scheme
  will appear immediately.

### VICE does not launch on ⌘R
- Verify `C64_VICE_TOOL` in Build Settings points to your VICE `x64sc` binary.
- Check **Product → Scheme → Edit Scheme → Run → Info** confirms `x64sc` as
  the executable.

### Build errors about missing include files
- Verify `C64_SHARED_LIB` in Build Settings contains a `-I <path>` entry that
  points to the directory holding the missing file.
- The default value covers `../shared/inc`, `../shared/lib`, and `../shared/mac`
  relative to `SOURCE_ROOT`. Add further `-I <path>` entries as needed.

### VICE launches but program does not load
- Confirm `$(TARGET_NAME).prg` exists in `$(TARGET_BUILD_DIR)` after a
  successful build. Use **Product → Show Build Folder in Finder** to locate it.
- Check the build log for any 64TASS errors or warnings.

### Branch too far errors
- `--long-branch` is enabled by default and should handle this automatically.
- If it fires, `-Wlong-branch` will note it in the build log — this is
  informational, not an error.

---

**Happy C64 coding!** 🎉
