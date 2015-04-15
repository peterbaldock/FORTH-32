comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-STR.ASM	:	Forth string routines

21-02-96 Version 1.00	:	
2003-01-14 Version 2.80	:	+ nested comments ( ( ... ) ) and (* (* ... *) *)
				+ Line Number counting ( not in .( ... ) )

================================================================================#

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern      lastAluLink:abs
% _link400  equ lastAluLink

    thisLink textequ <401>
    lastLink textequ <400>

forth_str	proc    near

codeword	<strcpy>, NORMAL ; (long source ptr, long dest ptr  - )	Extended version

	push	esi
	push	edi

	mov	edi, [si]
	mov	esi, [si-4]
	call	____xstrcpy

	pop	edi
	pop	esi
	sub	si, 8
	ret

____xlstrcpy::							;	long string copy (first word is length) esi=source pointer, edi=destination pointer
	movzx	ecx, word ptr [esi]
	inc ecx
	inc ecx
	jmp	____xncpy
____xstrcpy::							;	esi=source pointer, edi=destination pointer
	movzx	ecx, byte ptr [esi]
	inc	cx
____xncpy::
	push	es
	mov	ax, ds
	mov	es, ax
	cld
	db	67h			;	67h prefix means 32-bit addressing
	rep	movsb
;	.repeat
;		mov	al, [esi]
;		mov	[edi], al
;		inc	esi
;		inc	edi
;	.untilcxz
	pop	es
	ret
	
codeword	<bcopy>, NORMAL ; (long source ptr, long dest ptr, length  - )	Extended version

	push	esi
	push	edi

	mov	ecx, [si]
	mov	edi, [si-4]
	mov	esi, [si-8]
	
	call	____xncpy

	pop	edi
	pop	esi
	sub	si, 12
	ret
	
codeword	<strcat>, NORMAL;  address: add address: target	Extended version

	push	esi
	push	edi

	mov	edi, [si]
	mov	esi, [si-4]
	movzx	cx, byte ptr [esi]
	movzx	eax, byte ptr [edi]
	add	cx, ax
	.if	ax>255
		mov	ExecutionError, 35
	.else
		mov	[edi], cl
		movzx	ecx, byte ptr [esi]
		add	edi, eax
		inc	edi
		inc	esi

		call	____xncpy
	.endif
	pop	edi
	pop	esi
	sub	si, 8
	ret

codeword	<strchrz>, NORMAL;	( address: str, word: char - ptr )	Extended version

	mov	ax, [si]
	sub	si, 4
findchar:
	mov	ebx, [si]
	.repeat
		mov ah, [ebx]
		.if al==ah
			mov	[si], ebx
			ret
		.endif
		inc ebx
	.until	!ah
	
	jmp	false

codeword	<rchar>, NORMAL; ( address: str, word: char - str, position)		Extended version

	mov	ax, [si]
	mov	ebx, [si-4]
	movzx	ecx, byte ptr es:[ebx]
	.if	cx
		add	ebx, ecx
		.repeat
			.if	al==[ebx]
				sub	ebx, [si-4]
				mov	[si], ebx
				ret
			.endif
			dec	ebx
		.untilcxz
	.endif
	mov	[si], ecx
	ret



codeword	<endz>, NORMAL;	( address: str - ptr )	Extended version

	mov	ebx, dword ptr [si]
	.while byte ptr [ebx]
		inc	ebx
	.endw
	mov	dword ptr [si], ebx
	ret


codeword	<lenz>, NORMAL;	( address: str - length )	Extended version
	mov	eax, dword ptr [si]
	call	___endz
	sub	dword ptr [si],  eax
	ret
	

Code_word	<$=>, NORMAL, stringEqual	;;		Extended version

;	dstack points to two forth strings, returns true or false

	mov	ebx, [si]
	sub	si, 4
	push	esi
	mov	esi, [si]

	mov	cl, [esi]	; length of first string
	.if	cl!=[ebx]

StringEqualNoMatch:

	  pop	esi
