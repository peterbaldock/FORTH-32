Comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-PKT.ASM	:	Forth Remote Host I/O routines

2012-04-04 Version 5.31 + Full 255 bytes per packet data output packet.
2009-04-06 Version 4.12 + separated from FTH-COM
			Large packet handling. "l" and "L" packets with 16 bit count. Packet buffer now a far pointer.


============	Packet Functions

Code_word	<inDATA>, NORMAL
Code_word	<outDATA>, NORMAL
Code_word	<!>packet>, NORMAL, to_packet			;	( char - len )

Code_word	<putPacketByte>, NORMAL	;	( packet - done-flag )
Code_word	<formInputPacket>, NORMAL	;	( segment:packet - done-flag )
Code_word	<handleComms>, NORMAL
Code_word	<outFlush>, NORMAL


Code_word	<rxBlock>, NORMAL			; ( esptr - count )
Code_word	<download>, NORMAL		; ( fname - longcount )


============	Diagnostic Functions

Code_word	<DropData>, NORMAL		; (  - address )
Code_word	<CorruptData>, NORMAL		; (  - address )


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

	BlockCounter	db	0
	ByteCount	dd	0
	FHandle		dw	0
	BufferSeg	dw	0
	TransferError	dw	0
	DumpFileName db "CRCDUMP.LOG", 0
	DumpHandle		dw	0
	SequenceMessage	db sizeof _SequenceMessage
	_SequenceMessage byte 0ah, 0dh, "Packet Sequence Error. Dump :", 0ah, 0dh
	CRCMessage	db sizeof _CRCMessage
	_CRCMessage byte 0ah, 0dh, "Packet CRC Error. Dump :", 0ah, 0dh
	IllegalPacketMessage	db sizeof _IllegalPacketMessage
	_IllegalPacketMessage byte 0ah, 0dh, "Illegal Packet Error. Dump :", 0ah, 0dh

_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA
	assume	si:ptr dword

externdef		lastComLink:abs
% _link100	equ	lastComLink

	thisLink textequ <101>
	lastLink textequ <100>

;==================================================================================

forth_pkt	proc	near

;==================================================================================

Rx_LED		equ	02h	; bit 1 of $307 for yellow comms indicator
DB6_Rx_LED	equ	01h	; bit 0 of $321 for yellow



BLACK_BACK	equ	00h
BLUE_BACK 	equ	10h
GREEN_BACK 	equ	20h
RED_BACK 	equ	40h
YELLOW_FORE	equ	0Eh
WHITE_FORE	equ	0Fh


;====================================	Packet Functions  =========================


;==================================================================================

Code_word	<handleComms>, NORMAL

;==================================================================================


ST_IDLE		equ	0
ST_OUT_TxDATA	equ	1
ST_OUT_WaitDACK	equ	2
ST_OUT_OnlyDACK	equ	3

ST_OUT_TxZEROS	equ	4
ST_OUT_TxRESET	equ	5
ST_OUT_WaitRACK	equ	6

ST_IN_RxHOLD	equ	1
ST_IN_TxDACK	equ	2
ST_IN_TxRACK	equ	6


	mov	bl, InState
	mov	bh, OutState
	push	ds
	mov	ax, 0b800h
	mov	ds , ax
;	invoke	LoadSegment, 'ds', 0B800h, 0B800h, 0
	mov	ah, 2fh
	mov	al, bl
	add	al, '0'
	mov	word ptr ds:[09ch], ax
	mov	al, bh
	add	al, '0'
	mov	ds:[09eh], ax
	pop	ds

	xor	ax, ax

	.if	requestCommsReset
	  mov	OutState, ST_OUT_TxZEROS        ; send 256 zeros, then 'r' packet
	  mov	InState, al

	  invoke ShowStateChange, 'z '

	  mov	requestCommsReset, al
	  mov	waitingForReset, -1
	  mov	outCount, ax
	.endif


	.if (OutState==ST_IDLE) && outProgress	;	if ( not sending )&&( data to send )
		mov	OutState, ST_OUT_TxDATA	;	  go to <beginning to send> state
		invoke ShowStateChange, 0
	.endif

