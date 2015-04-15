comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-ALU.ASM	:	Forth arithmetic and logic functions

21-02-96 Version 1.00	:
03-12-98 Version 2.11	:	ftol fixed for f<1.5; 0< gives TRUE=-1
2002-08-29 Version 2.64 :	f*, f/, f+, f- and pi using FP processor only
2005-04-08 Verion 3.20	:	interpolate and f<, f<0 added for XYZV MoveTo correction
================================================================================#

option language:c

include forthmac.asm
include ..\include\pcatkeys.inc
include	..\include\serial.inc
include ..\include\forth.inc
include ..\include\fp.inc
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


extern      lastMemLink:abs
;externdef  _vocabulary:near
% _link300  equ lastMemLink

    thisLink textequ <301>
    lastLink textequ <300>

forth_alu	proc    near

	assume	si:ptr dword

codeword	<0>, NORMAL, zero
	xor	eax, eax
	jmp	PushEAX

;codeword	0w, NORMAL
;	xor	eax, eax
;	jmp	PushEAX


;codeword	1w, NORMAL
;	xor	eax, eax
;	inc	ax
;	jmp	PushEAX

codeword	1, NORMAL
	xor	eax, eax
	inc	ax
	jmp	PushEAX

;codeword	2w, NORMAL
;	xor	eax, eax
;	inc	ax
;	inc	ax
;	jmp	PushEAX

codeword	2, NORMAL
	xor	eax, eax
	inc	ax
	inc	ax
	jmp	PushEAX

;codeword	<-1w>, NORMAL, minus_1w
;	xor	eax, eax
;	dec	eax
;	jmp	PushEAX

codeword	<-1>, NORMAL, minus_1
	xor	eax, eax
	dec	eax
	jmp	PushEAX

codeword	<1+>, NORMAL, inc1
	inc	dword ptr [si]
	ret

codeword	<1->, NORMAL, dec1
	dec	dword ptr [si]
	ret

codeword	<2+>, NORMAL, inc2
	inc	dword ptr [si]
	inc	dword ptr [si]
	ret

codeword	<2->, NORMAL, dec2
	dec	dword ptr [si]
	dec	dword ptr [si]
	ret

codeword	<4+>, NORMAL, inc4
	add	dword ptr [si], 4
	ret

codeword	<4->, NORMAL, dec4
	sub	dword ptr [si], 4
	ret

codeword	<8+>, NORMAL, inc8
	add	dword ptr [si], 8
	ret

codeword	<8->, NORMAL, dec8
	sub	dword ptr [si], 8
	ret

;codeword	<d1+>, NORMAL, dinc1
;	inc	dword ptr [si]
;	ret

;codeword	<d1->, NORMAL, ddec1
;	dec	dword ptr [si]
;	ret

;codeword	<d2+>, NORMAL, dinc2
;	add	dword ptr [si], 2
;	ret

;codeword	<d2->, NORMAL, ddec2
;	sub	dword ptr [si],2
;	ret

;codeword	<d4+>, NORMAL, dinc4
;	add	dword ptr [si], 4
;	ret

;codeword	<d4->, NORMAL, ddec4
;	sub	dword ptr [si], 4
;	ret

codeword	<2*>, NORMAL, times2
	shl	dword ptr [si], 1
	ret

codeword	<2*!!>, NORMAL, times2_store
	mov	ebx, [si]
	sub	si, 4
	shl	dword ptr [ebx], 1
	ret
	
codeword	<4*>, NORMAL, times4
	shl	dword ptr [si], 2
	ret

codeword	<8*>, NORMAL, times8
	shl	dword ptr [si], 3
	ret

codeword	<2/>, NORMAL, slash2
	sar	dword ptr [si], 1
	ret

codeword	<4/>, NORMAL, slash4
	sar	dword ptr [si], 2
	ret

codeword	<8/>, NORMAL, slash8
	sar	dword ptr [si], 3
	ret

codeword	<2^>, NORMAL, power2
	xor	eax, eax
	xchg	eax, [si]
	bts	[si], eax
	ret

codeword	<+>, NORMAL, plus
	mov	eax, [si]
	sub	si, 4
	add	dword ptr [si], eax
	ret

