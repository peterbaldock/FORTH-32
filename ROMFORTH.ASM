comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	ROMFORTH.ASM	:	Main module

21-02-96 Version 1.00	:	
04-04-96 Version 1.01	+	front panel button control to disable automatic
				loading of 'forth.fth'

21-10-98 Version 1.02	+	; terminate immediately if button pressed
03-12-98 Version 2.11	:	ftol fixed for f<1.5; 0< gives TRUE=-1
2003-12-07 Version 2.90 +	Segment load checking with LoadSegment
2004-02-17 Version 2.92 +	call TLoopCalibrate for new PCI_BusDelay timing
2004-07-29 Version 3.00	+	virtual, override, indirect_execute, [pfa] for finding
2005-11-29 Version 3.24 ~	CheckBoards allows missing board 1 for Oryx4
				pfa of virtual constants etc.

2013-07-29 Version 5.40	<USBGet>, <USBPut> uses call	PCI_in in place of in to avoid parity errors.

================================================================================#

option language:c

include	..\include\forth-ab.inc
include	..\include\bios.inc
include	..\include\files.inc
include	..\include\macros.inc
include	..\include\loader.inc
include	..\include\hooks.inc
include	..\include\serial.inc
include	..\include\types.inc
include	..\include\forth.inc
include	..\include\pcatkeys.inc
include	..\include\step.inc
include	forthmac.asm
include	FTH-ERRS.inc


;	for ROM target, activate the following structure creation macro :
;	main "FORTH", "FORTH-D", 0FFFFh

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:nothing

	thisLink	textequ	<1>
	lastLink	textequ	<0>

public	prnbase
public	HostControl


FORTHinit	proc	far C

	push	ds	;	ds pointing to RAM already allocated by loader
	push	es
	push	si

	assume	ds:_FORTH_DATA ;	use data segment in ds suppliad by LOADER

	mov	FORTHds, ds	; save supplied data segment

	call    FLAT_install            ; Enable 4Gb address space
	mov	FlatAccess, ax			; 0 for no flat access. - cannot continue if no flat access
	
	call	SetHeap

	call	setdataseg

	mov	DOSpresent, 0	; indicate DOSless mode

	mov	si, offset cs:startingmsg
	.while	byte ptr cs:[si]
	  mov	al, cs:[si]
	  xor	bh, bh
	  mov	bl, 7
	  mov	ah, 0eh
	  int	10h
	  inc	si
	.endw

	push	ds		; set up int 79h vector
	push	seg _INTERRUPT
	pop	ds
	assume	ds:_INTERRUPT
	mov	eax, ds:[4*14h]
	mov	oldInt14, eax
	mov	ax, offset interrupt_14
	mov	ds:[4*14h], ax
	mov	ds:[4*14h+2], cs
	mov	intvec_79_seg, cs
	mov	intvec_79_off, offset cs:callRun
	pop	ds

	pop	si
	pop	es
	pop	ds
	ret

startingmsg	db	"Douglas Instruments FORTH kernel Version 4.xx"
		db	10,13,0

FORTHinit	endp

callRun	proc	far	; entry point for interrupt call of FORTH run code

	call	run
	call	FLAT_destall
	iret

callRun	endp

run	proc	far C

	finit			; reset the FPU
	
	push	ds
	push	es

	mov	ds, FORTHds	; FORTHds is in _TEXT
	push	ds
	pop	es
	assume	ds:_FORTH_DATA 	; use data segment originally suppliad by LOADER


	call	cls
	mov	si, dstack
	mov	BIOSss, ss
	mov	BIOSsp, sp ;	save supplied SP for later reloading
	mov	ax, ds
	mov	ss, ax
	mov	sp, offset _FORTH_DATA:StackTop

	mov	stepping_status, 0

	push	ds
	push	0
	pop	ds