;---------------------------------------------------------------------------------

	add	si, 4
	mov	word ptr[si], offset inDATA		;     try and get a packet into currentIn->buffer
	mov	[si+2], ds
	call	___formInputPacket


	mov	ax, word ptr [si]
	sub	si, 4

	.if ax && (inDATA.ptype != 0FFh)	;   if	( input packet ready )

	  mov	al, inDATA.ptype		;     get packet type

;---------------------------------------------------------------------------------

;	input packet is DATA

	.if (al=='d') || (al=='l')				;     if ( type == DATA )
		mov	ah, al
		xor	al, al
		invoke ShowStateChange, ax
		mov	al, ah
		mov	ah, inDATA.pid		;	get ID
		sub	ah, byte ptr inID 	;	compare with theory
		.if	ah			;	if ( discrepancy )

		  mov	 requestCommsReset, TRUE	;		TRUE requestCommsReset c!
		  invoke ShowStateChange, '# '  ;    ." ID error : inID="
		  invoke PacketDump, ADDR SequenceMessage, ADDR inDATA
		  invoke ShowStateChange, '#>'  ;    ." ID error : inID="

		.else				;	  else


		  .if	(OutState==ST_OUT_OnlyDACK) && (InState!=ST_IN_RxHOLD)
			mov requestCommsReset, TRUE
			invoke ShowStateChange, '£ '
			invoke PacketDump, ADDR SequenceMessage, ADDR  inDATA
		  .endif

		  .if	OutState==ST_OUT_WaitDACK
			mov OutState, ST_OUT_OnlyDACK
		  .endif
		.endif

		.if (!requestCommsReset)
			pusha



		    .if InState!=ST_IN_RxHOLD	   ; packet only just recvd

			mov	cx, inDATA.plength


			.if	cx							; if any data
			  xor	ax, ax			; clear CRC accumulator
			  mov	bl, inDATA.ptype
			  call	crc16
			  mov	bl, inDATA.pid
			  call	crc16
			  mov	bl, byte ptr inDATA.plength
			  call	crc16

			  .if	ch
			    invoke	ShowStateChange, 'LL'
			    mov	bl, ch
			    call crc16
			  .endif

			  push	si              ; if not checked
			  push	es
			  
			  les	si, inDATA.pdataPtr	; point to start of block - in FORTH ds segment, so no override
			  inc	si
			  inc	si
			  .repeat
			    mov	bl, byte ptr es:[si]  ; get byte
			    inc	si                 ; point to next byte
			    call crc16             ; do CRC with current byte
			  .untilcxz                ; for total length

			  ;sub	ax, es:[si]	; difference in CRCs
			  
			  .if	ax == word ptr es:[si]      ; (si pointing to 16 bit CRC on end of block)

			  	mov	bx, offset inDATA; point to packet header
				assume bx:ptr PacketHeader
				mov di, offset msgPKT
				assume di:ptr Message

				mov	cx, [bx].plength	; length - could be short or long
				les	bx, [bx].pdataPtr	; far pointer to data
				assume bx:nothing
				mov	al, es:[bx+2]
				mov	es:[bx], cx			; preface data with count
				
				;	Data format is now :
				
				;		Byte 0		|		Byte 1		|		Byte 2		|	Byte 3
				;	LengthLow	| 	Length High |	DataType	| 	Data................

				;	This allows for data blocks up to 64k
				
				.if	al=='M'
					mov	al, MSG_HOST_MESSAGE
				.else
					sub	al, 'A'-MSG_PACKET_RCVD-1	; 'A'->201, 'B'->202 etc, 'L'->212
				.endif

				mov	byte ptr cs:[di].number, al
				mov	cs:[di].dest, 0
				mov	word ptr (cs:[di].infoPtr), bx
				mov	word ptr (cs:[di].infoPtr+2), es
				assume di:nothing
				assume bx:nothing
				mov	InState, ST_IN_RxHOLD	; holding data packet

				invoke ShowStateChange, 0


			  .else
					mov requestCommsReset, TRUE
					invoke ShowStateChange, '% '
					;	dump faulty packet to file
					invoke PacketDump, ADDR CRCMessage, ADDR inDATA
			  .endif

			  pop	es
			  pop	si

			.endif
		    .endif			   ; endif(inSate==ST_IN_RxDATA)

		    popa

		.endif


