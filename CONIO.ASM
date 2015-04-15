comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	CONIO.ASM	:	keyboard and console routines

21-02-96 Version 1.00	:	FORTHcputs, gets, inkey, FORTHmess_out, emit_al, scrollUp
				parallel interface abandonned.
				serial comms combines into inkey() and emit_al().

22-02-96 Version 1.01	+	FORTHcputs handles <Del>
			+	
12-08-96 Version 1.02	+	messaging for editBuffer

2004-09-03 Version 3.03 +	PrintString replaces FORTHmess_out

================================================================================#

option language:c


_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA

include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\serial.inc
include ..\include\hooks.inc
include ..\include\forth.inc
include ..\include\loader.inc
include ..\include\parallel.inc
include ..\include\step.inc
include	..\include\macros.inc

extern	___display:near

FunctionNumber = 160 - 1

sendMessage	proto near C, msgPtr:word

FORTHcputs	proc	near C, source:dword

	invoke	PrintString, source, ds
	ret

FORTHcputs	endp

;===================================================================================

editBuffer	proc	near C public uses di si es, buffer:word, template:word, field:word

;===================================================================================


	invoke	editBuffer_setup, template, field
	invoke	editBuffer_enable
	.repeat
	  poll
	.until	editBuffer_lineReady
	invoke	editBuffer_disable
	ret


editBuffer	endp
;===================================================================================

editBuffer_setup	proc	near C public uses edi esi es , template:word, field:word

;===================================================================================


	mov	editBuffer_insert, 1
	mov	editBuffer_ccount, 0
	mov	editBuffer_lineReady, 0
	mov	ax, ds
	mov	es , ax
;	invoke	LoadSegment, 'es', ds , cs, 1000h ;seg _TEXT, seg _TEXT+1000h
	mov	ah, 3
	mov	bh, videopage
	int	10h		;	x=wherex(); y=wherey();
	mov	editBuffer_x, dl
	mov	editBuffer_y, dh

	movzx	esi, template
	
	xor	edi, edi
	mov	di, offset _FORTH_DATA:editBuffer_line+1
	mov	cx, field
	mov	editBuffer_lineLength, cx
	cld
	mov	cx, 75
	.if	si
@@:	  lodsb			; strncpy(buff, template, maxlen);
	  stosb
	  and	al, al
	  loopnz	@b
	  jcxz	@f
	  dec	di
	  inc	cx
	.endif
	mov	al, ' '
	cld
	rep	stosb		; for(i=strlen(buff);i<field;i++) buff[i]=' ';	/* padding on RHS	*/

@@:	mov	byte ptr [di], 0; buff[field]='\0';				/* terminator		*/
	xor	eax, eax
	mov	ax, offset editBuffer_line+1
	invoke	FORTHcputs, eax

	ret


editBuffer_x		db	0
editBuffer_y		db	0
editBuffer_ccount	dw	0
editBuffer_insert	db	0
editBuffer_lineReady	db	0
editBuffer_lineLength	dw	0


editBuffer_setup	endp

;===================================================================================

editBuffer_enable	proc	near C public uses edi si es

;===================================================================================

	call	editBuffer_gotoxy
	push	ds
	push	cs
	pop	ds
	assume	ds: _TEXT

	xor	edi, edi
	mov	di, offset hbMsg_EditBuffer
	mov	ds:[di+8], cs
	mov	ds:[di+6], offset editBuffer_messageHandler
	mov	cx, 0f000h
	mov	ax, 0010h	; MESSAGE
	mov	dx, 0
	int	80h
	pop	ds
	assume	ds:_FORTH_DATA
	ret
db 	'editBuffer_messageHandler', 25
dd	0
hbMsg_EditBuffer	HookBlockShort { 0, 0, editBuffer_messageHandler }

editBuffer_enable	endp

;===================================================================================

editBuffer_disable	proc	near C public uses edi ds

;===================================================================================

	push	cs
	pop	ds
	xor	edi, edi
	mov	di, offset _TEXT:hbMsg_EditBuffer
	mov	ax, 0110h	; uninstall MESSAGE
	int	80h
	ret

