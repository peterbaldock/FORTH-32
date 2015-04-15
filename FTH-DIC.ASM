comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-STR.ASM	:	Forth string routines

21-02-96 Version 1.00	:	

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


extern      lastStrLink:abs
;externdef  _vocabulary:near
% _link500  equ lastStrLink

    thisLink textequ <501>
    lastLink textequ <500>

forth_dic	proc    near

Code_word	<WordBuffer>, NORMAL
	add	si, 4
WordBuffer_r::
	mov	ax, offset WordBuffer
	jmp PokeShortAX
	
Code_word <_xbase>, NORMAL
	mov	eax, EXTENDED_BASE	; Start of dictionary in extended memory ( = 1000000h )
	jmp	PushEAX

Code_word	<here>, NORMAL
	mov	eax, ds:h
	jmp	PushEAX
	
Code_word	<h>, NORMAL
	mov	ax, offset	ds:h
	jmp	PushShortAX

Code_word	<!,>, NORMAL, enclose
	mov	eax,[si]
	sub	si, 4
	mov	ebx, ds:h
	mov	[ebx], eax
	add	h, 4
	
	ret

Code_word	<w!,>, NORMAL, wenclose
	mov	ax,[si]
	sub	si, 4
	mov	ebx, ds:h
	mov	[ebx], ax
	add	h, 2
	ret

___wencloseIfCompiling::

	.if	status & COMPILING
	  jmp	___wenclose
	.endif
	ret

Code_word	<c!,>,NORMAL, cenclose
	mov	al,[si]
	sub	si, 4
	mov	ebx, h
	mov	[ebx], al
	inc	h
	ret

Code_word	<f!,>, NORMAL, fenclose
	jmp	___enclose

Code_word	<allot>, NORMAL
	movzx	eax, word ptr [si]
	sub	si, 4
	mov	ebx, h

	.while	eax
	  mov	[ebx], bl
	  dec	eax
	  inc		ebx
	.endw

	mov	h, ebx

	ret

;	============================================================================

;	Not yet migrated to Extended dictionary

Code_word	<s!,>, NORMAL, stringenclose
;	????????????
	mov	bx, [si]	; TOS points to string at end of dictionary
	movzx	ax, byte ptr [bx]
	inc	ax
	
	.if	bx != word ptr h
		push	si
		mov	si, word ptr h
		mov	cx, ax
		.repeat
			mov	dl, [bx]
			mov	[si], dl
			inc	bx
			inc	si
		.untilcxz
		pop	si
	.endif
	
	add	word ptr h, ax
	ret

Code_word	<!{>, NORMAL, MarkStack
	mov	StackMarker, si
	ret
	
Code_word	<_!}>, NORMAL, EncloseStack

	call	PrepareShiftToStack
	.while si<dx
		add	si, 4
		mov	eax, dword ptr [si]
		mov	dword ptr [ebx], eax
		add	ebx, 4
		add	cx, 4
	.endw

AdjustHere:
	mov	h, ebx
	mov	si, StackMarker
	add	si, 4
	mov	[si], ecx
	ret

PrepareShiftToStack:
	mov	dx, si		;	keep TOS pointer
	mov	si, StackMarker
	xor	ecx, ecx
	mov	ebx, h
	ret
	
Code_word	<!}>, NORMAL, SEncloseStack

	movzx	eax, si
	sub	ax, StackMarker
	push	eax
	call	PushEAX
	call	___staticallot
	pop	eax
	mov	edx, [si]
	sub	si, 4
	mov	bx, StackMarker

	.while bx<si
		add	bx, 4
		mov	ecx, dword ptr [bx]
		mov	dword ptr [edx], ecx
		add	edx, 4
	.endw
	mov	si, StackMarker
	jmp	PushEAX
	
Code_word	<w!}>, NORMAL, SwEncloseStack

	movzx	eax, si
	sub	ax, StackMarker
	shr	eax, 1
	push	eax
	call	PushEAX
	call	___staticallot
	pop	eax
	mov	edx, [si]
	sub	si, 4
	mov	bx, StackMarker

	.while bx<si
		add	bx, 4
		mov	cx, word ptr [bx]
		mov	word ptr [edx], cx
		add	edx, 2
	.endw
	mov	si, StackMarker
	jmp	PushEAX
	
Code_word	<c!}>, NORMAL, ScEncloseStack

	movzx	eax, si
	sub	ax, StackMarker
	shr	eax, 2
	push	eax
	call	PushEAX
	call	___staticallot
	pop	eax
	mov	edx, [si]
	sub	si, 4
	mov	bx, StackMarker

	.while bx<si
		add	bx, 4
		mov	cl, [bx]
		mov	byte ptr [edx], cl
		inc	edx
	.endw
	mov	si, StackMarker
	jmp	PushEAX
	
StackMarker	dw	0

Code_word	<_w!}>, NORMAL, WEncloseStack

	call	PrepareShiftToStack
	
	.while si<dx
		add	si, 4
		mov	ax, word ptr [si]
		mov	word ptr [ebx], ax
		inc	ebx
		inc	ebx
		inc	cx
		inc	cx
	.endw

	jmp	AdjustHere
	
Code_word	<_c!}>, NORMAL, CEncloseStack

	call	PrepareShiftToStack
	
	.while si<dx
		add	si, 4
		mov	ax, word ptr [si]
		mov	byte ptr [ebx], al
		inc	ebx
		inc	cx
	.endw
	
	jmp	AdjustHere

Code_word	<forget>, NORMAL
;	????????????

	call	___find	;	leaves extended address on stack
	mov	ebx, [si]
	sub	si, 4
	and	ebx,ebx
	je	no_forget
	sub	bx, 4
	mov	ax,[bx]
	dec	bx
	mov	cl,[bx]
	and	cx, 01fh
	sub	bx,cx
	mov	word ptr h, bx
	mov	bx, word ptr ds:Current
	mov	[bx], ax
no_forget:
	ret

% lastDicLink =   _link&lastLink

public  lastDicLink
    
forth_dic   endp

_TEXT	ends

end

