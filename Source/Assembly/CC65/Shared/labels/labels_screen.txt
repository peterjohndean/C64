.ifndef LABELS_ROM_SCREEN_S
LABELS_ROM_SCREEN_S = 1

; PETSCII Control Codes
PETSCII_RETURN       = $0d
PETSCII_CLEAR        = $93
PETSCII_HOME         = $13
PETSCII_CURSOR_DOWN  = $11
PETSCII_CURSOR_UP    = $91
PETSCII_CURSOR_LEFT  = $9d
PETSCII_CURSOR_RIGHT = $1d

; PETSCII Colour Control Codes
PETSCII_WHITE       = $05   ; 5   → colour 1
PETSCII_RED         = $1c   ; 28  → colour 2
PETSCII_GREEN       = $1e   ; 30  → colour 5
PETSCII_BLUE        = $1f   ; 31  → colour 6
PETSCII_BLACK       = $90   ; 144 → colour 0
PETSCII_ORANGE      = $81   ; 129 → colour 8
PETSCII_BROWN       = $95   ; 149 → colour 9
PETSCII_LIGHT_RED   = $96   ; 150 → colour 10
PETSCII_DARK_GRAY   = $97   ; 151 → colour 11
PETSCII_GRAY        = $98   ; 152 → colour 12
PETSCII_LIGHT_GREEN = $99   ; 153 → colour 13
PETSCII_LIGHT_BLUE  = $9a   ; 154 → colour 14 (default)
PETSCII_LIGHT_GRAY  = $9b   ; 155 → colour 15
PETSCII_PURPLE      = $9c   ; 156 → colour 4
PETSCII_CYAN        = $9f   ; 159 → colour 3
PETSCII_YELLOW      = $9e   ; 158 → colour 7

;
SCREEN_RAM_BASE     := $0400 ; Screen RAM start: 1000 bytes (40x25 character grid)
                            ; NOTE: Colour RAM is at $D800, not $0800. Some reference materials incorrectly list $0800.
COLOR_RAM_BASE      := $d800 ; Colour RAM start: 1000 bytes (one nibble per cell)

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

.if 0
;D000		53248		Sprite 0 X Pos
;D001		53249		Sprite 0 Y Pos
D002		53250		Sprite 1 X Pos
D003		53251		Sprite 1 Y Pos
D004		53252		Sprite 2 X Pos
D005		53253		Sprite 2 Y Pos
D006		53254		Sprite 3 X Pos
D007		53255		Sprite 3 Y Pos
D008		53256		Sprite 4 X Pos
D009		53257		Sprite 4 Y Pos
D00A		53258		Sprite 5 X Pos
D00B		53259		Sprite 5 Y Pos
D00C		53260		Sprite 6 X Pos
D00D		53261		Sprite 6 Y Pos
D00E		53262		Sprite 7 X Pos
D00F		53263		Sprite 7 Y Pos
;D010		53264		Sprites 0-7 X Pos (msb of X coord.)

;D011		53265		VIC Control Register
;			7	Raster Compare: (Bit 8)	See 53266
;			6	Extended Color Text Mode 1 = Enable
;			5	Bit Map Mode. 1 = Enable
;			4	Blank Screen to Border Color: 0 = Blank
;			3	Select 24/25 Row Text Display: 1 = 25 Rows
;			2-0	Smooth Scroll to Y Dot-Position (0-7)

;D012	53266			Read Raster / Write Raster Value for Compare
				IRQ
D013	53267			Light-Pen Latch X Pos
D014	53268			Light-Pen Latch Y Pos
;D015	53269			Sprite display Enable: 1 = Enable

D016	53270			VIC Control Register
			7-6	Unused
			5	ALWAYS SET THIS BIT TO 0 !
			4	Multi-Color Mode: 1 = Enable (Text or
				Bit-Map)
			3	Select 38/40 Column Text Display: 1 = 40 Cols
			2-0	Smooth Scroll to X Pos

D017	53271			Sprites 0-7 Expand 2x Vertical (Y)

