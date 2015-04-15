Comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-INP.ASM	:	Forth string routines

21-02-96 Version 1.00	:
2003-01-14 Version 2.80	:	+ wsword (whitespace word)
				+ LineNo - line number tracking
				+ no suppression of TAB, LF, CR in fload
2004-07-29 Version 3.00	:	+ virtual declarations for forward references.
				+ FindVocabulary altered to not search null vocabularies.
				+ CheckVocabularyLinkage inserted for debugging
2004-08-23 Version 3.02 :	~ find checks order of links in case dictionary corrupted

================================================================================#

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\hooks.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include ..\include\serial.inc
include ..\include\macros.inc
include	..\include\fp.inc
include ..\include\step.inc
include	FTH-ERRS.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


externdef		lastDispLink:abs
% _link800	equ	lastDispLink

	thisLink textequ <801>
	lastLink textequ <800>


forth_inp	proc	near

codeword	<ReadKeyboard>, NORMAL
	mov	ah, 11h
	int	16h
	.if	zero?
		xor	ax, ax
	.else
		mov	ah, 10h
		int	16h
	.endif
	jmp	PushShortAX

codeword	<swapstream>, NORMAL

	mov	ax, [si-8]
	mov	bx, instr_seg
	mov	[si-8], bx
	mov	instr_seg, ax

	mov	ax, [si-4]
	mov	bx, instr_offset
	mov	[si-4], bx
	mov	instr_offset, ax

	mov	ax, [si]
	mov	bx, instream
	mov	[si], bx
	mov	instream, ax
	ret

;include	padding.asm ; 37 bytes 3D78:crashes

codeword	<next>, NORMAL

	push	fs
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	mov	bx, instr_offset
	add	bx, instream
	add	si, 2
	mov	al, fs:[bx]
	xor	ah, ah
	mov	[si], ax
	.if	ax
	  inc	instream
	.endif
	pop	fs
	ret

codeword	<-next>, NORMAL, minusnext

	push	fs
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	mov	ax, [si]
	.if	al
	  dec	instream
	.endif
	mov	bx, instr_offset
	add	bx, instream
	mov	fs:[bx], al
	sub	si, 2
	pop	fs
	ret

;==============================================================================

codeword 	<wsword>, NORMAL;	( - address )

;==============================================================================

	mov	edx, h			; copy up to 'here'

wsbword:: mov	bx, instream		; entry point for gp. code calls
	add	bx, instr_offset
	push	fs
	mov	fs, instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	
	add	si, 4
	push	esi
	mov	esi, edx	; target address for copy up
	push	esi

wswloop:
	.repeat
		mov	al, fs:[bx]
		.if	!al
			inc	esi
			mov	byte ptr [esi], 0	; nul
			pop	esi
			mov	byte ptr [esi], 1	; length
			sub	bx, instr_offset
			mov	instream, bx
			mov	ebx, esi
			pop	esi
			mov	[si], ebx
			pop	fs
			ret
	  	.endif
	  	inc	bx
	  	.if	al==LF
	  		inc	LineNo
	  	.endif

		call	_iswhite?
	.until	!zero?		; until no more leading delimiters

	dec	bx		; so bx points to start of word
	mov	cx, bx

	.repeat
		mov	al, fs:[bx]
		inc	bx
		.if	!al
			.break
		.endif
		inc esi
		mov [esi], al
		call	_iswhite?
	.until	zero?

	;mov	byte ptr [esi], 0
	dec	bx
	push	bx
	.if	al
	  inc	bx		; move input stream on to next character
	.endif

	sub	bx, instr_offset
	mov	instream, bx
	pop	bx
	sub	bx, cx		; length

	pop	esi
	mov	[esi], bl
	mov	ebx, esi
	pop	esi			; restore data stack
	pop	fs
	mov	eax, ebx
	mov	[si], eax
	ret
	
codeword	<iswhite?>, NORMAL
	mov	ax, [si]
	call	_iswhite?
	.if	zero?
	  jmp	true
	.else
	  jmp	false
	.endif

_iswhite?::
	cmp	al, ' '
	je	matched
	cmp	al, TAB
	je	matched
	cmp	al, CR
	je	matched
	cmp	al, LF
matched:
	retn

;==============================================================================

codeword 	<word>, NORMAL;	( char - )

;==============================================================================

	mov	ax, [si]                 ; delimiter
	mov	edx, h			; copy up to 'here'

bword::	mov	bx, instream		; entry point for gp. code calls
	add	bx, instr_offset
	push	fs
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	push	esi
	mov	esi, edx	;	usually 'here'
	push	esi
	dec	bx

