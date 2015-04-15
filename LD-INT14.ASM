comment/=====================================================================


	MODULE     -     LD-INT14.ASM


22-10-98 Version 2.1	~ Altered to be language:c and access _FORTH_DATA

============================================================================/

option language:c

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

include	..\include\serial.inc
include ..\include\forth.inc
include	..\include\loader.inc
include ..\include\step.inc
include	..\include\macros.inc
include	qfns.mac

PIC			= 20h
DB5_ADDRESS		= 300h
Rx_LED			= 02

BINARY		=80h
RxFLOW_CONT	=01h
TxFLOW_CONT	=02h
RxF_ON		=04h
TxF_ON		=08h

XON			=11h
XOFF		=13h
EOF			=1Ah

; output lines :	|  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  | B0  |
;			|  --  |  --  |  --  |  --  |IntEn |  --  |  RTS | DTR |

ENABLE_RX	=0Bh			; RTS=DTR=OUT1=1
DISABLE_RX	=08h			; RTS=DTR=0, OUT1=1(interrupt enable)

_TEXT	segment	public 'CODE'

	assume	cs:_TEXT

	.486

FunctionNumber = 0B7h

UARTaddr		dw	0
imask_list		db	11110111b,11101111b
flow_stat		db	BINARY	; RxFLOW_CONT+RxF_ON+TxFLOW_CONT+TxF_ON

time_out_delay	dw	1000


	make_q		RS_q, 256
	public		RS_q


comment\===========================================================================


Pass control to old routine unless channel corresponds to _comPort.
If so, replace the following functions:

COMMS_RESET	= 0	; Reset.	Also reset RX_q, PIC, UART interrupt.
COMMS_TRANSMIT	= 1	; Transmit.	No change.
COMMS_RECEIVE	= 2	; Receive.	Get data from RX_q, or wait until
			;		time-out specified by time_out_delay.
			;		Also implement XON/XOFF flow control.
COMMS_STATUS	= 3	; Status.	As before but data-available is
			;		determined by queue status.
COMMS_FLUSH	= 4	; Flush.	New function. Reset receive buffer.

=================================================================================\

interrupt_14	proc  far C

;=================================================================================

;	dx contains comms port number

	sti
	push	fs
	mov	fs, cs:FORTHds
	assume	fs:_FORTH_DATA


	inc	dx
	.if	dx != _FORTH_DATA:HostPort
	  dec	dx
	  pop	fs
	  jmp	dword ptr cs:oldInt14
	.endif
	dec		dx

	cmp		ah, COMMS_FLUSH
	ja		comms_exit

	push	ds
	push	dx
	push	cx
	push	bx

	push	cs
	pop		ds

	assume	ds:_TEXT
	.if		ah <= COMMS_TRANSMIT
	  je	comms_tx
	  jmp	comms_reset
	.endif

	.if		ah <= COMMS_STATUS
	  jb	comms_rx
	  je	comms_status
	.endif

;=================================================================================

comms_flush:

;=================================================================================

	push	si
	mov		si, offset _TEXT:RS_q
	call	q_init
	pop		si

;=================================================================================

comms_status:

;=================================================================================

	pushf
	call	dword ptr cs:oldInt14	; get normal port status

new_status:

	push	ax
	push	si
	mov		si, offset _TEXT:RS_q
	call	q_len			; any data in queue?
	pop		si
	pop		ax			; normal status
	and		ah, NOT 1		; discard usual data-ready bit
	.if	cx			; cx=number of bytes in RS_q
	  or	ah, 1			; else indicate data available
	.endif

comms_leave:
	pop	bx
	pop	cx
	pop	dx
	pop	ds
comms_exit:
	pop	fs
	iret
	
oldInt14	dd	0

;=================================================================================

comms_tx:

;=================================================================================

	mov		dx, UARTaddr
	push	ax

;	mov		al, ENABLE_RX	; DTR, RTS, OUT1, OUT2 active
	add		dx, 4			; -> Modem Control Register
;	out		dx, al

	mov		cx, time_out_delay
	inc		dx				; -> Line Status Register
tx1:
	push	cx
	mov		cx, 1000		; inner loop counter

tx2:
	in		al, dx			; Line Status Register (xFD)
	mov		ah, al			; save status
	and		al, 20h			; Tx buffer empty ?
	loopz	tx2
	jcxz	tx3

	inc		dx
	in		al, dx			; Modem Status Register (xFE)
	dec		dx
	and		al, 30h			; CTS,DSR
	cmp		al, 30h
	loopnz	tx2				; not active
	jcxz	tx3

	sub		dx, 5			; -> Tx register
	add		sp, 2			; drop counter
	pop		cx				; data into cl
	mov		al, cl
	out		dx, al			; send data
	jmp		comms_leave


tx3:
	pop		cx				; restore outer loop counter
	loop	tx1

	pop		cx				; original data
	mov		al,cl
	or		ah,80h			; indicate timeout
	jmp		comms_leave

;=================================================================================

comms_rx:

;=================================================================================

	push	si
	mov	si,	offset _TEXT:RS_q
	call	q_len
	.if 	ax > 60
	  mov	al, ENABLE_RX
	  mov	dx, UARTaddr
	  add	dx, 4			; point to line control register
	  out	dx, al
	.endif

	mov	cx, time_out_delay
data_wait1:
	push	cx
	mov	cx, 1000