codeword	<wsplit>, NORMAL
	push	[si]
	xor	eax, eax
	pop	ax
	mov	[si], eax
	pop	ax
	jmp	PushEAX

codeword	<bsplit>, NORMAL
	push	[si]
	xor	eax, eax
	pop	bx
	mov	al, bl
	mov	[si], eax
	mov	al, bh
	call	PushEAX
	pop	bx
	mov	al, bl
	call	PushEAX
	mov	al, bh
	jmp	PushEAX

;codeword	<d+>, NORMAL, dplus
;	jmp	___plus

codeword	<->, NORMAL, minus
	mov	eax, [si]
	sub	si, 4
	sub	[si], eax
	ret

codeword	<d->, NORMAL, dminus
	jmp	___minus

;codeword	<w->, NORMAL, wminus
;	jmp	___minus

codeword	<c->, NORMAL, cminus
	mov	al, byte ptr [si-4]
	sub	al, byte ptr [si]
	cbw
	cwde
	sub	si, 4
	mov	[si], eax
	ret

codeword	<over+>, NORMAL, over_plus
	mov	eax, [si-4]
	add	[si], eax
	ret

codeword	<w++>, NORMAL, wplus_plus
	mov	ebx, [si]
	inc	word ptr [ebx]
	sub	si, 4
	ret

codeword	<++>, NORMAL, plus_plus
	mov	ebx, [si]
	inc	dword ptr [ebx]
	sub	si, 4
	ret

codeword	<d++>, NORMAL, dplus_plus
	jmp	___plus_plus

codeword	<w-->, NORMAL, wminus_minus
	mov	ebx, [si]
	dec	word ptr [ebx]
	sub	si, 4
	ret

codeword	<-->, NORMAL, minus_minus
	mov	ebx, [si]
	dec	dword ptr [ebx]
	sub	si, 4
	ret

codeword	<d-->, NORMAL, dminus_minus
	jmp	___minus_minus

codeword	<+!!>, NORMAL, plus_store
	mov	ebx,[si]
	mov	eax,[si-4]
	add	[ebx], eax
	sub	si, 8
	ret

codeword	<d+!!>, NORMAL, dplus_store
	jmp	___plus_store

codeword	<over->, NORMAL, over_minus
	mov	eax,[si-4]
	sub	[si], eax
	ret

codeword	<swap->, NORMAL, swap_minus
	mov	eax, [si]
	sub	si, 4
	sub	eax, [si]
	mov	[si], eax
	ret

codeword	<-!!>, NORMAL, minus_store
	mov	ebx,[si]
	mov	eax,[si-4]
	sub	[ebx], eax
	sub	si, 8
	ret

codeword	<negate>, NORMAL
	neg	dword ptr [si]
	ret

codeword	<dnegate>, NORMAL
	neg dword ptr [si]
	ret

codeword	<abs>, NORMAL
	cmp	word ptr [si+2], 0
	jge	same_sign
	neg	dword ptr [si]
same_sign:
	ret

codeword	<dabs>, NORMAL
	jmp	___abs

codeword	<cbw>, NORMAL
	movsx	eax, byte ptr [si]
	mov	[si], eax
	ret

codeword	<cwbb>, NORMAL
	movzx	eax, word ptr [si]
	and	dword ptr [si], 0ffh
	shr	ax, 8
	jmp	PushShortAX

codeword	<cwd>, NORMAL
	mov	ax, word ptr [si]
	cwde
	mov	dword ptr [si], eax
	ret

codeword	<*>, NORMAL, star
	mov	eax,[si]
	sub	si, 4
	imul	dword ptr [si]
	mov	[si], eax
	ret

codeword	<m*>, NORMAL, mstar
	mov	eax,[si]
	imul	dword ptr [si-4]
	mov	[si], edx
	mov	[si-4], eax
	ret

codeword	<d*>, NORMAL, dstar
	jmp	___star

codeword	<w/>, NORMAL, wslash

	call	div16
	sub	si, 4
	jmp	PokeShortAX

