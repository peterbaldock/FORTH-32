comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-BLK.ASM	:	Forth Block Buffer functions

21-02-96 Version 1.00	:	

================================================================================#

option language:c

include forthmac.asm
include ..\include\pcatkeys.inc
include	..\include\serial.inc
include ..\include\forth.inc
include	FTH-ERRS.inc



_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern      lastDicLink:abs
;externdef  _vocabulary:near
% _link600  equ lastDicLink

    thisLink textequ <601>
    lastLink textequ <600>

forth_blk	proc    near

Code_word	<!>in>, NORMAL, to_in
	mov	ax, offset	ds:instream
	jmp	PushShortAX

Code_word	blk, NORMAL
	mov	ax, offset	ds:blk_addr
	jmp	PushShortAX

Code_word	<buffer>, NORMAL
	mov	ax,[si]
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	cmp	ax, ds:b1_blk
	mov	bx, offset ds:buf_ptr1
	jne	try_buf2
	test	ds:b1_stat, 2
	jne	no_update2
try_buf2:
	cmp	ax, ds:b2_blk
	mov	bx, offset ds:buf_ptr2
	jne	try_buf1
	test	ds:b2_stat, 2
	jne	no_update2
try_buf1:
	cmp	bx, ds:last_blk
	jne	buf_selected
	mov	bx, offset ds:buf_ptr1
buf_selected:
	test	byte ptr [bx-2],80h
	je	no_update
	push	ax
	push	bx
	call	write_buff
	pop	bx
	pop	ax
	mov	byte ptr [bx-2],3
no_update:
	stc
	mov	[bx-4],ax
no_update2:
	pushf
	mov	ax,[si]
	and	ax, 15
	xchg	ah,al
	shl	ah, 1
	shl	ah, 1
	add	ax,[bx]
	mov	[si],ax
	mov	ds:last_blk, bx
	popf
	ret

write_buff:
	call	form_name
to_disk:
	push	bx
	mov	dx, offset ds:scrname
	mov	cx, 0
	mov	ah,3ch
	int	21h
	jc	bad_flush
	mov	dx,[bx]
	mov	bx,ax
	mov	cx, 4000h
	mov	ah, 40h
	int	21h
	jc	bad_flush
	mov	ah,3eh
	int	21h
	jc	bad_flush
	pop	bx
	mov	byte ptr [bx-2],3
	ret

bad_flush:
	pop	bx
	add	ax, ERR_BAD_FLUSH
	mov	ds:err_no, ax
	call	FORTHabort
	db	' : Buffer write error', 13, 10, 0

form_name:
	mov	cx,[bx-4]
	mov	ch,cl
	and	ch, 0fh
	shr	cl, 1
	shr	cl, 1
	shr	cl, 1
	shr	cl, 1
	and	cl, 0fh
	add	cx,3030h
	cmp	cl,'9'
	jle	ok_rt
	add	cl,7
ok_rt:	cmp	ch,'9'
	jle	ok_lt
	add	ch,7
ok_lt:
	mov	bx, offset scrname
	.while	byte ptr [bx] != '#'
	  inc	bx
	.endw
	inc	bx
	mov	[bx], cx
	ret

Code_word	<block>, NORMAL
	push	[si]
	call	___buffer
	pop	cx
	pushf
	cmp	cx, 0
	jle	no_read2
	popf
	jc	read_block
no_read:
	ret
no_read2:
	popf
	ret

read_block:
	mov	ds:last_blk, bx
	call	form_name
	mov	dx, offset ds:scrname
	mov	ax,3d00h
	int	21h
	jc	bad_read
	mov	cx, 4000h
	mov	dx,[bx]
	mov	byte ptr [bx-2],3
	mov	bx,ax
	mov	ah,3fh
	int	21h
	mov	ah,3eh
	int	21h
	jc	bad_read
	ret

bad_read:
	mov	bx, ds:last_blk
	mov	word ptr [bx-2], 0
	add	ax, ERR_BAD_READ
	mov	ds:err_no, ax
	call	FORTHabort
	db	' : Buffer read error', 10, 13, 0

Code_word	<wipe>, NORMAL
	call	___buffer
	mov	ax,2020h
	mov	cx,200h
	mov	bx,[si]
	sub	si, 4
wipe_loop:
	mov	[bx],ax
	inc	bx
	inc	bx
	loop	wipe_loop
update::
	mov	bx, ds:last_blk
	test	byte ptr [bx-2],2
	je	cant_update
	or	byte ptr [bx-2],80h
	ret

cant_update:
	mov	ax, ERR_UPDATE
	call	FORTHabort
	db	' : Update Error - bad block', 13, 10, 0


Code_word	<copy>, NORMAL
	call	___swap
	call	___block
	call	___swap
	call	___block
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es , ax
;	invoke	LoadSegment, 'es', ds, cs, 1000h ;seg _TEXT, seg _TEXT+1000h
	mov	di,[si]
	mov	si,[si-2]
	mov	cx,512
	cld
	rep	movsw
	pop	es
	pop	di
	pop	si
	sub	si, 4
	jmp	update

Code_word	<flush>, NORMAL
	mov	bx, offset ds:buf_ptr1
	call	flushn
	mov	bx, offset ds:buf_ptr2
flushn:
	test	byte ptr [bx-2], 80h
	je	next_buf
	mov	cx, [bx-4]
	call	write_buff
next_buf:
	ret

Code_word	<empty-buffers>, NORMAL, empty_buffers
	mov	ds:b1_stat, 0
	mov	ds:b2_stat, 0
	mov	ds:b2_blk, 0
	mov	ds:b1_blk, 0
	ret

Code_word	<update>, NORMAL
	jmp	update

% lastBlkLink =   _link&lastLink

public  lastBlkLink
    
forth_blk   endp

_TEXT	ends

end