;	invoke	LoadSegment, 'ds', 0, 0, 0 ; point to interrupt table
	mov	eax, ds:[8*4]		   ; timer tick interrupt
	mov	StandardTickInterrupt, eax ; save Tick Interrupt Address
	push	cs
	push	offset step_int
	pop	dword ptr ds:[8*4]		; instate the tick interrupt

	pop	ds
	mov	bx, 513	; 8k memory request + 16 bytes for length and CRC	
	mov	ah, 48h
	int	21h
	.if	carry?
	  xor	ax, ax
	.endif
	shl	eax, 16
	mov	InputDataBuffer, eax
	mov	inDATA.pdataPtr, eax	; static data buffer for input data

	mov	bx, 513	; 8k memory request + 16 bytes for length and CRC	
	mov	ah, 48h
	int	21h
	.if	carry?
	  xor	ax, ax
	.endif
	shl	eax, 16
	mov	FileWriteBuffer, eax	; static file write buffer

	call	TLoopCalibrate	; 2004-02-17

	;============= test for DC7 board at 310h/318h ================= 
	
	call	CheckDC7
	; mov	ax, -1
	.if	!ax
	
		mov	CardType, 70
		
		xor	bx, bx
		.while	bx<4		;	Look for up to 4 x DB7s

			invoke	GetDB7Status, bl
			.if	(al & 2)
				mov	Board[bx], 0
			.else
				mov	Board[bx], 70		; Populate Board with DB7 presence
			.endif
			
			inc	bx
		
		.endw
		call	GetDC7Status		
		shr	al, 2	;	Put STOP bit in b0 
		jmp	BoardsDone
	
	.else

		mov	bx, 0
		mov	dx, 300h
		.while	bx<64
		  in	al, dx
		  mov	Board[bx+4], al
		  inc	dx
		  inc	bx
		.endw

		;============= test for DB5 board at 300h - 317h =================

		mov	bx, 2		; Board[2] (human 3)
		call	CheckDB5
		dec	bx
		call	CheckDB5
		.if	!ah		; no error
		  dec	bx
		  call	CheckDB5
		  .if	!ah		; Board[0] was DB5
			jmp	DB5System
		  .endif
		.endif

		.if	ah!=0FFh
		  jmp	BoardError
		.endif

		;============= test for DB6 board at 320h - 337h =================

		mov	bx, 2		; Board[2] (human 3)
		call	CheckDB6
		dec	bx
		call	CheckDB6
		dec	bx
		call	CheckDB6
		.if	!ah		; Board[0] was DB6
		  mov	dx, 0321h
		  in	al, dx
		  jmp	BoardsDone
		.endif

		jmp	BoardError
		
	.endif

	;=============	setup DB5 boards at 300h - 317h ==============

DB5System:

	mov	dx, 317h	; Board 3
	xor	al, al
	out	dx, al		; set PDIR bit (b7) = 0, so LS pins are inputs etc.
	sub	dx, 8    	; Board 2
	out	dx, al		; set PDIR bit (b7) = 0, so LS pins are inputs etc.
	sub	dx, 8		; Board 1
	out	dx, al		; set PDIR bit (b7) = 0, so LS pins are inputs etc.
	in	al, dx


BoardsDone:
	.if	!( al & 1 )	; RED BUTTON is bit 0 on Board 1 ($321 or $307)

	  mov	ax, offset cs:BachAir
	  invoke PlayTune, cs::ax, 80

	  jmp	___bye       	; terminate immediately if button pressed

BachAir	dw 0B010h, 0C010h, 0Bb10h, 0Ab10h, 0A910h, 0B910h, 0B710h, 0A710h
	dw 2510h, 4908h, 4508h, 4402h, 4206h, 4008h, 3b08h, 4008h, 3b18h, 3908h, 3720h, 0

	.endif


BoardError:
	push	ds
	push	0
	pop	ds
;	invoke	LoadSegment, 'ds', 0, 0, 0 ; point to interrupt table

	mov	ds:[5*4], offset cs:interrupt_05	; bounds interrupt
	mov	ds:[5*4+2], cs

	;mov	eax, ds:[8*4]		   ; timer tick interrupt
	;mov	StandardTickInterrupt, eax ; save Tick Interrupt Address
