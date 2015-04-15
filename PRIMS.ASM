comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	PRIMS.ASM	:	Assorted Forth primitives

21-02-96 Version 1.00	:
04-04-96 Version 1.01	~	<quit> rearranged for clearer structure :
				now calls 'drawCommandBox' as separate subroutine
18-11-98 Version 2.01	+ 	variable versioning in VERSION.FTH

2003-01-14 Version 2.80	:	+ wsword (whitespace word)
				+ LineNo - line number tracking
				+ Line number/file name reporting for abort
				+ no suppression of TAB, LF, CR in fload
				+ nested comments ( ( ... ) ) and (* (* ... *) *)
				+ stack level test for fload
2003-12-07 Version 2.90 	+ Segment load checking with LoadSegment
================================================================================#
;.nolist

option language:c

include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include	..\include\macros.inc
include	..\include\step.inc
include	..\include\fp.inc
include	FTH-ERRS.inc



_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA

FunctionNumber = 0BCh

extern		lastSysLink:abs
extern		lastStkLink:abs
extern		lastMemLink:abs
extern		lastAluLink:abs
extern		lastStrLink:abs
extern		lastDicLink:abs
extern		lastBlkLink:abs
extern		lastDispLink:abs
extern		lastInpLink:abs
extern		lastFlowLink:abs
extern		lastCompLink:abs
extern		lastStepLink:abs

% _link400	equ	lastAluLink
% _link500	equ	lastStrLink
% _link600	equ	lastDicLink
% _link700	equ	lastBlkLink
% _link800	equ	lastDispLink
% _link900	equ	lastInpLink
% _link1000	equ	lastFlowLink
% _link1100	equ	lastCompLink
% _link1200	equ	lastStepLink

	thisLink textequ <1201>
	lastLink textequ <1200>

;==================================================================================

GetFileSize	proc C uses bx cx dx, handle:word

;==================================================================================

	mov	bx, handle
	xor	cx, cx
	mov	dx, cx
	mov	ax, 4201h
	int	21h		; get current position
	push	dx
	push	ax

	xor	cx, cx
	mov	dx, cx
	mov	ax, 4202h
	int	21h		; return pointer at eof

	push	dx
	push	ax
	pop	eax		; result in eax


	pop	dx		; restore original position
	pop	cx
	push	eax
	mov	ax, 4200h
	int	21h

	pop	eax
	ret

;include	padding.asm ; 37 bytes 59D1:crashes

GetFileSize	endp

StackCheck	proc	near C

	push	bx

	mov	bx, offset ReturnStack
	.repeat
	  inc	bx
	  inc	bx
	.until	word ptr [bx]!=StackFillWord

	mov	ax, bx
	call	hexprint
	mov	al, '>'
	charout

	pop	bx
	ret

StackCheck	endp


FileReadEx	proc	C uses ds, handle:word, destination:word, bytes:dword, gettime : word	;	returns seg in ax, count in ecx, and time in edx, of requested
local 	StartSeg : word, Remaining : dword, Position		: dword
	
	mov	bx, handle
	
	mov	ax, destination	;	destination is the segment:0 to read into
	mov	StartSeg, ax
	
	mov	ecx, bytes
	mov	Remaining, ecx
	
	xor	edx, edx
	mov	Position, edx
	
	.while ecx

		;	calculate canonical form ds:dx = start of memory to load file into. ecx=file length. bx=file handle
		mov	edx, Position
		mov	eax, edx
		shr	eax, 16	
		add	ax, StartSeg
		mov	ds, ax	; data seg set to highest possible to receive next read
		and	dx, 0fh

		.if ecx>0ffffh
			mov	cx, 0fff0h
		.endif
		
		mov	ah,3fh			; read file
		int	21h
		.if	carry?
			ret		;	return with carry set
		.endif

		.if	!ax		;	read no bytes, ie past EOF
			mov	ax, 90
			stc
			ret
		.endif

		and	eax, 0ffffh
		mov	ecx, Remaining
		sub	ecx, eax
		mov	Remaining, ecx

		mov	edx, Position
		add	edx, eax
		mov	Position, edx
			
	.endw
	
	.if	gettime
		mov	ax, 5700h
		int	21h
		.if	carry?
			xor	edx, edx
		.else
			push	dx
			push	cx
			pop	edx
		.endif
	.endif

	mov	ax, StartSeg		;	return segment in ax
	mov	ecx, Position			;	return count in ecx
		
	clc							;	no error
	ret
			
