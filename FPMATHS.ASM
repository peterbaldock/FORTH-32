comment #

	fp 32 bit format as follows :

	SEEE EEEE | EMMM MMMM | MMMM MMMM | MMMM MMMM
	 Byte  3  |  Byte  2  |  Byte  1  |  Byte  0

	where S=sign, E=Exponent, M=Mantissa (implied MSB=1, replaced by E0).


06-01-98 Version 2.00	Start to convert to segmentless form
			1. fpmul - arguments passed by value, not address
			2. fpdiv - rewritten entirely to use 32 bit regs
			3. fpadd, fpsub rewritten
10-01-98 Version 2.01	All regular fp functions are in C form ie:
			fpmul, fpdiv, fpadd, fpsub, fpint, fpfract

			fpmul10 uses EAX for input and output for convenience
03-12-98 Version 2.11	ftol fixed for f<1.5; 0< gives TRUE=-1
2002-08-29 Version 2.64 : f*, f/, f+, f- and pi using FP processor only

#

	option language:c


	include	..\include\fp.inc

_TEXT	segment


	.486

	assume	ds:nothing

;****************************************************************************

SetDecimalCharacter proc near C uses ax, dp:byte

;****************************************************************************

	mov	al, dp
	mov	decimalCharacter, al
	ret

SetDecimalCharacter endp

;****************************************************************************

fpmul	proc C public, A:real4, B:real4

;****************************************************************************
local	result : real4

	fld	A
	fmul	B
	fstp	result
	fwait
	mov	eax, result
	ret


fpmul	endp



;****************************************************************************

fpdiv	proc	near C, A:real4, B:real4

;****************************************************************************
local	result : real4



;	return EAX = A / B,  C=0 or C=1 for error

	mov	eax, B
	and	eax, eax
	.if	zero?
	  stc
	  ret
	.endif

	fld	A
	fdiv	B
	fstp	result
	fwait
	mov	eax, result

fp_end::
	ret

fpdiv	endp

;****************************************************************************

fpsub	proc near C,  A:real4, B:real4

;****************************************************************************
local	result :REAL4

	fld	A
	fsub	B
	fstp	result
	fwait
	mov	eax, result
	ret

fpsub	endp


;****************************************************************************

fpadd	proc near C, A:real4, B:real4

;****************************************************************************
local	result :REAL4

	fld	A
	fadd	B
	fstp	result
	fwait
	mov	eax, result
	ret

fpadd	endp

;****************************************************************************

fpmul10	proc	near		; EAX contains float operand
				; on exit EAX = 10*EAX

;****************************************************************************
local	result :REAL4

	mov	result, eax
	fld	result
	fmul	ten
	fstp	result
	fwait
	mov	eax, result
	ret

fpmul10	endp

;****************************************************************************

fpsqrt	proc C public, A:real4

;****************************************************************************
local	result : real4

	fld	A
	fsqrt
	fstp	result
	fwait
	mov	eax, result
	ret


fpsqrt	endp



;****************************************************************************

fpcos	proc C public, A:real4

;****************************************************************************
local	result : real4

	fld	A
	fcos
	fstp	result
	fwait
	mov	eax, result
	ret


fpcos	endp


;****************************************************************************

fpsin	proc C public, A:real4

;****************************************************************************
local	result : real4

	fld	A
	fsin
	fstp	result
	fwait
	mov	eax, result
	ret


fpsin	endp




;****************************************************************************

ltof	proc	near C, value:dword

;****************************************************************************

;	long passed on stack, float returned in EAX

local	result : real4

	fild	value
	fstp	result
	fwait
	mov	eax, result
	ret

ltof	endp


;****************************************************************************

itof	proc	near C, value:word ;integer on stack, float returned in EAX

;****************************************************************************


	mov	ax, value
	cwde
	invoke	ltof, eax

itof	endp

;****************************************************************************

atol	proc near C, source:dword ; source->text, return long in EAX, si->1st bad char

;****************************************************************************

local	flag:word

	mov	esi, source
	sub	eax, eax
	mov	ebx, eax
	mov	ecx, 10
	mov	flag, ax

atol1:	mov	bl, [esi]
	inc	esi
	cmp	bl, ' '
	je	atol1
	cmp	bl, 09	; tab
	je	atol1
	cmp	bl, 0dh
	je	atol1
	cmp	bl, 0ah
	je	atol1
	.if	bl == '-'
	  or	flag, 8000h
	.else
	  dec	esi
	.endif


