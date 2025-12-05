Objectives:
	To display/store the contents of the BASIC variable/array storage.
	With a final version that is loaded into memory (as a wedge application),
	that can be activated using key-combinations.
	
Goals:
	To have fun learning about 6502/10 machine language programming on a 8-bit C64 machine.
	To utilise the builtin BASIC and KERNEL ROM routines (avoid re-invented the wheel, where possible).
	
Lessons:
	- ACME Assembler
	- Kernel/BASIC routines
	- Compare 16-bit values
	- Integer/Float mathematic routines.

References (Books):
	- 6502 Assembly Language Programming, 1979, Lance A. Leventhal
	- 6502 Software Design, 1980, Leo J. Scanlon
	- BEST MACHINE CODE ROUTINES FOR THE COMMODORE 64, 1984, Mark Greenshields
	- Commodore 64/128 Assembly Language Programming, Mark Andrews
	- COMMODORE 64 - PROGRAMMER'S REFERENCE GUIDE
	- COMPUTE!s Mapping The Commodore 64, Sheldon Leemon
	- Compute's Machine Language Routines for the Commodore 64/128, 1987, Todd D. Heimarck and Patrick Parrish
	- Strings in Assembly with Kernel Routines, https://www.youtube.com/watch?v=xPCMPGb6Qbg
	
References (Links):
	- https://skoolkid.github.io/sk6502/c64rom/index.html
	- https://www.pagetable.com/c64ref/c64disasm
	- https://www.pagetable.com/c64ref/c64mem
	- https://www.atarimagazines.com/compute/issue29/394_1_COMMODORE_64_MEMORY_MAP.php
TODO:
- load ml in wedge and auto-activate? Then return to BASIC
- output to screen (default), disk or other
- list reference sources
- what was learned during the creation of project 01

-------------------------------------------------------------------------------
pseudo

anything in storage?
- check variable storage
- check array storage

is variable storage?
calculate & display quantity, size, start and end address
list in order of creation;
	var name, type, value

is array storage?
calculate & display quantity, size, start and end address
list in order of creation;
	var name, type, dimensions
		dimension, value
		