FileReadEx endp

primitives	proc	near


;==================================================================================

Code_word	<RStackCheck>, NORMAL

;==================================================================================

	invoke	StackCheck
	jmp	PushShortAX


;==================================================================================

Code_word	<trap>, NORMAL+IMMEDIATE

;==================================================================================

	ret



;==================================================================================

Code_word	<debug>, NORMAL

;==================================================================================
;	????????????

	call	___find	;	leaves extended address on stack
	dec	si
	dec	si
	mov	bx, [si]
	dec	si
	dec	si
	.if	bx
	  dec	bx
	  dec	bx
	  mov	[bx], offset debug_new_word
	.endif
	ret

;==================================================================================

Code_word	<execute>, NORMAL

;==================================================================================

;	.if	word ptr [si+2]	;	if extended address

		mov	ebx, dword ptr [si]
		sub	si, 4
		sub	ebx, 4
		mov	ax, word ptr [ebx]
		jmp	ax

;	.else

;		mov	bx, [si]	;	get low word of extended address
;		sub	si, 4

;		dec	bx
;		dec	bx
;		jmp	word ptr [bx]

;	.endif
	
;==================================================================================

Code_word	<base>, NORMAL

;==================================================================================

	mov	ax, offset	base
	jmp	PushShortAX

;==================================================================================

Code_word	<setSeparator>, NORMAL	;	( char - )

;==================================================================================

	mov	al, [si]
	mov 	decimalSeparator, al
	invoke	SetDecimalCharacter, al
	ret

;==================================================================================

Code_word	<(debug)>, NORMAL, _debug

;==================================================================================

	mov	ax, offset	debugvector
	jmp	PushShortAX

;==================================================================================

Code_word	<(idle)>, NORMAL, _idle

;==================================================================================

	mov	ax, offset	idlevector
	jmp	PushShortAX

;==================================================================================

Code_word	<idle>, NORMAL

;==================================================================================

	mov	ebx, idlevector
	.if	ebx
	  inc	idlecount
	  sub	bx, 4
	  jmp	word ptr [ebx]
	.endif
	ret

;==================================================================================

Code_word	<idlecount>, NORMAL

;==================================================================================

	mov	eax, idlecount
	jmp	PushEAX

;==================================================================================

codeword	<WriteScreen>, NORMAL

;==================================================================================

;	mov     ax, 3                    ; Colour text mode
;	int     10h

	push	edi

	mov     edi, 000b8000h           ; EDI <- top left screen address
	xor	ax, ax
	mov	es, ax		   ; Base ES <- 000[0000]0h
	mov     ah, 1fh                  ; Colour = White on blue

	add	di, [si]
	sub	si, 4
	mov	bx, [si+2]	; address of Forth string
	movzx	cx, byte ptr [bx]
	inc	bx
	push	si

	mov	si, bx
l1:
	lodsb                         ; Get a char
	stos  word ptr es:[edi]       ; Store char + attrib
	loop    l1

	pop	si
	pop	edi
	ret


;==================================================================================

Code_word	<quit>, NORMAL

;==================================================================================

	mov	sp, offset _FORTH_DATA:StackTop;BIOSsp			; restore stack
	mov	eax, LocalTop
	mov	LocalSP, eax		;	reset pseudo SP
	call	___where			; save current cursor position
	call	drawCommandBox			; also switches of remote I/O

	or	HostControl, COMMS_IN_ENABLE		; allow remote data input
	invoke	gets, addr _FORTH_DATA:in_buffer, 0, 255 ; get the next command line
;	xor	eax, eax
;	mov	ax, offset in_buffer
;	invoke	gets, eax, 0, 255 ; get the next command line

	and	HostControl, NOT COMMS_OUT_ENABLE; stop echo
	call	___at				; restore cursor position and
	
	xor	eax, eax
	mov	ax, offset in_buffer
	invoke	PrintString, eax, FORTHds

	call	___cr
	or	HostControl, COMMS_OUT_ENABLE	; allow results to be sent to remote

quitentry::				public	quitentry

