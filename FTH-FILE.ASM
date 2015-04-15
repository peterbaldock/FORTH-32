comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-FILE.ASM	:	Forth File I/O routines

2009-04-06 Version 4.11 + fcreate, fopen, fwrite, fread, fclose, fflush.


================================================================================#

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\hooks.inc
include	..\include\serial.inc
include ..\include\forth.inc
include ..\include\files.inc
include ..\include\macros.inc
include ..\include\step.inc
include	..\include\fp.inc
include	FTH-ERRS.inc


_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA
	assume	si:ptr word

;==================================================================================

fcreate	proc C, Mode: word, FileName : dword

;==================================================================================

	mov	cx, Mode
	push	ds
	lds	dx, FileName
	mov	ah, 3ch
	int	21h
file_result::
	pop	ds
	.if	carry?
		mov	FileError, ax
		xor	ax, ax
	.else
		mov	FileError, 0
	.endif

	ret

fcreate endp

;==================================================================================

fopen	proc C, Mode:word, FileName:dword

;==================================================================================

	mov	ax, Mode
	push	ds
	lds	dx, FileName  ; far pointer to asciiz nul terminated string
	mov	ah, 3dh
	int	21h
	jmp	file_result

fopen	endp

;==================================================================================

fread	proc C, Handle:word, Buffer:dword, Count:word

;==================================================================================

	mov	bx, Handle
	push	ds
	lds	dx, Buffer
	mov	cx, Count
	mov	ah, 3fh
	int	21h
	jmp	file_result

fread	endp
;==================================================================================


;==================================================================================

fwrite	proc C, Handle:word, Buffer:dword, Count:word

;==================================================================================

	mov	bx, Handle
	push	ds
	lds	dx, Buffer
	mov	cx, Count
	mov	ah, 40h
	int	21h
	jmp	file_result

fwrite	endp
;==================================================================================

;==================================================================================

fputc	proc C, Handle:word, Char:byte

;==================================================================================

	mov	bx, Handle
	push	ds
	lea	dx, Char
	mov	cx, 1
	mov	ah, 40h
	int	21h
	jmp	file_result

fputc	endp
;==================================================================================

fputw	proc C, Handle:word, Value:word

;==================================================================================

	mov	bx, Handle
	push	ds
	lea	dx, Value
	mov	cx, 2
	mov	ah, 40h
	int	21h
	jmp	file_result

fputw	endp

;==================================================================================

;==================================================================================

fclose	proc C, Handle:word

;==================================================================================

	mov	bx, Handle
	mov	ah, 3eh
	int	21h
file_error::
	.if	! carry?
		xor	ax, ax
	.endif
	mov	FileError, ax
	ret

fclose endp
;==================================================================================


;==================================================================================

fflush	proc C, Handle:word

;==================================================================================

	mov	bx, Handle
	mov	ah, 68h
	int	21h
	jmp	file_error

fflush endp
;==================================================================================

fdelete	proc C, FileName : dword

;==================================================================================

	push	ds
	lds	dx, FileName
	mov	ah, 41h
	int	21h
	pop	ds
	jmp	file_error

fdelete endp

;==================================================================================

fexist	proc C, FileName : dword

	push	ds
	lds	dx, FileName
	mov	ax, 4300h	; get attributes
	int	21h
	pop	ds
	.if	carry?				; fault
		mov	FileError, ax
		xor	ax, ax
	.else
		mov	FileError, 0
		mov	ax, cx		
		or	ax, 8000h	; guarantee true
	.endif

	ret

fexist	endp



;==================================================================================

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA
	assume	si:ptr dword


extern		lastInpLink:abs

% _link870	equ	lastInpLink

	thisLink textequ <871>
	lastLink textequ <870>

;//============================================================================

forth_files	proc    near

;//============================================================================
codeword	<str!>DOS1>, NORMAL, StrToDOS1	;	( xPtr - shortPtr )
	mov	bx, offset _DOSBuffer1
	jmp	StrToDOS
	
codeword	<str!>DOS2>, NORMAL, StrToDOS2	;	( xPtr - shortPtr )
	mov	bx, offset _DOSBuffer2

StrToDOS:

	push	esi
	push	bx

	mov	esi, [si]
	.repeat
		mov	al, [esi]
		mov	[bx], al
		inc	esi
		inc	bx
	.until	!al

	pop	ax
	pop	esi

	jmp	PokeShortAX


codeword	<fcreate>, NORMAL;// ( word: Mode, word: es:FileName - word: handle )

	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	word ptr [si+2], ds			; supply segmented address
	invoke	fcreate, word ptr [si-4], dword ptr [si]
	sub	si, 4
	jmp PokeShortAX