;	call    FLAT_install            ; Enable 4Gb address space
;	mov	FlatAccess, ax			; 0 for no flat access.
	xor	ax, ax
	mov	gs, ax	; sot gs back to absolute

	push	cs
	pop	ds
	assume	ds: _TEXT

	mov	di, offset hbMsg_handleComms
	mov	ds:[di+8], cs
	mov	ds:[di+6], offset handleComms_messageHandler
	mov	cx, 0f000h
	mov	ax, 0010h	; MESSAGE
	mov	dx, 0
	int	80h
	pop	ds
	assume	ds:_FORTH_DATA


	jmp	quitentry	; remember ds is still on the stack
	
	


;	==============================================================================================


CheckDB5:
	mov	dx, 307h
	shl	bx, 3
	add	dx, bx
	shr	bx, 3
	xor	ax, ax
	out	dx, al
	sub	dx, 7
	.while	bh<6
	  in	al, dx	; if result is FF then no board here
	  .if bh==5	; reading STOP button
	    .if	bl	; Board[1..2]
	      xor al, 1 ;  invert STOP bit - should normally be 1
	    .else
	      and al, not 1 ; mask off STOP bit on Board[0]
	    .endif
	  .endif
	  or	ah, al
	  inc	dx
	  .if	bh==2
	    add	dx, 2
	  .endif
	  inc	bh
	.endw
	xor	bh, bh
	.if	!ah          	; successfully detected DB5
	  mov 	Board[bx], 50
	  mov	LEDOffset, 1
	  and	dx, 0FFF8h
	  sub	dx, 4
	  in	al, dx		; check limit switches
	  .if	!(al&1)		; 5V system link set on LS7
	    mov	SystemVoltage, 5
	  .endif
	.elseif ah==0FFh
	  mov	Board[bx], ah   ; Fail : no board present
	.else
	  mov	Board[bx], 0F5h ; Fail DB5 test
	.endif
	retn

CheckDB6:
	mov	dx, 321h
	shl	bx, 3
	add	dx, bx
	shr	bx, 1
	in	al, dx		; if result is FF then no board here
	mov	ah, al		; else <x x x x Board1 Board0 Ready STOP>
	.if	al!=0FFh	; may be a board here
	  .if	!bx
	    or	al, 1		; (no STOP button on Board0)
	  .endif
	  and	ax, 0Fh		; should read 0000bb11
	  xor	al, bl
	  ;					2010-07-29	see comment block below for old code
	  sub	al, 3
	  .if zero?		; bits 2-3 match board number
	    dec	dx
	    xor	ax, ax
	    out	dx, ax	; set motor currents to 0
	    
	    inc	dx
	    in	al, dx	; read status again to check READY bit - DB6 board should not be ready
	    and	al, DB6_Ready
	  .endif
	  
	.endif ; al!=0FFh

	mov	bh, 0
	shr	bx, 2 ; return to byte addressing

	.if	!ax
	  mov 	Board[bx], 60	; successfully detected DB6
	  mov	LEDOffset, 5
	  and	dx, 0FFF8h

	  xor	ax, ax
	  .repeat
	    inc	dx
	    push ax
	    .repeat
	     in	al, dx
	    .until (al & DB6_Ready)	; wait for ready bit to be true
	    pop	ax
	    dec	dx
	    out	dx, ax			; switch off all 4 motors
	    inc	ax
	  .until ax==4

	  add	dx, 5
	  in	al, dx		; check limit switches
	  .if	!(al&80h)	; 5V system link set on LS7
	    mov	SystemVoltage, 5
	  .endif
	.else
	  mov	Board[bx], 0ffh
	.endif

	retn


	
comment #
	  .if	al==3
		dec	dx
