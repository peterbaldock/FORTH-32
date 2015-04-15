commentœ=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-DISP.ASM	:	display routines

21-02-96 Version 1.00	:
04-04-96 Version 1.01	~	<cr> changed to CR/LF instead of LF/CR
2003-01-14 Version 2.80	:	+ n#, n$hold, for controlled field width
				+ format
				+ LineNo - line number tracking
				+ Line number/file name reporting for abort
				+ nested comments ( ( ... ) ) and (* (* ... *) *)

================================================================================œ

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include ..\include\step.inc
include ..\include\fp.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern		lastSysLink:abs
extern		lastStkLink:abs
extern		lastMemLink:abs
extern		lastAluLink:abs
extern		lastStrLink:abs
extern		lastDicLink:abs
extern		lastBlkLink:abs

;externdef	_vocabulary:near
% _link400	equ	lastAluLink
% _link500	equ	lastStrLink
% _link600	equ	lastDicLink
% _link700	equ	lastBlkLink

	thisLink textequ <701>
	lastLink textequ <700>

forth_disp	proc	near

codeword	<colour>, NORMAL
	mov	ax, offset	colour
	jmp	PushShortAX

codeword	<page>, NORMAL
	mov	ax, offset	videopage
	jmp	PushShortAX

codeword	<border>, NORMAL
	mov	ah, 0bh
	mov	bh, 0
	mov	bl, [si]
	sub	si, 4
	int	10h
	ret

codeword	<display>, NORMAL
	mov	ax, [si]
	sub	si, 4
	mov	videopage, al
	mov	ah, 05h
	int	10h
	ret

codeword	<cls>, NORMAL
cls::	
	mov	bl, videopage
	xor	bh, bh
	add	bl, bl
	mov	cx, pagesize[bx]
	shr	bl, 1
	mov	bh, bl
	mov	bl, colour
	
	mov	dh, ch
	xor	dl, dl

	.repeat
	  dec	dh
	  mov	ah,2
	  int	10h
	  mov	al, 20h
	  push	cx
	  mov	cx, 80
	  mov	ah, 9
	  int	10h
	  pop	cx
	.until	dh==cl

	mov	ah, 0bh		; set boarder colour to match background
	mov	bh, 0
	mov	bl, colour
	shr	bl, 1
	shr	bl, 1
	shr	bl, 1
	shr	bl, 1
	int	10h

	ret

codeword	<where>, NORMAL	; put cursor position on stack - TOS=y
	mov	ah, 3		; Video	GetCursor Position
	mov	bh, videopage
	int	10h		; Video interrupt
	mov	al, dh
	xor	ah, ah
	mov	dh, ah
	add	si, 8
	mov	[si], eax
	call	PokeShortAX
	movzx	eax, dx
	mov	[si-4], eax
	ret


codeword	<at>, NORMAL
	mov	dl,[si-4]
	mov	dh,[si]
	sub	si, 8
	mov	bh, 0
	mov	ah,2
	int	10h
	ret

codeword	<setStream>, NORMAL ;	( streamID - )
	invoke	pSetStream, [si]
	sub	si, 4
	ret

codeword 	<emit>, NORMAL
	mov	al, [si]
	sub	si, 4
	jmp	emit_al

codeword	<cr.>, NORMAL, cr_dot; crNoFlush
	mov	al, 0dh
	call	emit_al
	mov	al, 0ah
	jmp	emit_al

codeword	<cr>, NORMAL; cr with flush of output buffer
	call	___cr_dot
	call	pOutFlush
	ret

codeword	<space>, NORMAL
	mov	al, ' '
	jmp	emit_al

codeword	<spaces>, NORMAL
	mov	cx,[si]
	sub	si, 4
	and	cx,cx
	je	end_spaces
space_out:
	mov	al, ' '
	call	emit_al
	loop	space_out
end_spaces:
	ret

codeword	<type>, NORMAL
	mov	cx, [si]
	mov	ebx, [si-4]
	sub	si, 8
	cmp	cx, 0
	je	end_type
put_chars:
	mov	al, [ebx]
	call	emit_al
	inc	ebx
	loop	put_chars
end_type:
	ret

codeword	<ntype>, NORMAL
	movzx	eax, word ptr [si]
	mov	cx, [si-4]
	sub	si, 8
	mov	ebx,[si]
	cmp	cx, ax
	jbe	within
	mov	cx, ax
