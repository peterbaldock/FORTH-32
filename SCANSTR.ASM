comment#========================================================================


23-05-92 Version 2.00
24-05-93 Version 3.00	-	incorporated into BC C++

28-08-93 Version 3.15	returns CTRL-Z as default on all commands (as original Version 2.xx)


================================================================================#
	option language:c

	include	..\include\step.inc
	include	..\include\fp.inc

_FORTH_DATA	segment
	wptr1		dw	0
	parameterArray	db	16 dup(0)
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	ds:_FORTH_DATA


comment #
;*****************************************************************

check_ready	proc near

;*****************************************************************

	.if !(stepping_mode & NO_WAIT)
	  sti
@@:	  mov	ax, stepping_status
	  test	ax, STEPPING
	  jz	@F
	  call	key_press?
	  jnc	@B
	  mov	byte ptr stepping_status, al
	  jmp	@B

@@:	  mov	byte ptr stepping_status, 0
	  xor	ah, ah
	.endif
	ret

check_ready endp
#


;*****************************************************************

find_command	proc		; si->text, di->command list, cx is length

;*****************************************************************
	sub	ch,ch
	cld
	.while	byte ptr [di]!=0
	  .if	cl==[di]

		push	di
		push	si
		push	cx



@@:		lodsb			; direction set before start of .while
		inc	di
		cmp	al,[di]
		loope	@B
		pop	cx
		.if	zero?		; match found
		  add	sp,2
		  pop	ax
		  clc
		  inc	di
		  jmp	fc_exit
		.endif
		pop	si
		pop	di
	  .endif
	  mov	al,[di]
	  sub	ah,ah
	  add	di,ax
	  mov	al,[di+1]
	  add	al,4
	  add	di,ax
	.endw
	sub	ax,ax
	stc
fc_exit:
	ret

find_command	endp


;*****************************************************************

parameter_load	proc C, param_ptr:word

		; si points to source text
		; di points to parameter type ('dulxf')

;*****************************************************************


find_number:
	call	?digit
	.if	!zero?
	  .if	al==0		; is it EOL ?
		mov	ah,al	; ax=0
		jmp	pl_exit
	  .endif
	  inc	si		; otherwise point to next character
	  jmp	find_number
	.endif

	mov	al,[di]		; get argument type expected

	.if	(al=='u')||(al=='d')
	  call	asc_bin_convert
	  .if	!carry?
	    mov	bx, param_ptr
	    mov	[bx],ax
	    mov	ax, 2		; indicate number of bytes written
	  .else
	    sub	ax, ax		; zero bytes written
	  .endif
	  jmp	pl_exit
	.endif

	.if	(al=='l')
	  call	asc_bin_convert
	  .if	!carry?
	    mov	bx, param_ptr
	    mov	[bx], eax
	    mov	ax, 4		; indicate number of bytes written
	  .else
	    sub	ax, ax		; zero bytes written
	  .endif
	  jmp	pl_exit
	.endif

	.if	(al=='f')
	  invoke atof, si
	  .if	!carry?
	    mov	bx, param_ptr
	    mov	dword ptr [bx], eax
	    mov	ax,4		; 4 bytes for float
	  .else
	    xor	ax, ax
	  .endif
	.else
	  sub	ax,ax
	.endif


pl_exit:
	cmp	ax,1		; set carry if ax==0
	ret

parameter_load	endp

;*****************************************************************


comment\
*****************************************************************

	IDENTIFY CHARACTER IN [SI] AS 'A'-'Z','a'-'z','_' or '/'

	Inputs:	-	SI -> char

	Outputs:-	Zero flag set if letter.
			Lower case converted to upper case in [SI]

			Zero flag clear if not a letter

*****************************************************************
\

?letter	proc

	mov	al, [si]	; si points to text
	cmp	al,'_'
	je	is_letter
	cmp	al,'/'
	je	is_letter
	cmp	al,41h
	jl	not_letter
	cmp	al,5bh
	jl	is_letter
	cmp	al,61h
	jl	not_letter
	cmp	al, 7ah
	jg	not_letter
	sub	al,20h
	mov	[si], al	; convert letter from lower to upper case
is_letter:
	cmp	al, al
not_letter:
	ret

?letter	endp

comment\
******************************************************************

	IDENTIFY CHARACTER IN [SI] AS DIGIT '0'-'9'' OR '-'

	Inputs:	-	[SI] ->character

	Outputs:-	Zero flag set if char is 0,1..8,9 or -
			Zero flag clear if char is not.
			AL contains character on return.

******************************************************************
\

?digit	proc

	mov	al,[si]
	cmp	al,'-'
	je	is_digit
	cmp	al,'.'
	je	is_digit
	cmp	al,'0'
	jl	not_digit
	cmp	al,'9'
	jg	not_digit
is_digit:
	cmp	al,al	;	set Zero flag
not_digit:
	ret

?digit	endp

comment\
******************************************************************

	ASCII TO BINARY CONVERSION ROUTINE

	Inputs:	-	DS:SI -> ASCII string

	Outputs:-	DS:SI -> first bad character
		-	C=0	 EAX contains long signed binary result
		-	C=1	 Error:	EAX = 0	-	no number
					EAX =-1	-	out of range

******************************************************************
\
ten	dw	10

asc_bin_convert	proc

	push	ecx

	.while	(byte ptr [si]==' ')||(byte ptr [si]==09)
	  inc	si
	.endw

	cmp	byte ptr [si],'-'
	pushf
	.if	zero?
	  inc	si
	.endif
	xor	eax, eax
	mov	ecx, 100h

conv_loop:
	mov	cl,[si]
	sub	cl,'0'
	jl	bad_digit
	cmp	cl,9
	jg	bad_digit
	xor	ch,ch
	imul	eax, 10
	add	eax, ecx
	btr	eax, 31
	jc	too_big
	inc	si
	jmp	conv_loop

bad_digit:
	cmp	ch,0
	jne	no_number
	popf
	jne	no_negate
	neg	eax
no_negate:
	pop	ecx
	clc
	ret

too_big:
	mov	eax,-1
no_number:
	popf
	pop	ecx
	stc
	ret

asc_bin_convert	endp

comment\
******************************************************************

	BINARY TO ASCII CONVERSION ROUTINE

	Inputs:	-	DS:BX -> start of string buffer
		-	AX=Binary data.

	Outputs:-	DS:BX -> one before first char position

******************************************************************
\
powers	dd	1000000000
	dd	100000000
	dd	10000000
	dd	1000000
	dd	100000
	dd	10000
	dd	1000
	dd	100
	dd	10
	dd	1
	dd	0

bin_asc_convert	proc C uses si, dest:word, val:dword

	mov	eax, val
	mov	bx, dest
	xor	si, si
	cmp	eax,0
	jge	not_minus
	neg	eax
	mov	byte ptr [bx], '-'
	inc	bx
not_minus:
	cmp	eax, powers[si]
	jge	startdiv
	add	si, 4
	cmp	si, 36
	jl	not_minus

startdiv:
	xor	edx, edx
	div	powers[si]
	add	al,'0'
	mov	[bx], al
	inc	bx
	mov	eax, edx
	add	si, 4
	cmp	si,40
	jne	startdiv
	mov	byte ptr [bx], 0
	ret

bin_asc_convert	endp

_TEXT	ends


end