wloop:	.repeat
	  inc	bx
	  .if	! byte ptr fs:[bx]
			inc	esi
			mov	byte ptr [esi], 0	; nul
			pop	esi
			mov	byte ptr [esi], 1	; length
			sub	bx, instr_offset
			mov	instream, bx
			mov	ebx, esi
			pop	esi			; restore data stack
			mov	[si], ebx
			pop	fs
			ret
	  .endif
	.until	fs:[bx] != al		; until no more leading delimiters

	mov	cx,bx

	.while	(al != fs:[bx]) && (byte ptr fs:[bx])
	    mov	ah, fs:[bx]
	    inc	esi
	    mov	[esi], ah
	  	inc	bx
	.endw
	inc	esi
	mov	byte ptr [esi], 0	; nul terminate

	push	bx
	.if	byte ptr fs:[bx]
	  inc	bx
	.endif

	sub	bx, instr_offset
	mov	instream, bx
	pop	bx
	sub	bx,cx
	pop	esi
	mov	[esi],bl
	mov	ebx, esi
	pop	esi			; restore data stack
	mov	[si], ebx
	pop	fs
	ret
	
;Code_word	<extended?>, NORMAL
;	movzx	eax, xon
;	jmp	PushEAX


;=============================================================================

codeword	<''>, NORMAL, <find>

;=============================================================================
	xor	edx, edx
	mov	dx, offset WordBuffer		; copy up
	call	wsbword   	; for no copy up, returns bx = start of string
	jmp	___latefind

;=============================================================================

codeword	<find>, NORMAL, <latefind>

;=============================================================================
	; enter with string pointer on stack

	push	es
	push	ds
	pop	es

	push	edi
	push	esi		; save data stack pointer


	mov	edi, [si]          ; set es:edi to point to source text

SearchLocals:
	mov	bx, offset LocalsLink	; locals->context
	movzx	ebx, word ptr [bx]
	.while	ebx
		mov	esi, ebx
		sub	esi, 4
		invoke	XStringCompare, esi, edi, 0106h
		.if	ax
			jmp	found
		.endif
		movzx	eax, word ptr [ebx]
		.if	eax>ebx
			mov	dx, offset cs:msgConLinkage
			call LinkageError
			jmp	not_found
		.endif
		mov	ebx, eax
	.endw

SearchContext:

	mov	bx, ContextIndex
	.repeat
		push	bx
		shl	bx, 2
		mov	ebx, Context[bx]

SearchVocabularies::		;	Takes ebx = context, returns pointer or null

		mov	ebx, [ebx]

		.while	ebx		; points to link field
			mov	esi, ebx
			sub	esi, 4	; point to length field
			invoke	XStringCompare, esi, edi, 0106h
			.if	ax
				add	sp, 2	;	drop bx
				jmp	found
			.endif
			
			.if	byte ptr [ebx-2] & VOCABULARY
				;	if now pointing to this vocabulary link, then end of this search, unless index = 0
				pop	ax	;	index
				push	ax
				.if	ax
					shl	ax, 2
					xchg	eax, ebx
					.if	eax < Context[bx]
						xor	ebx, ebx
					.else
						mov	ebx, eax
						mov	ebx, [ebx]
					.endif
				.else
					mov	ebx, [ebx]
				.endif
			.else
				mov	ebx, [ebx]
			.endif
			
		.endw

		pop	bx
		dec	bx

	.until bh
  
not_found:
	pop	esi			; restore data stack
	xor	ebx, ebx
;	add	si, 4
	mov	dword ptr [si], ebx

	pop	edi
	pop	es
	ret

found:
	pop	esi		; restore data stack pointer
	mov	ax, [ebx-2]
	add	ebx, 8
;	jmp	TypePop
	
;found:
;	pop	esi		; restore data stack pointer
;	mov	al, [ebx-1]
;	add	ebx, 4

TypePop::
	and	al, OBJECT+VOCABULARY
	.if	al==OBJECT
	  or	status, AUTOPOP_TYPE
	.else
	  and	status, not AUTOPOP_TYPE
	.endif

;	add	si, 4
	mov	[si], ebx	;	leave extended address on stack in place of string pointer

	pop	edi
	pop	es
	ret

LinkageErrorMessage	db  "MCC : Linkage error in searching ", 0