;	finit			; reset the FPU

	mov	blk_addr, 0			; point interpreter to input
	mov	instream, 0			; and reset input pointer
	call	check_blk
	mov	LineNo, 0
	mov	CurrentFileName, offset File0
	mov	instr_seg, ds
	call	___interpret

OK::					public	OK

	invoke	pSetStream, 'A'
	xor	eax, eax
	mov	ax, offset cs:ok_mess
	invoke	PrintString, eax, cs

	jmp	___quit

		       ;0	  1         2         3         4         5         6         7
		       ;01234567890123456789012345678901234567890123456789012345678901234567890123456789

commandBox	db     '旼컴�0000000컴컴컴컴 FLASH-Forth - Version 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�'
		db     '쿚K>                                                                           �'
		db     '읕컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴 by Douglas Instruments 켸', 0


drawCommandBox:

	.if	HostControl & CON_OUT_ENABLE
		and	HostControl, NOT (COMMS_OUT_ENABLE OR COMMS_IN_ENABLE)
		mov	dx, 0
		mov	bh, videopage
		mov	ah, 2
		int	10h

		push	word ptr colour
		mov	colour, 7
		xor	eax, eax
		mov	ax, offset cs:commandBox
		invoke	PrintString, eax, cs

		mov	dx, 43
		mov	bh, videopage
		mov	ah, 2
		int	10h
		mov	ebx, FORTHversion
		inc	ebx
		invoke	PrintString, ebx, ds

		pop	word ptr colour
		mov	dx, 0104h
		mov	bh, videopage
		mov	ah, 2
		int	10h
	.endif
	retn
;include	padding.asm ; 5C77:crashes

Code_word	<interpret>, NORMAL

	mov	err_no, 0
	mov	stepError, 0
	invoke	pSetStream, 'D'
	; call	check_blk
	call	___find	;	leaves extended address on stack

	mov	ebx, dword ptr [si]
	or	ebx, ebx

	je	try_number
;	FnShow	'e'
	call	___execute
;	FnShow	'E'
	.if	err_no
	  mov	ax, err_no
	  call	FORTHabort
	  db	' - Forth language error', 13, 10, 0
	.elseif stepError
	  mov	ax, stepError
	  call	FORTHabort
	  db	' - Stepper command error', 13, 10, 0
	.endif
	.if	(TypePopStack & AUTOPOP_TYPE) && (status & AUTOPOP_TYPE)
	  sub	TypeSP, 2
	  shr	TypePopStack, 1
	.endif
	je	___interpret
	
try_number::
	public	try_number
;	FnShow	'n'
;	dec	si
;	dec	si		
;	sub	si, 4;	(extended address was on stack)
	mov	ax, offset	WordBuffer	;	0 is already on the stack, 
	call	PokeShortAX	;	requires pointer to text to convert to number
	call	___number
;	FnShow	'N'
	cmp	err_no, 0
	je	___interpret
word_err::
	public	word_err
;	invoke	pSetStream, 'E'
	mov	ax, offset	WordBuffer
	call	PushShortAX
	call	___count
	call	___type
	mov	al, '?'
	call	emit_al
	call	___cr
	mov	ax, err_no
	call	FORTHabort
	db	' : Word not found', 0

;include	padding.asm ;- 5E03:crash


check_blk::
	public	check_blk
	mov	ax, blk_addr
	and	ax, ax
	je	kbdin
	add	si, 4
	mov	[si], ax
	call	___block
	mov	ax, [si]
	mov	instr_offset, ax
	sub	si, 4
	ret
kbdin:
	mov	instr_offset, offset in_buffer
	ret

;include	padding.asm; - 5DB0:crash
;.listall

Code_word 	<spush>, NORMAL
;	????????????

	mov	ax, [si-2]
	StackPush [si], [si-2], up
	sub	si, 4
	ret

Code_word 	<spop>, NORMAL
;	????????????
	StackPop [si], up
	mov	[si], ax
	ret


;	Code_word <nul>
	db	0, 1, 0a0h		; length=1, invisible
_link0	dw	0
	dw	offset cs:___nul
___nul::
	public	___nul
	mov	ax, status
	and	ax, 80h
	jne	next_line
	add	sp, 2
	ret

next_line:
	cmp	blk_addr, 0
	je	continue_comp
	jmp	___quit
