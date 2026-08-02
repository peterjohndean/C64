.ifndef LABELS_ROM_KERNAL_S
LABELS_ROM_KERNAL_S = 1

;------------------------------------------------
; C64 KERNAL ROM
; E000–FFFF 57344–65535 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
KERNAL_BASSFT   := $e37b	; BASIC 2.0 Warm Restart [RUNSTOP-RESTORE] (use jmp)
KERNAL_INIT     := $e394	; BASIC 2.0 Cold Restart (use jmp)
KERNAL_LISTEN	:= $ffb1	; Command devices on the serial bus to LISTEN, register A = Logical
KERNAL_READST	:= $ffb7	; Read status register, register A
KERNAL_SETNAM	:= $ffbd	; Set filename pointer, Register A = length, YX to filename
KERNAL_SETLFS	:= $ffba	; Set LFS, Register A = Logical, X = First/Device, Y = secondary address
KERNAL_OPEN	    := $ffc0	; Open logical file
KERNAL_CLOSE	:= $ffc3	; Close logical file, register A = logical file #
KERNAL_CHKIN	:= $ffc6	; Set input device, register X = logic file #
KERNAL_CHKOUT	:= $ffc9	; Set output device, register X = logical file #
KERNAL_CLRCHN	:= $ffcc	; Clear channels
KERNAL_CHRIN	:= $ffcf	; Read character from input channel, register A
KERNAL_LOAD     := $ffd5	; Load RAM from device, A=0 (load), A=1 (verify), RAM at Y/X address.
KERNAL_CLALL	:= $ffe7	; Close all
KERNAL_CHROUT	:= $ffd2	; Output character in register A
KERNAL_GETIN    := $ffe4	; Get input character, reads the next key from the keyboard queue into A, or $00 if the queue is empty. Non-blocking.
.endif