;include	padding.asm	- crashes

editBuffer_disable	endp
;================================================================================

editBuffer_messageHandler	proc far

;================================================================================

	assume	ds:nothing


;	ds:dx -> message provides keystroke
;	now interpret keystroke
;	2015-01-16 converted to extended addressing

	push	edi
	mov	edi, edx
	.if	byte ptr [edi] != MSG_KBD_CHAR
	  pop	edi
	  ret
	.endif


	or	byte ptr [edi+2], 80h		; done
	mov	ax, [edi+4]			; get character
	
	push	edx
	push	ds
	mov	ds , FORTHds		; FORTHds is in _TEXT, so accessible via cs:
;	invoke	LoadSegment, 'ds', FORTHds , cs, 1000h ;seg _TEXT, seg _TEXT+1000h
	assume	ds:_FORTH_DATA
	push	HostControl
	and	HostControl, NOT COMMS_OUT_ENABLE
	mov	di, offset _TEXT:termCharList
	mov	cx, lengthof termCharList
	push	cs
	pop	es

	cld
	repne	scasw		; test for a terminating character

	.if	zero?

		mov	al, byte ptr editBuffer_lineLength
		mov editBuffer_line, al
		mov	word ptr (msgKBL.infoPtr), offset _FORTH_DATA:editBuffer_line
		mov	word ptr (msgKBL.infoPtr+2), ds
		broadcast msgKBL
		jmp	return

		msgKBL	Message{MSG_KBD_LINE, 1, 2, 0 }

	.endif
;==========================================================================

;	else check for special character

	  push	ds
	  pop	es

	  xor	edi, edi			; extended pointer MSW = 0
	  mov	di, offset _FORTH_DATA:editBuffer_line+1
	  add	di, editBuffer_ccount	; point to current position
	  assume di: ptr byte

	  .if (ax == kbBack) || ( ax == (kbBack OR 0FF00h))	; case BS:

	    .if editBuffer_ccount
			mov	cx, editBuffer_lineLength
			sub	cx, editBuffer_ccount
			dec	editBuffer_ccount
			mov	si, di
			dec	di
			push	edi			; save extended new current position
			cld
			rep	movsb
			mov	byte ptr [di], ' '
			call	editBuffer_gotoxy
			pop	edi
			invoke	FORTHcputs, edi
	    .endif

	  .elseif (ax==kbIns)||(ax==kbInsGray)

	    inc	editBuffer_insert;			;	ins++; ns++; break;

	  .elseif (ax==kbHome)||(ax==kbHomeGray)

	    mov editBuffer_ccount, 0		;	ccount=0; ns++; break;

	  .elseif (ax==kbEnd)||(ax==kbEndGray)

	    mov	cx, editBuffer_lineLength
	    mov	di, offset _FORTH_DATA:editBuffer_line+1 ; for(ccount=field-1;ccount;ccount--)
	    add	di, cx