PokeFalse:
	  xor	eax, eax
	  mov	[si], eax
	  ret
	.endif

	xor	ch, ch
	.if	cl == ch
	  jmp	StringEqualMatch
	.endif

	.repeat
	  inc	esi
	  inc	ebx
	  mov	al, [esi]
	.untilcxz al!=[ebx]

	jnz	StringEqualNoMatch

StringEqualMatch:
	pop	esi
PokeTrue:
	mov	word ptr [si], -1
	ret

Code_word	<$i=>, NORMAL, stringIEqual		;;		Extended version

;	dstack points to two forth strings, returns true or false

	mov	ebx, [si]
	sub	si, 4
	push	esi
	mov	esi, [si]

	mov	cl, [esi]	; length of first string
	.if	cl!=[ebx]
	  jmp	StringEqualNoMatch
	.endif

	xor	ch, ch
	.if	cl == ch
	  jmp	StringEqualMatch
	.endif

	.repeat
ContinueCompare:

	  inc	esi
	  inc	ebx
	  mov	al, [esi]
	.untilcxz al!=[ebx]

	jz	StringEqualMatch

	mov	ah, [ebx]
	and	ax, not 2020h
	.if	(ah==al)&&(ah>='A')&&(ah<='Z')
	  jcxz	StringEqualMatch
	  jmp	ContinueCompare
	.endif
	jmp	StringEqualNoMatch

