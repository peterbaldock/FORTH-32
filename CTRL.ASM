;===========================================================================

comment #

	FileName	:	CTRL.ASM
	Date		:	2015-01-06

	Function	:	Static hardware control for DB5, DB6 & DB7
	Note		:	All static I/O routines collected into this module

	Author		:	Peter Baldock
	Copyright	:	Douglas Instruments Limited 2010
	

Version History
============

	2015-01-06	reinstated STOP sensing (STOPButtonCheck)
	2013-13-26	temporarily suppressed STOP button reading because of Hyogo problem
	2010-09-01	Version 5.00 // Taken from ACT-DB6.ASM - Constant Timebase Stepping DC7-ACT.ASM and DC7-INT now call this module for I/O
#

;=================================================================================


	option language:c

;	include	netmacro.inc
	include	..\include\step.inc

_TEXT	segment

	.486

	assume	ds:_FORTH_DATA


;=================================================================================

comment #

Publics
======

	Input Functions
	============
		GetLimitSwitchInputs 	proc C uses bx si			(filtered)
		input_bits 					proc C, mno:word		(filtered)
		GetSenseInputs			proc C uses dx
		STOPButtonCheck		proc C uses dx
		
		GetFilteredLSInputs 	proc near C uses bx cx, BoardNo: word, nSamples:word			(filtered if nSamples>0)
		
		GetBoardLSInputs 		proc C, BoardNo:word			(NOT filtered)

		GetDB5LSInputs 		proc C uses cx dx, BoardNo:word			(NOT filtered)
		GetDB6LSInputs 		proc C uses dx, BoardNo:word			(NOT filtered)
		GetDB7LSInputs 		proc C uses dx, BoardNo:word			(NOT filtered)

		FilterBytes 					proc near C uses bx cx dx, Samples: word, nSamples:word


	Ouput Functions
	============
		MotorPower 				proc C, mno:word, action:word
		OutputMotorPhase 	proc C, Mno:word, Phase:byte
		LED_Display 				proc near C uses eax ebx edx si
		
		OutputDB5MotorPhase proc C uses bx dx, mno:word, phase:byte
		OutputDB6MotorPhase proc C, Mno:word, Phase:byte
		OutputDB7MotorPhase proc C, Mno:word, Phase:byte
		
		GetDB6CoilCurrents 	proc C uses bx cx dx, Mno:word, Angle:byte
		GetSingleCoilDAC 		proc C, Current:word, Angle:word
		LookupIntegerSine 		proc near C, Angle:byte
		
		DB6_PutWord				proc C, OutWord:word

===================================================================================#


;=================================================================================

input_bits proc C, mno:word

;=================================================================================

	mov	cx, mno		; motor number
	dec	cx		; 0 offset in STEPPER - 1 offset in SKIPPER
	.if	cx >= nmotors
	  mov	ax, ERR_MOTOR
	  stc
	.else
		mov	bx, cx
		shr	bx, 2
		invoke GetFilteredLSInputs, bx, LSQLength-1
		and	cx, 3
		add	cx, cx
		shr	eax, cl
	  	and	al, 3
	  	mov	ah, 0
	.endif
	ret

input_bits	endp

;=================================================================================

GetLimitSwitchInputs proc C uses cx

;=================================================================================

	mov	cx, nmotors
	shr	cx, 2
	
	cli
	.repeat
		dec	cx
		invoke GetFilteredLSInputs, cx, LSQLength-1
	.until !cx
	sti
	
	mov	eax, LimitSwitches
	ret


GetLimitSwitchInputs endp

;LSSample	proc near C uses bx cx, BoardNo: word, nSamples: word

;	invoke	GetDB7

;=================================================================================

GetFilteredLSInputs2 proc near C uses bx cx, BoardNo: word, nSamples:word

;=================================================================================

;	algorithm for scanning limit switches