@@:	    dec	di
	    cmp	byte ptr [di], ' '
	    loope @b
	    inc	di
	    sub	di,offset _FORTH_DATA:editBuffer_line+1
	    mov	editBuffer_ccount, di

	  .elseif (ax==kbRight)||(ax==kbRightGray); case	RtArrow:

	    mov	cx, editBuffer_ccount
	    .if cx < editBuffer_lineLength		;	if(ccount<field) ccount++;
		inc	editBuffer_ccount
	    .endif			;	ns++; break;

	  .elseif (ax==kbLeft)||(ax == kbLeftGray)

	    .if editBuffer_ccount			;	if(ccount)
		dec	editBuffer_ccount		;	  ccount--;
	    .endif			;	ns++; break;
	  .elseif (ax==kbDel)||(ax==kbDelGray)	; case	Delete:
	    mov	cx, editBuffer_lineLength
	    sub cx, editBuffer_ccount
	    .if	!zero?			;	if(ccount<field)
					;	{
			push	edi		; save current position
			.repeat
				mov	al, [di+1]
				mov	[di], al
				inc	di
			.untilcxz
			mov	[di], ' '
			pop	edi
			invoke	FORTHcputs, edi		; di already on stack invoke	FORTHcputs, di
	    .endif
	    
comment #
			  case	CtrlDelete:	for(i=ccount;i<field;buff[i++]=' ');
						ns++;
						FORTHcputs(buff+ccount);
						break;

			  case	UpArrow:	ccount=0;
						gotoxy(x,y);
						if(this_line==empty) this_line=history;
						else
						{
						  this_line+=strlen(this_line)+1;
						  if(strlen(this_line)==0) this_line=empty;
						}
						strcpy(buff,this_line);
						for(i=strlen(buff);i<field;i++) buff[i]=' ';	/* padding on RHS	*/
						buff[field]='\0';		/* terminator		*/
						FORTHcputs(buff);
						ns++;
						break;

			  case DnArrow:		ccount=0;
						gotoxy(x,y);
						if(this_line==history)this_line=empty;
						else
						{
						  if(this_line==empty) this_line=last_char;
						  while((--this_line>history)&&(*(this_line-1)));
						}
						strcpy(buff,this_line);
						for(i=strlen(buff);i<field;i++) buff[i]=' ';	/* padding on RHS	*/
						buff[field]='\0';		/* terminator		*/
						FORTHcputs(buff);
						ns++;
						break;

			}
			break;

#
	  .elseif	ax==kbEsc
	    jmp ___bye

	  .elseif	al<' '		; non printable char - eg F1-9 etc
	    jmp	return

	  .else				; default:	if(ns)

	    mov	cx, editBuffer_lineLength
	    .if	cx > editBuffer_ccount		; if(ccount<field)
		.if	(editBuffer_insert&1)	;	if(ins&1)
		  dec	cx
		  mov	di, offset _FORTH_DATA:editBuffer_line+1
		  add	di, cx
		  sub	cx, editBuffer_ccount
		  jcxz	@f
		  lea	si, [di-1]
		  std
		  rep	movsb
		  cld
		.endif
@@:		mov	di, offset _FORTH_DATA:editBuffer_line+1
		add	di, editBuffer_ccount
		
		mov	[di], al	;	buff[ccount]=c;
		movzx	eax, di
		invoke	FORTHcputs, eax  ;	FORTHcputs(buff+ccount);
		inc	editBuffer_ccount;	ccount++;
	    .endif			; }
	.endif

return:

	call	editBuffer_gotoxy
	pop	HostControl
	pop	ds
	pop	edx
	pop	edi
	ret

editBuffer_gotoxy::
	mov	dl, editBuffer_x
	add	dx, editBuffer_ccount
	mov	dh, editBuffer_y
	mov	ah, 2
	mov	bh, videopage
	int	10h		; gotoxy(x+ccount,y);
	retn

termCharList dw kbEnter, kbEnterNum, kbCtrlEnter, kbCtrlEnterNum,\
	kbUpGray, kbDownGray, kbPgUpGray, kbPgDnGray,\
	kbShiftLeft, kbShiftRight, kbShiftUp, kbShiftDown,\
	kbShiftIns, kbShiftInsGray, kbShiftDel, kbShiftDelGray,\
	kbCtrlUpGray, kbCtrlDownGray, kbCtrlHomeGray, kbCtrlEndGray,\
	kbCtrlPgUpGray, kbCtrlPgDnGray, kbCtrlInsGray, kbCtrlDelGray,\
	07F00h, 0ff00h
;kbEsc,

;kbBack         = 0E08h
;kbCtrlBack     = 0E7Fh
;kbTab          = 0F09h
;kbShiftTab     = 0F00h
;kbCtrlLeftGray ,
;kbCtrlRightGray = 74E0h
;================================================================================

editBuffer_messageHandler	endp

;===================================================================================

sendMessage	proc near C uses ds , msgPtr:word

