comment #=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-COMM.ASM	:	Forth serial I/O routines

ms			( milliseconds - )
HostError		variable
comReset		( port - status )
comStatus		( port - status )
comPut			( data, port - status )
CommGet			( port - status[+data] )
formInputPacket		( - flag )
handleComms		( - )
rxBlock			( esptr - count )
writeFlashImage		( loffset, n - count )
download		( filename - count )

24-04-96 Version 1.00	+	comReset, comStatus, comPut, comGet
25-04-96 Version 1.01	+	waitForEOI wait for End-of-Information
01-05-96 Version 1.02	+	rxBlock	- get input into memory block
17-12-97 Version 1.10	~	based on CRC packet technique
29-10-00 Version 2.39	~	ms->msDelay altered to use timer0 instead of loop
11-01-01 Version 2.40	+	<BREAK> added
2002-03-06 Version 2.58 ~	$307.b7 prevented from being set to solve bad LS reading
2002-04-26 Version 2.61 -	STOP button inhibition of comGet() removed.
2008-03-02 Version 4.06	+	CommRecord structure, CommPort[], COM1, COM2, HostPort, HostControl. Renamed CcmmReset, CommStatus, CommPut, CommGet
2009-04-04 Version 4.11 + Large packet handling. "l" and "L" packets with 16 bit count. Packet buffer now a far pointer.
2013-07-29 Version 5.40	<USBGet>, <USBPut> uses call	PCI_in in place of in to avoid parity errors.



=============	Timing functions

Code_word	<ms>, NORMAL
Code_word	<GetNanoTicks>, NORMAL
Code_word	<GetMilliSeconds>, NORMAL
Code_word	<NanoTicksElapsed>, NORMAL


============	Port Specification and Enabling

Code_word	<HostControl>, NORMAL
Code_word	<HostPort>, NORMAL
Code_word	<CommPort>, NORMAL		; stack = ( port - address )


============	RS232 Serial Port Functions (based on int14h)

Code_word 	<CommError>, NORMAL		; stack = ( port - status )
Code_word 	<CommReset>, NORMAL		; stack = ( port - status )
Code_word 	<CommStatus>, NORMAL		; stack = ( port - status )
Code_word 	<CommPut>, NORMAL		; stack = ( data, port - status )
Code_word 	<CommGet>, NORMAL		; stack = ( port - status|data )


============	USB Port Functions

Code_word 	<USBPut>, NORMAL		; stack = ( USBAddress - status|data )
Code_word 	<USBGet>, NORMAL		; stack = ( USBAddress - status|data )

============	GP Functions

Code_word	<putByte>, NORMAL		; ( char - SUCCESS )
Code_word	<getByte>, NORMAL		; ( - FALSE ) ( - byte, TRUE )
Code_word	<SSByte>,  NORMAL		; SPI via RS232 handshake lines ( byte to send - byte received )

============	Packet Functions

Code_word	<inDATA>, NORMAL
Code_word	<outDATA>, NORMAL
Code_word	<!>packet>,NORMAL,to_packet			;	( char - len )

Code_word	<putPacketByte>, NORMAL	;	( packet - done-flag )
Code_word	<formInputPacket>, NORMAL	;	( segment:packet - done-flag )
Code_word	<handleComms>, NORMAL
Code_word	<outFlush>, NORMAL


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
include ..\include\parallel.inc
include ..\include\macros.inc
include ..\include\step.inc
include	..\include\fp.inc
include	..\include\forth.inc



_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA
	assume	si:ptr word

externdef		lastSysLink:abs
% _link100	equ	lastSysLink

	thisLink textequ <101>
	lastLink textequ <100>

;==================================================================================

forth_com	proc	near

;==================================================================================

Rx_LED		equ	02h	; bit 1 of $307 for yellow comms indicator
DB6_Rx_LED	equ	01h	; bit 0 of $321 for yellow



BLACK_BACK	equ	00h
BLUE_BACK 	equ	10h
GREEN_BACK 	equ	20h
RED_BACK 	equ	40h
YELLOW_FORE	equ	0Eh
WHITE_FORE	equ	0Fh


;=============	Timing functions



;==================================================================================

Code_word	<ms>, NORMAL

;==================================================================================


	mov	ecx, dword ptr [si]
	sub	si, 4

	invoke	msDelay, cx

	ret

;==================================================================================

Code_word	<GetMilliSeconds>, NORMAL

;==================================================================================


	call	GetNanoTicks
	invoke	ltof, eax
	add	si, 4
	mov	dword ptr [si], eax


	fld	real4 ptr [si]
	fwait
	fdiv    TicksPerMillisecond
	fwait
	fstp	real4 ptr [si]
	fwait
	ret