D018	53272			VIC Memory Control Register
			7-4	Video Matrix Base Address (inside VIC)
			3-1	Character Dot-Data Base	Address (inside VIC)
			0	Select upper/lower Character Set

;D019	53273			VIC Interrupt Flag Register (Bit = 1: IRQ Occurred)
;			7	Set on Any Enabled VIC IRQ Condition
;			3	Light-Pen Triggered IRQ Flag
;			2	Sprite to Sprite Collision IRQ Flag
;			1	Sprite to Background Collision IRQ Flag
;			0	Raster Compare IRQ Flag

;D01A	53274			IRQ Mask Register: 1 = Interrupt Enabled
;D01B	53275			Sprite to Background Display Priority: 1 = Sprite
D01C	53276			Sprites 0-7 Multi-Color Mode Select: 1 = MCM.
D01D	53277			Sprites 0-7 Expand 2x Horizontal (X)

D01E	53278			Sprite to Sprite Collision Detect
;D01F	53279			Sprite to Background Collision Detect
;D020	53280			Border Color
;D021	53281			Background Color 0
D022	53282			Background Color 1
D023	53283			Background Color 2
D024	53284			Background Color 3
D025	53285			Sprite Multi-Color Register 0
D026	53286			Sprite Multi-Color Register 1

;D027	53287			Sprite 0 Color
D028	53288			Sprite 1 Color
D029	53289			Sprite 2 Color
D02A	53290			Sprite 3 Color
D02B	53291			Sprite 4 Color
D02C	53292			Sprite 5 Color
D02D	53293			Sprite 6 Color
D02E	53294			Sprite 7 Color
.endif


;
;$DE00 to $DEFF Open I/O slot #1 (CP/M Enable) 256 Bytes
;$DF00 to $DFFF Open I/O slot #2 (Disk) 256 Bytes

.if 0
DC00-DCFF	56320-56575	MOS 6526 Complex Interface Adapter (CIA) #1

;DC00	56320			Data Port A (Keyboard, Joystick, Paddles, Light-Pen)
;
;			7-0	Write Keyboard Column Values for Keyboard Scan
;			7-6	Read Paddles on Port A / B (01 = Port A, 10 = Port B)
;			4	Joystick A Fire Button: 1 = Fire
;			3-2	Paddle Fire Buttons
;			3-0	Joystick A Direction (0-15)
;
;DC01	56321			Data Port B (Keyboard, Joystick, Paddles):
;				Game Port 1
;			7-0	Read Keyboard Row Values for Keyboard Scan
;			7	Timer B Toggle/Pulse Output
;			6	Timer A: Toggle/Pulse Output
;			4	Joystick 1 Fire Button: 1 = Fire
;			3-2	Paddle Fire Buttons
;			3-0	Joystick 1 Direction

DC02	56322			Data Direction Register - Port A (56320)
DC03	56323			Data Direction Register - Port B (56321)
DC04	56324			Timer A: Low-Byte
DC05	56325			Timer A: High-Byte
DC06	56326			Timer B: Low-Byte
DC07	56327			Timer B: High-Byte

DC08	56328			Time-of-Day Clock: 1/10 Seconds
DC09	56329			Time-of-Day Clock: Seconds
DC0A	56330			Time-of-Day Clock: Minutes
DC0B	56331			Time-of-Day Clock: Hours + AM/PM Flag (Bit 7)

DC0C	56332			Synchronous Serial I/O Data Buffer
DC0D	56333			CIA Interrupt Control Register
				(Read IRQs/Write Mask)

			7	IRQ Flag (1 = IRQ Occurred) / Set-Clear Flag
			4	FLAG1 IRQ (Cassette Read / Serial Bus SRQ
				Input)
			3	Serial Port Interrupt
			2	Time-of-Day Clock Alarm Interrupt
			1	Timer B Interrupt
			0	Timer A Interrupt