codeword	</mod>, NORMAL, slashmod
	mov	ebx, [si]
	.if	!ebx
	  jmp   z_err
	.endif
	mov	eax, [si-4]
	cdq
	idiv	ebx
	mov	[si-4], edx
	mov	[si], eax
	ret

codeword	<w/mod>, NORMAL, wslashmod
	call	div16
	call	PokeShortAX
	movzx	eax, dx
	mov	[si-4], eax
	ret

div16:
	mov	bx, word ptr [si]
	and	bx, bx
	je	z_err
	xor	dx, dx
	mov	ax, word ptr [si-4]
	bt	ax, 15
	jnc	@F
	dec	dx
@@:     idiv	bx
	ret

z_err:	mov	ax, ERR_DIVIDE
	call	FORTHabort
	db	' : Attempted divide by zero', 0

codeword	<w*/>, NORMAL, wstarslash

	mov	bx, word ptr [si]
	and	bx,bx
	je	z_err

	sub	si, 8
	mov	ax, word ptr [si+4]
	imul	word ptr word ptr [si]
	idiv	bx
	jmp	PokeShortAX


make_digit::
	sub	cl,'0'
	jc	not_digit

	.if	cl>9
		and	cl, not 20h ; ignore case
		sub	cl, 11h
		jc	not_digit
		add	cl, 10
	.endif

numeral:
	.if	cl< byte ptr base
	  clc
	  xor	ch, ch
	  ret
	.endif
	
not_digit:
	xor	cl,cl
	stc
	ret

codeword	</>, NORMAL, slash
	mov	ebx, [si]
	.if	!ebx
	  jmp   z_err
	.endif
	sub	si, 4
	mov	eax, [si]
	xor	edx, edx
	bt	eax, 31
	jnc	@F
	dec	edx
@@:	idiv	ebx
	mov	[si], eax
	ret

codeword	<d/>, NORMAL, dslash
	jmp	___slash

codeword	<isin>, NORMAL

	invoke	LookupIntegerSine, byte ptr [si]
	jmp PokeShortAX

;include padding.asm ; 37 bytes 28B5:crashes


codeword	<rand>, NORMAL
	call	GetRandom16
	jmp	PushShortAX

;codeword	<finit>, NORMAL
;	call	fpinit
;	add	si, 2
;	mov	[si], ax
;	ret

	assume	si:ptr real4

codeword	<f+>, NORMAL, fplus

	fld	[si]
	fadd	[si-4]
	fstp	[si-4]
	fwait
	sub	si, 4
	ret

codeword	<f+!!>, NORMAL, fplusStore

	mov	ebx, dword ptr [si]
	sub	si, 8
	fld	[si+4]
	fadd	real4 ptr [ebx]
	fstp	real4 ptr [ebx]
	fwait
	ret

codeword	<f->, NORMAL, fminus

	fld	[si-4]
	fsub	[si]
	sub	si, 4
	fstp	[si]
	fwait
	ret


codeword	<fnegate>, NORMAL

	xor	word ptr [si+2], 8000h
	ret

codeword	<fabs>, NORMAL

	and	word ptr [si+2], not 8000h
	ret

codeword	<f*>, NORMAL, fmul


	sub	si, 4
	fld	[si+4]
	fmul	[si]
	fstp	[si]
	fwait
	ret


codeword	<f/>, NORMAL, FORTHfdiv

	sub	si, 4
	fld	[si]
	fdiv	[si+4]
	fstp	[si]
	fwait
	ret

codeword	<fsqrt>, NORMAL

	fld	[si]
	fsqrt
	fstp	[si]
	fwait
	ret


codeword	<fcos>, NORMAL, fcos

	fld	[si]
	fcos
	fstp	[si]
	fwait
	ret

codeword	<fsin>, NORMAL, fsin

	fld	[si]
	fsin
	fstp	[si]
	fwait
	ret

codeword	<fatan>, NORMAL, fatan

	fld	[si-4]
	fld	[si]
	fpatan
	sub	si, 4
	fstp	[si]
	fwait
	ret



codeword	<fxtract>, NORMAL, fxtract

	fld	[si]
	fxtract
	add	si, 4
	fwait
	fstp	[si]
	fstp	[si-4]
	ret

