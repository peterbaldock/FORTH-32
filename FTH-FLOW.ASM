comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-FLOW.ASM	:	Forth program control flow

21-02-96 Version 1.00	:
2003-01-14 Version 2.8	:	+ case statement
				  (select, case:, cases: endcase endselect)
				+ Structure checking with compiling words

================================================================================#

option language:c

include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\serial.inc
include ..\include\forth.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern		lastFileLink:abs

;externdef	_vocabulary:near
% _link900	equ	lastFileLink

	thisLink textequ <901>
	lastLink textequ <900>


forth_flow	proc	near

JumpAllocate::

	and	eax, 0FFFFh		;	set most significant word of eax to 0

	mov	ebx, h
	mov	[ebx], eax

	add	ebx, 4		;	next cell
	add	si, 4
	mov	[si], ebx	;	leave next cell address on stack
	add	h, 8

	ret
		
	
Code_word	<if>, NORMAL+IMMEDIATE
	mov	ax, offset @ds_if	; in dataseg????
	call	JumpAllocate

	mov	ax, offset ___if
	jmp	SetNesting

Code_word	<else>, NORMAL+IMMEDIATE
	mov	ax, offset ___if
	call	CheckNesting
	mov	ebx, h
	xor	eax, eax		;	set most significant word of eax to 0
	mov	ax, offset @ds_else
	mov	[ebx], eax
	add	ebx, 4
	mov	eax, ebx
	xchg	ebx, [si]  ; original ___if space reserved in dictionary
	add	eax, 4
	mov	[ebx], eax
	mov	h, eax

	mov	ax, offset ___if
	jmp	SetNesting


Code_word	<endif>, NORMAL+IMMEDIATE
	mov	ax, offset ___if
	call	CheckNesting
	
	mov	ebx, [si]
	sub	si, 4
	mov	eax, h
	mov	[ebx], eax
	ret
	
Code_word	<then>, NORMAL+IMMEDIATE
	jmp	___endif


Code_word	<begin>, NORMAL+IMMEDIATE
	call	___here
	mov	ax, offset ___begin
	jmp	SetNesting

Code_word	<while>, NORMAL+IMMEDIATE
	mov	ax, offset ___begin
	call	CheckNesting
	
	mov	ax, offset @ds_if	; in dataseg????
	call	JumpAllocate
	
	mov	ax, offset ___begin
	jmp	SetNesting


Code_word	<until>, NORMAL+IMMEDIATE
	mov	ax, offset ___begin
	call	CheckNesting
	
	mov	ax, offset @ds_until
	jmp	ExtendedCFAandEnclose