continue_comp:
	invoke	gets, addr _FORTH_DATA:in_buffer, 0, 255
;	xor	eax, eax
;	mov	ax, offset in_buffer
;	invoke	gets, eax, 0, 255 ; get the next command line
	call	___cr

	mov	instream, 0	; ?fs
	ret
	
;include	padding.asm - 5DD7:crash

Code_word	<sp>, NORMAL
	mov	ax, 20h
	jmp	PushShortAX

Code_word	<number>, NORMAL
	jmp	___form_number


Code_word	<LoadFile>, NORMAL ; (fname - count)  es=segment, edx = filetime
	
	;	fname is a 32-bit pointer (in DS space)
;	inc	dword ptr [si]
	call	___StrToDOS1	;	copy up to a DOS buffer in conventional memory
	mov	eax, [si]			
	push	eax			; save pointer to filename
	invoke	FstrToAsciiz, eax
	call	____LoadFile
	pop	eax			; restor pointer to filename
	push	edx		; file time
	invoke	AsciizToFstr, eax	; convert back to forth string
	pop	edx		; file time

	ret



Code_word	<_LoadFile>, NORMAL ; (far:asciiz - count)  es=segment

	mov	dx, [si]

	mov	ax,3d00h		; open file for al=0=read only
	int	21h
	jc	file_error
	push	ax			; file handle

	invoke	GetFileSize, ax		; length returned in EAX
	push	eax			; file length
	mov	ebx, eax
	shr	ebx, 4			; for paragraphs
	inc	ebx

	mov	ah, 48h
	int	21h     		; segment allocated in ax
	.if	carry?
	  mov	ax, ERR_DOS_ALLOC
malloc_error::
	  mov	err_no, ax
	  call	FORTHabort
	  db	' : Memory allocation error in _LoadFile', 0

	.endif
	pop	ecx			; file length
	pop	bx			; file handle
	.if	!ecx
	  mov	ax, 100
	  jmp	file_error
	.endif
	
	invoke	FileReadEx, bx, ax, ecx, 1	;	request filetime return in edx
	jc	file_error
	
	;	ax is segment where file has been loaded
	mov	es , ax
	mov	[si], ecx
			
	mov	ah, 3eh			; close file
	int	21h
	jc	file_error

	ret


Code_word	<fload>, NORMAL

	call	___wsword	

	push	edi
	movzx	edi, CurrentFileName
	add	di, 14
	mov	CurrentFileName, di
	push	edi
	push	esi
	mov	esi, [si]
	xor	cx, cx
	mov	cl, [esi]
	inc	cx
	.if	cx>13
	  mov	cx, 13
	.endif

	.repeat                 	; copy down to file name buffer
	  mov	al, [esi]
	  mov	[di], al
	  inc	esi
	  inc	di
	.untilcxz
	mov	byte ptr [di], 0	; nul terminate
	pop	esi
	pop	edi	; start of current filename


	mov	[si], edi			; form asciiz pathname
	invoke	FstrToAsciiz, edi
	pop	edi
	jmp	____fload


UnbalancedStackMsg	db	'Warning : Change in data stack pointer at end of ', 0


Code_word	<_fload>, NORMAL     ; ( faraddress: buffer - )

	push	es
	call	____LoadFile		; returns length on dstack
	.if	!dword ptr [si]
	  mov	ax, 30
	  jmp	file_error
	.endif
	mov	ax, es
	pop	es
	push	instr_seg
	mov	instr_seg, ax		; segment allocated


	mov	bx, 0			; pointer to start of block buffer
	push	fs
	; 2
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
clear_nasties::
	mov	al, fs:[bx]
;	call	emit_al
	cmp	al, 1ah
	je	end_of_file
	cmp	al, ' '
	jae	ok_char
	call	_iswhite?
	je	ok_char
	mov	byte ptr fs:[bx], 20h
ok_char:
	inc	bx
	loop	clear_nasties
	dec	bx
end_of_file:
	sub	si, 4
	mov	byte ptr fs:[bx], 0