local	Samples[15]:byte

	mov	cx, nSamples
	.if cx
	
		;===================	Poll Limit Switch Inputs ============================

			; windowed average over multiple steps works well,
			; but no good for single reads. Either do windowed average in step
			; interrupt or use validity mask

		lea	bx, Samples
		.repeat
			invoke GetBoardLSInputs, BoardNo
			mov	[bx], al
			inc	bx
		.untilcxz
		
		lea	bx, Samples
		invoke FilterBytes, bx, nSamples
	
	.else
			invoke GetBoardLSInputs, BoardNo
			mov	ah, -1
	.endif
	

	; al = result, ah = validity mask (valid bit positions = 1)
	
	mov	bx, BoardNo
	and	bx, 3
	and	al, ah
	not	ah
	and	byte ptr LimitSwitches[bx], ah ; set all new bits that are certain to 0
	or	byte ptr LimitSwitches[bx], al ; then or the valid 1 bits back in
	not	ah										; ah is still the validity mask

	ret
	
GetFilteredLSInputs2 endp

;=================================================================================

GetFilteredLSInputs proc near C uses bx cx si, BoardNo: word, nSamples:word

;=================================================================================

;	algorithm for scanning limit switches


	invoke GetBoardLSInputs, BoardNo	; value in al
	
	mov	cx, 8
	mov	bl, al
	xor	eax, eax
	.repeat
		shr	bl, 1
		rcr	eax, 4	; expand into bx
	.untilcxz
	
	mov	bx, BoardNo
	movzx	cx, LSIndex[bx]
	inc	cl
	.if	(cx >= nSamples)
		mov	LSIndex[bx], 0
	.else
		mov	LSIndex[bx], cl
	.endif
	dec	cl
	shl	cx, 2
	
	shl	bx, 5+LSQLength/16	; 8 or 16 or 32 x dword
	mov	si, offset LSQueue+4*(LSQLength-1)
	add	si, bx	; si points to accumulator word, which is last dword in 8 dword array for this board
	
	add	bx, cx	; address of oldest value
	
	xchg	eax, LSQueue[bx]
	sub	eax, [si]
	neg	eax
	add	eax, LSQueue[bx]
	mov	[si], eax
	
	mov	cx, 8
	.repeat
		mov	bl, al
		and	bl, 0Fh
		add	bl, bl
		cmp	byte ptr nSamples, bl
		rcr	bh, 1				; accumulate result in bh
		shr	eax, 4
	.untilcxz
	
	mov	al, bh
	mov	bx, BoardNo
	mov	byte ptr LimitSwitches[bx], al
	
	ret
	
GetFilteredLSInputs endp

;=================================================================================

PrimeLSQueue	proc near C uses bx cx, BoardNo: word, nSamples:word

;=================================================================================

	xor	eax, eax
	mov	bx, BoardNo
	mov	LSIndex[bx], al
	
	mov	cx, LSQLength
	shl	bx, 5+LSQLength/16
	.repeat
		mov	LSQueue[bx], eax
		add	bx, 4
	.untilcxz
	
	mov	cx, nSamples
	.repeat
		invoke GetFilteredLSInputs, BoardNo, nSamples
	.untilcxz
	
	ret


PrimeLSQueue	endp

;=================================================================================

GetBoardLSInputs proc C uses bx , BoardNo:word

;=================================================================================

	mov	ax, CardType
	mov	bx, BoardNo
	.if Board[bx]
		.if ax == 50
			invoke GetDB5LSInputs, BoardNo
		.elseif	ax <= 68
			invoke GetDB6LSInputs, BoardNo
		.else
			invoke GetDB7LSInputs, BoardNo
		.endif
	.else
		xor	al, al
	.endif
	
	mov	bx, BoardNo
	mov	LSBuffer[bx], al
	
	ret

GetBoardLSInputs endp

;=================================================================================

GetDB5LSInputs proc C uses cx dx, BoardNo:word

;=================================================================================

	mov	dx, BoardNo
	shl	dx, 3
	add	dx, 04h		; DB5 LS inputs at CardAddressess+4
	add	dx, CardAddress
	in	al, dx
	not	al
	mov	cx, 8
	.repeat    	; limit switch bit inputs appear in reverse order
		shl	al, 1	; ie. LS0=b7, LS1=b6 etc.
		rcr	ah, 1	; so reflect bit pattern to expected direction
	.untilcxz
	
	ret
	
