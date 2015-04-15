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



_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA

fhCRC	proc C uses bx cx dx ds es, handle:word

local	crc:word

	mov	bx, 100h		; 256 paragraphs = 4kb block
	mov	ah, 48h
	int	21h     		; segment allocated in ax
	.if	carry?
	  mov	ax, 11
	  jmp	fhCRCexit
	.endif
	mov	es, ax
	mov	ds, ax
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

CRCBlock	proc C uses bx cx si, buffer:word, count:word, crc:word


	mov	si, buffer
	mov	cx, count
	mov	ax, crc
	.repeat
;	  mov	bl, byte ptr es:[si]
	  mov	bl, byte ptr [si]
	  call	crc16
	  inc	si
	.untilcxz
	ret

crc16:: push	bx
	xor	bh, bh
	xchg	al, ah
	xchg    bl, al
	shl	bx, 1
	xor	ax, crc16Table[bx]
	pop	bx
	retn

crc16Table label word

include	crc16.asm


CRCBlock	endp




_TEXT	ends

	.list


end