;	mov	ax, fs
	pop	fs
	; 1
	push	instr_offset	; blk_addr
	; 2
	push	instream
	; 3
	push	LineNo
	; 4
	push	spStart
	; 5
	mov	LineNo, 1
	mov	spStart, si
	mov	instr_offset, 0 ; blk_addr,-16
	mov	instream, 0

	call	___interpret	; once compiled, data stack
	.if	si!=spStart	; should not have changed
		call	___cr
		xor	eax, eax
		mov	ax, offset cs:UnbalancedStackMsg
		invoke	PrintString, eax, cs

		movzx	eax, CurrentFileName
;		inc	ax
		invoke PrintString, eax, ds

		mov	al, '='
		call	emit_al
		mov	ax, si
		sub	ax, spStart
		sar	ax, 2
		cwde
		add	si, 4
		mov	[si], eax
		call	___sprint
		call	___cr
	.endif

	;	free memory used by last file

	push	es
	mov	es , instr_seg
;	invoke	LoadSegment, 'es', instr_seg, cs, 2800h
	mov	ah, 49h
	int	21h
	pop	es

	pop	spStart
	; 4
	pop	LineNo
	; 3
	pop	instream
	; 2
	pop	instr_offset	; blk_addr
	; 1
	pop	instr_seg
	; 0
	sub	CurrentFileName, 14
	ret

file_error::

	mov	err_no, ax
	call	FORTHabort
	db	' : File error in _LoadFile', 0

;include	padding.asm - 60A9:crashes?

Code_word	<hex>, NORMAL+IMMEDIATE
	mov	base, 16
	ret

Code_word	<decimal>, NORMAL+IMMEDIATE
	mov	base, 10
	ret

Code_word	<binary>, NORMAL+IMMEDIATE
	mov	base,2
	ret

;include	padding.asm - 60DD:crashes

Code_word	<vocabulary>, NORMAL
	mov	ax, offset _vocabulary
	call CreateExecutableHeader
	mov	ebx, h
	lea	eax, [ebx-8]
	mov	[ebx], eax
	add	h, 4
	or	byte ptr [ebx-10], IMMEDIATE+VOCABULARY
	ret	

_vocabulary::	public	_vocabulary
	add	ebx, 4
	mov	Context, ebx
	ret



Code_word	<OVocab>, NORMAL
	call	header
	forthcall	_objectVocabulary
	mov	bx, word ptr h			; call	___here
	lea	ax, [bx-4]
	mov	[bx], ax
	add	word ptr h, 2
	or	byte ptr [bx-5], IMMEDIATE+VOCABULARY+OBJECT
	ret

Code_word	<pushCO>, NORMAL
	mov	ax, [si]
	sub	si, 4
pushCurrentObject::
	push	bx
	add	TypeSP, 2
	mov	bx, TypeSP
	mov	[bx], ax
	pop	bx
	stc
	rcl	TypePopStack, 1
	ret

_objectVocabulary::	public	_objectVocabulary

	inc	bx
	inc	bx
	mov	ax, bx
	jmp	pushCurrentObject

Code_word <currentSize>, NORMAL
	mov	bx, TypeSP
	mov	ax, [bx]
	add	ax, 2
	jmp	PushShortAX

Code_word <sizeof>, NORMAL
	mov	bx, TypeSP
	mov	bx, [bx]
	mov	ax, [bx+2]
	jmp	PushShortAX


Code_word <ODefinitions>, NORMAL

	or	status, DEFINING_CLASS
	mov	bx, TypeSP
	mov	ax, [bx]		; get pointer to current type
	mov	word ptr Current, ax		; and set current to point to that type
	and	TypePopStack, not 1	; prevent autopop so this Type
					; endures through class definition
	ret

Code_word <class>, NORMAL+IMMEDIATE

	or	status, DEFINING_CLASS
	mov	bx, TypeSP
	mov	eax, [bx]
	mov	Current, eax		; current->parent cf definitions
	call	___OVocab		; create new class header
	mov	bx, TypeSP		; point to top of Type Stack
	mov	bx, [bx]                ; read pointer to currentObject
	mov	ax, [bx+2]		; get size of parent
	mov	bx, word ptr h			; pfa+2 of new class
	add	word ptr h, 2			; add size field
	mov	[bx], ax		; set sizeof(new class)=sizeof(parent)

	mov	ax, bx
	sub	ax, 2			; pfa
	mov	Current, eax             ; current voc->new class
	mov	bx, TypeSP
	mov	[bx], ax		; currentObject->new class
	ret