data_wait2:
	call	q_read
	cmp	ax, -1
	jnz	data_ready
	loop	data_wait2
	pop	cx
	loop	data_wait1


	mov	ah, 3			; get current status
	pushf				; pseudo int 14h
	call	dword ptr cs:oldInt14
	mov	al, EOF			; no character available
	push	cx

data_ready:
	pop		cx
	pop		si
	jmp		comms_leave

;=================================================================================

comms_reset:

;=================================================================================

	pushf
	call	dword ptr cs:oldInt14
	call	setupInt14
	jmp		comms_leave

;=================================================================================

interrupt_14	endp

;=================================================================================

setupInt14	proc	near

;=================================================================================

;	initialize receive queue

	push	si
	mov	si, offset _TEXT:RS_q
	call	q_init
	pop	si


;=================================================================================

;	set up Programmable Interrupt Controller

	push	dx
	mov	bx, HostPort
	and	bx, 1			; odd or even comms channel
	mov	ah, imask_list[bx]	; get interrupt mask for this UART

	mov	bx, HostPort
	dec	bx
	add	bx,bx
	push	0
	pop	ds			; page 0
	mov	dx, 0400h[bx]		; get  UART address
	push	cs
	pop	ds			; back to this segment
	mov	UARTaddr, dx		; save UART address

;	set hardware interrupt vector 0bh/0ch to interrupt_COMMS

	mov	bx, HostPort
	and	bx, 1
	add	bx, 0bh			; com2 interrupt vector=0bh
	shl	bx, 2			; com1 interrupt vector=0ch
	push	ds
	push	0
	pop	ds
	mov	word ptr ds:[bx], offset _TEXT:interrupt_COMMS
	mov	ds:[bx+2], cs		; this segment
	pop	ds



	mov		dx, PIC+1		; -> interrupt controller mask reg.
	in		al, dx			; get current mask
	and		al, ah			; activate serial interrupt
	cli
	out		dx, al			; PIC now ready.

;=================================================================================

;	enable FIFOs if they exist

	mov	dx, UARTaddr		; -> receive data register
	add	dx, 2			; FIFO control register of 16550...
	mov	al, 87h			; FIFOs enabled but no DMA - trigger on 8 chars
	out	dx, al

;	activate interrupt-on-RX-data on UART

	mov		dx, UARTaddr		; -> receive data register
	in		al, dx
	in		al, dx
	in		al, dx			; flush any extranious data

	inc		dx			; -> interrupt enable register
	mov		al, 1			; set UART to interrupt on data
	out		dx, al

	mov		al, ENABLE_RX	; set OUT1 and OUT2
	add		dx, 3			; -> modem control register
	out		dx, al			; enable interrupt line to PIC
	pop		dx
	sti
	ret

setupInt14	endp

;=================================================================================

	public	get_serial_

get_serial_	proc	near

;=================================================================================

	push	bp
	mov		bp, sp
	mov		dx, [bp+4]
	dec		dx
	mov		ah, 2
	int		14h
	pop		bp
	ret

get_serial_	endp

;****************************************************


;	HARDWARE INTERRUPT - 0bh/0ch	receive data


interrupt_COMMS	proc near


	push	bp
	mov	bp, sp
	push	ds
	push	dx
	push	cx
	push	bx
	push	ax

	push	0B800h
	pop	ds
	mov	word ptr ds:[156], 02F49h	; 'I' in White on Green
	push	cs
	pop	ds

	mov	dx, DB5_ADDRESS+7
	in	al, dx
	or	al, Rx_LED		; switch on Yellow COMMS LED
	out	dx, al

	jmp	checkDataReady

validData:
	mov	ah, al
	and	ah, 00011110b		; ignore some bits

	mov	dx, UARTaddr		; -> Receiver Buffer Register
	in	al, dx			; get character
	push	si
	mov	si, offset _TEXT:RS_q
	call	q_write
	call	q_len			; cx=count, ax=bytes left
	pop	si

	.if	ax < 10			; free bytes left in buffer
	  mov	dx, UARTaddr
	  add	dx, 4
	  mov	al, DISABLE_RX	; clear DTR + RTS
	  out	dx, al
	  push	ds
	  push	0b800h
	  pop	ds
	  mov	dword ptr ds:[60], 01f7ah
	  pop	ds
	  inc	BOR
	  jmp	end_int
	.endif

checkDataReady:
	mov	dx, UARTaddr
	add	dx, 5			; -> Line Status Register
	in	al, dx			; get RX stat
	test	al, 1
	jnz	validData		; not spurious interrupt


end_int:

;****************************************************


	.if	BOR
	  mov	ax, [bp+4]; cs
	  call	hexprint
	  mov	al, ':'
	  charout
	  mov	ax, [bp+2] ; ip
	  call	hexprint
	  mov	al, ' '
	  charout
	.endif


;	reset interrupt controller and restore registers

	mov		al, 20h
	mov		dx, PIC
	out		dx, al			; interrupt acknowledge

	pop		ax
	pop		bx
	pop		cx
	pop		dx
	pop		ds
	pop	bp
	iret

flow_on:
	or		flow_stat,TxF_ON
	jmp		end_int

flow_off:
	and		flow_stat,NOT TxF_ON
	jmp		end_int

msgInputBufferFull	db	"RS232 Input Buffer Full", 0

BOR	db	0

interrupt_COMMS	endp


_TEXT		ends

% LastLDINT14Function = FunctionNumber
public LastLDINT14Function

end