;---------------------------------------------------------------------------------

;	input packet is DACK


	  .elseif	al=='D'

	  ; should only be DACK if OutState = ST_OUT_WaitDACK (2) or
	  ;			   OutState = ST_OUT_OnlyDACK (3)
		  invoke ShowStateChange, 'D '
		  .if	(OutState==ST_OUT_WaitDACK) || (OutState==ST_OUT_OnlyDACK)
		    inc	outID
		    mov	outProgress, 0		; show packet gone
;		    invoke MarkFuncShow, 161, 'D'
		    mov	OutState, ST_IDLE

		      invoke ShowStateChange, 0

		  .else
		    mov	requestCommsReset, TRUE	; else reset
		    invoke ShowStateChange, '? '
			invoke PacketDump, ADDR SequenceMessage, ADDR inDATA
		  .endif

;---------------------------------------------------------------------------------

;	input packet is NACK


	  .elseif	al=='N'		; a NAK response from PC
	  ; easy case - data loss at PC end -> if OutState = ST_OUT_WaitDACK (2) or
	  ;			   OutState = ST_OUT_OnlyDACK (3)
		  invoke ShowStateChange, 'N '

		  .if	(OutState==ST_OUT_WaitDACK) || (OutState==ST_OUT_OnlyDACK)

			; simply resend the current packet, but resetting the ID
			mov outID, 0
		    mov	outProgress, 1		; show packet ready to go
;		    invoke MarkFuncShow, 161, 'N'
		    mov	OutState, ST_IDLE	; go to idle<beginning to send> state
		    mov	outCount, 0		; start from beginning again

		    invoke ShowStateChange, 0

		  .else
		    mov	requestCommsReset, TRUE	; else reset
		    invoke ShowStateChange, '! '
			invoke PacketDump, ADDR SequenceMessage, ADDR inDATA
		  .endif

;---------------------------------------------------------------------------------

;	input packet is RESET


	  .elseif	al=='r'
		  mov	InState, ST_IN_TxRACK
		  mov	currentOut, 0		; allow RACK to go immediately
		  mov	outCount, 0

		  invoke ShowStateChange, 'r '
		  invoke ShowStateChange, 0

;---------------------------------------------------------------------------------

;	input packet is RACK

	  .elseif al=='R'			;    if ( type == RACK )
			mov InState, ST_IDLE	;      reset input
			mov OutState, ST_IDLE	;      and output states

		      invoke ShowStateChange, 'R '
		      invoke ShowStateChange, 0

	  .elseif (al==0) || (al=='z')				;    if ( type == ZERO )

		      invoke ShowStateChange, 'z '

	  .elseif al=='^'			;    if ( type == BREAK )

		      invoke ShowStateChange, '^ '
		      mov	byte ptr stepping_status, ERR_BUTTON

	  .else                                 ;    else
			mov	requestCommsReset, TRUE	;      illegal packet
			mov	ah, al
			mov	al, 'X'
			invoke ShowStateChange, ax
			invoke PacketDump, ADDR IllegalPacketMessage, ADDR inDATA

	  .endif				;


	  ;	========================	End Case (input packet type)

	  ;	Flash yellow LED, to show input received
	  mov	dx, CardAddress
	  .if	CardType==50
	    add	dx, 7
	    in	al, dx
	    and	al, not (Rx_LED+128)
	    out	dx, al
	  .elseif CardType<=68
	    add	dx, 1
	    and DB6_Image01, not DB6_Rx_LED
	    mov	al, DB6_Image01
	  	out	dx, al
	  .endif


	.endif					;  end (input packet ready)

;---------------------------------------------------------------------------------