codeword	<fexp2>, NORMAL, fexp2

	fld	[si]
__exp2:
	fst	st(2)	; copy over

	frndint	; leaves int value on stack
	fst	st(1)	; dup

	fsubr	st, st(2); fractional part is TOS st(0) <- st(2) - st(0)
	f2xm1
	fld1
	fadd		; now have 2^fract
	fscale

	fstp	[si]
	fwait
	ret

codeword	<fexp>, NORMAL, fexp

	fld		[si]
	fldl2e
	fmul
	jmp	__exp2

codeword	<flog>, NORMAL, flog

	fldln2
	fld	[si]
	fyl2x
	fstp	[si]
	fwait
	ret


codeword	<f!<>, NORMAL, flt

	mov	eax, [si-4]
	mov	ebx, [si]
fcompare:
	sub	si, 4
	xor	cx, cx
	and	eax, eax
	.if	sign?	; first value is negative, so do unsigned integer compare
	  .if	dword ptr eax > ebx
	    mov	cx, -1
	  .endif
	.else		; first value is positive, so do signed integer compare
	  .if	sdword ptr eax < ebx
	    mov	cx, -1
	  .endif
	.endif
	movzx	eax, cx
	mov	[si], eax
	ret

codeword	<f!>>, NORMAL, fgt

	mov	eax, [si]
	mov	ebx, [si-4]
	jmp	fcompare

codeword	<fmax>, NORMAL

	mov	eax, [si]
	sub	si, 4
	and	eax, eax
	.if	sign?
	  .if	dword ptr [si]>eax
	    mov	[si], eax
	  .endif
	.else
	  .if	sdword ptr eax>[si]
	    mov	[si], eax
	  .endif
	.endif
	ret

codeword	<fmin>, NORMAL

	mov	eax, [si]
	sub	si, 4
	and	eax, eax
	.if	sign?
	  .if	dword ptr [si]<eax
	    mov	[si], eax
	  .endif
	.else
	  .if	sdword ptr eax<[si]
	    mov	[si], eax
	  .endif
	.endif
	ret

codeword	<f=>, NORMAL, fequals
	mov	eax, [si]
	sub	si, 4
	sub	eax, [si]
	jmp	check_signed_zero

codeword	<f0=>, NORMAL, fzeroequals
	mov	eax, [si]
check_signed_zero::
	clc
	shl	eax, 1
	.if	zero?
		dec	eax
	.else
		xor	eax, eax
	.endif
	mov	[si], eax
	ret

codeword	<fmean>, NORMAL	; : fmean word: n

	mov	cx, word ptr [si]
	.if	cx
		.if	cx==1
			sub	si, 4
			ret
		.endif
		call	___wtof
		push	dword ptr [si]
		sub	si, 4
		dec	cx
		.repeat
			call	___fplus
		.untilcxz
		add	si, 4
		pop	dword ptr [si]
		jmp	___FORTHfdiv
	.else
		jmp	___dup
	.endif

codeword	<0L>, NORMAL, d0
	jmp	___f0
codeword	<0.0>, NORMAL, f0
	xor	eax, eax
	jmp	PushEAX


codeword	<f0!<>, NORMAL, flt0

	xor	eax, eax
	.if	word ptr [si+2] & 8000h
	  dec	eax
	.endif
	mov	dword ptr [si], eax
	ret

codeword	<f0!>>, NORMAL, fgt0

	xor	eax, eax
	.if	!(word ptr [si+2] & 8000h)
	  dec	eax
	.endif
	mov	dword ptr [si], eax
	ret

