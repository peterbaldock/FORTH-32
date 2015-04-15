comment #

24-04-92 Version 1.53	nmotors, station_count added for
					reduced scan loop in actuate.

25-04-92 Version 1.54	turning prims.asm into a module
					all references to BASE removed

22-05-92 Version 2.00	turning all functions into C callable

25-05-92 Version 2.01	Split PRIMS.ASM into :
					MOVES.ASM + CTRL.ASM + TIMING.ASM

02-06-92 Version 2.06	Individual motor speed setting
					 + Get_Period

05-06-92 Version 2.07	Fully selectable speed control.

06-01-93 Version 2.11	msec corrected to use proper C calling/return

28-05-93 Version 3.00	32 bit positions/increments

01-06-93 Version 3.10	Interrupt driven

28-08-93 Version 3.15	Modifications to provide Ver. 2.xx compatible
				CR/EOF return buffer termination.

14-07-98 Version 4.20	+ Set_Speed_Factor, mods to Set_Speed

29-10-00 Version 2.39	~ msDelay altered to use timer0 instead of loop

01-12-00 Version 2.40	CLOCKS_PER_MILLISECOND changed to 1193 (previously doubled delay)

12-10-01 Version 2.55	+ ISA_BusDelay to prevent hanging when reading 8253 timer too frequently

21-11-01 Version 2.56	msDelay .until condition corrected

2003-08-26 Version 2.85	+ Set_Current_Speed - doesn't change max speed

2004-05-05 Version 2.93 + GetMaxSpeed, GetCurrentSpeed for correct priming of
			  Syringe.ocx in FP

#
	option language:c

	include	..\include\step.inc
	include	..\include\fp.inc


_TEXT	segment

	.486


	assume	ds:_FORTH_DATA



TLoop	proc C uses ecx, LoopCount: dword

	mov	ecx, LoopCount
	.while	ecx
	  dec	ecx
	.endw
	ret

TLoop	endp


TLoopTime proc C uses bx, LoopCount: dword

	pushf
	cli

	;call	T0Sync		; returns current value of Timer0 in ax

	call	read_8253
	mov	bx, ax
	invoke	TLoop, LoopCount
	call	read_8253
	xchg	bx, ax
	sub	ax, bx

	popf
	ret			; return number of 8253 clocks

TLoopTime endp

TLoopCalibrate proc C uses edx; ebx

local	LCMin	  : dword
local	LCMax	  : dword
local	ClocksMin : word
local	CPMS	  : dword

	mov	al, 34h			; rate generator mode for channel 0
	out	43h, al			; set mode - this also freezes current count
	mov	al, 0ffh
	out	40h, al
	out	40h, al

	mov	LCMin, 800	; start with small loop count
	invoke  TLoopTime, LCMin
	.while	ax<500
	  shl	LCMin, 1
	  invoke  TLoopTime, LCMin
	.endw

	; AX contains # 8253 clocks for TMin loops

	mov	ClocksMin, ax	; gives indication of milliseconds for LCMin



	; calculate LCMax = 32*LCMin for ~ 10ms sample


	mov	eax, LCMin
	shl	eax, 5
	mov	LCMax, eax

	invoke	TLoopTime, LCMax

	; AX contains # 8253 clocks for TMax loops

	sub	ax, ClocksMin
	movzx	ebx, ax	; convert to dword

	mov	eax, LCMax
	sub	eax, LCMin


	; eax should now contain # loops for ebx number of 8253 clocks
	; ebx contains number of 8253 clocks for this loop count

	mov	CPMS, CLOCKS_PER_MILLISECOND
	mul	CPMS
	div	ebx	; quotient in EAX
	mov	MicrosecondDelayCount[12], eax	; 10^3 us = 1ms
	mov	ebx, 10
	add	eax, 5
	mov	edx, 0
	div	ebx
	mov	MicrosecondDelayCount[8], eax	; 10^2 us = 100 us
	add	eax, 5
	mov	edx, 0
	div	ebx
	mov	MicrosecondDelayCount[4], eax	; 10^1 us = 10 us
	add	eax, 5
	mov	edx, 0
	div	ebx
	mov	MicrosecondDelayCount[0], eax	; 10^0 us = 1us
	shr	eax, 2
	mov	PCIBusDelayCount, eax		; 250ns=8cycles


	mov	eax, MicrosecondDelayCount[12]	; 10^3 us = 1ms

	ret		; loops (per millisecond) in eax