;	broadcast the receipt of a DATA input packet if there is one pending


	.if InState==ST_IN_RxHOLD

	  pusha
	  mov di, offset msgPKT
	  assume di:ptr Message
	  or	HostControl, COMMS_OUT_ON	; switch on external communications

	  push	ds
	  broadcast msgPKT
	  pop	ds

	  .if cs:[di].dest & mfDone				; if processed successfully
	    mov InState, ST_IN_TxDACK	; state changes to SendAcknowledge
	    invoke ShowStateChange, 0
	  .else
	    invoke ShowStateChange, 'QQ'
	  
	  .endif

	  popa
	  assume di:nothing
	.endif


;---------------------------------------------------------------------------------

;	( 2nd action - output functions )



	.if !currentOut					;   if ( not sending any packet )

	  .if OutState==ST_OUT_TxZEROS			;	  OutState c@ 6 = if

	    mov currentOut, offset outZERO		; 		currentOut !
	  .elseif OutState==ST_OUT_TxRESET		;	  OutState c@ 6 = if

	    mov currentOut, offset outRSET		; 		currentOut !

	  .elseif InState==ST_IN_TxDACK			;     if (due to acknowledge DATA in )

	    mov currentOut, offset outDACK		;	set pointer to reflect inDATA

	  .elseif InState==ST_IN_TxRACK			;	  InState  c@ 7 = if

	    mov	currentOut, offset outRACK		;		currentOut !

	  .elseif OutState==ST_OUT_TxDATA		;     if ( data ready to go ) is the last possibility

	    mov byte ptr outDATA, 'd'			;	mark packet as DATA
	    mov currentOut, offset outDATA		;	set pointer to outDATA buffer
	    mov cl, byte ptr outID			;
	    mov outDATA+1, cl				;	set packet ID

	  .endif					;	  then

	.endif						;	then


	.if currentOut==-1				;	currentOut @ dup -1 = if
	  inc	currentOut				;	  currentOut ++ drop 0
	.endif						;	then


	movzx	eax, currentOut
	.if	ax					;	dup if
		add	si, 4
		mov	dword ptr [si], eax				;
		call	___putPacketByte			;	  putPacketByte
		mov	eax, dword ptr [si]
		sub	si, 4
	.endif						;	then

	.if	ax					;	if	( putPacketByte TRUE )

		mov	bx, currentOut
		mov	al, [bx]			;	  get output packet type

;---------------------------------------------------------------------------------

;	output packet was DATA

		.if	al=='d'				;	  if ( type == DATA )
		  mov	OutState, ST_OUT_WaitDACK	;   	    wait for DACK

		  invoke ShowStateChange, ' d'
		  invoke ShowStateChange, 0

		.endif					;	  then

;---------------------------------------------------------------------------------

;	output packet was DACK

		.if al=='D'				;	  if ( type == DACK )
		  inc	inID
		  mov	InState, ST_IDLE

		  invoke ShowStateChange, ' D'
		  invoke ShowStateChange, 0
		    push	ax
			invoke	GetNanoTicks
			sub	eax, PacketStartTime
			.if	eax>PacketMaxTime
				mov	PacketMaxTime, eax
			.endif
			pop ax
		.endif

;---------------------------------------------------------------------------------

;	output packet was NACK

		.if al=='N'
		  mov	InState, ST_IDLE

		  invoke ShowStateChange, ' N'
		  invoke ShowStateChange, 0

		.endif

;---------------------------------------------------------------------------------

;	output packet was '\0'

		.if al==0				;	  if ( type == ZERO )
		  inc	outCount
		  .if	outCount == 256
			mov OutState, ST_OUT_TxRESET
			mov outCount, 0

			invoke ShowStateChange, ' z'
			invoke ShowStateChange, 0

		  .endif
		.endif					;	  then

;---------------------------------------------------------------------------------