LinkageError::	; dx = pointer to message

	push	eax
	push	bx
	push	dx
	xor	eax, eax
	mov	ax, offset LinkageErrorMessage
	invoke	PrintString, eax, cs
	xor	edx, edx
	pop	dx
	invoke	PrintString, edx, cs
	pop	ax
	call	FORTHhexprint
	mov	al, '='
	call	emit_al
	pop	eax
	call	FORTHhexprint
	call	___cr
;	mov	err_no, ERR_LINKAGE
	ret



msgLocLinkage	db	"Locals. ", 0
msgCOLinkage	db	"Current Object. ", 0
msgConLinkage	db	"Context. ", 0
msgVocLinkage	db	"Vocabulary. ", 0

;=================================================================================

codeword	<query>, NORMAL
	invoke	gets, addr _FORTH_DATA:DOSpad_start, 0, 79
	call	___cr
	ret

codeword	<expect>, NORMAL		; ( buff, count - )
	mov	ax, [si-4]
	invoke	gets, DS::ax, 0, [si]
	sub	si, 8
	ret

codeword	<incom>, NORMAL		; ( command - word )
	mov	dx, HostPort
	dec	dx

	.if	word ptr si	; get status
	  mov	ah, COMMS_STATUS
	  int	14h
	  test	ah, 1
	  .if	zero?		; bit zero=0 means no data ready
		sub	ax,ax
	  .endif
	.else
	  mov	ah, COMMS_RECEIVE
	  int	14h
	.endif
	mov	[si], ax
	ret

codeword	<button?>, NORMAL
	mov	dx, 307h
	in	al, dx
	and	ax, 1
	dec	ax
	jmp	PushShortAX

codeword	<!>kbd>, NORMAL, to_kbd
	mov	ax, offset	_FORTH_DATA:in_buffer
	jmp	PushShortAX

codeword	<convert>, NORMAL
	mov	ebx,[si]		;	pointer to string
	mov	eax,[si-4]	;	32-bit value accumulator is NOS
	xor	ecx, ecx
	push	base
	.if	byte ptr [ebx+1]=='$'
	  inc	ebx
	  mov	base, 16
	.endif
	mov	cx, base
	mov	dword ptr [si+4], ecx

nloop:	
	inc	ebx
	mov	cl, [ebx]
	call	make_digit
	jc	end_convert
	mul	dword ptr [si+4]
	add	eax, ecx
	jmp	short nloop

end_convert:
	mov	[si-4], eax
	mov	[si], ebx
	pop	base
	ret

codeword	<(number)>, NORMAL, form_number
	mov	ebx, [si]					; pointer to text to be converted
	cmp	byte ptr [ebx+1],'-'
	pushf
	push	ebx
	jne	positive
	inc	ebx
positive:
	mov	dword ptr [si], 0	;	initialize accumulator
	add	si, 4
	mov	[si], ebx				;	push string pointer
	call	___convert
	mov	ebx,[si]
	mov	al,[ebx]
	cmp	al, '.'
	je	float
	cmp	al, ','
	je	float
;	cmp	al, decimalSeparator	; 2003-10-22 always accept '.'&','
;	je	float
	add	sp, 4		; drop original ebx ptr
	
	.if	al=='w'

short_int:

		mov	punct, 0
		mov	number?, 1
		sub	si, 4
		popf
		je	___negate
		ret

	.endif
	
	cmp	al,':'
	je	double
	cmp	al,'l'
	je	double
	cmp	al,'L'
	je	double
	cmp	al,','
	je	double
	call	_iswhite?
	je	single
	cmp	al, 0
	je	single
	jmp	num_err
single:
	mov	punct, 'L'
	mov	number?, 2
	mov	places , 0
	sub	si, 4
	popf
	je	___dnegate
	ret

double:
	mov	punct, al
	mov	number?, 2
	push	ebx
	call	___convert
	mov	ebx,[si]
	mov	al, [ebx]
	;cmp	al,' '
	call	_iswhite?
	je	double2
	cmp	al, 0
	jne	num_err2
double2:
	pop	ecx
	sub	ebx,ecx
	mov	places , bl
	sub	si, 4
	popf
	je	___dnegate
	ret
float:
	mov	punct, al
	mov	number?, -2
	pop	ebx
	inc	ebx
	push	esi
	invoke	atof, ebx
	mov	bx, si
	pop	esi

	jc	num_err
	add	sp, 2			; drop flags
	sub	si, 4
	mov	[si], eax
	ret



num_err2:
	inc	sp
	inc	sp
num_err:
	inc	sp
	inc	sp
	mov	err_no, ERR_NUMERIC_INPUT
	mov	number?, 0
	ret

codeword	<number?>, NORMAL
	mov	ax, number?
	jmp	PushShortAX
	