within:
	sub	ax, cx
	mov	[si], eax
	and	cx, cx
	je	no_print
	call	put_chars
no_print:
	jmp	___spaces
	
codeword	<es:type>, NORMAL, es_type
	mov	cx, [si]
	mov	ebx,[si-4]
	sub	si, 8
	and	cx,cx
	je	end_type
	mov	ah, 2
esput_ch:
	mov	al, es:[ebx]
	call	emit_al
	inc	ebx
	loop	esput_ch
	ret

codeword	<es:ztype>, NORMAL, es_ztype
	mov	ebx,[si-4]
	mov	dh, [si]
	xor	ecx, ecx
zt1:	mov	al, es:[bx]
	inc	bx
	inc	cx
	cmp	al, dh
	je	zt3
	cmp	al, 0
	jne	zt2
	xor	bx, bx
	jmp	short zt3
zt2:
	call	emit_al
	jmp	zt1
zt3:	mov	[si-4], ebx
	mov	[si], ecx
	ret

codeword	<count>, NORMAL
	mov	ebx, [si]
	inc	dword ptr [si]
	movzx	eax, byte ptr [ebx]
	jmp	PushEAX

codeword	<an.>, NORMAL, alphanumprint
	mov	ax, [si]
	and	ax, 127			; @_literal, 127, @and
	.if	ax < 32			;  @dup, @_literal, 32, @lt
	  mov	ax, '.'			; @_if, not_dot, @drop, @_literal, 46
	.endif
	mov	[si], ax
	jmp	___emit			; not_dot	dw	@emit, @exit

codeword	<nibble.>, NORMAL, nibbledot
	mov	ax,[si]
	sub	si, 4
	jmp	FORTHnibbleprint

codeword	<byte.>, NORMAL, bytedot
bprint:	mov	ax,[si]
	sub	si, 4
	jmp	FORTHbyteprint

codeword	<word.>, NORMAL, worddot
wprint:	jmp	wprint2

codeword	<dword.>, NORMAL, dworddot
;dwprint:
	mov	ax, [si+2]
	call	FORTHhexprint
wprint2:
	mov	ax,[si]
	sub	si, 4
	jmp	FORTHhexprint

codeword	<hex.>, NORMAL, FORTHhexdot
print:
	call	___dworddot
	mov	al, 20h
	jmp	emit_al

codeword	<hexc.>, NORMAL, hexcdot
pr_byte:
	mov	ax,[si]
	mov	word ptr [si],20h
	call	FORTHbyteprint
	jmp	___emit

FORTHdhexprint::	public	FORTHdhexprint
	push	ebx
	push	eax
	pop	bx
	pop	ax
	call	FORTHhexprint
	mov	ax, bx
	call	FORTHhexprint
	pop	ebx
	ret

FORTHhexprint::	public	FORTHhexprint
	push	ax
	mov	al,ah
	call	FORTHbyteprint
	pop	ax
FORTHbyteprint::	public	FORTHbyteprint
	push	ax
	shr	al, 1
	shr	al, 1
	shr	al, 1
	shr	al, 1
	call	FORTHnibbleprint
	pop	ax
FORTHnibbleprint:
	and	al, 0fh
	add	al,30h
	cmp	al,'9'
	jle	decimal
	add	al,7
decimal:
	jmp	emit_al


codeword	<DOSpad>, NORMAL
	mov	ax, offset	ds:DOSpad_start
	jmp	PushShortAX

codeword	<!<#>, NORMAL, open_hash
	mov	DOSpad_point, offset DOSpad_stop
	mov	DOSpad_stop, 0
	ret

codeword	<#>, NORMAL, hash
	mov	ax,[si+2]	; does two 16-bit divisions
	xor	dx, dx
	div	base
	mov	[si+2], ax
	mov	ax,[si]
	div	base
	mov	[si], ax
	add	dl,'0'
	cmp	dl,'9'
	jle	pad_digit
	add	dl,7
pad_digit:
	mov	bx, DOSpad_point
	dec	bx
	mov	[bx],dl
	mov	DOSpad_point,bx
	ret

codeword	<#!>>, NORMAL, hash_close
	movzx	ebx, word ptr ds:DOSpad_point
	mov	[si], ebx
	mov	ax, offset ds:DOSpad_stop
	sub	ax, bx
	call PushShortAX
	ret