atol2:	mov	bl, byte ptr [esi]
	sub	bl, '0'
	.if	bl>9		; ie not a digit
	  jmp	invalid_digit	; end of conversion
	.endif

	mul	ecx
	add	eax, ebx
	or	flag, 1
	inc	esi
	jmp	atol2

invalid_digit:
	xor	cx, cx
	.if	flag&1   	; a valid number has been read
	  .if	flag & 8000h
	    neg	eax
	  .endif
	.else
	  xor	eax, eax
	  dec	cx
	.endif
	ret

atol	endp

;****************************************************************************

atof	proc near C, source:dword; source->text, return float in EAX, esi->1st bad char, cx[15..0] = S P i i i i i i    i ddddddd for valid number, or 0 for invalid

;****************************************************************************

local atof_flags : word; b15 = sign. b14 = dp present; b13-b7 = idigit count; b6-0 = ddigit count

;

	mov	esi, source
	sub	eax, eax
	mov	atof_flags, ax
	mov	edx, 3f800000h

atf1:	mov	bl, [esi]
	inc	esi
	cmp	bl, ' '
	je	atf1
	cmp	bl, 09	; tab
	je	atf1
	cmp	bl, 0dh
	je	atf1
	cmp	bl, 0ah
	je	atf1
	.if	bl == '-'
	  or	atof_flags, 8000h
	.else
	  dec	esi
	.endif


atf2:	call	get_digit	; returns fp value of digit in ebx,
	.if	carry?		; or carry=1 if not digit
	  ;cmp	bl, decimalCharacter
	  .if	(bl!='.')&&(bl!=',')
	   jmp	invalid_digit
	  .endif
	  bts	atof_flags, 14		; bit 1 flags presence of decimal point
	  jc	invalid_digit	; two decimal points in number
	  inc	esi		; mov on to next char
	  jmp	atf2		; and continue to scan
	.endif

	call	fpmul10

	push	edx
	invoke	fpadd, eax, ebx; eax = eax+float(digit)
	pop	edx
	.if	(atof_flags & 04000h)
		xchg	eax, edx
		call	fpmul10			; divide by extra 10 for each digit
		xchg	eax, edx
		inc	atof_flags
	.else
		add	atof_flags, 0080h
	.endif
	jmp	atf2

invalid_digit:
	mov	cx, atof_flags
	.if	cx & 03FFh   	; a valid number has been read
	  .if	cx & 04000h	; with a fractional part
		invoke	fpdiv, eax, edx
	  .endif
	  .if	cx & 8000h
	    or	eax, 80000000h
	  .endif
		clc
	.else
	  xor	cx, cx
	  stc
	.endif

	ret


;	take digit / divider, and add to dest. divider*=10

get_digit:
	movzx	bx, byte ptr [esi]
	sub	bl,'0'
	.if	(carry?)||(bl>9)
	  mov	bl, [esi]
	  stc
	  retn
	.endif

	inc	esi
	shl	bx, 2
	mov	ebx, digits[bx]
	clc
	retn

atof	endp

digits	real4	0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0

;****************************************************************************

fpint	proc	C, value:real4

;****************************************************************************

	mov	cx, word ptr value[2]
	shl	cx, 1
	sub	ch, 7fh		; drop exponent offset
	.if	carry?
	  xor	eax, eax
	  ret
	.endif
	mov	cl, ch
	mov	eax, value
	.if	!zero?
	  mov	cl, 23
	  sub	cl, ch
	  jle	@F
	  shr	eax, cl
	  shl	eax, cl
	.endif

@@:	ret

fpint	endp



;****************************************************************************

fpfract	proc near C, value:real4

;****************************************************************************

	mov	ebx, value
	rol	ebx, 1
	pushf
	shr	ebx, 1
	invoke	fpint, ebx
	invoke	fpsub, value, eax
	shl	eax, 1
	popf
	rcr	eax, 1
	ret

fpfract	endp



;****************************************************************************

ftol	proc	near C, value:real4	; source is on stack
					; returns long in EAX
					; 1/2 LSB in carry (for subsequent rounding)