GetDB5LSInputs endp

;=================================================================================

GetDB6LSInputs proc C uses dx, BoardNo:word

;=================================================================================

		
	mov	dx, BoardNo
	shl	dx, 3
	add	dx, 05h	; DB6 LS inputs at base+5
	add	dx, CardAddress
	in		al, dx
	not	al
	
	ret

GetDB6LSInputs endp

;=================================================================================

GetDB7LSInputs proc C uses bx cx dx, BoardNo:word

;=================================================================================


	movzx	ax, byte ptr BoardNo
	btr	LSSampledByInterrupt, ax
	.if	carry?
		
		mov	bx, ax
		mov	al, LSBuffer[bx]
		
	.else
		
		or		al, 30h	; function 3
		invoke	DB7_PutWord, 0, al		

;		mov	cx, 1
;		.repeat
;			call	PCI_BusDelay
;		.untilcxz

		call	PCI_inw	; this is formatted as LLLL PPPP, but old format is LP LP LP LP
		
	.endif
	
	not	al
	mov	dl, al
	mov	dh, al
	shr	dh, 4
	mov	cx, 4
	.repeat
		shr	dl, 1
		rcr	al, 1
		shr	dh, 1
		rcr	al, 1
	.untilcxz
	
	ret

LSSampledByInterrupt	dw	0
LSBuffer					db	4 dup(0)

GetDB7LSInputs endp

;=================================================================================

GetSenseInputs proc C uses dx

;=================================================================================

	mov	dx, CardAddress
	.if	CardType>=70
		call	PCI_in
		shr	al, 2
		or	al, 0Feh
	.else
		.if	CardType==50
		  add	dx, 1fh		; DB5 LS input port.
		.else
		  add	dx, 19h		; DB6 status port - STOP= bit 0
		.endif

		.while	dx > CardAddress
		  in	al, dx
		  shl	al, 6
		  shl	ax, 2
		  sub	dx, 8
		.endw

		mov	al, ah

		.if	CardType!=50
		  or	al, 0AAh
		.endif
	.endif
	
	xor	ah, ah
	ret

GetSenseInputs	endp


;**************************************************************

STOPButtonCheck	proc C uses dx

;**************************************************************

;	2001-01-04	Updated to read board 0 directly

	mov	dx, CardAddress
	
	.if	CardType>=70
		call	PCI_in
		and	al, DC7_Stop
	.else
		inc	dx
		.if	CardType==50
			add	dx, 6
		.endif
		in	al, dx
		and	al, DB6_Stop	; same as DB5_Stop
	.endif
	

	.if	zero?       ; bit 0 is Button - normally high
	    mov	ax, ERR_BUTTON
	    mov	byte ptr stepping_status, al	; 2015-01-06 reinstated STOP sensing (STOPButtonCheck)
	.endif

	ret

STOPButtonCheck	endp

;=================================================================================

FilterBytes proc near C uses bx cx dx, Samples: word, nSamples:word

;=================================================================================


	; now find bits that have the same value in n or (n-1) cases

	mov	cx, nSamples
	mov	dl, 0ffh
	mov	dh, 0

	.repeat
	  mov	bx, Samples
	  mov	al, 0
	  mov	ch, al
	  dec	cl
	  mov	ah, 0ffh
	  .repeat
	    .if	ch != cl
	      or  al, [bx] ; only 0s will remain 0
	      and ah, [bx] ; only 1s will remain 1
	    .endif
	    inc	bx
	    inc	ch
	  .until ch >= byte ptr nSamples

	  and	dl, al
	  or	dh, ah
	.until  !cl

	; 0s in dl are definitely 0
	; 1s in dh are definitely 1

	mov	ah, dl
	not	ah
	or	ah, dh	; validity mask
	mov	al, ah
	not	al
	or	al, dh ; output

	; validity mask al = result, ah = validity mask (valid bit positions = 1)

	ret

FilterBytes endp

;=================================================================================

MotorPower proc C, mno:word, action:word