DC0E	56334			CIA Control Register A
			7	Time-of-Day Clock Frequency: 1 = 50 Hz,
				0 = 60 Hz
			6	Serial Port I/O Mode Output, 0 = Input
			5	Timer A Counts: 1 = CNT Signals,
				0 = System 02 Clock

			4	Force Load Timer A: 1 = Yes
			3	Timer A Run Mode: 1 = One-Shot,
				0 = Continuous
			2	Timer A Output Mode to PB6: 1 = Toggle,
				0 = Pulse
			1	Timer A Output on PB6: 1 = Yes, 0 = No
			0	Start/Stop Timer A: 1 = Start, 0 = Stop

DC0F	56335			CIA Control Register B
			7	Set Alarm/TOD-Clock: 1 = Alarm, 0 = Clock
			6-5	Timer B Mode Select:
					00 = Count System 02 Clock Pulses
					01 = Count Positive CNT Transitions
					10 = Count Timer A Underflow Pulses
					11 = Count Timer A Underflows While
					     CNT Positive
			4-0	Same as CIA Control Reg. A - for Timer B

DD00-DDFF	56576-56831	MOS 6526 Complex Interface Adapter (CIA) #2

;DD00	56576			Data Port A (Serial Bus, RS-232, VIC Memory Control)
;			7	Serial Bus Data Input
;			6	Serial Bus Clock Pulse Input
;			5	Serial Bus Data Output
;			4	Serial Bus Clock Pulse Output
;			3	Serial Bus ATN Signal Output
;			2	RS-232 Data Output (User Port)
;			1-0	VIC Chip System Memory Bank Select
;				(Default = 11)

DD01	56577		Data Port B (User Port, RS-232)
			7	User / RS-232 Data Set Ready
			6	User / RS-232 Clear to Send
			5	User
			4	User / RS-232 Carrier Detect
			3	User / RS-232 Ring Indicator
			2	User / RS-232 Data Terminal Ready
			1	User / RS-232 Request to Send
			0	User / RS-232 Received Data

DD02	56578			Data Direction Register - Port A
DD03	56579			Data Direction Register - Port B
DD04	56580			Timer A: Low-Byte
DD05	56581			Timer A: High-Byte
DD06	56582			Timer B: Low-Byte
DD07	56583			Timer B: High-Byte

DD08	56584			Time-of-Day Clock: 1/10 Seconds
DD09	56585			Time-of-Day Clock: Seconds
DD0A	56586			Time-of-Day Clock: Minutes
DD0B	56587			Time-of-Day Clock: Hours + AM/PM Flag (Bit 7)
DD0C	56588			Synchronous Serial I/O Data Buffer
DD0D	56589			CIA Interrupt Control Register (Read
				NMls/Write Mask)
			7	NMI Flag (1 = NMI Occurred) / Set-Clear Flag
			4	FLAG1 NMI (User/RS-232 Received Data Input)
			3	Serial Port Interrupt

			1	Timer B Interrupt
			0	Timer A Interrupt

DD0E	56590			CIA Control Register A

			7	Time-of-Day Clock Frequency: 1 = 50 Hz,
				0 = 60 Hz
			6	Serial Port I/O Mode Output, 0 = Input
			5	Timer A Counts: 1 = CNT Signals,
				0 = System 02 Clock
			4	Force Load Timer A: 1 = Yes
			3	Timer A Run Mode: 1 = One-Shot,
				0 = Continuous
			2	Timer A Output Mode to PB6: 1 = Toggle,
				0 = Pulse
			1	Timer A Output on PB6: 1 = Yes, 0 = No
			0	Start/Stop Timer A: 1 = Start, 0 = Stop

DD0F	56591			CIA Control Register B
			7	Set Alarm/TOD-Clock: 1 = Alarm, 0 = Clock
			6-5	Timer B Mode Select:
					00 = Count System 02 Clock Pulses
					01 = Count Positive CNT Transitions
					10 = Count Timer A Underflow Pulses
					11 = Count Timer A Underflows While
					     CNT Positive
			4-0	Same as CIA Control Reg. A - for Timer B


DE00-DEFF	56832-57087	Reserved for Future I/O Expansion
DF00-DFFF	57088-57343	Reserved for Future I/O Expansion
.endif