;		.while	bh!=3
		  in	al, dx
		  or	ah, al
		  add	dx, 4
		  in	al, dx
		  or	ah, al
;		  sub	dx, 3
;		  inc	bh
;		  .if	bh==1
;		   inc	dx
;		  .endif
;		.endw
	  .else
	    mov	ah, 0F6h
	  .endif
	.endif
#
db	'hbMsg_handleComms', 17
dd	0
hbMsg_handleComms	HookBlockShort { 0, 0, handleComms_messageHandler }

Code_word	<forth>, NORMAL+IMMEDIATE+VOCABULARY
	jmp	_vocabulary

;Code_word	<xxxxyy>, NORMAL
;	ret



Code_word	<bye>, NORMAL

	.if	CardType

		mov	ax, offset	_FORTH_DATA:ShutdownCommand
		call	PushShortAX
		call	___latefind     ; returns extended address or zero on stack
		mov	ebx, dword ptr [si]
		.if	ebx
			call ___execute
		.endif

		mov	al, 0ffh
		out	40h, al
		out	40h, al

	.endif

IFDEF	OS
	  call	___flush
	  mov	ah, 4ch		; standard DOS .exe exit
	  int	21h
ELSE
	xor	eax, eax
	mov	ebx, eax
	mov	ecx, eax
	mov	edx, eax
	mov	edi, eax
	mov	esi, eax
	mov	ss, BIOSss	; ROM Version exit from 18h interrupt
	mov	sp, BIOSsp	; restore original stack

	pop	es		; and segments
	pop	ds
	ret			; far return
ENDIF


run	endp

SetHeap	proc near

;	set global addresses
	
	mov	eax, 10000000h	;	256MB - just a simple constant at the moment, but could be changed according to size of RAM
	mov	MemTop, eax
	sub	eax, 2 * MAX_HEAP_HANDLES
	mov	HandleStack, eax
	mov	HandleSP, eax		;		initialize stack pointer
	sub	eax, 4 * MAX_HEAP_HANDLES
	mov	HandleTable, eax
	mov	HeapLimit, eax
	mov	eax, 2000000h
	mov	HeapBase, eax
	mov	HeapTop, eax

;	initialize handle stack

	xor	eax, eax
	mov	ecx, MAX_HEAP_HANDLES
	mov	ebx, HandleStack
	.while	ecx
		mov	[ebx], ax
		inc	ax
		dec	ecx
		inc	ebx
		inc	ebx
	.endw
	
;	set handles to zero for diagnostics

	xor	eax, eax
	mov	ecx, MAX_HEAP_HANDLES
	mov	ebx, HandleTable
	.while	ecx
		mov	[ebx], eax
		dec	ecx
		add	ebx, 4
	.endw
	
	mov	ebx, HeapBase
	mov	eax, HeapLimit
	sub	eax, ebx
	mov	[ebx], eax
	xor	eax, eax
	mov	[ebx+4], eax
	mov	[ebx+8], eax
	
;	now set up various static areas in the heap

;	1.	Local variable space

	mov	ecx, 210*4	;	allow 200 local values, with underflow
	call	xalloc
	mov	eax, [eax]
	add	eax, 16+200*4
	mov	LocalSP, eax
	mov	LocalTop, eax
	
;	2.	Static variables	

	mov	ecx, 4000*4	;	allow 4000 static values - dynamic arrays are dealt with separately
	push	ecx
	call	xalloc
	mov	eax, [eax]
	add	eax, 16
	mov	StaticBase, eax
	mov	StaticTop, eax	;	rises as variables are allocated
	pop	ecx
	add	eax, ecx
	mov	StaticLimit, eax
	
	ret

SetHeap	endp

setdataseg	proc	near

;	setup data segment

		mov	ax, es:[2ch]	; get environment pointer
	mov	env_p, ax	; and save to variable


	mov	ax, ds
	mov	es, ax		; set es to point to datasegment

	mov	ax, 2020h		; empty pad
	mov	di, offset DOSpad_start
	mov	cx, 80h
	cld
	rep	stosw