;=================================================================================

	mov	bx, mno
	dec	bx

	.if	bx >= nmotors
	  stc
	  ret
	.endif

	
	.if	action>=2		; 
		
		;====================	read current state 	==================================
		
		bt		MotorPowerState, bx			; test appropriate bit
		sbb	ax, ax

	.elseif	action==1		

		;====================	switch motor power on		==============================
		
		bts	MotorPowerState, bx	; set bit bx

		mov	cx, bx          	;// keep mno

		inc	bx
		invoke GetMotorRecordOffset, bx
		mov	al, byte ptr Motor[bx+3].CyclePosition ;// look up position
		mov	bx, cx	; mno in bx
		
		;bsf	cx, StepMask
		mov	cl, Motor[bx].RoundOff
		shr	al, cl
		adc	al, 0
		shl	al, cl

		invoke OutputMotorPhase, bx, al
		
	.elseif	action==0		

		;===========================		switch motor power off		=====================
		
		btr	MotorPowerState, bx	; reset bit bx
		
		.if	CardType >= 70	; DC7, x86 explicit control
		
				mov	ax, bx
				shr	ax, 2	; gives DB7 board no
				and	al, 0fh	; guarantee function 0 (motor write)
				and	bx, 3			; last two bits are motor address
				invoke	DB7_PutWord, bx, al	; set both coils to 0
		
		.else	; either DB5 or DB6

			; work out the board address			
			mov	dx, bx
			add	dx, bx
			and	dx, 18h
			add	dx, CardAddress		;// board address in dx for motor bx

			.if	CardType==50

				.if	!(bx&2)
					inc	dx
				.endif			;// port address now in dx

				in	al, dx			;// current port setting for 2 motors
				.if	bx&1
				and	al, NOT 0ah 	;// high nibble motor
				.else
				and	al, NOT 0a0h  	;// low nibble motor
				.endif
				out	dx, al

			.elseif CardType>=60

				mov	ax, bx
				and	ax, 3			; last two bits are motor address
				invoke DB6_PutWord, ax	; set both coils to 0

			.endif
		
		.endif

	.endif

	clc
	ret

MotorPower	endp

;=================================================================================

OutputMotorPhase proc C uses bx cx, Mno:word, Phase:byte

;=================================================================================
	

	mov	ax, CardType
	

	.if ax >= 60 ; DB5 emulation by DB6
	

		.if ax <= 68	; DB6 card
			;invoke	GetDB6CoilCurrents, Mno, Phase
			invoke	OutputDB6MotorPhase, Mno, Phase
		.else	;	DC7 card
			.if ax == 70		;	DB7 card // DC7 clever stepping not resolved for the moment
				;invoke	GetDB6CoilCurrents, Mno, Phase
				invoke	OutputDB7MotorPhase, Mno, Phase
			.endif
		.endif
		
	.elseif ax == 50	; DB5 card
	
		invoke	OutputDB5MotorPhase, Mno, Phase
	
	.endif

	mov	ax, Mno
	bts	MotorPowerState, ax

	mov	bx, Mno
	bts	HasStepped, bx
	mov	light_time[bx], 100
	mov	cl, bl
	add	cl, cl
	mov	eax, 1
	shl	eax, cl
	.if	Motor[si].Status & BACKWARDS
		or	LEDSwitchOff, eax
		shl	eax, 1
		or	LEDSwitchOn, eax
	.else
		or	LEDSwitchOn, eax
		shl	eax, 1
		or	LEDSwitchOff, eax
	.endif
	clc


	ret


OutputMotorPhase endp

;=================================================================================

GetSingleCoilDAC proc C, Current:word, Angle:word

;=================================================================================

;	Angle	: 0-255, ie 360 degrees divided into 256 parts
;	Mno	: 0-15 - looks up motor_current[]


;	Result returned in AX : Saaaaaa=-sin(angle), Sbbbbbb=cos(angle)