;	output packet was RESET

		.if	al=='r'				;	  if ( output type == RESET )
		  mov	OutState, ST_OUT_WaitRACK	;	    change to (wait for RACK ) state
		  mov	outID, 0			;	    resynchronize
		  mov	inID, 0				;

		  invoke ShowStateChange, ' r'
		  invoke ShowStateChange, 0

		.endif					;	  then

;---------------------------------------------------------------------------------

;	output packet was RACK

		.if	al=='R'				;	  if ( output type == RACK )
		  mov OutState, ST_IDLE			;           reset states
		  mov InState, ST_IDLE			;
		  mov outID, 0				;           reset IDs
		  mov inID, 0				;

		  invoke ShowStateChange, ' R'
		  invoke ShowStateChange, 0

		.endif					;	  then


		mov	currentOut, 0			;	  NULL pointer


	.endif						;	then


	ret



msgPKT	Message{MSG_HOST_COMMAND, 1, 2, 0 }


;==================================================================================

handleComms_messageHandler label far

	xchg	dx, di
	assume	di:ptr Message
	.if	([di].number == MSG_SEND_PACKET)

	  mov	es , cs:FORTHds
;	  invoke LoadSegment, 'es', cs:FORTHds, cs, 1000h ;seg _TEXT, seg _TEXT+1000h

	  .if	es:outProgress		; handleComms is busy

		mov	[di].dest, mfDone+mfBusy

	  .else
		push	ds
		push	di
		push	si

		lds	si, [di].infoPtr
		mov	di, (offset _FORTH_DATA:outDATA)

		add	di, 2
		add	si, 2
		mov	cl, byte ptr [si]
		xor	ch, ch
		inc	cx

		cld
		rep	movsb
		mov	es:outProgress, 1
;		invoke MarkFuncShow, 161, 'h'

		pop	si
		pop	di
		pop	ds			; back to ds:di->message{}

		mov	[di].dest, mfDone+mfFinished

	    .endif
	.endif
	xchg	dx, di
	retf

	assume	di: nothing

;==================================================================================

Code_word	<formInputPacket>, NORMAL	;	( far:packet - done-flag )

;==================================================================================


	push	es

	.repeat
		call	___getByte		; returns TRUE if byte ready
		sub	si, 4
					
		.if	!ax
			movzx	ebx, ax
			jmp	ExitFIP
		.endif
		
		mov	ax, word ptr [si]		; get it off [si] data stack
		sub	si, 4
		
		;mov	ah, '@'
		;invoke ShowStateChange, ax
		
		
		mov	cx, inCount
		inc	cx
		
		.if	!inCount	; we are not yet building a packet
		
			.if al == 0F8h
				xor	ebx, ebx
				mov	dword ptr [si], ebx
				ret
			.endif
				
			les	bx, dword ptr [si]	; also es:bx=packet buffer pointer
			assume bx : ptr PacketHeader
			mov	PacketType, al
			mov es:[bx].ptype, al
			
			.if	al=='d'
				mov	ax, 3	; support old short data packets
			.elseif al=='l'
				mov	ax, 4	; new 2 byte length 'l' for large
			.else

				.if	!al
					mov	al, 'z' ;	zero
				.endif
				.break
				

			.endif
			;	building a data packet
			mov	PacketHeaderLength, ax
			mov	InputPtr+2, es
			mov	byte ptr es:[bx].plength+1, ah ; ensure MSB of length set to 0
			inc	bx
			xor	ax, ax		

		.else
			les	bx, dword ptr InputPtr
			.if cx <= PacketHeaderLength
		
				mov	byte ptr es:[bx], al

				.if	cx==PacketHeaderLength
				  mov	bx, word ptr [si]
				  mov	ax, es:[bx].plength
				  mov	ax, es:[bx].plength
				  add	ax, PacketHeaderLength
				  inc	ax
				  inc	ax
				  mov	BytesRequired, ax
				  
				  les	bx, es:[bx].pdataPtr
				  mov	InputPtr+2, es
				  inc	bx	; allow 2 bytes for count at front of data block(including next inc)
				.endif
				
				inc	bx	; always increment bx - gets written to InputPtr at bottom
				xor	ax, ax		

			.else
				assume bx:ptr byte
				mov	es:[bx], al
				inc	bx
				.if	cx==BytesRequired
				  xor	cx, cx
				  movzx	ax, PacketType
				.else
				  xor	ax, ax		
				.endif
			.endif
		
		.endif
		
		mov	InputPtr, bx
		mov	inCount, cx

	.until	ax		
			
	movzx	ebx, PacketType