TLoopCalibrate endp



GetTickCount proc C uses cx dx
	mov	ah, 0
	int	1ah
	push	cx
	push	dx
	pop	eax
	ret
GetTickCount endp


;**************************************************************

Tone proc C uses ax bx dx, frequency:word, period:word

;**************************************************************

	.if	!period		; if period==0 switch off speaker immediately
	  jmp	ToneOff
	.endif
	mov     ax,  34DDh
	mov     dx,  0012h
	cmp     dx,  frequency
	jnb     ToneOff
	div     frequency
	mov     bx,  ax
	in      al,  61h
	test    al,  3
	jne     j1
	or      al,  3
	out     61h, al
	mov     al,  0B6h
	out     43h, al
j1:
	mov     al,  bl
	out     42h, al
	mov     al,  bh
	out     42h, al

	.if	period!=-1	; period==65535 => leave on continuously
	  invoke msDelay, period ; sound tone for period milliseconds
ToneOff:

	  in      al, 61H
	  and     al, 0fcH
	  out     61H, al

	.endif

	ret

Tone	endp

;**************************************************************

PlayNote proc C uses ax bx cx dx, note:word, duration:word

;**************************************************************

local	staccato:word

	mov	ax, duration
	mul	UnitNoteDuration


	mov	bx, note
	xor	bh, bh
	mov	staccato, bx
	and	staccato, 80h
	.if	!zero?
	  shr	ax, 1
	.endif

	.if	bx

	  and	bl, 7fh
	  mov	cx, 09fh
	  sub	cx, bx
	  shr	cx, 4
	  and	cx, 0Fh

	  and	bx, 0Fh
	  add	bx, bx
	  mov	dx, cs:scale[bx]
	  shr	dx, cl

	  invoke Tone, dx, ax
	  .if	staccato
	    jmp	rest
	  .endif
	.else

rest:	  invoke msDelay, ax

	.endif

	ret

scale	dw 16384, 17358, 18390, 19484, 20643, 21870
	dw 23170, 24548, 26008, 27554, 29193, 30929

Bach	dw 3040h, 4040h, 3b40h, 2b40h, 2a40h, 3a40h, 2a40h, 0

PlayNote endp

;**************************************************************

PlayTune proc C uses ax bx cx es, buffer:dword, tempo:byte

;**************************************************************

	les	bx, buffer
	mov	ax, 3000
	div	tempo
	mov	UnitNoteDuration, al

	.while	byte ptr es:[bx]	; low byte is duration
	  xor	cx, cx
	  mov	ax, es:[bx]
	  mov	cl, ah		; high byte is note
	  mov	ah, ch
	  invoke PlayNote, cx, ax
	  add	bx, 2
	.endw
	ret

PlayTune endp


;**************************************************************

GetNanoTicks	proc C uses edx

	; read the msElapsed value and the value in the 8253 timer to return
	; the total number of milliseconds since system on
	; returns EAX : milliseconds

;**************************************************************

local tStart : dword

	mov	eax, NanoTicksElapsed
	mov	tStart, eax
	call	ReadTimer0
	movzx	edx, ax
	mov	eax, NanoTicksElapsed

	.if	eax != tStart
		call ReadTimer0
		movzx	edx, ax
		mov	eax, NanoTicksElapsed
	.endif

	sub	eax, edx
	movzx	edx, word ptr step_time
	add	eax, edx

	ret

GetNanoTicks endp

;**************************************************************

msDelay	proc C uses eax edx, milliseconds:word

;**************************************************************

local DoPoll : word, TargetTime : dword