codeword	<interpolate>, NORMAL; ( float: value, ptr: table, word: offset)

    sub	si, 2
    .if	word ptr [si]

	push	di
	mov	eax, [si-4]	; value
	mov	di, word ptr [si]; point to table
	mov	dx, [di]	; number of entries
	dec	dx
	add	di, 2		; start of data
	.if	sword ptr [si+2]<0
	  sub	di, word ptr [si+2]
	.endif
	mov	cx, 0		; cx indexes lowest point in table, and dx indexes highest
	mov	bx, dx
	shl	bx, 3

	.if	word ptr [si-2] &8000h	; negative value

	  assume bx: ptr dword
	  assume di: ptr dword

	  .if	eax < [di]		; value is less than first entry
	    mov	word ptr [si], -1	; show not interpolated
	    pop	di
	    ret
	  .endif

	  .if	eax > [di+bx]		; value is outside range of table
	    mov	word ptr [si], -2	; show not interpolated
	    pop	di
	    ret
	  .endif

	  mov	bx, dx
	  add	bx, cx
	  shr	bx, 1			; midpoint between high and low

	  .while bx>cx

	    shl	bx, 3
	    .if	eax<=[di+bx]		; high index can be reduced
	      shr bx, 3
	      mov dx, bx
	      add bx, cx
	    .else
	      shr bx, 3
	      mov cx, bx
	      add bx, dx
	    .endif

	    shr	bx, 1

	  .endw

	.else

	  assume bx: ptr sdword
	  assume di: ptr sdword

	  .if	eax < [di]		; value is less than first entry
	    mov	word ptr [si], 0	; show not interpolated
	    pop	di
	    ret
	  .endif

	  .if	eax > [di+bx]		; value is outside range of table
	    ;mov eax, [di+bx]
	    ;mov word ptr [si-4], di    ; show pointer values
	    ;mov word ptr [si-2], bx
	    mov	word ptr [si], -1	; show not interpolated
	    pop	di
	    ret
	  .endif

	  mov	bx, dx
	  add	bx, cx
	  shr	bx, 1			; midpoint between high and low

	  .while bx>cx

	    shl	bx, 3
	    .if	eax<=[di+bx]		; high index can be reduced
	      shr bx, 3
	      mov dx, bx
	      add bx, cx
	    .else
	      shr bx, 3
	      mov cx, bx
	      add bx, dx
	    .endif

	    shr	bx, 1

	  .endw

	.endif

	; low and high points found - now interpolate between

	; eax contains original value
	; subtract value indicated by cx, then divide this by ([dx]-[cx])

	shl	cx, 3
	add	di, cx
	mov	bx, word ptr [si+2]	; offset for matching value

	fld	[di+bx]		; Y0
	fld	[si-4]
	fld	[di]
	fsub	st(1), st	; V-X0
	fld	[di+8]
	fsubr			; X1-X0
	fdiv		 	; (V-X0)/(X1-X0)

	fld	[di+bx+8]       ; Y1
	fsub	st, st(2)       ; Y1-Y0
	fmul                    ; (Y1-Y0)*(V-X0)/(X1-X0)
	fadd
	fstp	[si-4]
	fwait
	mov	word ptr [si], 15
	pop	di
    .endif
    ret

	assume bx: nothing
	assume di: nothing

codeword	<pi>, NORMAL

	add	si, 4
	fldpi
	fstp	[si]
	fwait
	ret

codeword	<wtof>, NORMAL	;	( double - float )

	fild	word ptr [si]
	fstp	real4 ptr [si]
	fwait
	ret

codeword	<ltof>, NORMAL	;	( double - float )

	fild	dword ptr [si]
	fstp	real4 ptr [si]
	fwait
	ret

codeword	<ftol>, NORMAL	;	( double - float )

	invoke	ftol, dword ptr [si]
	mov	dword ptr [si], eax
	ret

codeword	<atol>, NORMAL	;	( ptr - newptr, [value], flag )

	push	si
	invoke	atol, dword ptr [si]
	mov	ebx, esi
	pop	si
	mov	[si], ebx

	.if	!cx
	  add	si, 4
	  mov	dword ptr [si], eax
	.endif
	not	cx
	mov	ax, cx
	jmp	PushShortAX

codeword	<atof>, NORMAL	;	( ptr - newptr, [value], flag )

	push	esi
	invoke	atof, dword ptr [si]
	movzx	ebx, si
	pop	esi
	mov	dword ptr [si], ebx
	.if	cx
		add	si, 4
		mov	real4 ptr [si], eax
	.endif
	mov	ax, cx
	jmp	PushShortAX
	