ExitFIP:
	sub	si, 4
	mov	dword ptr [si], ebx
	pop	es
	ret
		

		assume	bx:nothing

PacketHeaderLength dw 0
PacketType	db	0

BytesRequired 	dw 0
InputPtr	dw 0, 0			; including segment

PacketStartTime	dd 0
PacketMaxTime	dd 0


;==================================

Code_word	<InState>, NORMAL

;==================================

	mov	ax, offset InState
	jmp	PushShortAX

;==================================

Code_word	<OutState>, NORMAL

;==================================

	mov	ax, offset OutState
	jmp	PushShortAX

;==================================

Code_word	<InDATA>, NORMAL

;==================================

	mov	ax, offset inDATA
	jmp	PushShortAX

;==================================

Code_word	<OutDATA>, NORMAL

;==================================

	mov	ax, offset outDATA
	jmp	PushShortAX


;==================================

Code_word	<outID>, NORMAL

;==================================

	mov	ax, offset outID
	jmp	PushShortAX

;==================================================================================

Code_word	<putPacketByte>, NORMAL	;	( packet - done-flag )

;==================================================================================

	assume	ax:sword
	.if	!outCount
	  mov	packetOutCRC, 0
;	  invoke MarkFuncShow, 1, '0'
	.endif

	mov	bx, word ptr [si]		; point to packet
	.if	byte ptr [bx] == 'd'	; if data packet
	  mov	al, [bx+2]		; packet data length
	  xor	ah, ah
	  add	ax, 3			; account for header
	  sub	ax, outCount		; any bytes left to send?
	  .if	ax>0
	    add	bx, outCount
	    mov	al, [bx]
	    xor	ah, ah
	    push -1			; temporary state = sending DATA
	  .else
	    neg	ax
	    mov	bx, ax			; bx can be 0 or 1
	    mov	al, byte ptr packetOutCRC[bx]
	    push bx			; state = sending CRC
	  .endif
	.else
	  movzx	eax, byte ptr [bx]		; get packet type
	  call	putByte			; try to send it
	  mov	[si], eax		; return SUCCESS flag
	  ret
	.endif

	; ------------------------ only data packet continues here -----------

	push	ax			; save char
	call	putByte			; putByte
;	invoke MarkFuncInc, 1
	pop	bx			; output byte restored

	.if	ax			; if (done==TRUE)
	  inc	outCount		;   outCount++
	  pop	ax                      ;   get temporary state
	  .if	ax<0                    ;   if (still transmitting data)
	    mov	ax, packetOutCRC
	    call crc16			;     ax = crc, bx = char
	    mov	packetOutCRC, ax	;     update crc
	    xor	ax, ax			;     show packet not yet done
	  .elseif ax			;   else if finished transmitting CRC
	    mov	outCount, 0		;       show packet done
	    mov	ax, -1
;	    invoke MarkFuncShow, 1, '#'	;
	  .endif
	.else				; else byte not sent, so
	  add	sp, 2			;   ignore temprary state on stack
	  xor	ax, ax			;   done = 0
	.endif
	mov	word ptr [si], ax		; done flag
	ret
	assume	ax:nothing

	packetOutCRC	dw	0

putByte::
	inc	si
	inc	si
	mov	word ptr [si], ax		; char to send
	jmp	___putByte

;==================================================================================

Code_word	<pktTime>, NORMAL

;==================================================================================
		.if	dword ptr [si]
			mov	eax, PacketMaxTime
			mov	dword ptr [si], eax
			add	si, 4
		.else
			mov	PacketMaxTime, 0
			sub	si, 4
		.endif
		ret
;==================================================================================