;****************************************************************************
	mov	eax, value
	push	ecx
	and	eax, eax
	mov	ecx, eax
	shr	ecx, 23		; get exponent in cl, sign in ch:0
	shl	eax, 7
	bts	eax, 30		; replace msb of mantissa
	btr	eax, 31		; msb must be 0 for +ve signed long
	sub	cl, 7eh		; 7eh not 7fh 03-12-98 Version 2.11

	jae	@F              ; jae, not ja for f<1.5
	sub	eax, eax
	pop	ecx
	ret

@@:	neg	cl
	add	cl, 31          ; add 31, not 30
	js	overflow

	shr	eax, cl
	jnc	@F
	inc	eax	; round if 1/2 LSB in carry is '1'

@@:	rcr	ch, 1	; correct for sign
	jnc	@F
	xor	ch, 80h	; invert truncation bit
	neg	eax
@@:	shl	ch, 1	; 1/2 LSB in carry for later truncation (and clears overflow)
	pop	ecx
	ret
overflow:
	mov	ch, 40h
	mov	eax, 80000000h
	jmp	@B

ftol	endp


;****************************************************************************

lprint	proc	near uses si edi

;	long in eax, edi -> destination buffer, cl=field width, ch=point position
;			bh=sign/prefix, bl=padding character.
;****************************************************************************
	movzx	edx, cl
	add	edi, edx
	mov	byte ptr [edi], 0

print_digit:
	xor	edx, edx
	div	long10
	add	dl,'0'
	dec	edi
	mov	[edi], dl
	and	ch,ch
	jz	@F
	dec	ch
	jnz	@F
	dec	edi
	push	ax
	mov	al, decimalCharacter
	mov	byte ptr [edi], al
	pop	ax
	loop	print_digit
	
	and	eax, eax
	jne	done		; couldn't convert in given width
	
@@:	and	eax, eax
	loopne	print_digit
	jne	done		; couldn't convert in given width
	and	ch,ch
	jne	print_digit	; padding zeroes to decimal point

	dec	ax
	.if	bh!=bl
	  jcxz	done
	  dec	cx
	  .if	bl==' '
	    dec	edi
	    mov	[edi],bh
	    mov	bh,bl
	  .endif
	.endif
	inc	ax
	jcxz	put_sign
@@:	dec	edi
	mov	[edi],bl
	loop	@B
put_sign:
	.if	bh!=bl
	  dec	edi
	  mov	[edi],bh
	.endif
done:	or	eax, eax
	ret

long10	dd	10
lprint	endp




;****************************************************************************

ltoa	proc C uses edi, dest:dword, val:dword, len:word, padding:word

;****************************************************************************

	mov	edi,dest
	mov	eax, val
	mov	cx,len		; if ch>0 then ch specifies precision
	mov	bx,padding		; padding - normally bl=' ', bh=' '
	.if	(bh!='u')	; signed/unsigned ? (unsigned if bh='u')
	  and	eax,eax
	  .if	sign?
		neg	eax
		mov	bh,'-'
	  .endif
	.endif
	call	lprint
	ret
ltoa	endp



;****************************************************************************

ftoa	proc C uses edi, dest:dword, value:real4, field:word, precision:word

;****************************************************************************

	mov	edi,dest
	mov	eax, value
	btr	eax, 31
	pushf
	mov	cx, precision
	cmp	cx, 0
	je	blown_up
	jg	fixed_point

	mov	bx, field	; multiply up until as many digits as field - 1
	sub	bx, 3
	jnc	@F
	sub	bx, bx

@@:	shl	bx, 2
	inc	cx
@@:	cmp	eax, power10[bx]
	jae	@F
	call	fpmul10
	add	cx,4
	cmp	cx, bx
	jl	@B
@@:     shr	cx, 2
	jmp	blown_up

fixed_point:
	call	fpmul10
	loop	fixed_point
	mov	cx, precision
blown_up:
	invoke	ftol, eax
;	sbc	eax, 0		; require truncation, not nearest int
	popf
	.if	carry?
	  mov	bx,'- '		; unconditional sign, padded with spaces
	.else
	  mov	bx,'  '		; positive
	.endif

	xchg	ch, cl
	or	cx, field

	invoke	ltoa, edi, eax, cx, bx; dest, val, field, padding

	ret

ftoa	endp

power10	real4	1.0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11, 1.0e12
ten	real4	10.0

decimalCharacter db '.'

_TEXT	ends


;****************************************************************************

	end