;	15 14 13 12 11 10 9   8  7  6  5  4  3  2   1  0
;	S  a  a  a  a  a  a   S  b  b  b  b  b  b   m  m


	push	bx
	push	dx			; save original dx (port address)


	mov	bx, Angle
	xor	bh, bh			; period 256
	shl	bl, 1				; word addressing sine table
	pushf				; save carry = sign bit

	add	bx, CoilCurrentTable
	mov	ax, Current
	mul	word ptr [bx]

	popf
	.if	carry?
	  .if	dx
	    add	dx, 04080h		; result = - sin(angle-128)
	  .endif
	.else
	  .if	dx
	    add	dx, 00080h		; result in dh
	  .endif
	.endif

	mov	ax, dx			; save sine result

	pop	dx			; restore port address
	pop	bx

	ret


GetSingleCoilDAC endp


;=================================================================================

GetDB6CoilCurrents proc C uses bx cx dx, Mno:word, Angle:byte

;=================================================================================

;	Angle	: 0-255, ie 360 degrees divided into 256 parts
;	Mno	: 0-(nmotors-1) - looks up motor_current[]


;	Result returned in AX : Saaaaaa=-sin(angle), Sbbbbbb=cos(angle)

;	15 14 13 12 11 10 9   8  7  6  5  4  3  2   1  0
;	S  a  a  a  a  a  a   S  b  b  b  b  b  b   m  m


local	Current: word


	mov	bx, Mno
	inc	bx
	invoke	GetMotorRecordOffset, bx
	mov	ax, Motor[bx].Current
	.if	ax>7E00h		; test for high current mode
	  shr	ax, 1			; note - should send range bit=1 to 3972
	.endif
	mov	Current, ax
	movzx	bx, Angle

	invoke	GetSingleCoilDAC, Current, bx
	push	ax			; save sine result

	add	bx, 64
	invoke	GetSingleCoilDAC, Current, bx ; cos value

	pop	dx			; sine value
	mov	al, dh
	shl	al, 1
	shl	ax, 1
	and 	ax, not 3
	mov	dx, Mno
	and	dx, 3			; for motors 0-3 per board
	or	ax, dx			; merge motor number

	ret


GetDB6CoilCurrents endp

;=================================================================================

LookupIntegerSine proc near C, Angle:byte

;=================================================================================

	movzx	bx, Angle
	shl	bl, 1
	pushf
	.if	bx
	  mov	ax, SineTable[bx]
	  shr	ax, 1
	  popf
	  .if	carry?
	    neg	ax
	  .endif
	.else
	  popf
	  xor	ax, ax
	.endif

	ret

LookupIntegerSine endp

;===================================================================

OutputDB5MotorPhase proc C uses bx dx, mno:word, phase:byte

;=====================	Point to motor port	================================

	mov	dx, mno
	mov	al, dl
	and	dl, 0Fh
	shl	dx, 2
	add	dx, CardAddress	; point to port A
	.if	!(al & 2)
		inc	dx; point to port B for motors 0, 1
	.endif

;======================	Lookup new phase pattern ============================

	movzx	bx, phase
	shr	bx, 5			; just 3 MSBs
	mov	ah, DB5_PhaseTable[bx]	; get new bit pattern in both high and low nibbles

;====================== Merge with current motor pair outputs	=============

	in	al, dx			; get current port setting
	
	.if	mno & 1			; odd motor

	    ;//	Note motor adresses are in reverse order i.e.

	    ;//	Motor 0		Port bits B4-B7
	    ;//	Motor 1		Port bits B0-B3
	    ;//	Motor 2 	Port bits A4-A7
	    ;//	Motor 3 	Port bits A0-A4
	
		xchg	al, ah			; swap new/current to change which half is retained
		
	.endif				
	
	and	ax, 0f00fh
	or	al, ah                  ; merge new with current
	out	dx, al			; and send new phase pattern to port

	ret

OutputDB5MotorPhase endp

;====================	Motor Phase Pattern Table  =============================


L1_LO	=	000h
L1_HI	=	011h
L1_EN	=	022h
L2_LO	=	000h
L2_HI	=	044h
L2_EN	=	088h

DB5_PhaseTable	label	byte
;public phase_table


	db	L1_HI + L1_EN +	L2_HI + L2_EN	; 0     F
	db                      L2_HI + L2_EN	; 1     C
	db	L1_LO + L1_EN +	L2_HI + L2_EN	; 2     E
	db	L1_LO + L1_EN                   ; 3	2
	db	L1_LO + L1_EN +	L2_LO + L2_EN	; 4	A
	db                      L2_LO + L2_EN	; 5     8
	db	L1_HI + L1_EN +	L2_LO + L2_EN	; 6     B
	db	L1_HI + L1_EN                   ; 7     3