comment #	Now copy dictionary down to RAM in Dataseg

Two types of copy :
	
	1. Code_word copy - where the codepointer points to machine code
	   immediately following it. This does not require the code to 
	   be copied, and the codepointer value is preserved, pointing
	   to the original code in the CS segment. This applies to the
	   bulk of words.

	2. forthword/other copy - where the codepointer invokes remote code
	   (as in colon definitions), and the parameter field is treated as 
	   data. In this case the complete word must be copied. However, all
	   execution address pointers must be modified to fit the new map.

There are currently only 16 forthword definitions. It is therefore possible to
eliminate case 2 with the exception of the FORTH vocabulary word which can be 
set up specially.

#

;	mov	di, offset _FORTH_DATA:dictionaryStart
;	and	edi, 0FFFFh

	mov	edi, EXTENDED_BASE		; dictionary start
	mov	CopyStart, edi
	
	mov	cx, 0	; counter
	mov	si, offset codeDictionaryEnd
	mov	bx, offset @ByeOnError-2	; linkListStart
;	mov	ax, cs
;	mov	ds, ax		; point to dictionary in codeseg

	.repeat
	  push	bx
	  inc	cx
	  mov	bx, cs:[bx]	; and pick up next link
	.until	bx==0		; until bx == 0

;	now all links and end points are stacked.
;	si points to start of first word (nul), and bx = 0
	movzx	edx, bx	; offset _FORTH_DATA:forthlink	; so that nul will link to forth

@@:	pop	bx		;	retrieve link address in CS
	push	cx			;	push word count
	lea	si, [bx-2]		; point to length byte
	movzx	cx, byte ptr cs:[si]	; get length
	sub	si, cx		; count back to beginning of name
	sub	bx, si
	
	push	cx
	.repeat
		mov	al, cs:[si]
		mov [edi], al
		inc	si
		inc	edi
	.untilcxz
	pop	cx
	
	mov	[edi], cx	;	write 16-bit length
	add	edi, 2
	
	inc	si				;	point to attribute byte
	movzx	ax, byte ptr cs:[si]
	mov	[edi], ax	;	write 16-bit attribute
	add	edi, 2
	
	mov	[edi], edx	; adjust link
	mov edx, edi	; save next link
	add	edi, 4
	
	add	si, 3			; point to code field in CS
	movzx	ebx, word ptr cs:[si]
	mov	[edi], ebx
	.if	al & VOCABULARY
		add	edi, 8
	.else
		add	edi, 4
	.endif
	
	pop	cx		; restore word counter
	loop	@b

;	mov	ax, es
;	mov	ds, ax		; restore data segment addressing

;	edi now points to dictionary end in dataseg
;	so [edi-8] is firstlink

	mov	h, edi	; end of Dataseg dictionary

	mov	ebx, edi
	sub	ebx, 8
	mov	last_link, ebx	; now last_link refers to dataseg Dictionary
	
	mov	edi, CopyStart
	add	edi, 30	;	offset forthPFA = 'forth'+2(len)+2(a)+4(link)+4(code field)

;	mov	edi, EXTENDED_BASE+30
	
	mov	[edi], ebx
	mov	Current, edi
	mov	Context, edi
	
	ret

CopyStart dd	0

setdataseg	endp

intro		db	10,10,10,'             x86  32-Bit FORTH Compiler :'
		db	'  Version 8.00'
		db	10,13,10,'        Copyright (c) 1986-2015 Peter Baldock - '
		db	'all rights reserved.',13,10,10,0

ok_mess		db	' OK',13,10,0
err_mess	db	'Error number ',0
blockFileName	db	'BLOCK#00.FTH', 0

inner_interpreter	proc	near

new_word_indirect::	public	new_word_indirect

	mov	ebx, [ebx+4]
;	jmp	word ptr [ebx]	;	this is slower than call/ret
	call	word ptr [ebx]
	ret
