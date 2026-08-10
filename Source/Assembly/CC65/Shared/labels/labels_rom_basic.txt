.ifndef LABELS_ROM_BASIC_S
LABELS_ROM_BASIC_S = 1

;------------------------------------------------
; C64 BASIC 2.0 ROM
; A000–BFFF 40960–49151 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
BASIC_GOCR      := $aad7    ; Output cr/lf
BASIC_STROUT    := $ab1e    ; Output zero/null terminated string at Y/A
BASIC_GIVAYF	:= $b391    ; Convert int16 (Register A/Y) → FAC1
BASIC_MOVMF     := $bba2    ; Unpack Memory (Y/A) → FAC1. Memory contains a 5-Byte C64 float
BASIC_MOVFM     := $bbd4    ; Pack FAC1 → Memory (Y/X). Memory contains a 5-Byte C64 float
BASIC_LINPRT    := $bdcd    ; Output uint16 (Register A/X) as a number in ASCII/PETSCII
BASIC_FOUT      := $bddd    ; FAC1 → ASCII string at Y/A (ready for STROUT)
.endif

.if 0
a000	40960	-	Restart Vectors				WORD
a00c	40972	stmdsp	BASIC Command Vectors			WORD
a052	41042	fundsp	BASIC Function Vectors			WORD
a080	41088	optab	BASIC Operator Vectors			WORD
a09e	41118	reslst	BASIC Command Keyword Table		DATA
a129	41257	msclst	BASIC Misc. Keyword Table		DATA
a140	41280	oplist	BASIC Operator Keyword Table		DATA
a14d	41293	funlst	BASIC Function Keyword Table		DATA
a19e	41374	errtab	Error Message Table			DATA
a328	41768	errptr	Error Message Pointers			WORD
a364	41828	okk	Misc. Messages				TEXT
a38a	41866	fndfor	Find FOR/GOSUB Entry on Stack
a3b8	41912	bltu	Open Space in Memory
a3fb	41979	getstk	Check Stack Depth
a408	41992	reason	Check Memory Overlap
;a435	42037	omerr	Output ?OUT OF MEMORY Error
a437	42039	error	Error Routine
a469	42089	errfin	Break Entry
a474	42100	ready	Restart BASIC
a480	42112	main	Input & Identify BASIC Line
a49c	42140	main1	Get Line Number & Tokenise Text
a4a2	42146	inslin	Insert BASIC Text
a533	42291	linkprg	Rechain Lines
a560	42336	inlin	Input Line Into Buffer
a579	42361	crunch	Tokenise Input Buffer
a613	42515	fndlin	Search for Line Number
a642	42562	scrtch	Perform [new]
a65e	42590	clear	Perform [clr]
a68e	42638	stxpt	Reset TXTPTR
a69c	42652	list	Perform [list]
a717	42775	qplop	Handle LIST Character
a742	42818	for	Perform [for]
a7ae	42926	newstt	BASIC Warm Start
a7c4	42948	ckeol	Check End of Program
a7e1	42977	gone	Prepare to execute statement
a7ed	42989	gone3	Perform BASIC Keyword
a81d	43037	restor	Perform [restore]
a82c	43052	stop	Perform [stop], [end], break
a857	43095	cont	Perform [cont]
a871	43121	run	Perform [run]
a883	43139	gosub	Perform [gosub]
a8a0	43168	goto	Perform [goto]
a8d2	43218	return	Perform [return]
a8f8	43256	data	Perform [data]
a906	43270	datan	Search for Next Statement / Line
a928	43304	if	Perform [if]
a93b	43323	rem	Perform [rem]
a94b	43339	ongoto	Perform [on]
a96b	43371	linget	Fetch linnum From BASIC
a9a5	43429	let	Perform [let]
a9c4	43460	putint	Assign Integer
a9d6	43478	ptflpt	Assign Floating Point
a9d9	43481	putstr	Assign String
;a9e3	43491	puttim	Assign TI$
aa2c	43564	getspt	Add Digit to FAC#1
aa80	43648	printn	Perform [print]#
aa86	43654	cmd	Perform [cmd]
aa9a	43674	strdon	Print String From Memory
aaa0	43680	print	Perform [print]
aab8	43704	varop	Output Variable
;aad7	43735	crdo	Output CR/LF
aae8	43752	comprt	Handle comma, TAB(, SPC(
;ab1e	43806	strout	Output String
ab3b	43835	outspc	Output Format Character
ab4d	43853	doagin	Handle Bad Data
ab7b	43899	get	Perform [get]
aba5	43941	inputn	Perform [input#]
abbf	43967	input	Perform [input]
abea	44010	bufful	Read Input Buffer
abf9	44025	qinlin	Do Input Prompt
ac06	44038	read	Perform [read]
ac35	44085	rdget	General Purpose Read Routine
acfc	44284	exint	Input Error Messages			TEXT
ad1e	44318	next	Perform [next]
ad61	44385	donext	Check Valid Loop
ad8a	44426	frmnum	Confirm Result
ad9e	44446	frmevl	Evaluate Expression in Text
ae83	44675	eval	Evaluate Single Term
aea8	44712	pival	Constant - pi				DATA
aead	44717	qdot	Continue Expression
aef1	44785	parchk	Expression in Brackets
aef7	44791	chkcls	Confirm Character
aef7	44791	-	-test ')'-
aefa	44794	-	-test '('-
aefd	44797	-	-test comma-
;af08	44808	synerr	Output ?SYNTAX Error
af0d	44813	domin	Set up NOT Function
af14	44820	rsvvar	Identify Reserved Variable
af28	44840	isvar	Search for Variable
af48	44872	tisasc	Convert TI to ASCII String
afa7	44967	isfun	Identify Function Type
afb1	44977	strfun	Evaluate String Function
afd1	45009	numfun	Evaluate Numeric Function
afe6	45030	orop	Perform [or], [and]
b016	45078	dorel	Perform <, =, >
b01b	45083	numrel	Numeric Comparison
b02e	45102	strrel	String Comparison
b07e	45182	dim	Perform [dim]
b08b	45195	ptrget	Identify Variable
b0e7	45287	ordvar	Locate Ordinary Variable
b11d	45341	notfns	Create New Variable
b128	45352	notevl	Create Variable
b194	45460	aryget	Allocate Array Pointer Space
b1a5	45477	n32768	Constant 32768 in Flpt			DATA
b1aa	45482	facinx	FAC#1 to Integer in (AC/YR)
b1b2	45490	intidx	Evaluate Text for Integer
b1bf	45503	ayint	FAC#1 to Positive Integer
b1d1	45521	isary	Get Array Parameters
b218	45592	fndary	Find Array
;b245	45637	bserr	?BAD SUBSCRIPT/?ILLEGAL QUANTITY
b261	45665	notfdd	Create Array
b30e	45838	inlpn2	Locate Element in Array
b34c	45900	umult	Number of Bytes in Subscript
b37d	45949	fre	Perform [fre]
b391	45969	givayf	Convert Integer in (AC/YR) to Flpt
b39e	45982	pos	Perform [pos]
b3a6	45990	errdir	Confirm Program Mode
b3e1	46049	getfnm	Check Syntax of FN
b3f4	46068	fndoer	Perform [fn]
;b465	46181	strd	Perform [str$]
b487	46215	strlit	Set Up String
b4d5	46293	putnw1	Save String Descriptor
b4f4	46324	getspa	Allocate Space for String
b526	46374	garbag	Garbage Collection
b5bd	46525	dvars	Search for Next String
b606	46598	grbpas	Collect a String
b63d	46653	cat	Concatenate Two Strings
b67a	46714	movins	Store String in High RAM
b6a3	46755	frestr	Perform String Housekeeping
b6db	46811	frefac	Clean Descriptor Stack
;b6ec	46828	chrd	Perform [chr$]
;b700	46848	leftd	Perform [left$]
;b72c	46892	rightd	Perform [right$]
;b737	46903	midd	Perform [mid$]
b761	46945	pream	Pull sTring Parameters
b77c	46972	len	Perform [len]
b782	46978	len1	Exit String Mode
b78b	46987	asc	Perform [asc]
b79b	47003	gtbytc	Evaluate Text to 1 Byte in XR
b7ad	47021	val	Perform [val]
b7b5	47029	strval	Convert ASCII String to Flpt
b7eb	47083	getnum	Get parameters for POKE/WAIT
b7f7	47095	getadr	Convert FAC#1 to Integer in LINNUM
b80d	47117	peek	Perform [peek]
b824	47140	poke	Perform [poke]
b82d	47149	wait	Perform [wait]
b849	47177	faddh	Add 0.5 to FAC#1
b850	47184	fsub	Perform Subtraction
b862	47202	fadd5	Normalise Addition
b867	47207	fadd	Perform Addition
;b947	47431	negfac	2's Complement FAC#1
;b97e	47486	overr	Output ?OVERFLOW Error
b983	47491	mulshf	Multiply by Zero Byte
b9bc	47548	fone	Table of Flpt Constants			DATA
b9ea	47594	log	Perform [log]
ba28	47656	fmult	Perform Multiply
ba59	47705	mulply	Multiply by a Byte
ba8c	47756	conupk	Load FAC#2 From Memory
bab7	47799	muldiv	Test Both Accumulators
bad4	47828	mldvex	Overflow / Underflow
bae2	47842	mul10	Multiply FAC#1 by 10
baf9	47865	tenc	Constant 10 in Flpt			DATA
bafe	47870	div10	Divide FAC#1 by 10
bb07	47879	fdiv	Divide FAC#2 by Flpt at (AC/YR)
bb0f	47887	fdivt	Divide FAC#2 by FAC#1
;bba2	48034	movfm	Load FAC#1 From Memory
bbc7	48071	mov2f	Store FAC#1 in Memory
bbfc	48124	movfa	Copy FAC#2 into FAC#1
bc0c	48140	movaf	Copy FAC#1 into FAC#2
bc1b	48155	round	Round FAC#1
bc2b	48171	sign	Check Sign of FAC#1
bc39	48185	sgn	Perform [sgn]
bc58	48216	abs	Perform [abs]
bc5b	48219	fcomp	Compare FAC#1 With Memory
bc9b	48283	qint	Convert FAC#1 to Integer
bccc	48332	int	Perform [int]
bcf3	48371	fin	Convert ASCII String to a Number in FAC#1
bdb3	48563	n0999	String Conversion Constants		DATA
;bdc2	48578	inprt	Output 'IN' and Line Number
bddd	48605	fout	Convert FAC#1 to ASCII String
be68	48744	foutim	Convert TI to String
bf11	48913	fhalf	Table of Constants			DATA
bf71	49009	sqr	Perform [sqr]
;bf7b	49019	fpwrt	Perform power ($)
bfb4	49076	negop	Negate FAC#1
bfbf	49087	logeb2	Table of Constants			DATA
bfed	49133	exp	Perform [exp]
.endif
