;===========================================================================

comment #

	FileName	:	DC7-INT.ASM
	Date		:	2012-08-13

	Function	:	Stepper interrupt routine for constant timebase algorithm for DC7+DB7/DB6/DB5??
	Note		:	Taken from ACT-DB6.ASM

	Author		:	Peter Baldock
	Copyright	:	Douglas Instruments Limited 2010
	

Version History
============

	2013-05-16	Version 5.39 // DC7-INT::OneStep Old phase uses CycleCount[si+2] instead of [si+3]
	2012-08-13	Version 5.35 // ::Dwell - Backlash compensation now done at VStart
	2010-08-27	Version 5.00 // Taken from ACT-DB6.ASM - Constant Timebase Stepping -now pairs with DC7-ACT.ASM

#

;=================================================================================

option language:c

	include	..\include\loader.inc
	include	..\include\step.inc
	include ..\include\macros.inc

_TEXT	segment

	.486
	
	
;=================================================================================

comment #

Publics
======

	OneStep							proc near
	step_int							proc	near		; interrupt routine
	
#


;=============================================================================

step_int	proc	near		; interrupt routine

;=============================================================================
local	TStart: dword

	pushad				; save everything
	push	ds

	
	
	mov	ds , FORTHds		; FORTHds is in _TEXT, so accessible via cs:
;	invoke	LoadSegment, 'ds', FORTHds , cs, 1000h ;seg _TEXT, seg _TEXT+1000h
	assume	ds:_FORTH_DATA

	mov	dx, 0318h
	mov	ax, -1			; Fiducial marker (probe 6) 
	out	dx, eax

;	call	PCI_ind	
;	invoke	WriteLogWord, ax
	
;	mov	TStart, eax
	
	.if	StepMask

		.if	stepping_status & STEPPING

			call	OneStep	; returns n motors stepped in ax

			;.if	(!ax)&&!(stepping_status & 0ffh)	; if not end of move and not stepping
			;	call	[ActuateNextMove]	; run setup for next stage of movement
			;.endif

		.endif

	 	invoke LED_Display

	.endif

	movzx	eax, word ptr step_time
	.if	eax
		add	NanoTicksElapsed, eax
	.else
		add	NanoTicksElapsed, 0FFFFh
	.endif
	
	.if	(!ax) || (ax>2000)
		sub	pseudo_timer, 597
	.else
		sub	pseudo_timer, ax
	.endif
	
	.if	carry?
	  ; Generate pulses at regular intervals to synchronize AxisActuate. etc

	  mov	ax, interruptCounter
	  inc	ax
	  .if	ax>=PulseGeneratorInterval	; interval now specified in ticks
	    xor	ax, ax
	    or	PulseOut, 1
	  .endif
	  mov	interruptCounter, ax
;	  jmp clear_PIC	; dignostics only, to remove BIOS timer function

;	  .if	stepping_status & DECELERATING
;	    or	PulseOut, 2
;	  .endif


StandardTick:
	  pushf
	  call	StandardTickInterrupt	; standard routine should clear PIC

	.else

clear_PIC:
	  cli
	  mov	al, 20h
	  out	20h, al			; clear PIC

	.endif


	;call	GetNanoTicks
	;sub	eax, TStart
	;.if	ax > stepping_status[ssMaxIntTime]
	;  mov	stepping_status[ssMaxIntTime], ax
	;.endif
	
;	call	PCI_ind	
;	invoke	WriteLogWord, ax

	mov	dx, 0318h
	mov	ax, -2			; Fiducial marker (probe 6)
	out	dx, eax
	
	

	pop	ds
	popad

	iret


;=====================================================================

;LogInterruptTime::
;
;	mov	al, 0
;	out	43h, al
;	in	al, 40h
;	mov	ah, al
;	in	al, 40h
;	xchg	al, ah
;	neg	ax
;	add	ax, word ptr step_time
;	mov	stepping_status[ssIntTime], ax
;	.if	ax > stepping_status[ssMaxIntTime]
;	  mov	stepping_status[ssMaxIntTime], ax
;	.endif
;
;	retn


step_int	endp

;=================================================================================

OneStep	proc near

;==============================================================

local	mno:word, MotorsStepping:word, OldPhase:byte

; BEGIN Read Inputs	======= Get STOP Button and Limit Switch inputs =====


	.if	(stepping_mode & BUTTON)		;	Scan STOP Button State
	  invoke	STOPButtonCheck
	.endif

	.if	(stepping_mode & LIMIT_SWITCH)	;	Scan LS Inputs if necessary
		pushad
	 	call	ScanLimitSwitches
	 	popad
	.endif


; END Read Inputs	=====================================================



