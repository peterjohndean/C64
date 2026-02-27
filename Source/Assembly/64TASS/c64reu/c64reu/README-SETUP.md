# c64reu - C64 Assembly Project

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

After **⌘B** or **⌘R**, check your project folder:
```
c64reu/
├── c64reu.prg       ← C64 executable
├── c64reu_lbl.txt   ← VICE monitor labels
└── c64reu_lst.txt   ← Assembly listing
```

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
| `C64_SHARED_LIB` | `../SharedLib/Includes` | Shared include directory |
| `C64_SOURCE` | `$(PROJECT_NAME)/main.s` | Input source file |
| `C64_PRG` | `$(SOURCE_ROOT)/$(PROJECT_NAME)/$(TARGET_NAME).prg` | Output binary |
| `C64_LABELS` | `$(SOURCE_ROOT)/$(PROJECT_NAME)/$(TARGET_NAME)_lbl.txt` | VICE label file |
| `C64_LIST` | `$(PROJECT_NAME)/$(TARGET_NAME)_lst.txt` | Assembly listing |
| `C64_ASM_FLAGS` | See below | All assembler flags |

### Assembler Flags Reference

| Flag | Purpose |
|------|---------|
| `-I $(C64_SHARED_LIB)` | Add shared library to `.include` search path |
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

---

## 💡 Assembly Tips

### Including Shared Code

Use `.include` to load shared libraries — 64TASS searches `C64_SHARED_LIB` automatically:

```asm
.include "macros.s"        ; load shared macros
.include "constants.s"     ; load system constants and labels
```

### Renaming the Target

`$(PROJECT_NAME)` always points to the source subdirectory created at project
creation time, so renaming the target only affects output filenames — `main.s`
is always found correctly.

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

## 📚 Project Structure

```
Your-Workspace/
├── SharedLib/
│   └── Includes/              ← shared .include files
│       ├── macros.s
│       └── constants.s
│
└── c64reu/
    ├── c64reu.xcodeproj/
    │   └── xcshareddata/
    │       └── xcschemes/
    │           └── c64reu.xcscheme   ← pre-configured Run scheme
    └── c64reu/
        └── main.s             ← your code starts here
```

---

## 🆘 Troubleshooting

### VICE does not launch on ⌘R
- Verify `C64_VICE_TOOL` in Build Settings points to your VICE `x64sc` binary
- Check **Product → Scheme → Edit Scheme → Run → Info** confirms `x64sc` as executable

### Build errors about missing include files
- Verify `C64_SHARED_LIB` in Build Settings points to your shared includes directory

### VICE launches but program does not load
- Confirm `$(TARGET_NAME).prg` exists in the project subfolder after a successful build
- Check the build log for any 64TASS errors or warnings

### Branch too far errors
- `--long-branch` is enabled by default and should handle this automatically
- If it fires, `-Wlong-branch` will note it in the build log — this is informational, not an error

---

**Happy C64 coding!** 🎉
