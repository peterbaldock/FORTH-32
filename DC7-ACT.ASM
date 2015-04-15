
;=================================================================================

comment #

	FileName	:	DC7-ANT.ASM
	Date           	:	2010-08-27

	Function	:	Motor movement algoriths
	Note		:	Uses DC7-INT.ASM

	Author		:	Peter Baldock
	Copyright	:	Douglas Instruments Limited 2010
	
	

Version History
============

	2004-10-14	Version 3.07 // +	More clever opto switch sampling for non-Schmidt Z+V
	2004-11-10	Version 3.11 // +	Brake on STOP/LIMIT_SWITCH in 1/2 acceleration distance.
	2008-05-09	Version 4.09 // +	Constant Timebase Stepping -
	2011-09-13	Version 5.17 // +	Small stepping error fixed with JS at CCMB

#

;=================================================================================

option language:c

	include	..\include\loader.inc
	include	..\include\step.inc
	include ..\include\macros.inc

	CLEANUP	=	0400h

;===========================================================================

_FORTH_DATA		segment
externdef	ReturnStack	:word
_FORTH_DATA ends

;===========================================================================


_TEXT	segment

	.486
	assume	ds:_FORTH_DATA

;=======================================================================================

actuate	proc near, newMode:word

;=======================================================================================


comment #

		the global int   stepping_mode controls stepping as follows :

		  B15----------------------------B11   	 B10	  B9-----B8
				Not used    		NoWait	   Not Used

		  B7	  B6	  B5	  B4	 B3	 B2	  B1	 B0
		Limits	Keybd	Button LSwitch Concrnt  Speed	Vector	BComp

		BComp		Enable backlash compensation			Default OFF
		Vector		Vector Decomposition of move to 45ø vectors	Default OFF
		Speed		Use motor speed array for calculation		Default ON
		Concrnt		Allow independent actuation of separate step commands - illegal.
		LSwitch		Enable optoswitch polling			Default OFF
		Button		Enable BREAK button polling - abort on change	Default ON
		Keybd		Enable keyboard scanning    - abort on keypress	Default OFF
		Limits		Enable limit switch polling - abort on limit	Default OFF

		NoWait		Allow immediate return from actuate, before completion.

		BCOMP		=	0x0001
		VECTOR		=	0x0002
		SPEED		=	0x0004
		CONCURRENT	=       0x0008
		LIMIT_SWITCH	=	0x0010
		BUTTON		=	0x0020
		KEYBD		=	0x0040
		LIMITS		=	0x0080
		NO_ACCELERATION	=	0x0100
		LS_HIGH		=	0x0200
		NO_WAIT		=	0x1000

		DEFAULT_MODE	=	SPEED+BUTTON

;===========================================================================

#

	mov	ax, newMode
	.if	ax != 0ffffh
	  mov	stepping_mode, ax
	.endif

	.if	!(stepping_mode & NO_WAIT)
		call	waitForCompletion
	.endif
	and	stepping_status, STEPPING
	
	call	ActuateCalcs

	.if	!ax ; ax returns error, 0 for success
	
		mov	ax, 4
		.repeat
			dec ax
			push	ax
			invoke PrimeLSQueue, ax, LSQLength-1
			mov	LSSampledByInterrupt, 0Fh
			pop	ax
		.until !ax
		
		cli
		or	stepping_status, STEPPING
		sti

		.if	!(stepping_mode & CONCURRENT)
			call	waitForCompletion
		.endif
	.else
		.if	ax==-1
			inc	ax
		.endif
	.endif
	ret

actuate	endp

;=======================================================================================

ActuateCalcs	proc near uses si di
	
	call	CalculateDistance ; returns number of motors that need to step in ax

	.if	ax
		.if	(stepping_mode & VECTOR)
			call	vectored_move
		.else
			call	proportional_move
		.endif
	.else
		dec	ax	; return -1 to indicate no motors to step
	.endif

	ret
		
ActuateCalcs	endp
;=======================================================================================


;==========================================================================================

proportional_move proc near

;==========================================================================================

local	StartTime : dword
local	RunTime : dword
local	AccelerationTime : dword
local	Temp1 : dword
local StepsToDo : word

	xor	ebx, ebx
	mov	StartTime, ebx
	mov	RunTime, ebx
	mov	AccelerationTime, ebx
	mov StepsToDo, bx

	;	Find the limiting starting velocity for all motors. This is calculated by knowing that
	;	Distance/Vstart must be the same for all motors, if they are to move  in synch

	xor	si, si	;	Motor index
	mov	cx, nmotors
	