LightBit	db	03h, 0Ch, 30h, 0C0h


;=================================================================================

OutputDB6MotorPhase proc C, Mno:word, Phase:byte

;=================================================================================


	invoke	GetDB6CoilCurrents, Mno, Phase

	mov	dx, Mno
	and	dx, 0FCh
	shl	dx, 1
	add	dx, CardAddress
	invoke	DB6_PutWord, ax

	ret


OutputDB6MotorPhase endp

;=================================================================================

OutputDB7MotorPhase proc C, Mno:word, Phase:byte

;=================================================================================


	invoke	GetDB6CoilCurrents, Mno, Phase
	mov	cx, ax
	mov	bx, Mno
	shr	bx, 2
	invoke	DB7_PutWord, cx, bl

	ret


OutputDB7MotorPhase endp


;======================   LED Display  =========================================

OutputToLED proc near C uses ax bx dx, BoardNo : word, Value : byte

;=============================================================================

	mov	al, Value
	mov	bx, BoardNo
	and	bx, 3

	.if	al != LEDPortImage[bx]

		mov	LEDPortImage[bx], al
		
		.if	CardType>=50
		
			.if CardType<=68
				
				mov	dx, BoardNo
				shl	dx, 3
				add	dx, CardAddress
				add	dx, 5
				out	dx, al			; LED port
				
			.elseif CardType==70
				
				mov	dx, CardAddress
				
				mov	ah, LEDMap[bx]
				out	dx, eax		; LED port is BaseAddress+0, dword write. format: 0000 0YBB DDDDDDDD where Y is yellow light, BB is LED bank index, DDDDDDDDD is LED bit pattern

			.endif
				
		.endif

	.endif

	ret
	
OutputToLED	endp
;======================   LED Display  =========================================

LED_Display proc near C uses eax ebx edx si

;=============================================================================

; LightsOn contains bit pattern for lights that should be ON etc.


;	control of front panel LEDs - calculate when to switch OFF

local	nboards : word

	xor	ebx, ebx
	mov	si, bx

	mov	eax, 3
	.repeat
	  .if	light_time[bx]

		dec	light_time[bx]
		.if	zero?		; time to switch light off
			or	LEDSwitchOff, eax
		.endif

	  .endif
	  shl	eax, 2
	  inc	bx
	.until bx==nmotors

	mov	eax, LEDSwitchOff
	not	eax
	and	eax, dword ptr LEDPortImage
	or	eax, LEDSwitchOn


	mov	bx, nmotors
	shr	bx, 2
	mov	nboards, bx

	xor	bx, bx
	.repeat
		invoke	OutputToLED, bx, al
		shr	eax, 8
		inc	bx
	.until	bx==nboards
	
	mov	LEDSwitchOn, 0
	
	ret

LEDSwitchOn  dword	0
LEDSwitchOff 	dword	0

LED_Display	endp

;===========================================================================

DB6_PutWord	proc C, OutWord:word

;===========================================================================

local	DB6State:byte

comment #

stepping_status array elements defined in STEP.INC :

ssStatus		equ	0
ssBoard 		equ	2
ssInstruction		equ	4
ssAccessCount		equ	6
ssMaxAccessCount	equ	8
ssIntTime		equ	10
ssMaxIntTime		equ	12

#

	mov	stepping_status[ ssBoard ], dx	; record board address
	push	dx
	and	dx, not 7
	inc	dx			; point to status port

	mov	stepping_status[ ssAccessCount ], 0
	.repeat
	  call	PCI_BusDelay
	  in	al, dx
	  call	PCI_BusDelay
	  inc	stepping_status[ ssAccessCount ]
	.until  (al & DB6_Ready)||(stepping_status[ ssAccessCount ]==20000); wait for ready bit to be true

	mov	DB6State, al
	mov	dx, stepping_status[ ssAccessCount ]
	.if	dx > stepping_status[ ssMaxAccessCount ]
	  mov	stepping_status[ ssMaxAccessCount ], dx
	.endif

	pop	dx			; point back to destination port

	mov	ax, OutWord
	mov	stepping_status[ ssInstruction ], ax


	.if !(DB6State & DB6_Ready)
	  or	stepping_status, ERR_DB6CARD
