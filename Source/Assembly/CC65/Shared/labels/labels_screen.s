.ifndef LABELS_ROM_SCREEN_S
LABELS_ROM_SCREEN_S = 1

; PETSCII Control Codes
PETSCII_RETURN          = $0d
PETSCII_INSTDEL         = $14   ; Backspace/Delete
PETSCII_CLEAR           = $93   ; Clear screen + home
PETSCII_HOME            = $13
PETSCII_RVSON           = $12   ; RVS on
PETSCII_RVSOFF          = $92   ; RVS off
PETSCII_CURSOR_DOWN     = $11
PETSCII_CURSOR_UP       = $91
PETSCII_CURSOR_LEFT     = $9d
PETSCII_CURSOR_RIGHT    = $1d

; PETSCII Colour Control Codes
PETSCII_WHITE           = $05   ; 5   → colour 1
PETSCII_RED             = $1c   ; 28  → colour 2
PETSCII_GREEN           = $1e   ; 30  → colour 5
PETSCII_BLUE            = $1f   ; 31  → colour 6
PETSCII_BLACK           = $90   ; 144 → colour 0
PETSCII_ORANGE          = $81   ; 129 → colour 8
PETSCII_BROWN           = $95   ; 149 → colour 9
PETSCII_LIGHT_RED       = $96   ; 150 → colour 10
PETSCII_DARK_GRAY       = $97   ; 151 → colour 11
PETSCII_GRAY            = $98   ; 152 → colour 12
PETSCII_LIGHT_GREEN     = $99   ; 153 → colour 13
PETSCII_LIGHT_BLUE      = $9a   ; 154 → colour 14 (default)
PETSCII_LIGHT_GRAY      = $9b   ; 155 → colour 15
PETSCII_PURPLE          = $9c   ; 156 → colour 4
PETSCII_CYAN            = $9f   ; 159 → colour 3
PETSCII_YELLOW          = $9e   ; 158 → colour 7

;
SCREEN_RAM_BASE     := $0400    ; Screen RAM start: 1000 bytes (40x25 character grid)
                                ; NOTE: Colour RAM is at $D800, not $0800. Some reference materials incorrectly list $0800.
COLOR_RAM_BASE      := $d800    ; Colour RAM start: 1000 bytes (one nibble per cell)

;
;
SPRITE_PTR_BASE     := $07f8 ; 07F8-07FF Default Sprite Data Pointers.
SPRITE_0_PTR        := SPRITE_PTR_BASE

;
; --- VIC-II (MOS 6566 Video Interface Controller) Chip Registers ($D000–$D02E) ---
;
VICII_BASE      := $d000

SPRITE_0X       := VICII_BASE			; Sprite 0 X position
SPRITE_0Y       := VICII_BASE + $01		; Sprite 0 Y position
SPRITE_0C       := VICII_BASE + $27		; Sprite 0 colour

SPRITE_XMSB     := VICII_BASE + $10		; Sprites 0-7 X Pos (msb of X coord.): bit N = 9th X bit for sprite N
SPRITE_XENABLE  := VICII_BASE + $15 	; Sprites 0-7 X Enable register: bit N = 1 → sprite N visible
SPRITE_BGPR     := VICII_BASE + $1b 	; Sprite/background priority:
										;   bit N = 0 → sprite N FRONT of background
										;   bit N = 1 → sprite N BEHIND background

VICII_SPTOBGCOL     := VICII_BASE + $1f ; Sprite to Background Collision Detect
VICII_CTRLREG       := VICII_BASE + $11 ; VIC Control Register
VICII_RASTER        := VICII_BASE + $12 ; Current raster scan line (read-only)
VICII_IRQFLAG       := VICII_BASE + $19 ; VIC Interrupt Flag Register (Bit = 1: IRQ Occurred)
VICII_IRQENABLE     := VICII_BASE + $1a ; IRQ Mask Register: 1 = Interrupt Enabled
VICII_BGCOLOR0      := VICII_BASE + $21 ; Background colour 0 (drawn behind all text)
VICII_BORDERCOLOR   := VICII_BASE + $20 ; Screen border colour register

SID_BASE	:= $d400 ; $D400 to $D7FF SID (Sound Synthesizer) 1K Bytes

;
; --- CIA 1 (MOS 6526 Complex Interface Adaptor - DC00-DCFF) Chip Registers ---
;
CIA1_BASE   := $dc00
CIA1_PORTA  := CIA1_BASE		; Data Port A (Keyboard, Joystick, Paddles, Light-Pen)
								; 7-0	Write Keyboard Column Values for Keyboard Scan
								; 7-6	Read Paddles on Port A / B (01 = Port A, 10 = Port B)
								; 4	Joystick A Fire Button: 1 = Fire
								; 3-2	Paddle Fire Buttons
								; 3-0	Joystick A Direction (0-15)
								
CIA1_PORTB  := CIA1_BASE + $01	; Data Port B (Keyboard, Joystick, Paddles)
								; Game Port 1
								; 7-0	Read Keyboard Row Values for Keyboard Scan
								; 7	Timer B Toggle/Pulse Output
								; 6	Timer A: Toggle/Pulse Output
								; 4	Joystick 1 Fire Button: 1 = Fire
								; 3-2	Paddle Fire Buttons
								; 3-0	Joystick 1 Direction

;
; --- CIA 2 (MOS 6526 Complex Interface Adaptor - DD00-DDFF) Chip Registers ---
;
CIA2_BASE   := $dd00
CIA2_PORTA  := CIA2_BASE		; Data Port A (Serial Bus, RS-232, VIC Memory Control)
.endif