codeword	<with>, IMMEDIATE
	call	___find
	mov	ebx, [si]
	.if	ebx
		.if	byte ptr [ebx-10] & VOCABULARY
			jmp	___contextpush
		.else
			mov	ax, ERR_BAD_VOCABULARY
			call	FORTHabort
			db	' : "with" used with non-vocabulary word', 0
		.endif
	.endif
	mov	ax, ERR_BAD_VOCABULARY
	call	FORTHabort
	db	' : "with" could not find vocabulary specified', 0
	ret

codeword	<endwith>, IMMEDIATE
	call	___contextpop
	jmp	___drop
	


codeword	<''voc>, NORMAL, findVoc

	xor	edx, edx
	mov	dx, offset WordBuffer		; copy up
	call	wsbword
	push	edi
	push	es
	push	esi		; save data stack pointer

	movzx	esi, cx          ; set si to point to source text
	movzx	ecx, bx		; and cx = text length

	mov	edi, Context
	sub	edi, 4
	call	FindVocabulary
	.if	ebx		; returns bx pointing to link field
	  add	ebx, 4		; make bx point to parameter field of vocabulary
	.endif
	pop	esi
	pop	es
	pop	edi
	mov	[si], ebx
	ret


codeword	<CVL>, NORMAL
	mov	edi, [si]
	call	CheckVocabularyLinkage
	mov	[si], eax
	ret

% lastInpLink =   _link&lastLink

public  lastInpLink

forth_inp	endp

;****************************************************************************

FindVocabulary proc near uses cx si di

;****************************************************************************

comment #

	This function searches all sub vocabularies for a vocabulary entry
	matching the text at DS:ESI of length CX<256. On entry, EDI points to
	the link field of the vocabulary to be searched.

	Return value : EBX contains matching vocabulary pfa or 0

	Vocabulary Dictionary Entry : (Normal entry + parameter field = VV)

	XX....XX N P LLLL CCCC VVVV 		XX..XX : vocabulary name
					N  : length of name
					P  : word properties (NoCase, Vocab etc) (2014-01-09 INVISIBLE dropped)
					LLLL : link field (4 bytes)
					CCCC : code pointer field
					VVVV : vocabulary link field to last
						word in this vocabulary
#

	.if	!edi
	  clc
	  mov	ebx, edi
	  ret
	.endif

	mov	ebx, [edi+8]	; point to last word in this vocabulary

	; search back from most recent word in current vocabulary
	; for a sub-vocabulary

	.repeat
	  .while !((byte ptr [ebx-1])&VOCABULARY) && ebx
	    mov	eax, [ebx]
	    .if	eax>ebx
	      mov  dx, offset cs:msgVocLinkage
	      call LinkageError
	      mov  ebx, 0
	      ret
	    .endif
	    mov	ebx, eax
	    ; mov	bx, [bx]
	  .endw
	  .if	!ebx
	    ret
	  .endif

	  .if	ebx != edi
	   push	edi
	   mov	edi, ebx
	   call	FindVocabulary

	   .if	ebx
	    pop	edi
	    stc
	    ret
	   .endif
	   mov	ebx, edi
	   pop	edi
	   mov	ebx, [ebx]
	  .endif
	.until	ebx==edi

	;      now test this vocabulary entry

	call	CompareWord
	.if	carry?
	  mov	ebx, edi		; word link field of matching vocabulary
	.else
	  mov	ebx, 0		; not found
	.endif

	ret



FindVocabulary endp

;****************************************************************************

CheckVocabularyLinkage proc near uses cx si di

;****************************************************************************

comment #

	This function counts all sub vocabularies and returns the count.
	If linkage is unexpected or erroneous it aborts with a short count.
	On entry, DI points to the link field of the vocabulary to be searched.

	Return value : BX contains vocabulary count or -1 on error.

	Vocabulary Dictionary Entry : (Normal entry + parameter field = VV)

	XX....XX N P LL CC VV 		XX..XX : vocabulary name
					N  : length of name
					P  : word properties (NoCase, Vocab etc)  (2014-01-09 INVISIBLE dropped)
					LL : link field (2 bytes)
					CC : code pointer field
					VV : vocabulary link field to last
						word in this vocabulary