comment #
	push	si
	invoke	atof, [si]
	mov	bx, si
	pop	si
	mov	[si], bx
	.if	!cx
	  mov	real4 ptr [si+2], eax
	  add	si, 6
	.else
	  add	si, 2
	.endif
	not	cx
	mov	[si], cx
	ret
#

codeword	<ftoa>, NORMAL	; ( ptr, value, width, precision - )

	invoke	ftoa, dword ptr [si-12], real4 ptr [si-8], word ptr [si-4], word ptr [si]
	sub	si, 16
	ret

codeword	<ftopad>, NORMAL	; ( value, width, precision - pad, n )

	xor	eax, eax
	mov	ax, offset DOSpad_start+1
	invoke	ftoa, eax, real4 ptr [si-8], word ptr [si-4], word ptr [si]
	sub	si, 4
	movzx	eax, word ptr [si]	; width
	mov	DOSpad_start, al
	mov	dword ptr [si], eax
	mov	ax, offset DOSpad_start+1
	mov	dword ptr [si-4], eax
	ret

codeword	<fw.p>, NORMAL, fwp_print	; ( value, width, precision - )
	call	___ftopad
	jmp	___type

codeword	<fw.>, NORMAL, fw_print	; ( value, width - )

	xor eax, eax
	dec	eax
	add	si, 4
	mov	dword ptr [si], eax
	jmp	___fwp_print

codeword	<f.>, NORMAL, f_print	; ( value - )

	add	si, 8
	mov	dword ptr [si], -1
	mov	dword ptr [si-4], 8
	jmp	___fwp_print

codeword	<carry?>, NORMAL, carryset?
	test	[si], 1
	jz	false
	jmp	true

codeword	<!!carry?>, NORMAL, carryclear?
	and	[si], 1
	dec	[si]
	ret

codeword	<zero?>, NORMAL, zeroset?
	test	[si], 40h	; bit 6
	je	false
	jmp	true

codeword	<!!zero?>, NORMAL, zeroclear?
	test	[si], 40h	; bit 6
	jne	false
	jmp	true

codeword	<minus?>, NORMAL, minusset?
	test	[si], 80h	; bit 7
	je	false
	jmp	true

codeword	<!!minus?>, NORMAL, minusclear?
	test	[si], 80h	; bit 7
	jne	false
	jmp	true

codeword	<0=>, NORMAL, eq0
	cmp	dword ptr [si], 0
	je	true
false::
	xor	eax,eax
	mov	dword ptr [si], eax
	ret

codeword	<r=>, NORMAL, requals
	pop	cx
	pop	eax
	push	eax
	push	cx
	jmp	compare_eax

codeword	<=>, NORMAL, equal
	mov	eax, [si]
	sub	si, 4
compare_eax:
	cmp	eax, [si]
	jne	false
true::
	xor	eax,eax
	dec	eax
	mov	dword ptr [si], eax
	ret

codeword	<!!=>, NORMAL, not_equal
	mov	eax,[si]
	sub	si, 4
	cmp	eax, [si]
	jne	true
	jmp	false


codeword	<!>>, NORMAL, gt
	mov	eax,[si]
	sub	si, 4
	cmp	[si], eax
	jg	true
	jmp	false

codeword	<!>=>, NORMAL, ge
	mov	eax,[si]
	sub	si, 4
	cmp	[si], eax
	jge	true
	jmp	false

codeword	<!<>, NORMAL, lt
	mov	eax,[si]
	sub	si, 4
	cmp	[si], eax
	jl	true
	jmp	false

codeword	<!<=>, NORMAL, le
	mov	eax, [si]
	sub	si, 4
	cmp	[si], eax
	jle	true
	jmp	false

codeword	<max>, NORMAL

	mov	eax, [si]
	sub	si, 4
	.if	sdword ptr eax>sdword ptr [si]
		mov	[si], eax
	.endif
	ret

codeword	<min>, NORMAL

	mov	eax, [si]
	sub	si, 4
	.if	sdword ptr eax<[si]
		mov	[si], eax
	.endif
	ret