;==================================================================================

Code_word	<GetNanoTicks>, NORMAL

;==================================================================================


	call	GetNanoTicks
	add	si, 4
	mov	dword ptr [si], eax

	ret

;==================================================================================

Code_word	<NanoTicksElapsed>, NORMAL

;==================================================================================

	inc	si
	inc	si
	mov	[si], offset NanoTicksElapsed

	ret





;	============	Port Specification and Enabling
Code_word	<CommsArea>, NORMAL	; (word:index - word: address)

	mov	eax, dword ptr [si]
	shl	ax, 1
	add	ax, offset Comms
	mov	dword ptr [si], eax
	ret
	
;==================================================================================

Code_word	<HostControl>, NORMAL	;	(	-	address )

;==================================================================================

	mov	ax, offset	_FORTH_DATA:HostControl
	jmp	PushShortAX

;==================================================================================

Code_word	<HostPort>, NORMAL	;	(	-	address )

;==================================================================================

	mov	ax, offset	HostPort
	jmp	PushShortAX

;==================================================================================

Code_word	<CommPort>, NORMAL		; stack = ( port - address )

;==================================================================================

	mov	ax, word ptr [si]
	call	GetPortOffset
	lea	ax, CommPort[bx]
	jmp PokeShortAX

GetPortOffset:
	dec	ax
	mov	ah, sizeof(CommRecord)
	mul	ah
	movzx	ebx, ax
	ret





;	============	RS232 Serial Port Functions (based on int14h)

;==================================================================================

Code_word 	<CommError>, NORMAL		; stack = ( port - status )

;==================================================================================


	mov	ax, word ptr [si]
	call	GetPortOffset
	lea	ax, CommPort[bx].Error
	jmp PokeShortAX

;==================================================================================

Code_word 	<CommReset>, NORMAL		; stack = ( port - status )

;==================================================================================

	mov	ax, word ptr [si]
	call	GetPortOffset
	movzx	ax, CommPort[bx].Control
	

	jmp	comStatCall

;==================================================================================

Code_word 	<CommStatus>, NORMAL		; stack = ( port - status )

;==================================================================================

	mov	ah, 3			; function 3 = get status

comStatCall::

	mov	dx, word ptr [si]
	dec	dx
	int	14h
	jmp PokeShortAX

;==================================================================================

Code_word 	<CommPut>, NORMAL		; stack = ( data, port - status )

;==================================================================================

	mov	ax, word ptr [si]				; port is 1, 2  etc
	call	GetPortOffset	; returns port record address in bx (does not change stack)

	call	___CommStatus		; stack = ( port - status ) also registers : returns ax=status, dx=port

	sub	si, 4; drop status (already in ax)

	.if	(ah & TxHRE)		; tx holding reg empty

;	  .if	(al & CTS) || !(CommPort[bx].TxMask & CTS)

	    mov	al, byte ptr [si]
	    mov	ah, 1			; function 1 = send serial byte
	    int	14h
	    .if	!(ah & TxTIMEOUT)
	    
	    	.if CommsLogHandle
	    		mov	al, ah
	    		mov	ah, byte ptr [si]
				invoke fputw, CommsLogHandle, ax
			.endif
	    		
			mov	ax, 0  			; function successful
	    .endif

;	  .endif

	.endif


;	Diagnostics were here
	jmp PokeShortAX	; replace data char with result (0=success, otherwise status)

cptr	dw	0
	db	128 dup(11h)


;==================================================================================

Code_word 	<CommGet>, NORMAL		; stack = ( port - status|data )

;==================================================================================


	mov	dx, word ptr [si]
	dec	dx

	mov	ax, word ptr [si]
	call	GetPortOffset
	push	bx


	xor	ax, ax
	mov	CommPort[bx].Error, ax

	mov	ah, 3
	int	14h
	pop	bx

	.if	carry?

	  xor	ax, ax
	  mov	CommPort[bx].Error, -1


	.elseif	ax & 100h	; data ready

		mov	ah, 2			; get data
		int	14h
		.if	ah	; erroro
			.if CommsLogHandle
				invoke fputw, CommsLogHandle, -1
			.endif
			xor	ax, ax
		 .else
	  		mov	word ptr [si], ax
			.if CommsLogHandle
				invoke fputw, CommsLogHandle, word ptr [si]
			.endif
			add	si, 4
			mov	ax, 1
	  		and	HostControl, not USB_ACTIVE	; turn off USB channel
	  	.endif
	.else
	  mov	CommPort[bx].Error, ax
	  mov	CommPort[bx].Status, ax
	  xor	ax, ax
	.endif

	jmp PokeShortAX