Code_word	<outFlush>, NORMAL

;==================================================================================
;	invoke	MarkFuncShow, 81, 'X'
	.while	outProgress
	  poll
	.endw
;	invoke  MarkFuncShow, 81, '#'
	ret

;==================================================================================

Code_word	<!>packet>,NORMAL,to_packet			;	( char - len )

;==================================================================================

	mov	al, byte ptr [si]
	mov	bx, offset outDATA
	mov	cl, [bx+2]
	xor	ch, ch
	inc	cx
	mov	[bx+2], cl				;  outDATA 2+ dup ++ dup c@ + c!
	add	bx, cx
	mov	[bx], al

	.if	cx>=255					;	outDATA 2+ c@ 17 >= if
	  call	___outFlush				;	  outFlush
	.endif						;	then

	movzx	ecx, byte ptr outDATA+2				;	outDATA 2+ c@
	mov	[si], ecx

	ret


;==================================================================================

Code_word	<rxBlock>, NORMAL	; ( esptr - count )

;==================================================================================

	mov	HostError, 0
	mov	dx, CardAddress
	.if	CardType==50
	  add	dx, 02h
	.else
	  add	dx, 05h
	.endif
	mov	al, 0
	out	dx, al

	mov	bx, word ptr [si]	; esptr

	.repeat
	  invoke getInputLine, es::bx, 8200
	.until	ax

	 

	mov	dx, CardAddress
	.if	CardType==50
	  add	dx, 02h
	.else
	  add	dx, 05h
	.endif
	mov	bx, word ptr [si]
	movzx	eax, word ptr es:[bx]
	dec	ax	; to ignore the data type (B, C, D, E, M etc)
	out	dx, al
	mov	[si], eax

	ret

;==================================================================================

Code_word	<txBlock>, NORMAL	; ( ptr, count  - newptr, newcount )

;==================================================================================

	mov	HostError, 0
	mov	ecx, [si]
	mov	ebx, [si-4]	; esptr

	.repeat
	  invoke getInputLine, es::bx, 8200
	.until	ax

	.repeat
		mov	al, [ebx]
		push	ebx
		push	ecx
		invoke pOutByte, al
		pop	ecx
		pop	ebx
		inc	ebx
		dec	ecx
	.until ecx==0
	
	invoke pOutFlush
	 
	mov	[si], ecx
	mov	[si-4], ebx

	ret

;==================================================================================

Code_word	<upload>, NORMAL		; ( fname - longcount )

;==================================================================================


;	2015-03-11	Uses LoadFile

	call	___LoadFile		;	leaves segment in es, and length on stack, filetime in edx
	mov	ecx, dword ptr [si]

	add	si, 4
	mov	[si], edx			; put file time on stack

	xor	ebx, ebx
	
	.repeat
		mov	al, es:[ebx]
		push	ebx
		push	ecx
		invoke pOutByte, al
		pop	ecx
		pop	ebx
		inc	ebx
		dec	ecx
	.until ecx==0
	
	mov	ah, 49h	;	release the memory
	int	21h
	
	ret


;==================================================================================

Code_word	<download>, NORMAL		; ( fname - longcount )

;==================================================================================


;	2003-11-10	Incorrect error trapping for failing to open file
;			Bad stack unwind caused silent error.


	push	di
	push	es

	xor	al, al
	mov	BlockCounter, al

