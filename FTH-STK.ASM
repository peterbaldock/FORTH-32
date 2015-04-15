comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-STK.ASM	:	Forth stack routines

21-02-96 Version 1.00	:	

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


extern      lastPktLink:abs
% _link100  equ lastPktLink

    thisLink textequ <101>
    lastLink textequ <100>

forth_stk	proc    near

Code_word	<dup>, NORMAL
	mov	eax, dword ptr [si]
	add	si, 4
	mov	[si], eax
	ret

Code_word	<?dup>, NORMAL
	cmp	dword ptr [si], 0
	jne	___dup
	ret

Code_word	<ndup>, NORMAL	; ( n - W(n), W(n-1)... W(1) )

	assume	cx:sword
	mov	bx, [si]
	mov	cx, bx
	add	bx, bx
	add	bx, bx
	neg	bx
	.if	cx>0
	  .repeat
	    mov	eax, [si+bx]
	    mov	[si], eax
	    add	si, 4
	  .untilcxz
	.endif
	sub	si, 4
	ret
	assume	cx:nothing

Code_word	<nip>, NORMAL
	mov	eax, [si]
	sub	si, 4
	mov	[si], eax
	ret

Code_word	<swap>, NORMAL
	mov	eax, [si]
	xchg	eax, [si-4]
	mov	[si], eax
	ret

Code_word	<drop>, NORMAL
	sub	si, 4
	ret

Code_word 	<rot>, NORMAL
	mov	eax,[si-8]
	xchg	eax, [si]
	xchg	eax, [si-4]
	xchg	eax, [si-8]
	ret

Code_word 	<-rot>, NORMAL, brot
	mov	eax, [si]
	xchg	eax, [si-8]
	xchg	eax, [si-4]
	xchg	eax, [si]
	ret

Code_word 	<roll>, NORMAL
	mov	cx, [si]
	sub	si, 4
	.if	cx > 0
	  mov	bx, cx
	  shl		bx, 2
	  neg	bx
	  mov	eax, [si]
	  .repeat
		xchg	eax, [si+bx]
		add	bx, 4
	  .untilcxz
	.endif
	ret

Code_word	<pick>, NORMAL

	mov	bx, [si]
	inc	bx
	shl	bx, 2
	neg	bx
	mov	eax, [si+bx]
	mov	[si],  eax
	ret


Code_word 	<over>, NORMAL
	mov	eax, [si-4]
	add	si, 4
	mov	[si], eax
	ret

Code_word	<2drop>, NORMAL
	sub	si, 8
	ret

Code_word	<2dup>, NORMAL
	mov	eax, dword ptr [si]
	add	si, 8
	mov	[si], eax
	mov	eax, dword ptr [si-12]
	mov	[si-4], eax
	ret

Code_word	<2swap>, NORMAL
	mov	eax, [si]
	xchg	ax, [si-8]
	mov	[si], eax
	mov	eax, [si-4]
	xchg	ax, [si-12]
	mov	[si-4], eax
	ret

Code_word	<2over>, NORMAL
	mov	eax, dword ptr [si-8]
	add	si, 8
	mov	[si], eax
	mov	eax, dword ptr [si-20]
	mov	[si-4], eax
	ret

Code_word	<fdup>, NORMAL
	jmp	___dup

Code_word	<fdrop>, NORMAL
	sub	si, 4
	ret

Code_word	<ndrop>, NORMAL
	mov	ax, [si]
	inc	ax
	shl	ax, 2
	sub	si, ax
	ret


Code_word	<fover>, NORMAL
	jmp	___over

Code_word	<reverse>, NORMAL ; ( w[1], .. w[n], n - w[n], .. w[1] )
	mov	cx, [si]
	dec	cx
	shl	cx, 2
	sub	si, 4

	push	si
	mov	bx, si
	sub	bx, cx
	mov	cx, 4
	
	.while	bx<si
	
		mov	eax, [si]
		mov	edx, [bx]
		mov	[bx], eax
		mov	[si], edx
		
		add	bx, cx
		sub	si, cx
		
	.endw
	pop	si
	ret
	
	