;===================================================================================

	mov	dx, msgPtr
	push	cs
	pop	ds
	mov	ah, MESSAGE
	mov	al, 1
	int	80h
	ret

sendMessage	endp

;===================================================================================

gets	proc	near C public uses di si es, buffer:dword, template:word, field:word

;===================================================================================


	assume	ds:_FORTH_DATA
	assume	di:nothing

	and	HostControl, NOT COMMS_OUT_ENABLE

	invoke	editBuffer_setup, template, field
	invoke	editBuffer_enable

	.repeat
	  call 	___idle
	  invoke getInputLine, buffer, field
	.until	ax
	invoke	editBuffer_disable
	invoke	LTStringToAsciiz, buffer

return:
	or	HostControl, COMMS_OUT_ENABLE

	ret


;================================================================================

gets	endp

;================================================================================


;================================================================================

getInputLine	proc far C, buffPtr:dword, nBytes:word

;================================================================================

	mov	eax, buffPtr
	mov	destBuff, eax
	mov	ax, nBytes
	mov	MaxCount, ax
	
	mov	bctrl, cfWaiting
	poll
	 xor	ax, ax
	.if	( bctrl & cfReady )
	  dec	ax
	.endif
	mov	bctrl, 0
	ret

;include	padding.asm - crashes

getInputLine_handleMessage label far

	push	di
	mov	di, dx
	assume	di:ptr Message
	mov	ah, [di].number
	.if	(ah == MSG_KBD_LINE)||\
		(ah == MSG_HOST_BINARY)||\
		(ah == MSG_HOST_COMMAND)||\
		(ah == MSG_HOST_DATA)


	  .if	bctrl & cfWaiting
		;mov	inputSource, ah		; problem - ds=cs when handler runs
				; ds should be = ForthDS
		invoke	ShowStateChange, '. '
		mov	[di].dest, mfDone

		or	[di].dest, mfFinished
		mov	bctrl, cfReady

		push	es
		push	ds
		push	si

		lds	si, [di].infoPtr	; -> [n][B1..Bn] (ie FORTH string)
		les	di, destBuff	; in CS segment (NB: lost di pointer to message)
		assume	di:nothing

		; si is now pointing to data - this could be in form of FString, or 
		; Long Typed String (LTString) [CountLow, CountHi, Type, bytes..................] from comms input
		
		; translate all into LTString format
		mov	cx, [si]	; get count (may include first byte of data in MSB, if FString format)
		.if	ah==MSG_KBD_LINE	; KBD_LINE provides FString, so create new count, and substitute type 'K' for one byte count
			xor	ch, ch
			add	cx, 3	; to include Count and Type bytes
			
			.if	cx>MaxCount			; protect overfilling of destination buffer
				mov	cx, MaxCount
				; error code?
			.endif
			dec	cx
			dec	cx
			mov	es:[di], cx
			inc	di
			inc	di
			mov	byte ptr es:[di], 'K'
			inc	di
			inc	si	; skip original length byte
			dec	cx
		.else
			inc	cx			; transfer block complete with count
			inc	cx
			.if	cx>MaxCount			; protect overfilling of destination buffer
				mov	cx, MaxCount
				; error code?
			.endif
		.endif
		
		
		cld
		rep	movsb

		pop	si
		pop	ds
		pop	es
		.endif
		call	___nosound
	.elseif ah==MSG_SEND_PACKET
;	  call	___nosound
	.endif
	pop	di
	retf

	assume	di: nothing

bctrl		db	0
destBuff	dd	0
MaxCount dw 0
msgDump		db	CR, LF, "Unrecogized message :", CR,LF, 0
;hbMsg_getInputLine	HookBlockShort	{ 0, _getInputLine_handleMessage }
;public	hbMsg_getInputLine


comment #
	from original gets