; BEGIN Scan Motors	============ Scan motors to calculate new phase currents  =============


	xor	esi, esi
	mov	mno, si
	mov	MotorsStepping, si
	mov	LEDSwitchOn, esi
	mov	LEDSwitchOff, esi

	.repeat	; for si indexing all motors

		call	CheckForAbort

		.if	Motor[si].Status & STEPPING

			
			.if Motor[si].Status & WAITING
				call	Dwell
			.else				

; ===========	motor has the possibility of stepping		========================================

				;	round the current position and store for comparison after new position calculation
				mov	al, byte ptr Motor[si+3].CyclePosition
				mov	cl, byte ptr Motor[si].RoundOff	;StepMask+1
				.if cl
					shr	al, cl
					adc	al, 0
					shl	al, cl
				.endif
				mov	OldPhase, al			; save rounded current coil angle
				
				call	IncrementPosition	; returns distance moved in edx

				.if	Motor[si].Status & ACCELERATING
					call	Accelerate
				.endif
				
				
				.if	Motor[si].AccelCount

					.if Motor[si].Status & DECELERATING
						call	Decelerate
					.else; check if deceleration necessary
						call	DecelerationCheck
					.endif

				.endif ;/ Motor[si].AccelCount
				
				call	CheckMoveEnd	; check to see if end of normal move reached

;=================================================================================

				;	round the position							
				mov	al, byte ptr Motor[si+3].CyclePosition
				mov	cl, byte ptr Motor[si].RoundOff	;StepMask+1
				.if cl
					shr	al, cl
					adc	al, 0
					shl	al, cl
				.endif
				
				.if	al != OldPhase	; output the new position (if changed)
				
					mov	bl, al
					sub	bl, OldPhase	
				
					.if	bl > sbyte ptr stepping_status[16]
						mov	sbyte ptr stepping_status[16], bl
					.elseif bl < sbyte ptr stepping_status[17]
						mov	sbyte ptr stepping_status[17], bl
					.endif

					call	ISA_BusDelay
					call	ISA_BusDelay
					call	ISA_BusDelay
					
					call	ISA_BusDelay
					call	ISA_BusDelay
					call	ISA_BusDelay
					
					invoke	OutputMotorPhase, mno, al	; ax returned with LS bits 0-3

					mov	bx, mno
					shr	bl, 2
					bts	LSSampledByInterrupt, bx
					.if		!carry?
					
						mov	ax, CardType
						
						.if ax == 50
							invoke GetDB5LSInputs, bx
						.elseif	ax <= 68
							invoke GetDB6LSInputs, bx
						.else
							mov	dx, CardAddress
							call PCI_inw					; read DB7 word
						.endif
						mov	LSBuffer[bx], al
						
					.endif

				.endif			; /output the new position (if OldPhase changed)
		
			.endif

		 .endif ; if STEPPING

		add	si, sizeof(MotorRecord)
		inc	mno
		mov	cx, mno

	.until cx==nmotors


	mov	ax, MotorsStepping
	.if !ax
		  and	stepping_status, NOT (STEPPING+ACCELERATING+DECELERATING)
	.endif
	
	ret
	
; END Scan Motors	=====================================================

CheckForAbort:

	.if	stepping_status & 0ffh	; an abort condition
	  .if	Motor[si].AccelCount
		and Motor[si].Status, not ACCELERATING
		or Motor[si].Status, DECELERATING
	  .else
		and	Motor[si].Status, not (STEPPING + ACCELERATING + DECELERATING)
	  .endif
	.endif
	
retn

;=================================================================================

IncrementPosition:

	mov	eax, Motor[si].DeltaX
	add	Motor[si].CyclePosition, eax
	cdq
	adc	Motor[si].CycleCount, dx		; 48 bit position

	mov	eax, Motor[si].TargetPosition
	sub	eax, Motor[si+2].CyclePosition	; eax is new distance
	mov	edx, Motor[si].Distance
	mov	Motor[si].Distance, eax		; write back new distance
	sub	edx, eax			; edx=change in distance

retn

;=================================================================================

Accelerate:					; takes distance moved in edx

	  add	Motor[si].AccelerationDistance, edx
	  mov	ebx, Motor[si].DeltaV
	  add	ebx, Motor[si].DeltaX


	  .if	Motor[si].Status & BACKWARDS	; stepping backwards
		.if	ebx<Motor[si].DeltaXRun
		  mov	ebx, Motor[si].DeltaXRun
		  and	Motor[si].Status, not ACCELERATING
		.endif
	  .else
		.if	ebx>Motor[si].DeltaXRun
		  mov	ebx, Motor[si].DeltaXRun
		  and	Motor[si].Status, not ACCELERATING
		.endif
	  .endif

	  mov	Motor[si].DeltaX, ebx
	  inc	Motor[si].AccelCount

retn

;=================================================================================