;===================================		stage 1 - find max start time		====================

	.repeat

	  .if	Motor[si].Status & STEPPING

		  mov	ebx, Motor[si].Vstart
		  .if	ebx>Motor[si].Vrun				; use Vrun if it is less than VStart
			mov	ebx, Motor[si].Vrun
		  .endif

		  .if	!ebx
			mov	ax, 25
			ret
		  .endif


		  fild	Motor[si].Magnitude
		  fmul	TwoPower16
		  mov	Temp1, ebx
		  fild	Temp1
		  fdiv
	  
		  ;	===================================	calculate StartTime only
		  
		  frndint
		  fistp	Temp1
		  fwait
		  mov	eax, Temp1

		  .if	eax>StartTime
			mov	StartTime, eax
		  .endif
		inc	StepsToDo	; means there are steps to do
			
	  .endif

	  add	si, sizeof(MotorRecord)

	.untilcxz; cx==0

;==============================================================================
	
	.if StepsToDo

		xor	si, si
		mov	cx, nmotors
		.repeat			;	Set up initial velocity of each motor

			mov	eax, Motor[si].Distance
			
			.if	eax

				.if StartTime

					fild	Motor[si].Distance
					fmul	TwoPower16
					;fld	StartTime
					fild	StartTime
					fdiv
					frndint
					fistp	Motor[si].DeltaX
					fwait
					mov	eax, Motor[si].DeltaX

					fild	Motor[si].Magnitude	;	Also calculate limiting acceleration rate
					fmul	TwoPower16
					fild  Motor[si].Vrun
					fdiv
					frndint
					fistp	Temp1
					fwait
					mov	eax, Temp1

					.if	eax>RunTime
						mov	RunTime, eax
					.endif
				
				.else	; no StartTime => Target achieved in one step

					shl	eax, 16
				  	mov	Motor[si].DeltaX, eax
				  	
				.endif
					
			.endif

		  add	si, sizeof(MotorRecord)

		.untilcxz

		xor	si, si
		mov	cx, nmotors
		.repeat			;	Set up running velocity of each motor

			xor	eax, eax
			mov	Motor[si].AccelerationDistance, eax

			.if	Motor[si].Distance
				
				.if	RunTime
					fild	Motor[si].Distance
					fmul	TwoPower16
					fild	RunTime
					fdiv
					frndint
					fistp	Motor[si].DeltaXRun

					.if !(stepping_mode & NO_ACCELERATION)	;	Also calculate limiting acceleration rate, if using acceleration
						mov	ebx,	 Motor[si].Acceleration
						.if	ebx>0

							fild  Motor[si].Magnitude	;	Also calculate limiting acceleration rate
							fild  Motor[si].Acceleration
							fdiv
							;fmul  TwoPower16
							frndint
							fistp	Temp1
							fwait
							mov	eax, Temp1
							.if	eax>AccelerationTime
								mov	AccelerationTime, eax
							.endif

						.else
							;or	Motor[si].Status, NO_ACCELERATION
							mov	Motor[si].DeltaV, eax
						.endif
					.endif
				.endif					
		  .endif
		  add	si, sizeof(MotorRecord)

		.untilcxz


		xor	si, si
		mov	cx, nmotors
		.repeat			;	Set up acceleration for this move for each motor

		  .if (stepping_mode & NO_ACCELERATION) || !AccelerationTime

			or	Motor[si].Status, NO_ACCELERATION

		  .else

			mov	eax, Motor[si].Distance
			or		eax, AccelerationTime

			.if	eax

			   fild	Motor[si].Distance
			   fild	AccelerationTime
			   fdiv
			   ;fmul	TwoPower16
			   frndint
			   fistp	Motor[si].DeltaV
			   fwait
			   .if	!Motor[si].DeltaV
					.if	word ptr Motor[si].Distance&8000h
						dec	Motor[si].DeltaV
					.else
						inc	Motor[si].DeltaV
					.endif
			   	.endif

			   ;.if	Motor[si].Status & BACKWARDS
			   ;	  dec	eax
			   ;.else
			   ;	  inc	eax
			   ;.endif
			   or	Motor[si].Status, ACCELERATING
			.endif

		  .endif

		  add	si, sizeof(MotorRecord)

		.untilcxz

	.endif



	sub	eax, eax			; show no error
	ret




proportional_move endp

TwoPower16	real4 65536.0

;=================================================================================================

vectored_move	proc near

;=================================================================================================