;	push	ds		; setup gets message handler
;	push	cs
;	pop	ds
;	assume	ds: _TEXT
;	mov	di, offset _TEXT:hbMsg_gets
;	mov	[di+6], cs
;	mov	cx, 08000h
;	mov	ax, 0010h	; MESSAGE
;	mov	dx, 0
;	int	80h
;	pop	ds
;	assume	ds:_FORTH_DATA

	push	ds		; unhook message handler
	push	cs
	pop	ds
	assume	ds: _TEXT
	mov	di, offset _TEXT:hbMsg_gets
	mov	ax, 0110h	; MESSAGE
	int	80h
	pop	ds
	assume	ds:_FORTH_DATA

#

getInputLine	endp

;================================================================================

PrintString	proc near C uses ax ebx cx es, Source:dword, SourceSeg:word

;================================================================================

	mov	ebx, dword ptr Source
	mov	es, SourceSeg
	
	mov	ah, 03h
	int	10h		; return cursor limits in cx
	push	cx
	mov	ah, 01h
	mov	ch, 20h		; invisible cursor
	int	10h

@@:	mov	al, es:[ebx]
	and	al, al
	je	@f

	call	emit_al
	inc	ebx
	jmp	short	@b

@@:	pop	cx
	mov	ah, 01h
	int	10h
	ret

PrintString endp



inkey	proc near	public

	mov	ah, 11h
	int	16h
	.if	zero?			; nothing from kbd so test comms
	
;	  call	incom

	.else
	  mov	ah, 10h
	  int	16h			; get unmapped key
	  mov	bx, offset cs:keymap	; in CS space
	  .while word ptr cs:[bx]

		.if	ax == cs:[bx]
		  mov	ax, cs:[bx+2]
		  .break
		.endif
		add	bx, 4
	  .endw
	.endif
	retn

keymap	label	word
include	usa2uk.map

inkey	endp

emit_al	proc near	public


	push	bx
	push	cx
	push	dx

	.if	(HostControl & COMMS_OUT_ENABLE)&&(HostControl & COMMS_OUT_ON)
	  push	ax
	  call	pOutChar
	  pop	ax
	.endif

	mov	bl, colour
	mov	bh, videopage
	mov	cx, 1
	push	ax
	.if	(al!=0ah)&&(al!=0dh)		; line feed/carriage return
	  mov	ah, 09h
	  int	10h
	.endif
	mov	ah, 03h
	int	10h
	pop	ax
	.if	al==0ah
	  inc	dh
	.elseif	al==0dh
	  sub	dl, dl
	.else
	  inc	dl
	.endif
	.if	dl>=80
	  xor	dl, dl
	  inc	dh
;	  .if	(HostControl & COMMS_OUT_ENABLE)&&(HostControl & COMMS_OUT_ON)
;	   invoke pOutChar, CR
;	   invoke pOutChar, LF
;	  .endif
	.endif

	push	bx
	mov	bl, bh
	xor	bh, bh
	add	bl, bl

	.if	dh>= 25; byte ptr pagesize[bx+1]
	  call	scrollUp
comment #
	  mov	dx, bx
	  mov	ah, 0fh		; get video mode/currently active page
	  int	10h
	  push	bx
	  mov	bx, dx		; original active page
	  mov	al, bh
	  mov	ah, 5
	  int	10h		; display page set to active page

	  mov	al, 0ah
	  mov	ah, 0eh
	  int	10h		; CR in TT mode
	  pop	bx		; original display page
	  mov	al, bh
	  mov	ah, 5
	  int	10h
	  mov	bx, dx		; original active page
#
	  mov	dh, 25; byte ptr pagesize[bx+1]
	  dec	dh
	  mov	dl, 0
	.endif

	pop	bx
	mov	ah, 02h
	int	10h
	pop	dx
	pop	cx
	pop	bx
	ret

emit_al	endp

outPacket	ShortPacket{}
public outPacket
currentStream	db	0
public currentStream
msgSendPkt	Message{ MSG_SEND_PACKET, 0, 0, 0 }
public msgSendPkt
messageQueue	dw	32 dup(0)
public messageQueue

queueMessage	proc	near C, msgPtr : word

	.if	!messageQueue[62]
	  mov	bx, 0
	  .while messageQueue[bx]
	    add	bx, 2
	  .endw
	  mov	ax, msgPtr
	  mov	messageQueue[bx], ax
	  xor	ax, ax
	.endif
	ret