CLOCKS_PER_MILLISECOND	EQU	1193	;; 2386

	.if	milliseconds==0
	  ret
	.endif

	mov	DoPoll, 0
	.if	milliseconds > 5
	  dec	DoPoll
	.endif

	mov	ax, CLOCKS_PER_MILLISECOND
	mul	milliseconds
	push	dx
	push	ax

	call	GetNanoTicks
	
	

	pop	TargetTime
	add	TargetTime, eax				; target time
	
	mov	edx, TargetTime
	
	
	.if	carry?
	  .repeat
	    push	edx
	    .if	DoPoll
		mov	ax, 2001h
		int	MULTITASK      	;;;;;;;;;;;; continue polling
	    .endif
	    call	GetNanoTicks
	    pop	 	edx
	  .until	sdword ptr eax >= edx
	.else
	  .repeat
	    push	edx
	    .if	DoPoll
		mov	ax, 2001h
		int	MULTITASK      	;;;;;;;;;;;; continue polling
	    .endif
	    call	GetNanoTicks
	    pop		edx
	  .until	eax >= edx
	.endif
	ret
msDelay endp


;**************************************************************

ten_us	proc

	invoke	TLoop, MicrosecondDelayCount[4]
	ret

ten_us	endp
;**************************************************************

wait_AX_clocks	proc near uses bx cx dx

;		inputs	: AX = number of 8253 clocks to wait
;		output  : AX undefined

;**************************************************************

	mov	dx, 40h		; 8253 channel 0 address
	mov	cx, ax
	call	ReadTimer0	; get starting value
store_T0:
	mov	bx, ax
	cmp	ax, cx		; is the counter too near 0?
	jb	too_low
not_done:
	call	ReadTimer0
	sub	ax, bx
	ja	done		; counter wrapped around
	add	ax, cx
	jnc	done
	jne	not_done
done:
	clc
	ret
too_low:
	sub	cx, ax		; number of counts that will be outstanding
				; when 8253 reaches 0
@@:	call	ReadTimer0
	cmp	ax, bx		; wait for timer to be greater than  original reading
	je	@B
	ja	store_T0
	dec	bx		; prevent a stalemate - bx will ultimately
	jmp	@B		; reach a value lower than the reload value

wait_AX_clocks	endp

;**************************************************************

read_8253	proc near

;		Not used 2004-02-05 inputs	: DX = counter channel address
;		output  : AX = timer value

;		2004-02-05 Altered to have no delay between accesses
;		for experimental purposes.

;**************************************************************
	pushf
	cli		; 	prevent interrupts from doing interleaved read
	push	dx	;	save channel address

	; original general code for any timer
	;mov	al, dl
	;or	dx, 3	;	address control register
	;shl	al, 6	;	channel number in bits 6-7, 0 in bits 0-5

	; code for T0 only
	mov	al, 0h  ; 	control code to latch t0
	mov	dx, 43h ; 	address of 8253 control register

	out	dx, al	;	command for latch count
	;call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia
	;pop	dx	;	get original channel address

	mov	dx, 40h	;	T0 address
	in	al, dx	;	low byte
	;call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia
	mov	ah, al
	in	al, dx	;	high byte
	;call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia
	xchg	ah, al	;	normal order
	pop	dx	;	get original channel address
	popf		;	restore interrupt status
	ret

read_8253	endp

;**************************************************************

ReadTimer0 proc C

;**************************************************************

	pushf
	cli
	mov	al,0h           ; control code to latch t0
	out	43h,al		; control reg. at 43h
	call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia

	in	al, 40h		; Timer0 at 40h
	call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia
	mov	ah, al		; save LSB in ah

	in	al, 40h		; get high byte
	call	ISA_BusDelay	; give the 8253 a chance - may need to be extended for Pentia

	xchg	ah, al		; get right byte order
	;	not	ax		; for incrementing value	; No! 2008-03-14
	popf			; restore int flag
	ret			; return #840ns clocks in AX

ReadTimer0 endp

;**************************************************************

;**************************************************************

PCI_BusDelay proc near

;**************************************************************


	; wait 250 ns

	pushf
	cli
	invoke	TLoop, PCIBusDelayCount
	popf
	ret


PCI_BusDelay endp

;**************************************************************

;**************************************************************

ISA_BusDelay proc near

;**************************************************************


	; wait 1 microsecond

	pushf
	cli
	invoke	TLoop, MicrosecondDelayCount[0]
	popf
	ret


ISA_BusDelay endp

;**************************************************************

_TEXT	ends

end