A:	
	inc	dword ptr [si]	; need asciiz string, not Forth string
	call	___StrToDOS1
	mov	[si+2], ds			; supply segmented address
	mov	dx, word ptr [si]		; pointer to filename

	xor	cx, cx			; attribute = 0
	mov	ah, 3ch			; open file
	int	21h

	mov	ByteCount, 0			; set byte count = 0 (moved out of .if)

	.if	carry?			; dup if	( n, handle )
	  mov	FHandle, 0
	  mov	TransferError, ax
	.else
		mov	FHandle, ax
		mov	TransferError, 0
		.repeat

			les	bx, FileWriteBuffer
			and	ebx, 0ffffh
			mov	[si], ebx

			call ___rxBlock		; leaves count on stack
			mov ecx, [si]
			.if	cx && !TransferError	; if bytes received and no error, write to file

				add	ByteCount, ecx; inc byte count by length of block
				mov	bx, FHandle

				push	cx
				push	ds

				lds	dx, FileWriteBuffer
				add	dx, 3;  binary data starts at byte 3, bytes 0 and 1 are count, byte 2 = data type
				mov	ah, 40h
				int	21h		; fwrite drop
				.if	carry?
				  mov	TransferError, 7
				.endif

				pop	ds
				pop	cx

			.endif
		.until !cx

	.endif

	mov	bx, FHandle
	.if	bx
	    mov	ah, 3eh
	    int	21h			; fclose
	.endif


	movzx	eax, TransferError
	mov	dword ptr [si], eax
	add	si, 4
	mov	eax, ByteCount
	mov	dword ptr [si], eax
	
	pop	es
	pop	di
	ret				;


;==================================================================================

Code_word	<SSByte>, NORMAL ; ( byte to send - byte received )

;==================================================================================



	mov	cx, 8
	movzx	ebx, word ptr [si]
	mov	dx, 02FCh
	pushf
	cli

	.repeat
	  xor	al, al
	  shl	bl, 1
	  rcl	al, 1	; puts data bit in al.0
	  xor	al, 3	; use complement
	  out	dx, al	; clock->0, data bit set
	  and	al, not 2
	  mov	ah, al
	  inc	dx
	  inc	dx
	  in	al, dx
	  dec	dx
	  dec	dx
	  shr	al, 1
	  rcl	bh, 1
	  mov	al, ah
	  out	dx, al	; clock->1, should now read data
	.untilcxz

	xchg	bh, bl
	and	ebx, 0ffffh
	mov	[si], ebx
	popf
	ret

;==================================================================================

Code_word	<DropData>, NORMAL		; (  - address )

;==================================================================================
	mov	ax, offset DropData
	jmp	PushShortAX


;==================================================================================

Code_word	<CorruptData>, NORMAL		; (  - address )

;==================================================================================
	mov	ax, offset CorruptData
	jmp	PushShortAX

;==================================================================================

% lastPktLink =   _link&lastLink
public  lastPktLink

forth_pkt	endp

;==================================================================================

PacketDump proc	C uses ax bx cx dx es, ErrorMessage:far ptr byte, PacketPtr : far ptr ShortPacket

		mov	ax, DumpHandle
		.if	!ax
			invoke	fcreate, NORMAL,  ADDR DumpFileName
			mov	DumpHandle, ax
		.endif
		.if	ax
			les	bx, ErrorMessage
			movzx	cx, byte ptr es:[bx]
			inc	bx
			invoke	fwrite, DumpHandle, es::bx, cx
			les	bx, PacketPtr
			movzx	cx, byte ptr [bx+2]
			add	cx, 5
			invoke	fwrite, DumpHandle, es::bx, cx
			invoke fflush, DumpHandle
			;invoke	fclose, FHandle
		.endif
		ret
		
PacketDump endp

ShowStateChange proc C uses ax bx es, CharPair : word

	.if	DebugBits & DEBUG_COMMS
		pusha
		mov	ax, CharPair
		.if	!ax
		  mov	al, InState
		  mov	ah, OutState
		  add	ax, '00'
		.endif
		push	ax
		push	0b820h
		pop	es
		mov	bx, StateChangeCount
		and	bx, 03fh
		add	bx, bx
		mov	ah, 2fh
		mov	es:[bx], ax
		pop	ax
		mov	al, ah
		mov	ah, 4fh
		mov	es:[bx+160], ax
		mov	ax, 0FF20h
		add	bx, 2
		and	bx, 07eh
		mov	es:[bx], ax
		mov	es:[bx+160], ax
		shr	bx, 1
		mov	StateChangeCount, bx
		popa
	.endif
	
	ret

StateChangeCount  dw 0

ShowStateChange endp



_TEXT	ends

end