;.listmacroall	

pfa_stack_does_indirect::
	public	pfa_stack_does_indirect	; in '<builds ... does>' words, the first cell
	lea	eax, [ebx+8]	; of the parameter field is the (does) execution
	mov	eax, [eax]		;	indirect parameter field
	jmp	StackAndGo

pfa_stack_does::
	public	pfa_stack_does	; in '<builds ... does>' words, the first cell
	lea	eax,[ebx+8]	; of the parameter field is the (does) execution

StackAndGo:

	add	si, 4		; address, so the practical pfa is code pointer
	mov	[si], eax	;  + 4.  Stack this address

	push	edi		; Save current interpreter pointer
	mov	edi, [ebx+4]	; and pick up new execution address
;	push	bp
;	mov	bp, sp
	PushLocal	ebp
	mov	ebp, LocalSP
	jmp	next_now	; Start new [:] interpretation



new_class_word::
	push	es
	mov	es, [si]
	sub	si, 4

new_word_pushBP::
	push	edi
	mov		edi, ebx
;	push	bp
;	mov	bp, sp
	PushLocal	ebp
	mov	ebp, LocalSP

next::
	add	edi, 4
next_now::
;comment #
	mov	ax, sp
	.if	(ax>(offset _FORTH_DATA:StackTop)) || (ax< (offset _FORTH_DATA:ReturnStack))
		regprint <offset cs:BadSP>
		mov	sp, offset StackTop
		mov	ax, ERR_RETURN_STACK
		call	FORTHabort
BadSP	  db	' : Return stack pointer out of bounds in colon definition', 13, 10, 0
	.endif
;#
	mov	ebx, [edi]
	call	word ptr [ebx]
	jmp	short	next

ii_exit::
;	mov	sp, bp
;	pop	bp
	mov	LocalSP, ebp
	PopLocal	ebp
	add	sp, 2
	pop	edi
	ret

class_exit::
;	mov	sp, bp
;	pop	bp
	mov	LocalSP, ebp
	PopLocal	ebp
	pop	edi
	pop	es
	ret
	

;====================================================================

debug_new_word::
	push	edi
	mov	edi, ebx
debug_next::
	add	edi, 4
	sub	si, 4
	mov	[si], edi
	mov	ebx, debugvector
	call	word ptr ds:[ebx]
	mov	ebx, [edi]
	call	word ptr [ebx]
	jmp	short debug_next

Code_word	<exit>, IMMEDIATE, ii_exit

	mov	ebx, h
	.if	status & DEFINING_CLASS
	  mov	word ptr [ebx], offset @ds_classExit
	.else
	  mov	word ptr [ebx], offset @ds_exit
	.endif
	mov	word ptr [ebx+2], 0
	add	h, 4
	ret

comment #
longpfa_return::
	add	bx, 2
	movzx	eax, bx
	add	si, 4
	mov	[si], eax
	ret
#

pfa_return::
;	regprint	<offset cs:msgpfa_return>
	add	ebx, 4
	add	si, 4
	mov	[si], ebx
	ret

;msgpfa_return	db	"Entered xpfa_return", 0

processHook::
	push	esi
	push	edx
	push	ds
;	mov	ax, ds

	mov	ds, FORTHds	; FORTHds is in _TEXT
	add	bx, 12h
	mov	si, 0ff00h ;	FORTHsi
	add	si, 4
	.if	ax==1001h
		mov	[si], edx	; far pointer to message
	.else
		mov	[si], edx	; far pointer to message
	.endif
	;mov	ax, es:[bx]	; call destination
	call	word ptr es:[ebx]
	pop	ds
	pop	edx
	pop	esi
	retf


% ROMForthLink	=	_link&lastLink

public	ROMForthLink

inner_interpreter	endp

_TEXT	ends

	.list

IFDEF	OS
	endline	equ	<end	DOSinit>
ELSE
	endline equ	<end>
ENDIF

endline