;local	SteppingModeCopy : word


	mov	ax, stepping_mode
;	mov	SteppingModeCopy, ax


	xor	si, si	;	Motor index
	mov	cx, nmotors

	.repeat


	  .if	Motor[si].Status & STEPPING

		mov	eax, Motor[si].Vrun
		mov	Motor[si].DeltaXRun, eax
		mov	ebx, Motor[si].Vstart
		.if	ebx>=eax ; use Vrun if it is less than VStart
		  mov	ebx, eax
		  or	Motor[si].Status, NO_ACCELERATION
		.endif
		mov	Motor[si].AccelerationDistance, 0
		
		mov	eax, ebx
		shr	eax, 16
		.if	eax>Motor[si].Magnitude
			mov	ebx, Motor[si].Magnitude
			shl	ebx, 16
		.endif


		.if	Motor[si].Status & NO_ACCELERATION
		  xor	eax, eax
		.else
		  mov	eax, Motor[si].Acceleration
		  or	Motor[si].Status, ACCELERATING
		.endif

		.if	Motor[si].Status & BACKWARDS
			neg	eax
			neg	ebx
			neg	Motor[si].DeltaXRun
		.endif

		mov	Motor[si].DeltaV, eax
		mov	Motor[si].DeltaX, ebx


	  .endif

	  add	si, sizeof(MotorRecord)

	.untilcxz

	sub	eax, eax
	ret

vectored_move	endp

;=================================================================================

CalculateDistance proc near

;=================================================================================

local	nStepping : word

	xor	si, si
	mov	nStepping, si
	mov	cx, nmotors

	;	scan through all Motor records, calculating distance to move

	.REPEAT

	  xor	eax, eax
	  mov	Motor[si].Status, ax
	  mov	Motor[si].AccelerationDistance, eax
	  mov	Motor[si].DeltaV, eax
	  mov	Motor[si].AccelCount, ax


	  mov	eax, Motor[si].TargetPosition
	  sub	eax, Motor[si+2].CyclePosition
	  mov	Motor[si].Distance, eax
	  mov	Motor[si].Magnitude, eax

	  .if	sign?
		or	Motor[si].Status, BACKWARDS
		neg	Motor[si].Magnitude
	  .endif

	  .if Motor[si].Magnitude > 07Fh

		or	Motor[si].Status, STEPPING
		inc	nStepping

		.if	(stepping_mode & BCOMP)

			; if the signs of the distance to move, and the backlash are
			; different, then the backlash distance must be subtracted

			xor	eax, Motor[si].Backlash
			.if	sign?
			  mov	eax, Motor[si].Backlash
			  sub	Motor[si].Distance, eax
			  sub	Motor[si].TargetPosition, eax
			  or	Motor[si].Status, BCOMP
			.endif
		.endif
	  .endif

	  add	si, sizeof MotorRecord

	.UNTILCXZ
	mov	ax, nStepping
	ret

CalculateDistance	endp

;===========================================================================

waitForCompletion	proc near

;===========================================================================


	sti				; enable interrupts
	.while (stepping_status & STEPPING)
	    mov	ax, 2001h
	    int	MULTITASK      	;;;;;;;;;;;; continue polling
	.endw
	xor	ax, ax
	ret

waitForCompletion	endp

;===========================================================================

stop_actuate 	proc 	near

;===========================================================================

	mov	byte ptr stepping_status, ERR_ABORT
	sub	ax,ax
	ret

stop_actuate	endp


;===========================================================================

Div64by32 proc near C, TopValueLow : dword, TopValueHigh : dword, BottomValue : dword

;===========================================================================
local	Result : dword

	fild	qword ptr TopValueLow
	fild	BottomValue
	fdiv
	frndint
	fistp	Result
	fwait
	mov	eax, Result

	ret

Div64by32 endp

comment #
;===========================================================================

DebugLog proc near C uses bx ax, data:word

;===========================================================================

	mov	bx, DebugPointer
	mov	ax, data
	mov	DebugBlock[bx], ax
	add	bx, 2
	and	bx, 2047
	mov	DebugPointer, bx
	ret

DebugLog endp

#

comment #
;===========================================================================

PutCharAt	proc near C uses ds bx ax, position:word, character:byte

;===========================================================================

	mov	bx, 0B800h
	mov	ds , bx
	mov	bx, position
	add	bx, bx
	mov	al, character
	mov	byte ptr ds:[bx], al
	ret

PutCharAt	endp
;===========================================================================

#

_TEXT	ends

	end