codeword	<n#>, NORMAL, nhash
	mov	cx, [si]
	sub	si, 4
	.while	cx
	  dec	cx
	  call	___hash
	  .if	dword ptr [si]==0
	    .break
	  .endif
	.endw

	.if	cx
	  mov	al, FieldFill
	  .repeat
	    dec	bx
	    mov	[bx], al
	  .untilcxz
	  mov	DOSpad_point, bx
	.endif
	ret

codeword	<#s>, NORMAL, hashes
	call	___hash
	mov	ax, [si]
	or	ax, [si+2]
	jne	___hashes
	ret

codeword	<hold>, NORMAL
	mov	al, [si]
	sub	si, 4
qhold:
	dec	DOSpad_point
	mov	bx, DOSpad_point
	mov	[bx], al
	ret

codeword	<-hold>, NORMAL, minushold
	mov	ax, [si]
	sub	si, 4
	add	ds:DOSpad_point, ax
	ret

codeword	<n$hold>, NORMAL
	movzx	cx, byte ptr [si]
	sub	si, 4
	mov	bx, [si]
_n$hold:
	sub	si, 4
	push	si
	mov	si, DOSpad_point
	movzx	ax, byte ptr [bx]
	.if	cx>ax
	  add	bx, ax
	.else
	  add	bx, cx
	.endif
	.repeat
	  dec	si
	  .if	al==0
	    mov	byte ptr [si], ' '
	  .else
	    mov	ah, [bx]
	    mov [si], ah
	    dec	al
	    dec	bx
	  .endif
	.untilcxz
	mov	DOSpad_point, si
	pop	si
	ret


codeword	<$hold>, NORMAL
	mov	bx, [si]
	mov	cl, [bx]
	xor	ch, ch
	jmp	_n$hold


codeword	<sign>, NORMAL
	mov	bx, DOSpad_point
	.if	sword ptr [si+2]<0
	  assume bx:ptr byte
	  .if	[bx]!=' '
	    dec	bx
	    mov	DOSpad_point, bx
	  .else
	    .while [bx+1]==' '
	      inc bx
	    .endw
	  .endif
	  mov	[bx], '-'
;	.else
;	  dec	bx
;	  mov	DOSpad_point, bx
;	  mov	[bx], ' '
	.endif
	sub	si, 4
	ret
	assume	bx:nothing

codeword	<ltoa>, NORMAL
	invoke		ltoa, [si-12], [si-8], [si-4], [si]
	sub	si, 16
	ret
	
codeword	<format>, NORMAL    ; ( formatstring - address, count )
	push	edi
	mov	edi, [si]	; point to format string
	sub	si, 4
	movzx	ecx, byte ptr [edi]	; format string length
	inc	edi
	add	edi, ecx		; point to end of format string
	mov	DOSpad_point, offset DOSpad_stop

	.while	cx
		push	cx
		dec	edi
		mov	al, [edi]
		.if	al=='%'
			push	edi
			.if	byte ptr [edi+1]=='0'
				mov FieldFill, '0'
			.else
				mov FieldFill, ' '
			.endif
			add	si, 8

			mov	dword ptr [si-4], 0
			mov	[si], edi
			call	___convert
			mov	ax, [si-4]
			mov	FieldWidth, ax

			xchg	edi, [si]
			mov	al, [edi]
			xchg	edi, [si]
			.if	al=='.'
				mov	word ptr [si-4], 0
				call	___convert
				mov	ax, [si-4]
				mov	FieldPrecision, ax
			.else
				mov	FieldPrecision, 4
			.endif

			mov	eax, edi
			mov	edi, [si]
			sub	eax, edi		; number of digits used to specify width
			neg	eax
			mov	FieldDigits, ax

		   mov	al, [edi]
			sub	si, 8							; value is again TOS

		   .if	(al=='l')||(al=='d')

				mov	ax, FieldDigits
				add	DOSpad_point, ax
				.if	sword ptr [si+2]<0
				  neg	dword ptr [si]
				  pushd	-1
				.else
				  pushd	0
				.endif
				movzx	eax, FieldWidth
				.if	ax
					add	si, 4
					mov	[si], eax
					call	___nhash
				.else
				  call	___hashes
				.endif
				; sub	si, 4
				pop	dword ptr [si]
				call	___sign

		   .elseif al=='f'

				mov	ax, FieldDigits
				add	DOSpad_point, ax		; real4 value is on TOS
				
				movzx	eax, FieldWidth
				.if	!ax
				  mov	ax, 8			; width=8 as default
				.endif
				add	si, 8
				mov	[si-4], eax		; width
				movzx	eax, FieldPrecision
				mov	dword ptr [si], eax
				call	___ftopad
				dec	word ptr [si-4]
				call	___n$hold


		   .elseif al=='x'

				push	base
				mov	base, 16
				call	FormatWord
				pop	base

		   .elseif al=='b'

				push	base
				mov	base, 2
				call	FormatWord
				pop	base

		   .elseif al=='s'

				mov	ax, FieldDigits
				add	DOSpad_point, ax
				movzx	eax, FieldWidth
				.if	ax
					add	si, 4
					mov	[si], eax
					call	___n$hold
				.else
				  call	___$hold
				.endif
		   .elseif al=='c'
				inc	DOSpad_point
				call	___hold
		   .else
				.if al=='>'		; symbol for TAB
					mov	al, TAB
				.endif
				mov	bx, DOSpad_point
				inc	bx
				movzx	cx, byte ptr FieldWidth
				.if	(!cx)||(cx>80)
					mov	cx, 1
				.endif
				
				.repeat
					dec	bx
				   .if al=='<'		; symbol for CRLF
						mov	byte ptr [bx], LF
						dec	bx
						mov	byte ptr [bx], CR
					.else
						mov	byte ptr [bx], al
					.endif
				.untilcxz
				mov	DOSpad_point, bx
		   .endif

		   pop	edi	; restore format string ptr

	  .else	; not '%'
		call qhold
	  .endif
	  pop	cx
	  dec	cx
	.endw