#
local	wcount:word
	mov	wcount, 0
	mov	bx, [di+4]	; point to last word in this vocabulary

	; search back from most recent word in current vocabulary
	; for a sub-vocabulary

	.repeat
	
		.while !((byte ptr [bx-1])&VOCABULARY) && bx
		
			.if bx>[bx]
				inc	wcount
				mov	bx, [bx]
			.else
				mov	wcount, -1
				mov	bx, 0
			.endif
			
		.endw
		
		.if	!bx
			mov	ax, wcount
			ret
		.endif

		.if	bx != di
			push	di
			mov	di, bx
			call	CheckVocabularyLinkage
			
			.if	ax==-1
				pop	di
				ret
			.endif
			
			add	wcount, ax
			mov	bx, di
			pop	di
			mov	bx, [bx]
			
		.endif
		
	.until	bx==di

	mov	ax, wcount
	ret

CheckVocabularyLinkage endp


;==============================================================================

XStringCompare proc C uses esi edi, S1:dword, S2:dword, style:word

;==============================================================================

Comment #
	Compare String ds:S1 (long address accessed as ds:[esi] ) with es:S2 (es:[edi])
						F	E	D	C	B		 A		  9	  8     		7	6	5	4	3		 2		 1		 0
	Styles			0	0	0	0	0		p2	Length2   		0 	0	0	0	0		p1	Length1
	
	p1, p2	-	position of length field for S1 and S2.	If set, then length is at END of string
	
	Length1, Length2	- 00=>use CX value,  01=>1 byte length field, 10=> 2 byte length field
	
	0			CX contains the count - ie compare CX chars
	1			1 byte count at START of string (old Forth style)
	2			2 byte count at START of string (long string)
	5			1 byte count at END of string (old Forth dictionary entry)
	6			2 byte count at END of string (new extended style dictionary entry)
	
	Examples:
		
			$0101	(al=1, ah=1)		:	S1 = old Forth string, S2 = old Forth string.
			$0501	(al=1, ah=5)	:	S1 = old Forth string, S2 = old Forth dictionary entry
			$0601	(al=1, ah=6)	:	S1 = old Forth string, S2 = New Forth dictionary entry
			$0202	(al=2, ah=2)		:	S1 = new Forth string, S2 = new Forth string.
	
	;	Returns AX=0, C=0 if no match; AX=-1, C=1 if match.
#

local DefaultLength : word

	mov DefaultLength, cx
	mov	ax, style
	mov	esi, S1
	mov	edi, S2

	.if al==1
		movzx	cx, byte ptr [esi]
		inc	esi
	.elseif al==2
		mov	cx, [esi]
		inc	esi
		inc	esi
	.elseif al==5
		movzx	ecx,  byte ptr [esi]
		sub esi, ecx
	.elseif al==6
		movzx	ecx, word ptr [esi]
		sub esi, ecx
	.elseif al
		jmp	NoMatch
	.endif		

	push cx

	.if	ah==1
		movzx	cx,  byte ptr es:[edi]
		inc	edi
	.elseif ah==2
		mov	cx, es:[edi]
		inc	edi
		inc	edi
	.elseif ah==5
		movzx	ecx,  byte ptr es:[edi]
		sub edi, ecx
	.elseif ah==6
		movzx	ecx, word ptr es:[edi]
		sub edi, ecx
	.elseif ah
		pop	cx
		jmp	NoMatch
	.endif		

	pop	ax

	.if	ax!=cx
NoMatch:
		xor	ax, ax
		jmp	@f
	.endif

	.repeat
		mov	al, [esi]
		mov	ah, es:[edi]
		.if al!=ah
			xor	ax, ax
			jmp	@f
		.endif
		inc	esi
		inc	edi
	.untilcxz

	mov	ax, -1
	
@@:
	mov	cx, DefaultLength
	ret

XStringCompare	endp	

;****************************************************************************

CompareWord proc near uses cx si di

;****************************************************************************

comment #

	This function compares the text at FS:SI of length CX<256 with the
	dictionary entry pointed to by DS:EDI. DI points to the first byte of
	the link field, LL.

	Dictionary Entry :

	XX....XX N P LL CC		XX..XX ; word name
					N  : length of name
					P  : word properties (invisible, NoCase, Vocab etc)
					LL : link field (2 bytes)
#
	mov	ax, [edi-2]		; al = N, ah = P
	.if	al != cl		; lengths do not match
not_found:
	  clc				; return c=0 for no match
	  ret
	.endif


	sub	edi, 2
	sub	edi, ecx			; point to start of word text
	cld

	dec	si
	dec	edi
	.repeat
		inc	si
		inc	edi
		mov	al, fs:[si]
	.untilcxz al!=[edi]

	jne	not_found
;	  repe	cmpsb
;	  je	found
;	.endif

found:
	stc				; return c=1 for match
	ret

CompareWord endp


_TEXT	ends

end