.if 0
;
;	C64 KERNEL ROM
;
(exp	= $e000
polyx	= $e043
rmulc	= $e08d		data
rnd	= $e097
bioerr	= $e0f9
bchout	= $e10c
bchin	= $e112
bckout	= $e118
bckin	= $e11e
bgetin	= $e124
sys	= $e12a
savet	= $e156
verfyt	= $e165
opent	= $e1be
closet	= $e1c7
slpara	= $e1d4
combyt	= $e200
deflt	= $e206
cmmerr	= $e20e
ocpara	= $e219
cos	= $e264
sin	= $e26b
tan	= $e2b4
pi2	= $e2e0		data
atn	= $e30e
atncon	= $e33e		data
bassft	= $e37b
init	= $e394
initat	= $e3a2
rndsed	= $e3ba
initcz	= $e3bf
initms	= $e422
bvtrs	= $e447		data
initv	= $e453
words	= $e45f
-	= $e4ad
-	= $e4b7		illegal
-	= $e4da
-	= $e4e0
-	= $e4ec		data
iobase	= $e500
screen	= $e505
plot	= $e50a
cint1	= $e518
-	= $e544
-	= $e566
-	= $e56c
	= ;
-	= $e59a
lp2	= $e5b4
-	= $e5ca
-	= $e632
-	= $e684
-	= $e691
-	= $e6b6
-	= $e6ed
-	= $e701
-	= $e716
-	= $e87c
-	= $e891
-	= $e8a1
-	= $eacb
-	= $e8da
-	= $e8ea
-	= $e965
-	= $e9c8
-	= $e9e0
-	= $e9f0
-	= $e9ff
-	= $ea13
-	= $ea24
-	= $ea31
scnkey	= $ea87
-	= $eadd		data
-	= $eb79		data
-	= $eb81		data
-	= $ebc2		data
-	= $ec03
-	= $ec44		data
-	= $ec78		data
-	= $ecb9
-	= $ece7		data
-	= $ecf0
talk	= $ed09
-	= $ed40
-	= $edad
second	= $edb9
-	= $edbe
tksa	= $edc7
-	= $edcc
ciout	= $eddd
untlk	= $edef
acptr	= $ee13
-	= $ee85
-	= $ee8e
-	= $ee97
-	= $eea0
-	= $eea9
-	= $eeb3
-	= $eebb
-	= $ef06
-	= $ef2e
-	= $ef39
-	= $ef4a
-	= $ef59
-	= $ef7e
-	= $ef90
-	= $efe1
-	= $f00d
-	= $f017
-	= $f04d
-	= $f086
-	= $f0a4
-	= $f0bd
-	= $f128
getin	= $f13e
chrin	= $f157
-	= $f199
chrout	= $f1ca
chkin	= $f20e
chkout	= $f250
close	= $f291
-	= $f30f
-	= $f31f
clall	= $f32f
clrchn	= $f333
open	= $f34a
-	= $f3d5
-	= $f409
load	= $f49e
;
;--------------
;
save	= $f5dd
udtim	= $f69b
rdtim	= $f6dd
settim	= $f6e4
stop	= $f6ed
restor	= $fd15
vector	= $fd1a
ramtas	= $fd50
ioinit	= $fda3
setnam	= $fdf9
setlfs	= $fe00
readst	= $fe07
setmsg	= $fe18
settmo	= $fe21
memtop	= $fe25
membot	= $fe34
cint	= $fe58
;
;
; C64 KERNEL call addresses
;
acptr	= $ffa5
chkin	= $ffc6
chkout	= $ffc9
;chrin	= $ffcf
;chrout	= $ffd2
ciout	= $ffa8
cint	= $ff81
clall	= $ffe7
close	= $ffc3
clrchn	= $ffcc
getin	= $ffe4
iobase	= $fff3
ioinit	= $ff84
listen	= $ffb1
load	= $ffd5
membot	= $ff9c
memtop	= $ff99
open	= $ffc0
plot	= $fff0
ramtas	= $ff87
rdtim	= $ffde
readst	= $ffb7
restor	= $ff8a
save	= $ffd8
scnkey	= $ff9f
screen	= $ffed
second	= $ff93
setlfs	= $ffba
setmsg	= $ff90
setnam	= $ffbd
settim	= $ffdb
settmo	= $ffa2
stop	= $ffe1
talk	= $ffb4
tksa	= $ff96
udtim	= $ffea
unlsn	= $ffae
untlk	= $ffab
vector	= $ff8d
;


;
;
;	C64 Kernal ROM
;
e000	57344	(exp continues)	EXP continued From BASIC ROM
e043	57411	polyx	Series Evaluation
e08d	57485	rmulc	Constants for RND			DATA
e097	57495	rnd	Perform [rnd]
e0f9	57593	bioerr	Handle I/O Error in BASIC
e10c	57612	bchout	Output Character
e112	57618	bchin	Input Character
e118	57624	bckout	Set Up For Output
e11e	57630	bckin	Set Up For Input
e124	57636	bgetin	Get One Character
e12a	57642	sys	Perform [sys]
e156	57686	savet	Perform [save]
e165	57701	verfyt	Perform [verify / load]
e1be	57790	opent	Perform [open]
e1c7	57799	closet	Perform [close]
e1d4	57812	slpara	Get Parameters For LOAD/SAVE
e200	57856	combyt	Get Next One Byte Parameter
e206	57862	deflt	Check Default Parameters
e20e	57870	cmmerr	Check For Comma
e219	57881	ocpara	Get Parameters For OPEN/CLOSE
e264	57956	cos	Perform [cos]
e26b	57963	sin	Perform [sin]
e2b4	58036	tan	Perform [tan]
e2e0	58080	pi2	Table of Trig Constants			DATA

;e2e0	1.570796327	pi/2
;e2e5	6.28318531	pi*2
;e2ea	0.25

;e2ef	#05	(counter)
;e2f0	-14.3813907
;e2f5	42.0077971
;e2fa	-76.7041703
;e2ff	81.6052237
;e304	-41.3417021
;e309	6.28318531

e30e	58126	atn	Perform [atn]
e33e	58174	atncon	Table of ATN Constants			DATA

;e33e	#0b	(counter)
;e3ef	-0.000684793912
;e344	 0.00485094216
;e349	-0.161117018
;e34e	 0.034209638
;e353	-0.0542791328
;e358	 0.0724571965
;e35d	-0.0898023954
;e362	 0.110932413
;e367	-0.142839808
;e36c	 0.19999912
;e371	-0.333333316
;e376	 1.00

;e37b	58235	bassft	BASIC Warm Start [RUNSTOP-RESTORE]
;e394	58260	init	BASIC Cold Start
e3a2	58274	initat	CHRGET For Zero-page
e3ba	58298	rndsed	RND Seed For zero-page			DATA
;e3b2	0.811635157
e3bf	58303	initcz	Initialize BASIC RAM
e422	58402	initms	Output Power-Up Message
e447	58439	bvtrs	Table of BASIC Vectors (for 0300)	WORD
e453	58451	initv	Initialize Vectors
e45f	58463	words	Power-Up Message			DATA
e4ad	58541	-	Patch for BASIC Call to CHKOUT
e4b7	58551	-	Unused Bytes For Future Patches		EMPTY
e4da	58586	-	Reset Character Colour
e4e0	58592	-	Pause After Finding Tape File
e4ec	58604	-	RS-232 Timing Table -- PAL		DATA
e500	58624	iobase	Get I/O Address
e505	58629	screen	Get Screen Size
e50a	58634	plot	Put / Get Row And Column
e518	58648	cint1	Initialize I/O
e544	58692	-	Clear Screen
e566	58726	-	Home Cursor
e56c	58732	-	Set Screen Pointers
e59a	58778	-	Set I/O Defaults (Unused Entry)
e5a0	58784	-	Set I/O Defaults
e5b4	58804	lp2	Get Character From Keyboard Buffer
e5ca	58826	-	Input From Keyboard
e632	58930	-	Input From Screen or Keyboard
e684	59012	-	Quotes Test
e691	59025	-	Set Up Screen Print
e6b6	59062	-	Advance Cursor
e6ed	59117	-	Retreat Cursor
e701	59137	-	Back on to Previous Line
e716	59158	-	Output to Screen
e72a	59178	-	-unshifted characters-
e7d4	59348	-	-shifted characters-
e87c	59516	-	Go to Next Line
e891	59537	-	Output <CR>
e8a1	59553	-	Check Line Decrement
e8b3	59571	-	Check Line Increment
e8cb	59595	-	Set Colour Code
e8da	59610	-	Colour Code Table
e8ea	59626	-	Scroll Screen
e965	59749	-	Open A Space On The Screen
e9c8	59848	-	Move A Screen Line
e9e0	59872	-	Syncronise Colour Transfer
e9f0	59888	-	Set Start of Line
e9ff	59903	-	Clear Screen Line
ea13	59923	-	Print To Screen
ea24	59940	-	Syncronise Colour Pointer
ea31	59953	-	Main IRQ Entry Point
ea87	60039	scnkey	Scan Keyboard
eadd	60125	-	Process Key Image
eb79	60281	-	Pointers to Keyboard decoding tables	WORD
eb81	60289	-	Keyboard 1 -- unshifted			DATA
ebc2	60354	-	Keyboard 2 -- Shifted			DATA
ec03	60419	-	Keyboard 3 -- Commodore			DATA
ec44	60484	-	Graphics/Text Control
ec78	60536	-	Keyboard 4 -- Control			DATA
ecb9	60601	-	Video Chip Setup Table			DATA
ece7	60647	-	Shift-Run Equivalent
ecf0	60656	-	Low Byte Screen Line Addresses		DATA
ed09	60681	talk	Send TALK Command on Serial Bus
ed0c	60684	listn	Send LISTEN Command on Serial Bus
ed40	60736	-	Send Data On Serial Bus
edad	60845	-	Flag Errors
edad	60845	-	Status #80 - device not present
edb0	60848	-	Status #03 - write timeout
edb9	60857	second	Send LISTEN Secondary Address
edbe	60862	-	Clear ATN
edc7	60871	tksa	Send TALK Secondary Address
edcc	60876	-	Wait For Clock
eddd	60893	ciout	Send Serial Deferred
edef	60911	untlk	Send UNTALK / UNLISTEN
ee13	60947	acptr	Receive From Serial Bus
ee85	61061	-	Serial Clock On
ee8e	61070	-	Serial Clock Off
ee97	61079	-	Serial Output 1
eea0	61088	-	Serial Output 0
eea9	61097	-	Get Serial Data And Clock In
eeb3	61107	-	Delay 1 ms
eebb	61115	-	RS-232 Send
ef06	61190	-	Send New RS-232 Byte
;ef2e	61230	-	'No DSR' / 'No CTS' Error
ef39	61241	-	Disable Timer
ef4a	61258	-	Compute Bit Count
ef59	61273	-	RS-232 Receive
ef7e	61310	-	Set Up To Receive
ef90	61328	-	Process RS-232 Byte
efe1	61409	-	Submit to RS-232
f00d	61453	-	No DSR (Data Set Ready) Error
f017	61463	-	Send to RS-232 Buffer
f04d	61517	-	Input From RS-232
f086	61574	-	Get From RS-232
f0a4	61604	-	Serial Bus Idle
f0bd	61629	-	Table of Kernal I/O Messages		DATA
f12b	61739	-	Print Message if Direct
f12f	61743	-	Print Message
f13e	61758	getin	Get a byte
f157	61783	chrin	Input a byte
f199	61849	-	Get From Tape / Serial / RS-232
f1ca	61898	chrout	Output One Character
f20e	61966	chkin	Set Input Device
f250	62032	chkout	Set Output Device
f291	62097	close	Close File
f30f	62223	-	Find File
f31f	62239	-	Set File values
f32f	62255	clall	Abort All Files
f333	62259	clrchn	Restore Default I/O
f34a	62282	open	Open File
f3d5	62421	-	Send Secondary Address
f409	62473	-	Open RS-232
f49e	62622	load	Load RAM
f4b8	62648	-	Load File From Serial Bus
f533	62771	-	Load File From Tape
f5af	62927	-	Print "SEARCHING"
f5c1	62913	-	Print Filename
f5d2	62930	-	Print "LOADING / VERIFYING"
f5dd	62941	save	Save RAM
f5fa	62970	-	Save to Serial Bus
f659	63065	-	Save to Tape
f68f	63119	-	Print "SAVING"
f69b	63131	udtim	Bump Clock
f6dd	63197	rdtim	Get Time
f6e4	63204	settim	Set Time
f6ed	63213	stop	Check STOP Key
f6fb	63227	-	Output I/O Error Messages
;f6fb	63227	-	'too many files'
;f6fe	63230	-	'file open'
;f701	63233	-	'file not open'
;f704	63236	-	'file not found'
;f707	63239	-	'device not present'
;f70a	63242	-	'not input file'
;f70d	63245	-	'not output file'
;f710	63248	-	'missing filename'
;f713	63251	-	'illegal device number'
f72d	63277	-	Find Any Tape Header
f76a	63338	-	Write Tape Header
f7d0	63440	-	Get Buffer Address
f7d7	63447	-	Set Buffer Stat / End Pointers
f7ea	63466	-	Find Specific Tape Header
f80d	63501	-	Bump Tape Pointer
f817	63511	-	Print "PRESS PLAY ON TAPE"
f82e	63534	-	Check Tape Status
f838	63544	-	Print "PRESS RECORD..."
f841	63553	-	Initiate Tape Read
f864	63588	-	Initiate Tape Write
f875	63605	-	Common Tape Code
f8d0	63696	-	Check Tape Stop
f8e2	63714	-	Set Read Timing
f92c	63788	-	Read Tape Bits
fa60	64096	-	Store Tape Characters
fb8e	64398	-	Reset Tape Pointer
fb97	64407	-	New Character Setup
fba6	64422	-	Send Tone to Tape
fbc8	64456	-	Write Data to Tape
fbcd	64461	-	IRQ Entry Point
fc57	64599	-	Write Tape Leader
fc93	64659	-	Restore Normal IRQ
fcb8	64696	-	Set IRQ Vector
fcca	64714	-	Kill Tape Motor
fcd1	64721	-	Check Read / Write Pointer
fcdb	64731	-	Bump Read / Write Pointer
fce2	64738	-	Power-Up RESET Entry
fd02	64770	-	Check For 8-ROM
;fd12	64786	-	8-ROM Mask '80CBM'			DATA
fd15	64789	restor	Restore Kernal Vectors (at 0314)
fd1a	64794	vector	Change Vectors For User
fd30	64816	-	Kernal Reset Vectors			WORD
fd50	64848	ramtas	Initialise System Constants
fd9b	64923	-	IRQ Vectors For Tape I/O		WORD
fda3	64931	ioinit	Initialise I/O
fddd	64989	-	Enable Timer
fdf9	65017	setnam	Set Filename
fe00	65024	setlfs	Set Logical File Parameters
fe07	65031	readst	Get I/O Status Word
fe18	65048	setmsg	Control OS Messages
fe21	65057	settmo	Set IEEE Timeout
fe25	65061	memtop	Read / Set Top of Memory
fe34	65076	membot	Read / Set Bottom of Memory
fe43	65091	-	NMI Transfer Entry
fe66	65126	-	Warm Start Basic [BRK]
febc	65212	-	Exit Interrupt
fec2	65218	-	RS-232 Timing Table - NTSC	DATA
fed6	65238	-	NMI RS-232 In
ff07	65287	-	NMI RS-232 Out
ff43	65347	-	Fake IRQ Entry
ff48	65352	-	IRQ Entry
ff5b	65371	cint	Initialize screen editor
ff80	65408	-	Kernal Version Number [03]	DATA
;
; C64 Kernal Jump Table
;
ff81	jmp $ff5b	cint		Init Editor & Video Chips
ff84	jmp $fd23	ioinit		Init I/O Devices, Ports & Timers
ff87	jmp $fd50	ramtas		Init Ram & Buffers
ff8a	jmp $fd15	restor		Restore Vectors
ff8d	jmp $fd1a	vector		Change Vectors For User
ff90	jmp $fe18	setmsg		Control OS Messages
ff93	jmp $edb9	secnd		Send SA After Listen
ff96	jmp $edc7	tksa		Send SA After Talk
ff99	jmp $fe25	memtop		Set/Read System RAM Top
ff9c	jmp $fe34	membot		Set/Read System RAM Bottom
ff9f	jmp $ea87	scnkey		Scan Keyboard
ffa2	jmp $fe21	settmo		Set Timeout In IEEE
ffa5	jmp $ee13	acptr		Handshake Serial Byte In
ffa8	jmp $eddd	ciout		Handshake Serial Byte Out
ffab	jmp $edef	untalk		Command Serial Bus UNTALK
ffae	jmp $edfe	unlsn		Command Serial Bus UNLISTEN
ffb1	jmp $ed0c	listn		Command Serial Bus LISTEN
ffb4	jmp $ed09	talk		Command Serial Bus TALK
ffb7	jmp $fe07	readss		Read I/O Status Word
ffba	jmp $fe00	setlfs		Set Logical File Parameters
ffbd	jmp $fdf9	setnam		Set Filename
ffc0	jmp ($031a)	(iopen)		Open Vector [f34a]
ffc3	jmp ($031c)	(iclose)   	Close Vector [f291]
ffc6	jmp ($031e)	(ichkin)   	Set Input [f20e]
ffc9	jmp ($0320)	(ichkout)	Set Output [f250]
ffcc	jmp ($0322)	(iclrch)	Restore I/O Vector [f333]
ffcf	jmp ($0324)	(ichrin)	Input Vector, chrin [f157]
;ffd2	jmp ($0326)	(ichrout)	Output Vector, chrout [f1ca]
ffd5	jmp $f49e	load		Load RAM From Device
ffd8	jmp $f5dd	save		Save RAM To Device
ffdb	jmp $f6e4	settim		Set Real-Time Clock
ffde	jmp $f6dd	rdtim		Read Real-Time Clock
ffe1	jmp ($0328)	(istop)		Test-Stop Vector [f6ed]
ffe4	jmp ($032a)	(igetin)	Get From Keyboad [f13e]
ffe7	jmp ($032c)	(iclall)	Close All Channels And Files [f32f]
ffea	jmp $f69b	udtim		Increment Real-Time Clock
ffed	jmp $e505	screen		Return Screen Organization
fff0	jmp $e50a	plot		Read / Set Cursor X/Y Position
fff3	jmp $e500	iobase		Return I/O Base Address

;fff6	Vectors

fff6	[5252]		-
fff8	[5942]		SYSTEM

;fffa	Transfer Vectors
fffa	[fe43]		NMI
fffc	[fce2]		RESET
fffe	[ff48]		IRQ

.endif