;	add	si, 2
;	mov	ax, FieldDigits		; for debugging
;	mov	[si], ax

	movzx	ebx, word ptr DOSpad_point
	mov	ax, offset DOSpad_stop
	sub	ax, bx
	dec	ebx
	mov	[bx], al
	add	si, 4
	mov	[si], ebx
	pop	edi
	ret

FormatWord:
		mov	ax, FieldDigits
		add	DOSpad_point, ax
		mov	ax, [si]
		add	si, 4
		mov	word ptr [si], 0
		mov	ax, FieldWidth
		.if	ax
			add	si, 4
			mov	[si], ax
		 	call	___nhash
		.else
		 	call	___hashes
		.endif
		sub	si, 8
		ret

FieldWidth	dw	0
FieldPrecision dw 0
FieldDigits	dw	0
FieldFill	db	' '

codeword	<d.>, NORMAL, dprint
	call	___rdup
	call	___dabs
	call	___open_hash
	mov	ax,20h
	call	qhold
	call	___hashes
	call	___r_to
	call	___sign
	call	___hash_close
	jmp	___type

codeword	<u.>, NORMAL, uprint
	jmp	___dprint

codeword	<.>, NORMAL, sprint
	jmp	___dprint

codeword	<sound>, NORMAL	; ( frequency - )

	mov     bx,  [si]
	sub	si, 4
	invoke	Tone, bx, -1		; -1 means continuous tone
	ret


codeword	<nosound>, NORMAL	; ( - )

	in      al, 61H
	and     al, 0fcH
	out     61H, al
	ret

codeword	<beep>, NORMAL	; ( frequency, duration - )
	
	invoke	Tone, [si-4], [si]
	sub	si, 8
	ret

codeword	<whoop>, NORMAL	; (  word: pitch word: duration word: slew )

	.repeat
		invoke	Tone, word ptr [si-8], 20
		mov	ax, word ptr [si-8]	;pitch
		imul	word ptr [si]	;slew
		add	word ptr [si-8], dx
		sub	word ptr [si-4], 20	;duration
	.until carry?
	sub	si, 12
	jmp	___nosound

codeword	<Note>, NORMAL	; ( note, duration - )

	mov	bx, [si]
	sub	si, 8
	mov	ax, [si+4]
	invoke	PlayNote, ax, bx
	ret

codeword	<Bach>, NORMAL
	mov	ax, offset	_TEXT:BachAir
	call	PushShortAX
	mov	ax, cs
	jmp	PushShortAX
	
codeword	<PlayTune>, NORMAL
	  invoke PlayTune, dword ptr [si-8], [si]
	  sub	si, 12
	  ret


% lastDispLink =   _link&lastLink

public  lastDispLink

forth_disp   endp

_TEXT	ends

end