Code_word <endclass>, NORMAL

	mov	bx, TypeSP
	.if	word ptr [bx]
	  sub	bx, 2
	  mov	TypeSP, bx
	  shr	TypePopStack, 1
	.endif

	mov	eax, Context             ; change definitions to
	mov	Current, eax		; context vocabulary

	and	status, not DEFINING_CLASS
	ret

Code_word <member>, NORMAL

	call	header
	mov	bx, word ptr h
	mov	[bx], offset _MemberRun
	or	byte ptr [bx-3], OBJECT+IMMEDIATE
	push	di
	mov	di, TypeSP
	mov	di, [di]
	mov	ax, [di+2]	; call	___sizeof call	___dup
	mov	[bx+2], ax	; call	___enclose
	add	ax, [si]
	sub	si, 2
	mov	[di+2], ax	; + currentSize !
	add	word ptr h, 4
	pop	di
	ret

;include	padding.asm - crashes

_MemberRun::
	test	status, COMPILING
	jz	_MemberOffset
	mov	bx, word ptr h
	.if	TypePopStack & AUTOPOP_TYPE	; is this an external reference
	  mov	[bx], offset _MemberOffset     	; explicit access - heap ptr already on stack
	.else
	  mov	[bx], offset _PushThis		; within its own class - implicit push of *This
	.endif
	add	word ptr h, 2
	ret

_PushThis::	; first push This on stack
	inc	si
	inc	si
	mov	[si], es	; *This pointer is maintained in ES

_MemberOffset::	; push offset into object on heap
	mov	ax, [bx+2]
	inc	si
	inc	si
	mov	[si], ax
	ret

comment #
Code_word	<SegCheck>, NORMAL
	mov	ax, ErrorSegmentValue
	mov	[si+2], ax
	mov	ax, ErrorSegmentMin
	mov	[si+4], ax
	mov	ax, ErrorSegmentMax
	mov	[si+6], ax
	mov	ax, ErrorSegmentCall
	mov	[si+8], ax
	mov	ax, ErrorSegmentReg
	mov	[si+10], ax
	add	si, 10
	ret
#

Code_word	<.!"abort>, NORMAL, messageabort
	mov	ax, [si]
	mov	ebx, [si-4]
	jmp	FORTHMessageAbort

msgLno	db ' in ', 0

Code_word	<abort>, NORMAL
	mov	ax, [si]
	call	FORTHabort
	db	0

FORTHabort::
	mov	ebx, 0
FORTHMessageAbort::
	mov	si, dstack
	push	ebx
	push	ax
	invoke	pSetStream, 'E'
	and	status, 0ff7fh
	xor	eax, eax
	mov	ax, offset cs:err_mess
	invoke	PrintString, eax, cs

	pop	ax
	call	FORTHbyteprint
	pop	ebx
	.if	!ebx
	  pop	bx			; call return address (message)
	  mov	ax, cs
	.else
	  mov	ax, ds
	.endif
;	and	ebx, 0FFFFh
	invoke	PrintString, ebx, ax
	
	xor	eax, eax
	mov	ax, offset cs:msgLno
	invoke	PrintString, eax, cs

	movzx	eax, CurrentFileName
	call	PushEAX
	.if ax>offset File0
		invoke	AsciizToFstr, eax
	.endif
	call	___count
	call	___type

	.if	LineNo
	  mov	al, ':'
	  call	emit_al
	  mov	ax, LineNo
	  call	PushShortAX
	  push	base
	  mov	base, 10
	  call	___sprint
	  pop	base
	.endif
	call	___cr

	mov	blk_addr, 0
	.if	ByeOnError
		jmp	___bye
	.else
		jmp	___quit
	.endif

ByeOnError db 1

Code_word	<ByeOnError>, NORMAL
	mov	ax, [si]
	sub	si, 4
	or	al, ah
	mov	ByeOnError, al
	ret
;externdef	linkListStart : abs
;	linkListStart	=	@ByeOnError
;	public	linkListStart


codeDictionaryEnd	label byte


SetNesting::
	jmp	PushShortAX

CheckNesting::

	call	CheckNestingNoPop
	sub	si, 4
	ret