;	  .if	DebugMode & dlDB6_OUTPUT
;	    invoke DebugLog, ax
;	    mov	ax, dx
;	    or	ax, 8000h
;	    invoke DebugLog, ax
;	  .endif
	  stc

	.else

	  call	PCI_BusDelay
	  out	dx, ax			; Output to port
	  call	PCI_BusDelay
;	  .if	DebugMode & dlDB6_OUTPUT
;	    invoke DebugLog, ax
;	    invoke DebugLog, dx
;	  .endif
	  clc

	.endif


;	for testing only

;	or stepping_status, ERR_DB6CARD
;	stc

	ret

DB6_PutWord endp

CheckDC7 proc C

	mov	dx, 0318h
	mov	CardAddress, dx
	mov	bx, 4
	
	.repeat
		dec	bx
		xor	eax, eax
		mov	ax, bx
		out	dx, eax
		call	PCI_ind	;	in	eax, dx
		sub	ax, bx
	.until	ax || bx==0
	
	ret

CheckDC7 endp

PCI_in	proc C

	pushf
	cli
	;call	PCI_BusDelay
	in	al, dx
	.if	al==0ffh
		;call	PCI_BusDelay
		add	dx, 4
		in	al, dx
		sub	dx, 4
	.endif
	popf
	ret
	
PCI_in	endp

PCI_inw proc C

	pushf
	cli
	;call	PCI_BusDelay
	in	ax, dx
	.if	ax == -1
		;call	PCI_BusDelay
		add	dx, 4
		in	ax, dx
		sub	dx, 4
	.endif
	popf
	ret
	
PCI_inw	endp

PCI_ind proc C

	pushf
	cli
	;call	PCI_BusDelay
	in	eax, dx
	.if	eax == -1
		;call PCI_BusDelay
		add	dx, 4
		in	eax, dx
		sub	dx, 4
	.endif
	popf
	ret

;	mov	cx, 16
;	push dx
;	.repeat
;		in	eax, dx
;		xor	dx, 4
;	.untilcxz	ax!= -1
;	pop dx
;	ret
	
PCI_ind	endp
;===========================================================================

DB7_PutWord	proc C uses es ebx, OutWord:word, Address:byte

;===========================================================================

	
	mov	dx, CardAddress
	xor	ah, ah
	.repeat
		call	PCI_in
		dec	ah
	.until (al & 1)||(!ah)

	
	.if !ah
		mov	ax, -1
		mov	es:[ebx], ax
		mov	es:[ebx+2], ax
		stc
	.else
		mov	al, Address
		out	dx, al
		mov	ax, OutWord
		out	dx, ax
		call	PCI_in	;	in		al, dx	 ie GetDC7Status
		xor	ah, ah
		clc
	.endif
	ret


DB7_PutWord endp

WriteLogWord proc C uses ax ds ebx, Data:word
	
	push	0
	pop	ds
	
	mov	ebx, LogIndex
	mov	ax, Data
	mov	[ebx+200000h], ax
	inc	ebx
	inc	ebx
	and	ebx, 0FFFFFFh
	mov	LogIndex, ebx
	ret

WriteLogWord endp


LogIndex dd	0

;===========================================================================

GetDB7Status	proc C, BoardNo:byte

;===========================================================================

	mov	al, BoardNo
	or	al, 30h
	invoke DB7_PutWord, 0, al
	
	xor	ah, ah
	.repeat
		call	PCI_in
		dec	ah
	.until (al & 1)||(!ah)

	call	PCI_in	;	in		al, dx

	ret
	
GetDB7Status	endp

;===========================================================================

GetDC7Status	proc C uses dx

;===========================================================================

	mov	dx, 0318h
	call	PCI_in	;	in		al, dx
	ret
	
GetDC7Status	endp

_TEXT	ends


	end