;==================================================================================

Code_word	<CommsLogHandle>, NORMAL

;=================================================================================

	mov	ax, offset	CommsLogHandle
	jmp	PushShortAX


;==================================================================================





;	============	USB Port Functions

RxDATA_READY	= 1
TxBUFFER_FULL	= 2

;==================================================================================

Code_word 	<USBPort>, NORMAL		; stack = ( 	-	USBAddress )

;==================================================================================

	mov	ax, offset	USBPort
	jmp	PushShortAX

;==================================================================================

Code_word 	<USBPut>, NORMAL		; stack = ( char - status|data )

;==================================================================================


	mov	dx, USBPort
	.if dx
		call	PCI_BusDelay
		call	PCI_in
		.if	!(al & TxBUFFER_FULL)		; TxBuffer is not full  (FULL=2)

	    	.if CommsLogHandle
	    		push	ax
	    		push	dx
	    		mov	al, ah
	    		mov	ah, byte ptr [si]
				invoke fputw, CommsLogHandle, ax
				pop	dx
				pop	ax
			.endif

			;call	PCI_delay
			
			.if (al != 0FFh)
				mov	al, byte ptr [si]
				out	dx, al  	; send the character
				xor	ax, ax		; show no error
;			.else
;	    		mov	ah, byte ptr [si]
			.endif

		 .else
		 	xor	ah, ah
		.endif
	.else
		xor	ax, ax
	.endif

	jmp	PokeShortAX


;=============================================	USB Functions	===================

;==================================================================================

Code_word 	<USBOutIn>, NORMAL		; stack = ( outchar - status|data )

;==================================================================================

	mov	ax, word ptr [si]
	mov 	dx, 0319h
	out	dx, al
	
	call	PCI_in
	xor	ah, ah
	jmp	PokeShortAX


;==================================================================================

Code_word 	<USBGet>, NORMAL		; stack = ( USBAddress - status|data )

;==================================================================================


	mov	dx, USBPort
	.if dx
		call	PCI_BusDelay
		call	PCI_in	; byte wide input - gets status
		.if (al == 0FFh) 	;	a PCI bus error
			.if CommsLogHandle
				invoke fputw, CommsLogHandle, 0FFFFh
			.endif
			xor	ax, ax
		.else
			.if (al & RxDATA_READY)	; a byte is waiting
				push	ax
				call	PCI_BusDelay
				call	PCI_inw	; word wide input - gets status in b7-8

				call	PushShortAX	; includes the Tx and Rx flags
				pop	ax		; retrieve full status (5 bits)
				mov	ah, byte ptr [si+1]
				shl	ah, 5
				or		al, ah
				mov	byte ptr [si+1], al

				.if CommsLogHandle
					invoke fputw, CommsLogHandle, word ptr  [si]
					mov	al, byte ptr [si+1]
				.endif
				or	HostControl, USB_ACTIVE
				xor	ah, ah
			.else
				xor	ax, ax
			.endif
		.endif
	.else
		xor	ax, ax
	.endif

	jmp	PushShortAX



;	============	GP Functions


;==================================================================================

Code_word	<putByte>, NORMAL; ( data - SUCCESS )

;==================================================================================


	.if	HostControl & USB_ACTIVE

	  call	___USBPut

	.else

		add	si, 4

	  mov	dx, HostPort
	  mov	word ptr [si], dx
	  call	___CommPut

	.endif
	
	mov	ax, word ptr [si]
	sub	si, 4
	.if	ax			; invert error flag
	  xor	ax, ax			; return 0 (=not DONE)
	.else
	  dec	ax			; TRUE=Success so return -1
	.endif
	ret

;==================================================================================

Code_word	<getByte>, NORMAL		;	( - FALSE ) ( - byte, TRUE )

;==================================================================================

	call		PCI_BusDelay
	call	___USBGet

	.if	dword ptr [si] == 0
		movzx	edx, HostPort
		mov	dword ptr [si], edx
		call	___CommGet			;	  HostPort @ CommGet
		xor	dx, dx
		sub	dx, ax
		movzx	eax, dx
		mov	dword ptr [si], eax
	.endif
	
	mov	eax, dword ptr [si]	; ax is nonzero if byte received

	ret





% lastComLink =   _link&lastLink
public  lastComLink

forth_com	endp

;==================================================================================

_TEXT	ends

end