codeword	<umax>, NORMAL

	mov	eax, [si]
	sub	si, 4
	.if	dword ptr eax>[si]
		mov	[si], eax
	.endif
	ret

codeword	<umin>, NORMAL

	mov	eax, [si]
	sub	si, 4
	.if	dword ptr eax<[si]
		mov	[si], eax
	.endif
	ret


codeword	<between>, NORMAL
	mov	eax, [si]
	sub	si, 8
	mov	ebx, [si]
	.if	eax<sdword ptr [si+4]
	  .if	(eax>=dword ptr ebx) && (ebx>=dword ptr[si+4])
	    jmp	true
	  .endif
	.else
	  .if	(eax>=sdword ptr ebx) && (ebx>=sdword ptr[si+4])
	    jmp	true
	  .endif
	.endif
	jmp	false

codeword	<bounds>, NORMAL; bounds check - generates int 5 on error
	mov	dx, offset msgBounds
	mov	ebx, [si]
	sub	si, 4
	mov	eax, [si]
	bound	eax, [ebx]
	ret
msgBounds	db	' : <bounds> fail $', 0

codeword	<wbounds>, NORMAL; bounds check - generates int 5 on error
	mov	bx, word ptr [si]
	sub	si, 4
	mov	ax, word ptr [si]
	bound	ax, [bx]
	ret

codeword	<d!>>, NORMAL, dgt
	sub	si, 4
	mov	eax, dword ptr [si+4]
	cmp	sdword ptr [si], eax
	jg	true
	jmp	false

codeword	<d!<>, NORMAL, dlt
	sub	si, 4
	mov	eax, dword ptr [si+4]
	cmp	sdword ptr [si], eax
	jl	true
	jmp	false

codeword	<c!>>, NORMAL, cgt
	mov	al, byte ptr [si]
	sub	si, 4
	cmp	byte ptr [si], al
	jg	true
	jmp	false

codeword	<c!<>, NORMAL, clt
	mov	al, byte ptr [si]
	sub	si, 4
	cmp	byte ptr [si], al
	jl	true
	jmp	false

codeword	<0!>>, NORMAL, gt0
	cmp	dword ptr [si], 0
	jg	true
	jmp	false

codeword	<0!<>, NORMAL, lt0
	cmp	dword ptr [si], 0
	jl	true
	jmp	false

codeword	<u!>>, NORMAL, ugt
	mov	eax, [si]
	sub	si, 4
	cmp	[si], eax
	ja	true
	jmp	false

codeword	<u!<>, NORMAL, ult
	mov	eax, [si]
	sub	si, 4
	cmp	[si], eax
	jb	true
	jmp	false

codeword	<!<!>>, NORMAL, ne
	mov	eax, [si]
	sub	si, 4
	cmp	[si], eax
	je	false
	jmp	true

codeword	<u!>=>, NORMAL, uge
	mov	eax, [si]
	sub	si, 4
	cmp	[si], eax
	jae	true
	jmp	false

codeword	<and>, NORMAL
	mov	eax, dword ptr [si]
	sub	si, 4
	and	dword ptr [si], eax
	ret

codeword	<and!!>, NORMAL, and_store
	mov	eax, dword ptr [si]
	mov	ebx, dword ptr [si-4]
	and	[ebx], eax
	sub	si, 8
	ret

codeword	<or>, NORMAL
	mov	eax,dword ptr [si]
	sub	si, 4
	or	dword ptr [si], eax
	ret

codeword	<or!!>, NORMAL, or_store
	mov	eax, dword ptr [si]
	mov	ebx, dword ptr [si-4]
	or		dword ptr [ebx], eax
	sub	si, 8
	ret

codeword	<xor>, NORMAL
	mov	eax,dword ptr [si]
	sub	si, 4
	xor	dword ptr [si], eax
	ret

codeword	<not>, NORMAL
	not	dword ptr [si]
	ret


codeword	<shr>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	shr	dword ptr [si], cl
	ret

codeword	<asr>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	sar	dword ptr [si], cl
	ret

codeword	<asl>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	sal	dword ptr [si], cl
	ret

codeword	<shl>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	shl	dword ptr [si],cl
	ret