;Code_word	<(!")>, NORMAL, _quote	
;
;	movzx	ebx, di
;	inc	bx
;	inc	bx
;	add	si, 4
;	mov	[si], ebx
;	mov	al,[ebx]
;	xor	ah,ah
;	add	di, ax
;	inc	di
;	inc	di
;	ret

Code_word	<(!")>, NORMAL, _quote		;;	Extended version

	mov	ebx, edi
	add	edi, 4
	add	si, 4
	mov	[si], edi
	movzx	eax, byte ptr [edi]
	add	edi, eax
	sub	edi, 2
	ret

Code_word	<!">, NORMAL+IMMEDIATE, quote

	.if	status & COMPILING
		  mov	ebx, h
		  mov	word ptr [ebx], offset @ds_quote
		  mov	word ptr [ebx+2], 0
		  add	h, 4
	.endif

QuotedStringToDictionary::		;;		Extended version

	add	si, 4

QuotedStringToDictionary2::

	mov	dword ptr [si], '"'		; @_literal, 22h
	call	___word				; copies to low dictionary - need to copy up for extended dictionary
	
	.if	status & COMPILING
	
StringToDictionary::

		mov	ebx, [si]	;	pointer to result of 'word' is on stack
		movzx	ecx, byte ptr [ebx]
		inc	cx						; to take care of the count byte
		inc	cx						; and the terminating NULL
		add	h, ecx
		sub	si, 4
	.endif
	
	ret

Code_word	<string>, NORMAL	;;		Extended version, but not yet using heap
	
	or	status, COMPILING

	call	___create
	call	QuotedStringToDictionary
	
	and	status, not COMPILING
	ret

Code_word	<.!">, NORMAL+IMMEDIATE, dot_quote		;;	Extended version

	mov	ebx, h
	mov	[ebx], offset @ds_dot_quote
	mov	word ptr [ebx+2], 0
	add	h, 4

	jmp	QuotedStringToDictionary
	
;Code_word	<(.!")>, NORMAL, _dot_quote
;	add	di, 2
;	mov	cl,[di]
;	xor	ch,ch
;	cmp	cl,ch
;	je	end_quote
;	mov	ah,2
;out_quote:
;	inc	di
;	mov	al, [di]
;	call	emit_al
;	loop	out_quote
;end_quote:
;	ret

Code_word	<(.!")>, NORMAL, _dot_quote		;;	Extended version
	add	edi, 4
	movzx	cx, byte ptr [edi]
	cmp	cl,ch
	je	xend_quote
	mov	ah,2
xout_quote:
	inc	edi
	mov	al, [edi]
	call	emit_al
	loop	xout_quote
xend_quote:
	sub	edi, 2
	ret

Code_word	<(>, NORMAL+IMMEDIATE, comment
	push	fs
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	mov	CommentDepth, 1
	mov	bx, instream
	add	bx, instr_offset
	assume	bx: ptr byte
	mov	dl, ')'
	mov	dh, '('

	.repeat
	  mov	al, fs:[bx]
	  .if	!al
	    .break
	  .endif
	  .if	al==dh
	    inc	CommentDepth
	  .elseif al==dl
	    dec	CommentDepth
	  .elseif al==LF
	    inc	LineNo
	  .endif
	  inc	bx
	.until	!CommentDepth
	sub	bx, instr_offset
	mov	instream, bx
	pop	fs
	ret
	assume	bx: nothing

Code_word	<(*>, NORMAL+IMMEDIATE, pcomment
	push	fs
	mov	fs , instr_seg
;	invoke	LoadSegment, 'fs', instr_seg, cs, 2800h
	mov	CommentDepth, 1
	mov	bx, instream
	add	bx, instr_offset
	assume	bx: ptr byte
	mov	dl, ')'
	mov	dh, '('

	.repeat
	  mov	al, fs:[bx]
	  .if	!al
	    .break
	  .endif
	  .if	(al==dh)&&(fs:[bx+1]=='*')
	    inc	CommentDepth
	  .elseif (al==dl)&&(fs:[bx-1]=='*')
	    dec	CommentDepth
	  .elseif al==LF
	    inc	LineNo
	  .endif
	  inc	bx
	.until	!CommentDepth
	sub	bx, instr_offset
	mov	instream, bx
	pop	fs
	ret
	assume	bx: nothing

CommentDepth	dw	0

Code_word	<.(>, NORMAL+IMMEDIATE, printcomment
	mov	ax,')'
	add	si, 4
	mov	edx, h			; copy to 'here'
	call	bword
	call	___count
	jmp	___type

codeword	<str->, NORMAL, strminus;	( address: text, address: match - n )	;	for nul-terminated

	push	edi
	mov	edi, dword ptr [si]	; match
	sub	si, 4
	push	si
	mov	esi, dword ptr [si]		; text
	
	xor	ecx, ecx
	mov	al, [edi]
	.while (al) && (al == [esi])
		inc	ecx
		inc	esi
		inc	edi
		mov	al, [edi]
	.endw
	
	pop	si
	mov	dword ptr [si], ecx
	pop	edi
	ret


Code_word	<!>asciiz>, NORMAL, ToAsciiz

	invoke	FstrToAsciiz, dword ptr [si]	;	32-bit
	ret

Code_word	<asciiz!>>, NORMAL, FromAsciiz

	invoke	AsciizToFstr, dword ptr [si]	;	32-bit
	ret


	
;====================================================================

;	The following words are not extended memory compatible

;=====================================================================


codeword	<instr>, NORMAL; ( address: str, word: start, word: char - str, position )	;	NOT extended memory compatible

	mov	ax, [si]
	mov	bx, [si-8]
	movzx	cx, byte ptr es:[bx]
	add	bx, [si-4]
	xchg	di, bx
	inc	di
	
	cld
	repne	scasb
	
	.if	zero?
		sub	di, [si-8]
		dec	di
	.else
		xor	di, di
	.endif
	
	xchg	di, bx
	sub	si, 4
	mov	[si], bx
	
	ret
	

Code_word	$search, NORMAL			;	NOT extended memory compatible
	mov	bx,[si]
	sub	si, 12
	pushf
	push	di
	push	si
	mov	di,[si]
	mov	cx,[si+4]
	and	cx,cx
	je	search_fail
	mov	si,[si+8]
	mov	ax,[si]
	add	si, 2
	cmp	bx, 1
	je	single_byte_scan
	jb	search_fail
	and	cx,cx
	jns	up_search
	std
	neg	cx
	sub	cx,bx
	jc	search_fail
	add	di,cx
	dec	bx
	inc	cx
	dec	bx
	sub	di, 2
find_first:
	inc	di
	scasw
	loopnz	find_first
	jnz	search_fail
	and	bx,bx
	jz	string_found_dn
	push	si
	push	di
	push	cx
	mov	cx,bx
	add	di, 4
	cld
	repe	cmpsb
	pop	cx
	pop	di
	pop	si
	std
	jne	find_first
string_found_dn:
	add	di, 2
string_found:
	pop	si
	mov	[si],di
	add	si, 4
	mov	dword ptr [si], 1
	pop	di
	popf
	ret
up_search:
	cld
	sub	cx,bx
	jc	search_fail
	sub	bx, 2
	inc	cx
	inc	di
find_firstu:
	dec	di
	scasw
	loopnz	find_firstu
	jnz	search_fail
	and	bx,bx
	jz	string_found_up
	push	di
	push	si
	push	cx
	mov	cx,bx
	cld
	repz	cmpsb
	pop	cx
	pop	si
	pop	di
	jne	find_firstu
string_found_up:
	sub	di, 2
	jmp	short string_found

search_fail:
	pop	si
	pop	di
	popf
	mov	dword ptr [si], 0
	ret

single_byte_scan:
	and	cx,cx
	jns	sb_up
	dec	di
	neg	cx
	add	di,cx
	std
	repne	scasb
	jne	search_fail
	inc	di
	jmp	short	string_found
sb_up:	cld
	repne	scasb
	jne	search_fail
	dec	di
	jmp	short	string_found

Code_word	<-trailing>, NORMAL, minus_trailing			;	NOT extended memory compatible
	mov	cx,[si]
	mov	bx,cx
	add	bx,[si-4]
	mov	al,20h
	inc	cx
sp_look:
	dec	bx
	cmp	al,[bx]
	loope	sp_look
	mov	[si],cx
	ret

Code_word	<-text>, NORMAL, minus_text	; s1=[si], n=[si-4], s2=[si-8]			;	NOT extended memory compatible

	push	di
	push	es
	push	ds
	pop	es

	mov	bx, si		; use bx to address data stack
	mov	si, [bx]
	mov	di, [bx-8]
	mov	cx, [bx-4]
	jcxz	match
	cld
	repz	cmpsb
	.if	zero?
match:	  sub	ax, ax
	.else
	  dec	di
	  dec	si
	  mov	al, [di]
	  sub	al, [si]
	  cbw
	.endif

	mov	si, bx
	pop	es
	pop	di
	sub	si, 8
	call PokeShortAX

	ret

% lastStrLink =   _link&lastLink

public  lastStrLink

forth_str   endp


;	========================================	Procedures follow	====================================================


FstrToAsciiz	proc near C uses esi edi, bptr:dword	; 32-bit implementation

	mov	esi, bptr
	mov	edi, bptr
	movzx	cx, byte ptr [esi]
	inc	esi
	.repeat
		mov	al, [esi]
		mov	[edi], al
		inc	esi
		inc	edi
	.untilcxz
	mov	[edi], cl
	ret

FstrToAsciiz	endp

AsciizToFstr	proc near C uses esi edi, bptr:dword	; 32-bit implementation

	mov	esi, bptr
	mov	edi, esi
	xor	cx, cx

	.repeat
		mov	al, [esi]
		inc	esi
		inc	cx
	.until !al

	dec	cx
	mov	dx, cx
	dec	esi
	mov	edi, esi
	
	.repeat
		dec	esi
		mov	al, [esi]
		mov	[edi], al
		dec	edi
	.untilcxz
	
	mov	[edi], dl
	ret

AsciizToFstr	endp

comment #
LTStringToAsciiz	proc near C uses esi edi, bptr:dword	; 32-bit implementation

	mov	esi, bptr
	mov	edi, bptr
	mov	cx, word ptr [esi]
	dec	cx
	add	esi, 3
	.repeat
		mov	al, [esi]
		mov	[edi], al
		inc	esi
		inc	edi
	.untilcxz
	mov	[edi], cl
	ret

LTStringToAsciiz	endp
#



LTStringToAsciiz	proc near C uses si di es ds, bptr:dword

	;	this is still 16-bit segmented, as it is used by gets which is not yet converted to 32-bit.
	
	lds	si, bptr
	les	di, bptr
	mov	cx, [si]
	dec	cx
	add	si, 3
	rep	movsb
	mov	es:[di], cl
	ret

LTStringToAsciiz	endp


_TEXT	ends

end