codeword	<fopen>, NORMAL;// ( Mode:word, word: es:FileName - word: handle )

	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	word ptr [si+2], ds			; supply segmented address
	invoke	fopen, word ptr [si-4], dword ptr [si]
	sub	si, 4
	jmp PokeShortAX

codeword	<fread>, NORMAL;// (Handle:word, word: es:Buffer, word: Count - word: handle )

	;mov	ax, [si]	; count
	mov	word ptr [si-2], es
	invoke	fread, word ptr [si-8], dword ptr [si-4], word ptr [si]
	sub	si, 8
	jmp PokeShortAX

codeword	<fwrite>, NORMAL;// ( Handle:word, Buffer:dword, Count: word	- word: bytes written )

	;mov	ax, [si] ; count
	.if	word ptr [si-2]==0	;	is buffer in extended memory?
		mov	word ptr [si-2], ds
		invoke	fwrite, word ptr [si-8], dword ptr [si-4], word ptr [si]
	.else
		mov	ax, word ptr [si]
	.endif
	sub	si, 8
	jmp PokeShortAX	;	ax = bytes written

codeword	<fputc>, NORMAL;// ( Handle:word, char: word -  )

	invoke fputc, word ptr [si-4], byte ptr [si] 
	sub	si, 4
	jmp PokeShortAX

codeword	<fputs>, NORMAL; ( word: handle word: s - bytes remaining to be written )
	mov	bx, word ptr [si]
	movzx	ax, byte ptr es:[bx]
	push	ax
	inc	bx
	invoke	fwrite, word ptr [si-4], es::bx,  ax
	.if	carry?
		mov	err_no, ERR_FILE_WRITE
	.endif
	sub	si, 4
	pop	bx
	sub	bx, ax	; # bytes still to be written
	mov	ax, bx
	jmp PokeShortAX


codeword	<fclose>, NORMAL;// ( Handle:word- word: handle )

	invoke	fclose, word ptr [si]
	jmp PokeShortAX

codeword	<fflush>, NORMAL;// (Handle:word - word: handle )

	invoke	fflush, word ptr [si]
	jmp PokeShortAX

codeword	<fdelete>, NORMAL;// ( FileName : dword- word: handle )

	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	word ptr [si+2], ds			; supply segmented address
	invoke	fdelete, dword ptr [si]
	jmp PokeShortAX


codeword	<fexist>, NORMAL;// (FileName : dword - word: handle )

	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	word ptr [si+2], ds			; supply segmented address
	invoke	fexist, dword ptr [si]
	jmp PokeShortAX

codeword	<fgettime>, NORMAL;  ( handle - time, date )

	mov	bx, word ptr [si]
	mov	ax, 5700h
	int	21h
	.if	carry?
		xor	cx, cx
		mov	dx, cx
	.endif
	mov	word ptr [si], cx
	mov	word ptr [si+2], dx
	ret

codeword	<fsettime>, NORMAL;	( handle,time, date - )

	mov	dx, word ptr [si]
	mov	cx, word ptr [si-4]
	sub	si, 8
	mov	bx, word ptr [si]	;	handle
_fst:
	mov	ax, 5701h
	int	21h
	mov	ax, 0
	sbb	ax, 0
	jmp PokeShortAX

codeword	<fredate>, NORMAL; ( time, date, asciiz - )
;	????????????

	mov	eax, dword ptr [si]
	mov	dword ptr [si], 0
	add	si, 4
	mov	dword ptr [si], eax
	call	___fopen
	mov	bx, word ptr [si]	; handle in bx
	sub	si, 8
	.if	bx
		mov	dx, word ptr [si+4]
		mov	cx, word ptr [si]
		call	_fst
		invoke	fclose, bx
	.endif
	ret
	
codeword	<filecrc>, NORMAL	; (fname - crc)

	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	word ptr [si+2], ds			; supply segmented address
	mov	dx, word ptr [si]		; pointer to filename
	mov	ax,3d00h		; open file for al=0=read only
	int	21h
	jc	file_error

	push	ax			; file handle

	invoke	fhCRC, ax
	and	eax, 0FFFFh
	pop	bx			; file handle
	pushf				; save carry flag to show error
;	push	dword ptr [si]			; save pointer to filename
	mov	dword ptr [si], eax		; put result on stack

	mov	ah,3eh			; close file
	int	21h

;	pop	eax			; restor pointer to filename
;	invoke	AsciizToFstr, eax	; convert back to forth string
	mov	ax, word ptr [si]		; result
	call PokeShortAX

	popf
	jc	file_error
	ret
	

codeword	<ferror>, NORMAL
	mov	ax, FileError
	jmp	PushShortAX

% lastFileLink =   _link&lastLink

public  lastFileLink

forth_files endp


_TEXT	ends

end