Code_word	<freverse>, NORMAL ; ( f[1], .. f[n], n - f[n], .. f[1] )
	jmp	___reverse

comment #

	mov	cx, [si]
	dec	cx
	shl	cx, 2
	dec	si
	dec	si
	push	si
	dec	si
	dec	si
	mov	bx, si
	sub	bx, cx
	mov	cx, 4
	
	.while	bx<si
	
		mov	eax, [si]
		mov	edx, [bx]
		mov	[bx], eax
		mov	[si], edx
		
		add	bx, cx
		sub	si, cx
		
	.endw
	pop	si
	ret
#

Code_word	<!&r>, NORMAL, rstack_address
	mov	ax, sp
	jmp	PushShortAX
	
Code_word	<!&r0>, NORMAL, rstack_top
	mov	ax, offset	StackTop
	jmp	PushShortAX

Code_word	<!>r>, NORMAL, to_r
	pop	ax
	push	dword ptr [si]
	sub	si, 4
	jmp	ax


Code_word	<2!>r>, NORMAL, 2to_r
	pop	ax
	push	dword ptr [si]
	push	dword ptr [si-4]
	sub	si, 8
	jmp	ax

Code_word	<f!>r>, NORMAL, fto_r
	jmp	___to_r


Code_word	<r!>>, NORMAL, r_to
	pop	ax
	add	si, 4
	pop	dword ptr [si]
	jmp	ax

Code_word	<2r!>>, NORMAL, 2r_to
	pop	ax
	add	si, 8
	pop	dword ptr [si-4]
	pop	dword ptr [si]
	jmp	ax

Code_word	<fr!>>, NORMAL, fr_to
	jmp	___r_to

Code_word	<rdup>, NORMAL
	pop	ax
	push	dword ptr [si]
	jmp	ax

Code_word	<2rdup>, NORMAL
	pop	ax
	pushd	dword ptr[si]
	pushd	dword ptr[si-4]
	jmp	ax

Code_word	<rdrop>, NORMAL
	retn	4

Code_word	<r>, NORMAL
	pop	ax
	add	si, 4
	pop		dword ptr [si]
	pushd	dword ptr [si]
	jmp	ax

Code_word	<i>, NORMAL
	pop	ax	;	return address
	add	si, 4
	pop	dword ptr [si]
	push dword ptr	[si]
	jmp	ax
		
;Code_word	<wi>, NORMAL	;; leaves just a 16-bit value on stack
;	pop	ax	;	return address
;	inc	si
;	inc	si
;	pop	[si]
;	push	[si]
;	jmp	ax

;Code_word	<xi>, NORMAL
;	pop	ax	;	return address
;	inc	si
;	inc	si
;	pop	[si]
;	push	[si]
;	inc	si
;	inc	si
;	mov	word ptr [si], 0
;	jmp	ax
;
Code_word	<2i>, NORMAL, _2i
	jmp	___i

Code_word	<i''>, NORMAL, i_dash
	add	si, 4
	push	bp
	mov	bp, sp
	mov	eax, [bp+8]
	mov	[si], eax
	pop	bp
	ret

Code_word	<j>, NORMAL
	add	si, 4
	push	bp
	mov	bp,sp
	mov	eax,[bp+12]
	mov	[si], eax
	pop	bp
	ret

StackMessage	db ' : Warning! Data stack depth = ',0

Code_word <stackCheck>, NORMAL; address: msg


	.if	si<=spStart
		call	___count
		call	___type
		xor	eax, eax
		mov	ax, offset cs:StackMessage
	  
		invoke	PrintString, eax, cs

		mov	ax, si
		sub	ax, spStart
		sar	ax, 1
		call	___sprint
		call	___cr
	.else
		sub	si, 4
	.endif
	ret

;

% lastStkLink =   _link&lastLink

public  lastStkLink

forth_stk   endp

_TEXT	ends

end