DecelerationCheck:

	;deceleration calculation


	.if	Motor[si].Status & BACKWARDS
		mov	eax, Motor[si].AccelerationDistance
		sub	eax, Motor[si].Distance
	.else
		mov	eax, Motor[si].Distance
		sub	eax, Motor[si].AccelerationDistance
	.endif

	.if carry? || stepping_status & 0ffh	; error flagged
		or	Motor[si].Status, DECELERATING
		and	Motor[si].Status, not ACCELERATING
	.endif

	retn

;=================================================================================

Decelerate:
				
		sub 	Motor[si].AccelerationDistance, edx ; movement

		mov	ebx, Motor[si].DeltaX
		sub	ebx, Motor[si].DeltaV
		mov	Motor[si].DeltaX, ebx

		dec	Motor[si].AccelCount

retn
;=================================================================================

Dwell:

	inc	MotorsStepping
	dec	Motor[si].AccelCount
	.if	zero?
		.if	Motor[si].Status & BCOMP
			and	Motor[si].Status, not (WAITING+ACCELERATING+DECELERATING)
			mov	eax, Motor[si].Backlash
			mov	Motor[si].Distance, eax
			mov	Motor[si].Magnitude, eax
			add	Motor[si].TargetPosition, eax
			mov	eax, Motor[si].Vstart
			mov	Motor[si].DeltaX, eax
			mov	Motor[si].DeltaV, 0
			.if  eax<0
				neg	Motor[si].DeltaX
				neg	Motor[si].Magnitude
			.endif
			xor	Motor[si].Status, BACKWARDS+BCOMP
		.else
			and	Motor[si].Status, not (STEPPING+WAITING+ACCELERATING+DECELERATING)
			dec	MotorsStepping
		.endif
	.endif
	
retn
		
;=================================================================================

CheckMoveEnd:


		.if	Motor[si].Status & LIMIT_SWITCH
		
			.if	!Motor[si].AccelCount
				and	Motor[si].Status, not (STEPPING+WAITING+ACCELERATING+DECELERATING)
			.else
				inc	MotorsStepping
			.endif		
		
		.else

			mov	eax, Motor[si].TargetPosition

			.if	Motor[si].Status & BACKWARDS
				cmp	eax, Motor[si+2].CyclePosition	; .if	eax>=Motor[si+2].CyclePosition
			.else
				cmp	Motor[si+2].CyclePosition, eax	; eax<=Motor[si+2].CyclePosition.if
			.endif

			jl	@F	; jump if target not reached

			; target reached

			mov	Motor[si+2].CyclePosition, eax
			mov	word ptr Motor[si], 0
			.if	Motor[si].DwellTime
				mov	ax, Motor[si].DwellTime
				mov	Motor[si].AccelCount, ax
				and	Motor[si].Status, not (ACCELERATING + DECELERATING)
				or	Motor[si].Status, WAITING
			.else
				and	Motor[si].Status, not (STEPPING + ACCELERATING + DECELERATING)
				dec	MotorsStepping
			.endif

@@:
			inc	MotorsStepping
		
		.endif

retn

OneStep	endp

;=================================================================================

ScanLimitSwitches proc near

;===========================================================================

local	BoardCount : word, SameCount:word

	assume ds:_FORTH_DATA


;===================	Poll Limit Switch Inputs ============================


	mov	si, nmotors
	shr	si, 2			; 4 motors/board
	mov	BoardCount, si
	xor	si, si
	mov	bx, si
	
	.repeat


		mov	ax, Motor[si].Status
		or	ax, Motor[si+sizeof(MotorRecord)].Status
		or	ax, Motor[si+2*sizeof(MotorRecord)].Status
		or	ax, Motor[si+3*sizeof(MotorRecord)].Status
	  
		bt	LSSampledByInterrupt, bx
	  	.if	carry? && (ax & STEPPING)	; if any motor on this board due to move, and there is limit switch data waiting

			invoke GetFilteredLSInputs, bx, LSQLength-1
				; returns filtered LS inputs in al
			.if	(stepping_mode & LS_HIGH)
				not	al
			.endif

			mov	cx, 4
			.repeat
				push	cx
				.if (al & 1)
					.if Motor[si].Status & STEPPING
						.if	Motor[si].AccelCount
							and Motor[si].Status, not ACCELERATING
							or Motor[si].Status, DECELERATING + LIMIT_SWITCH
						.else
							and	Motor[si].Status, not (STEPPING + ACCELERATING + DECELERATING)
							or Motor[si].Status, LIMIT_SWITCH
						.endif
						; mov byte ptr stepping_status, ERR_LIMITSWITCH
					.endif
				.endif
				shr al, 2
				add	si, sizeof(MotorRecord)			; next motor
				pop	cx
			.untilcxz
		.else
			add	si, 4 * sizeof(MotorRecord)	; move on 4 motors to next board
		.endif	; endif any motor on this board due to move

		inc	bx

	.until	bx==BoardCount

	ret

;=================================================================================

ScanLimitSwitches endp

;=================================================================================


_TEXT	ends

end