CheckNestingNoPop::
	.if	(ax!=[si])
	  mov	ax, ERR_NESTING
	  mov	bx, offset BadStructure
	  and	ebx, 0ffffh
	  jmp	FORTHMessageAbort
	.endif
	ret

;include	padding.asm - crashes

% lastPrimsLink	=	_link&lastLink

public	lastPrimsLink


primitives	endp

fhCRC	proc C uses bx cx dx ds es , handle:word

local	crc:word

	mov	bx, 100h		; 256 paragraphs = 4kb block
	mov	ah, 48h
	int	21h     		; segment allocated in ax
	.if	carry?
	  mov	ax, 11
	  jmp	fhCRCexit
	.endif
	mov	es , ax
;	invoke	LoadSegment, 'es', ax, cs, 2000h
	mov	ds , ax
;	invoke	LoadSegment, 'ds', ax, cs, 2000h
	mov	crc, 0


	.repeat
	  mov	bx, handle
	  mov	cx, 1000h		; max 4k block
	  mov	dx, 0
	  mov	ah,3fh			; read file
	  int	21h
	  jc	fhCRCexit
	  .if	ax    			; ax = # bytes read
	    invoke CRCBlock, 0, ax, crc
	    mov	crc, ax
	    mov	ax, 1
	  .endif
	.until	!ax

	clc
fhCRCexit:
	pushf
	push	ax
	mov	ah, 49h
	int	21h
	pop	ax
	popf
	.if	!carry?
	  mov	ax, crc
	.endif
	ret

fhCRC	endp

DSPush proc C, Stack:word, Value:word
	mov	bx, Stack
	add	word ptr [bx], 2
	add	bx, [bx]
	mov	ax, Value
	mov	[bx], ax
	ret
DSPush	endp

DSPop proc C, Stack:word
	mov	bx, Stack
	sub	word ptr [bx], 2
	add	bx, [bx]
	mov	ax, [bx]
	ret
DSPop	endp

interrupt_05	proc far

	; dx points to message in CS
	
	regprint	dx

;	assume that ax is used as index, or ebx is being used for address, and that edi points to address field within faulting word

	and	edx, 0FFFFh
	push dx
	invoke PrintString, edx, cs
	pop	dx

	.if	dx==offset msgSafeStore
		mov	eax, ebx
	.endif
	call	FORTHdhexprint
	
	xor	eax, eax
	mov	ax, offset msgBadAccessCaller
	invoke PrintString, eax, cs
	mov	eax, edi
	call	FORTHdhexprint
	call	___cr

	mov	ax, ERR_MEMORY_BOUNDS
	xor	ebx, ebx
	mov	bx, offset BadAccessMessage
	sti
	jmp	FORTHMessageAbort
	
msgOutOfBounds db ' : Bad memory write', 0

msgBadAccess	db	'MCC : Illegal write to $', 0
msgBadAccessCaller	db ', called from $', 0

interrupt_05	endp

db	100 dup(0Ah)	;	causes crash in call to CommReset

comment #
LoadSegment proc near C uses ax, SegReg:word, SegValue:word, SegMin:word, SegRange:word
local	SegError:word
	mov	SegError, 0
	assume	ax:word
	mov	ax, SegValue
	.if	SegReg=='ds'
	  mov	ds , ax
	.elseif SegReg=='es'
	  mov	es , ax
	.elseif SegReg=='fs'
	  mov	fs , ax
	.elseif SegReg=='gs'
	  mov	gs , ax
	.endif
	.if	ax<SegMin
	  inc	SegError
	.endif
	sub	ax, SegMin
	.if	ax>SegRange
	  inc	SegError
	.endif

	.if SegError
	  mov	ax, SegValue
	  mov	ErrorSegmentValue, ax
	  mov	ax, [bp+2]
	  mov	ErrorSegmentCall, ax
	  mov	ax, SegReg
	  mov	ErrorSegmentReg, ax
	  mov	ax, SegMin
	  mov	ErrorSegmentMin, ax
	  add	ax, SegRange
	  mov	ErrorSegmentMax, ax
	.endif

	ret

ErrorSegmentValue dw 0
ErrorSegmentCall  dw 0
ErrorSegmentMin	  dw 0
ErrorSegmentMax   dw 0
ErrorSegmentReg	  dw 0

LoadSegment endp
#


_TEXT	ends

	.nolist


end