Code_word	<repeat>, NORMAL+IMMEDIATE
	mov	ax, offset ___begin
	call	CheckNesting

	xor	eax, eax
	mov	ax, offset @ds_else		; same run-time behaviour as else
	mov	ebx, h
	mov	[ebx],  eax

	;	stack:	TOS = pfa of <while>, NOS = begin start address
	mov	eax, [si-4]
	add	bx, 4
	mov	[ebx], eax;	so enclose the NOS value as parameter field of <repeat>

	add	ebx, 4			; bx points to next here (ie where further colon addresses will be compiled
	mov	eax, [si]		; pfa of <while>
	xchg	eax, ebx
	mov	[ebx], eax		; put here in parameter field of <while>
	mov	h, eax			; update dictionary pointer
	sub	si, 8

	ret


	
Code_word	<do>, NORMAL+IMMEDIATE
	xor	eax, eax
	mov	ax, offset @ds_do
	mov	ebx, h
	mov	[ebx], eax
	add	h, 4
	call	___here

	
	mov	ax, offset ___do
	jmp	SetNesting

Code_word	<loop>, NORMAL+IMMEDIATE
	mov	ax, offset ___do
	call	CheckNesting
	
	mov	ax, offset @ds_loop
	jmp	ExtendedCFAandEnclose

Code_word	<+loop>, NORMAL+IMMEDIATE, plus_loop
	mov	ax, offset ___do
	call	CheckNesting

	mov	ax, offset @ds_plus_loop
	jmp	ExtendedCFAandEnclose

Code_word	<leave>, NORMAL

	push bp						;	does not interfere with LocalSP (bp unchanged)
	mov	bp, sp
	mov	ebx, [bp+8]
	mov	[bp+4], ebx
	pop	bp
	ret	

Code_word	<select>, NORMAL+IMMEDIATE

	mov	ax, offset @ds_select
	call	JumpAllocate
	
	mov	ax, offset ___select
	jmp	SetNesting

Code_word	<endselect>, NORMAL+IMMEDIATE

	mov	ax, offset ___select
	call	CheckNesting
	
	mov	eax, h		; poke exit address back into
	mov	ebx, [si]        ; slot after beginning of case block
	mov	[ebx], eax
	sub	si, 4
	mov	ebx, eax
	xor	eax, eax
	mov	ax, offset @ds_endselect
	mov	[ebx],  eax
	add	h, 4
	ret

Code_word	<case:>, NORMAL+IMMEDIATE, startcase

	mov	ax, offset @ds_case

GeneralCase:

	push	ax
	mov	ax, offset ___select
	call	CheckNesting
	pop	ax
	call	JumpAllocate
	mov	ax, offset ___startcase
	jmp	SetNesting

Code_word	<?case:>, NORMAL+IMMEDIATE, start?case

	mov	ax, offset @ds_if
	jmp	GeneralCase

Code_word	<cases:>, NORMAL+IMMEDIATE, startcases

	mov	ax, offset @ds_cases
	jmp	GeneralCase

Code_word	<endcase>, NORMAL+IMMEDIATE	; two addresses on stack

	mov	ax, offset ___startcase
	call	CheckNesting	; check TOS=startcase
	sub	si, 4				;	lose TOS
	
	xor	eax, eax
	mov	ax, offset @ds_endcase
	mov	ebx, h
	mov	[ebx], eax

	add	ebx, 4
	mov	eax, [si]
	mov	[ebx], eax	; indirect jump address for exit
	add	ebx, 4
	mov	h, ebx
	mov	eax, ebx		; poke next execution address back into
	mov	ebx, [si+4]      ; location pointed to by original TOS
	mov	[ebx], eax

	mov	ax, offset ___select
	jmp	SetNesting
	
	
	
	
;	================================================================================


;	run-time code for flow control compiling words


;____if::
;	inc	di
;	inc	di
;	.if	! dword ptr [si]
;		mov	di, [di]
;		dec	di
;		dec	di
;	.endif
;	sub	si, 4
;	ret

____if::
	add	edi, 4
	.if	! dword ptr [si]
		mov	edi, [edi]
		sub	edi, 4
	.endif
	sub	si, 4
	ret

;____else::
;	mov	di,[di+2]
;	dec	di
;	dec	di
;	ret

____else::
	mov	edi, [edi+4]
	sub	edi, 4
	ret

;____until::
;	inc	di
;	inc	di
;	.if ! dword ptr [si]
;		mov	di, [di]
;		dec	di
;		dec	di
;	.endif	
;	sub	si, 4
;	ret

____until::
	add	edi, 4
	.if	! dword ptr [si]
		mov	edi, [edi]
		sub	edi, 4
	.endif
	sub	si, 4
	ret

____do::		; 2014-01-18 added to 32 counter.	___do is universal (ie the same for low dictionary and extended dictionary)
	pop	ax
	push	dword ptr [si-4]
	push	dword ptr [si]
	sub	si, 8
	jmp	ax


____loop::		; 2014-01-18 added 32-bit counter version
	push	bp
	mov	bp, sp					;	does not interfere with LocalSP (bp unchanged)
	mov	eax, [bp+8]
	inc		dword ptr [bp+4]
	cmp	eax, [bp+4]			; 2014-01-18 NB: 32-bit comparison
	pop	bp						;	does not interfere with LocalSP (bp unchanged)
	jbe	xno_rept
	mov	edi, [edi+4]
	sub	edi, 4
	ret
	
xno_rept:
	add	edi, 4
	ret	8


____plus_loop::		; 2014-01-18 added 32-bit counter version
	push	bp
	mov	bp, sp							;	does not interfere with LocalSP (bp unchanged)
	mov	eax, [si]
	sub	si, 4
	test	byte ptr [si+7],80h
	jne	down_loop
	add	eax,[bp+4]
	mov	[bp+4],ax
	cmp	eax,[bp+8]
	pop	bp								;	does not interfere with LocalSP (bp unchanged)
	jge	xno_rept
	mov	edi, [edi+4]
	sub	edi, 4
	ret

down_loop:
	add	eax, [bp+4]
	mov	[bp+4], eax
	cmp	eax, [bp+8]
	pop	bp
	jle	xno_rept
	mov	edi, [edi+4]
	sub	edi, 4
	ret


____select::
	; runtime action of select is to :
	; 1. push key onto rstack
	; 2. jump over endcase jmp

	add	edi, 4	; skip jump
	jmp	___to_r

____endselect::
	ret	4

;____case::
;	pop	ax
;	pop	ebx
;	push	ebx
;	inc	di
;	inc	di
;	.if	ebx != [si]
;	  mov	di, [di]
;	  dec	di
;	  dec	di
;	.endif
;	sub	si, 4
;	jmp	ax

____case::
	pop	ax
	pop	ebx
	push	ebx
	add	edi, 4
	.if	ebx != [si]
	  mov	edi, [edi]
	  sub	edi, 4
	.endif
	sub	si, 4
	jmp	ax

;____?case::
;	inc	di
;	inc	di
;	.if	! dword ptr [si]
;	  mov	di, [di]
;	  dec	di
;	  dec	di
;	.endif
;	sub	si, 4
;	ret

____?case::
	add	edi, 4
	.if	! dword ptr [si]
	  mov	edi, [edi]
	  sub	edi, 4
	.endif
	sub	si, 4
	ret

;____cases::
;	pop	ax
;	pop	bx
;	push	bx
;	inc	di
;	inc	di
;	mov	cx, si
;	sub	cx, [si]
;	sub	cx, [si]
;	sub	cx, [si]
;	sub	cx, [si]
;	.while	si>cx
;	sub	si, 4
;	  .if	bx==[si]
;			mov	di, [di]
;			dec	di
;			dec	di
;			.break
;	  .endif
;	.endw
;
;	mov	si, cx
;	sub	si, 4
;	jmp	ax

____cases::
	pop	ax
	pop	bx		;	>r
	push	bx
	add	edi, 4		;	point to next colon field
	
	mov	cx, si
	sub	cx, [si]
	sub	cx, [si]
	sub	cx, [si]
	sub	cx, [si]
	.while	si>cx
	sub	si, 4
	  .if	bx==[si]	; 
			mov	edi, [edi]
			sub	edx, 4
			.break
	  .endif
	.endw

	mov	si, cx
	sub	si, 4
	jmp	ax

;____endcase::
;	mov	di, [di+2]
;	mov	di, [di]
;	dec	di
;	dec	di
;	ret

____endcase::
	mov	edi, [edi+4]
	mov	edi, [edi]
	sub	edi, 4
	ret



% lastFlowLink =   _link&lastLink

public  lastFlowLink
    
forth_flow   endp

_TEXT	ends

end

