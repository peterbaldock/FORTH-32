comment #=======================================================================

			Douglas Instruments

			STEPPER Resident Motor Driver for DB5.

			STEPINIT.ASM	:	initialization module


21-12-95 		STEPPER (hic)	FLASH/ROM resident stepper motor driver
			Taken from SKIPPER Version 3.18

	 Version 1.00	Basic structure including downloading from FLASH to RAM
			This working for original parallel port DB4 control

02-01-96 Version 1.01	ACTUATE.ASM changed to ACT-DB5.ASM, for direct PIO
			control of DB5 boards. Original ACTUATE can still be used for
			upgrade DB5 controllers to control existing DB3/4s.

11-04-96 Version 1.05	~	backlash -ve bug - anding of 32 bit balcklash[] corrected

12-10-01 Version 2.55
=================================================================================#

	include	..\include\step.inc
	option language:c

_FORTH_DATA	segment


initmess	db	CR,LF
		db	'DB5 '
		db	'STEPPER 386-586   Resident Stepper Motor Driver Version'
version		db	' '
		db	VERS
		db	CR, LF,'Last update: 12-10-01',CR, LF
		db	'Copyright (c) Douglas Instruments 1987-2001. All rights reserved.'

feed		db	CR,LF,LF,'$'

port_msg	db	CR,LF,'Parallel ports available :  $'
using_msg	db	CR,LF,'Network  port  selected  :  $',0

_FORTH_DATA	ends

_TEXT	segment

	.486

stepperInitialize	proc far

	push	ds
	pusha
;	mov	ax, 0			; not loading interrupt 78h 21-01-98
;	mov	ds , ax
;	assume	ds:nothing

;	mov	bx, 4*78h
;	mov	word ptr [bx], offset entryPoint
;	mov	ax, cs
;	mov	[bx+2], ax

;	mov	ax, seg _FORTH_DATA
;	mov	ds , ax			; now point to driver segment
	assume	ds:_FORTH_DATA

;	mov	ax, offset ReadBuffer	- removed 21-01-98
;	mov	RdBuffEntry, ax         - removed 21-01-98
;	mov	RdBuffRemoval, ax       - removed 21-01-98

;	call	find_ports		; establish location of parallel ports

;	call	write_screen

	mov	al, 80h
	mov	dx, 303h
	out	dx, al
	add	dx, 8
	out	dx, al
	add	dx, 8
	out	dx, al


	popa
	pop	ds
	ret

stepperInitialize	endp

;	Initialization message and Version Number

endCode::

 _TEXT	ends


	end