queueMessage	endp

unqueueMessage	proc	near C

	push	messageQueue
	xor	bx, bx
	.repeat
	  mov	ax, messageQueue[bx+2]
	  mov	messageQueue[bx], 2
	  add	bx, 2
	.until	!ax

	pop	ax
	ret

unqueueMessage	endp

comment #
		    call unqueueMessage
		    .if	ax
		      xor	bx, bx
		      push	si
		      mov	si, ax
		      .repeat
			mov	al, byte ptr [si]
			inc	si
			inc	bx
			mov	outDATA.pdata[bx], al
		      .until	!al
		      pop	si
		      mov	outDATA.pdata, 'M'	; message
		      mov	outprogress, 1		; packet still to go
		    .else

#

pSetStream	proc	near C, streamID : byte

	mov	al, streamID
	.if	al!=currentStream
	  call	pOutFlush
	.endif
	mov	al, streamID
	mov	currentStream, al
	ret

pSetStream	endp

pOutChar	proc	near C uses si, char:byte

	;	append char to the current packet and transmit if necessary

	mov	al, outPacket.plength
	xor	ah, ah
	mov	si, ax
	mov	al, char
	inc	si
	mov	outPacket.pdata[si], al
	mov	ax, si
	mov	outPacket.plength, al
	.if	(char==LF)||(si>=255)
	  call	pOutFlush
	.endif
	ret
pOutChar	endp

pOutByte	proc	near C uses si, value:byte

	;	append byte to the current packet and transmit if necessary

	movzx	si, outPacket.plength
	mov	al, value
	inc	si
	mov	outPacket.pdata[si], al
	mov	ax, si
	mov	outPacket.plength, al
	.if	si>=240
	  call	pOutFlush
	.endif
	ret
pOutByte	endp

pOutFlush	proc near C uses dx si

	mov	al, currentStream
	.if	(al) && (outPacket.plength) ; if not nul stream and data

	  mov	outPacket.pdata[0], al
	  inc	outPacket.plength
	  mov	word ptr msgSendPkt.infoPtr, offset _TEXT:outPacket
	  mov	word ptr msgSendPkt.infoPtr+2, cs
	  and	HostControl, NOT COMMS_OUT_ENABLE

	  call	___outFlush ; direct call to function in FTH-COM.ASM

	  .repeat

	    ; inform handlecomms of pending packet

	    invoke sendMessage, offset _TEXT:msgSendPkt


	  .until	msgSendPkt.dest & mfFinished

	  ; attempt to shift remains of packet for diagnostic purposes

	  ; call	___outFlush ; direct call to function in FTH-COM.ASM

	  or	HostControl, COMMS_OUT_ENABLE
	.endif
	mov	outPacket.plength, 0
	ret

;include	padding.asm -  crashes

pOutFlush	endp



scrollUp	proc	near uses ds es ax cx dx si di

	mov	dh, colour
	mov	dl, ' '

	mov	cl, videopage
	xor	ch, ch
	add	cx, cx
	mov	si, cx
	mov	cx, pagesize[si]	; cl = start row, ch = stop row

	mov	al, 160
	mul	cl
	mov	di, ax

	lea	si, [di+160]		; next line down
	sub	ch, cl
	mov	al, 160
	mul	ch
	mov	cx, ax

	mov	ax, 0b800h
	add	ah, videopage
	mov	es , ax		; point es , ds to screen
	mov	ds , ax
;	invoke	LoadSegment, 'ds', ax , 0B800h, 250
;	invoke	LoadSegment, 'es', ax , 0B800h, 250


	cld
	rep	movsw		; shift up 1 line (80 words)

	mov	ax, dx
	mov	cx, 80
	rep	stosw		; blank the bottom line

	ret

scrollUp	endp



% LastCONIOFunction = FunctionNumber
public LastCONIOFunction


_TEXT	ends

end

