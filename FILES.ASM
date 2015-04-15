comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-FILE.ASM	:	Forth File I/O routines

2009-04-06 Version 4.11 + fcreate, fopen, fwrite, fread, fclose, fflush.

fcreate	proc C uses ds, Mode: word, FileName : dword
fopen	proc C uses ds, Mode:word, FileName:dword
fread	proc C uses ds, Handle:word, Buffer:dword, Count:word
fwrite	proc C uses ds, Handle:word, Buffer:dword, Count:word
fclose	proc C, Handle:word
fflush	proc C, Handle:word
fdelete	proc C uses ds, FileName : dword
fexist	proc C uses ds, FileName : dword

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

fcreate	proc C uses ds, Mode: word, FileName : dword

;==================================================================================

	mov	cx, Mode
	lds	dx, FileName
	mov	ah, 3ch
	int	21h
file_result::
	.if	carry?
	  mov	err_no, ax
	  xor	ax, ax
	.endif
	
	ret

fcreate endp

;==================================================================================

fopen	proc C uses ds, Mode:word, FileName:dword

;==================================================================================

	mov	ax, Mode
	lds	dx, FileName
	mov	ah, 3dh
	int	21h
	jmp	file_result
	
fopen	endp

;==================================================================================

fread	proc C uses ds, Handle:word, Buffer:dword, Count:word

;==================================================================================

	mov	bx, Handle
	lds	dx, Buffer
	mov	cx, Count
	mov	ah, 3dh
	int	21h
	jmp	file_result
	
fread	endp
;==================================================================================


;==================================================================================

fwrite	proc C uses ds, Handle:word, Buffer:dword, Count:word

;==================================================================================

	mov	bx, Handle
	lds	dx, Buffer
	mov	cx, Count
	mov	ah, 40h
	int	21h
	jmp	file_result
	
fwrite	endp
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

fdelete	proc C uses ds, FileName : dword

;==================================================================================

	lds	dx, FileName
	mov	ah, 41h
	int	21h
	.if	! carry?
		xor	ax, ax
	.endif
	ret

fdelete endp

;==================================================================================

fexist	proc C uses ds, FileName : dword

	lds	dx, FileName
	mov	ax, 4300h	; get attributes
	int	21h
	.if	carry?				; fault
		xor	ax, ax
	.else
		mov	ah, -1		; guarantee true
	.endif
	
	ret
	
fexist	endp
;==================================================================================

_TEXT	ends

end