codeword	<qshr>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	mov	eax, dword ptr [si-4]
	mov	edx, dword ptr [si]
	shrd	edx, eax, cl
	shr	eax, cl
	mov	dword ptr [si-4], eax
	mov	dword ptr [si], edx
	ret

codeword	<qshl>, NORMAL
	mov	cx, word ptr [si]
	sub	si, 4
	mov	eax, dword ptr [si-4]
	mov	edx, dword ptr [si]
	shld	edx, eax, cl
	shl	eax, cl
	mov	dword ptr [si-4], eax
	mov	dword ptr [si], edx
	ret

codeword	<!>bit>, NORMAL, to_bit
	mov	eax, dword ptr [si]
	sub	si, 8
	.if	dword ptr [si+4]
	  bts	dword ptr [si], eax
	.else
	  btr	dword ptr [si], eax
	.endif
	ret

codeword	<!>bit!!>, NORMAL, to_bit_store
	mov	ebx, dword ptr [si]
	mov	eax, dword ptr [si-4]
	sub	si, 12
	.if	word ptr [si+4]
	  bts	[ebx], eax
	.else
	  btr	[ebx], eax
	.endif
	ret
codeword	<w!>bit!!>, NORMAL, wto_bit_store
	mov	ebx, dword ptr [si]
	mov	ax, word ptr [si-4]
	sub	si, 12
	.if	word ptr [si+4]
	  bts	word ptr [bx], ax
	.else
	  btr	word ptr [bx], ax
	.endif
	ret

codeword	<bts>, NORMAL
	mov	eax, dword ptr [si]
	sub	si, 4
	mov	ebx, dword ptr [si]
	bts	[ebx], eax
	jc	true
	jmp	false

codeword	<btr>, NORMAL
	mov	eax, dword ptr [si]
	sub	si, 4
	mov	ebx, dword ptr [si]
	btr	[ebx], eax
	jc	true
	jmp	false

codeword	<bit?>, NORMAL
	mov	eax, dword ptr [si]
	sub	si, 4
	bt	dword ptr [si], eax
	jc	true
	jmp	false

codeword	<!!bit?>, NORMAL, not_bit
	mov	eax, dword ptr [si]
	sub	si, 4
	bt	dword ptr [si], eax
	jc	false
	jmp	true

codeword	<SwapBitPairs>, NORMAL
	mov	eax, dword ptr [si]
	mov	cx, 16
	
	.repeat
		shr	eax, 1
		rcr	bx, 1
		shr	eax, 1
		rcr	dx, 1
	.untilcxz
	
	mov	word ptr [si], bx
	mov	word ptr [si+2], dx
	ret


codeword	<crc>, NORMAL		; ( crc, char - crc )

	mov	bx, word ptr [si]
	sub	si, 4
	mov	ax, word ptr [si]
	call	crc16
	jmp	PokeShortAX


crc16:: push	bx
	xor	bh, bh
	xchg	al, ah
	xchg    bl, al
	shl	bx, 1
	xor	ax, crc16Table[bx]
	pop	bx
	ret

codeword	<crctest>, NORMAL		; ( ptr, count - crc )

	mov	cx, word ptr [si]	; count
	sub	si, 4
	push	si
	mov	si, word ptr [si] ; address
	xor	ax, ax
	
	.repeat
		mov	bl, byte ptr [si]
		call	crc16
		inc	si
	.untilcxz
	
	pop	si
	jmp PokeShortAX



crc16Table label word

include	crc16.asm



% lastAluLink =   _link&lastLink

public  lastAluLink

forth_alu   endp

GetRandom16	proc C uses bx

	call	GetTickCount
	mov	bx, ax
	xor	bl, bh
	mov	ax, LastRand
	call	crc16
	mov	LastRand, ax
	ret

LastRand	dw 0

GetRandom16 endp


CRCBlock	proc C uses bx cx si, buffer:word, count:word, crc:word


	mov	si, buffer
	mov	cx, count
	mov	ax, crc
	.repeat
	  mov	bl, byte ptr es:[si]
	  call	crc16
	  inc	si
	.untilcxz
	ret



CRCBlock	endp


_TEXT	ends

end

