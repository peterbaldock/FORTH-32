;===========================================================================

comment #

	FileName	:	FTH-STEP.ASM
	Date		:	2010-09-01

	Function	:	Stepper functions exposed to Forth
	Note		:	Greatly cleaned up for Constant Timebase Stepping

	Author		:	Peter Baldock
	Copyright	:	Douglas Instruments Limited 2010


Version History
============

	2010-09-01	Version 5.00 // Greatly cleaned up for Constant Timebase Steppingv BaseAddr -> CardAddress

#

;=================================================================================

option language:c

include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include ..\include\macros.inc
include ..\include\fp.inc
include ..\include\step.inc



_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment


	.486
	assume	cs:_TEXT
	assume	ds:_FORTH_DATA

extern      lastCompLink:abs

% _link200  equ lastCompLink

    thisLink textequ <201>
    lastLink textequ <200>

;//============================================================================

forth_step	proc    near

;//============================================================================


Code_word	<CardAddress>, NORMAL	;// ( - &CardAddress )
	mov	ax, offset	CardAddress
	jmp	PushShortAX

Code_word	<BaseAddr>, NORMAL	;// ( - &CardAddress )
	jmp	___CardAddress


Code_word	<CardType>, NORMAL	;// ( - &CardAddress )
	mov	ax, offset	CardType
	jmp	PushShortAX
	
Code_word	<Board>, NORMAL
	mov	ax, [si]
	add	ax, offset Board
	jmp PokeShortAX

Code_word	<.LED>, NORMAL, dotLED	;// ( - &CardAddress )
	movzx	eax, word ptr LEDOffset
	add	[si], eax
	ret
	
Code_word	<.LEDPortImage>, NORMAL, LEDPortImage
		add	[si], offset LEDPortImage
		ret

Code_word	<ReadLED>, NORMAL	;// ( BoardNo - Value)
		mov	bx, [si]
		movzx	eax, LEDPortImage[bx]
		mov	[si], eax
		ret

Code_word	<WriteLED>, NORMAL	;// ( BoardNo, Value - )
		invoke	OutputToLED, [si], byte ptr [si-4]
		sub	si, 8
		ret

Code_word	<StepMask>, NORMAL	;// ( - &CardAddress )
	mov	ax, offset	StepMask
	jmp	PushShortAX

Code_word	<SineTable>, NORMAL	;// ( - &CardAddress )
	mov	ax, [si]
	shl	ax, 1
	add	ax, offset SineTable
	jmp PokeShortAX

Code_word	<CoilCurrentTable>, NORMAL	;// ( - &CardAddress )
	mov	ax, offset	CoilCurrentTable
	jmp	PushShortAX

Code_word	<OutputMotorPhase>, NORMAL	;//  ( Mno:word, Phase:byte -  )
	invoke OutputMotorPhase, [si-4], [si]
	sub	si, 4
	mov	[si], eax
	ret
	
Code_word	<!>DB7>, NORMAL, DB7PutWord
	invoke 	DB7_PutWord, [si-4], [si]
	sub	si, 8
	ret

Code_word	<LSQueue>, NORMAL
	mov	ax, offset LSQueue
	jmp	PushEAX

Code_word	<PrimeLSQueue>, NORMAL
	invoke PrimeLSQueue, [si-4], [si]
	sub	si, 4
	jmp PokeShortAX
	
Code_word	<GFI>, NORMAL
	invoke GetFilteredLSInputs, [si-2], [si]
	sub	si, 4
	jmp PokeShortAX
	
Code_word	<GetDB7LSInputs>, NORMAL
	invoke GetDB7LSInputs, [si]
	jmp PokeShortAX

Code_word	<GetDB7Status>, NORMAL
	invoke GetDB7Status, [si]
	jmp PokeShortAX

Code_word	<GetDC7Status>, NORMAL
	invoke	GetDC7Status
	xor	ah, ah
	jmp	PushEAX

Code_word	<LimitSwitches>, NORMAL
	mov	ax, offset	LimitSwitches
	jmp	PushShortAX

Code_word	<FilterBytes>, NORMAL	;;	????????????

	invoke FilterBytes, [si-4], [si];	????????????
	sub	si, 4
	jmp PokeShortAX

Code_word	<GetMotorLSInputs>, NORMAL		;//	( mno:short - bits:short )
	invoke	input_bits, [si]
	jmp PokeShortAX

Code_word	<GetBoardLSInputs>, NORMAL
	invoke GetFilteredLSInputs, [si], 5
	jmp PokeShortAX

Code_word	<GetAllLSInputs>, NORMAL
	call	GetLimitSwitchInputs
	jmp	PushEAX

Code_word	<Contact>, NORMAL		;//	( - bits:short )

	invoke	GetSenseInputs
	jmp	PushShortAX

Code_word	<LightTime>, NORMAL
	mov	ax, offset	light_time
	jmp	PushShortAX

Code_word	<LED>, NORMAL
	jmp	LED_Display

Code_word	<HasStepped>, NORMAL
	mov	ax, offset	HasStepped
	jmp	PushShortAX

Code_word	<PulseGeneratorInterval>, NORMAL
	mov	ax, offset	PulseGeneratorInterval
	jmp	PushShortAX

Code_word	<PulseOut>, NORMAL
	mov	ax, offset	PulseOut
	jmp	PushShortAX

Code_word	<DebugMode>, NORMAL
	mov	ax, offset	DebugMode
	jmp	PushShortAX

Code_word	<StepError>, NORMAL	;// ( - address:near )
	mov	ax, offset	stepError
	jmp	PushShortAX

Code_word	<Motor>, NORMAL	;// ( mno:short - address:near )
	invoke	GetMotorRecordOffset, _FORTH_DATA:[si]
	add	bx, offset Motor
	movzx	ebx, bx
	mov	[si], ebx
	ret

Code_word	<.RoundOff>, NORMAL, RoundOff
	add	word ptr [si], offset Motor.RoundOff - offset Motor
	ret
Code_word	<.PhaseOffset>, NORMAL, PhaseOffset
	add	word ptr [si], offset Motor.PhaseOffset - offset Motor
	ret
Code_word	<.Phase>, NORMAL, Phase
	add	word ptr [si], offset Motor.CycleCount - offset Motor -1
	ret
Code_word	<.DeltaXRun>, NORMAL, DeltaXRun
	add	word ptr [si], offset Motor.DeltaXRun - offset Motor
	ret
Code_word	<.DeltaX>, NORMAL, DeltaX
	add	word ptr [si], offset Motor.DeltaX - offset Motor
	ret
Code_word	<.DeltaV>, NORMAL, DeltaV
	add	word ptr [si], offset Motor.DeltaV - offset Motor
	ret
Code_word	<.TargetPosition>, NORMAL, TargetPosition
	add	word ptr [si], offset Motor.TargetPosition - offset Motor
	ret
Code_word	<.Distance>, NORMAL, Distance
	add	word ptr [si], offset Motor.Distance - offset Motor
	ret
Code_word	<.Magnitude>, NORMAL, Magnitude
	add	word ptr [si], offset Motor.Magnitude - offset Motor
	ret
Code_word	<.Vrun>, NORMAL, Vrun
	add	word ptr [si], offset Motor.Vrun - offset Motor
	ret
Code_word	<.Vstart>, NORMAL, Vstart
	add	word ptr [si], offset Motor.Vstart - offset Motor
	ret
Code_word	<.Acceleration>, NORMAL, Acceleration
	add	word ptr [si], offset Motor.Acceleration - offset Motor
	ret
Code_word	<.AccelerationDistance>, NORMAL, AccelerationDistance
	add	word ptr [si], offset Motor.AccelerationDistance - offset Motor
	ret
Code_word	<.AccelCount>, NORMAL, AccelCount
	add	word ptr [si], offset Motor.AccelCount - offset Motor
	ret
Code_word	<.DwellTime>, NORMAL, DwellTime
	add	word ptr [si], offset Motor.DwellTime - offset Motor
	ret
Code_word	<.Current>, NORMAL, Current
	add	word ptr [si], offset Motor.Current - offset Motor
	ret
Code_word	<.Backlash>, NORMAL, Backlash
	add	word ptr [si], offset Motor.Backlash - offset Motor
	ret
Code_word	<.Pitch>, NORMAL, Pitch
	add	word ptr [si], offset Motor.Pitch - offset Motor
	ret
Code_word	<.Vmax>, NORMAL, Vmax
	add	word ptr [si], offset Motor.Vmax - offset Motor
	ret
Code_word	<.XLength>, NORMAL,  XLength
	add	word ptr [si], offset Motor.XLength - offset Motor
	ret
Code_word	<.XRange>, NORMAL, XRange
	add	word ptr [si], offset Motor.XRange - offset Motor
	ret
Code_word	<.LimitLow>, NORMAL, LimitLow
	add	word ptr [si], offset Motor.LimitLow - offset Motor
	ret
Code_word	<.LimitHigh>, NORMAL, LimitHigh
	add	word ptr [si], offset Motor.LimitHigh - offset Motor
	ret
Code_word	<.Status>, NORMAL, Status
	add	word ptr [si], offset Motor.Status - offset Motor
	ret

Code_word	<SetTimebase>, NORMAL

	fld	real4 ptr [si]
	fmul	TicksPerSecond
	fistp	step_time

	mov	eax, [si]
	mov	TimeBase, eax
	add	eax, 08000000h ; *65356 ie shifted 16 places
	mov	TimeBaseFine, eax
	sub	si, 4
	fwait
	mov	ax, word ptr step_time
	out	40h, al
	mov	al, ah
	out	40h, al

	ret

Code_word	<GetTimebase>, NORMAL
	mov	eax, TimeBase
	jmp	PushEAX

Code_word	<OneStep>, NORMAL
	pushad
	call	OneStep
	popad
	ret
	
Code_word	<Zero>, NORMAL	;// ( mno:short -  )

	call	waitForCompletion
	invoke	GetMotorRecordOffset, [si]	; get motor number

	.if	!carry?
	  mov	ax, Motor[bx].PhaseOffset
	  cwde
	  neg	eax
	  mov	Motor[bx].TargetPosition, eax
	  sub	ax,ax
	.endif
	sub	si, 4
	ret

Code_word	<Reset>, NORMAL 	;// ( mno:short - )

	invoke	GetMotorRecordOffset, [si]
	.if	!carry?
	  xor	eax, eax
	  mov	Motor[bx].DeltaX, eax
	  mov	word ptr Motor[bx], ax
	  sub	ax, word ptr Motor[bx+3].CyclePosition
	  mov	Motor[bx].PhaseOffset, ax
	  cwde
	  neg	eax
	  mov	Motor[bx+2].CyclePosition, eax
	.endif
	sub	si, 4
	ret

Code_word	<ClearSteps>, NORMAL ;// ( - )

	mov	cx, nmotors
	xor	bx, bx
	.repeat
		mov	word ptr Motor[bx].CyclePosition, 0
		mov	eax, Motor[bx+2].CyclePosition
		mov	Motor[bx].TargetPosition, eax
		;mov	Motor[bx].Distance, 0
		add	bx, sizeof(MotorRecord)
	.untilcxz
	ret

Code_word	<MotorPower>, NORMAL 	;// ( mno:short, action:0..3 - [state] )


	mov	cx, [si]		;// On/Off/Read
	sub	si, 4
	mov	bx, [si]		;// mno
	push	cx			; save action

	invoke	MotorPower, bx, cx

	pop	cx

	.if	carry?
	  xor	eax, eax
	  mov	stepError, ERR_MOTOR
	.elseif	cx>=2
		and	eax, 0ffffh
		mov	[si], eax
	.else
		sub	si, 4
	.endif

	ret

PositionFileName db "POSITION.DAT", 0
Code_word	<InvalidatePositionFile>, NORMAL

	.if	PositionsValid & POSITION_FILE_VALID
		mov	bx, offset PositionFileName
		invoke	fdelete, cs::bx
		and PositionsValid, not POSITION_FILE_VALID
	.endif
	ret

Code_word	<ActuateCalcs>, NORMAL
	invoke	ActuateCalcs
	jmp	PushEAX
	
Code_word	<Actuate>, NORMAL 	;// ( mode:short - )


	call	___InvalidatePositionFile
	.if	!stepError
	  invoke actuate, [si]
	  mov	stepError, ax
	.endif
	sub	si, 4
	ret

Code_word	<PositionsValid?>, NORMAL
	movsx	eax, PositionsValid
	jmp	PushEAX

Code_word	<_spv>, NORMAL
	mov	ax, [si]
	mov	PositionsValid, ax
	sub	si, 4
	ret

Code_word	<WaitForCompletion>, NORMAL ;// ( )
	call	waitForCompletion
	ret

Code_word	<Stop>, NORMAL 	;// ( - )

	invoke	stop_actuate
	mov	stepError, ax
	ret

Code_word	<SteppingMode>, NORMAL	;// ( - mode:short )

	mov	ax, stepping_mode
	jmp	PushShortAX


Code_word	<SteppingStatus>, NORMAL	;// ( - addr:cs )

	mov	ax, offset stepping_status
	jmp	PushShortAX


Code_word	<get_status>, NORMAL 	;// ( - word:short )

	mov	ax, stepping_status
	jmp	PushShortAX

Code_word	<SetCurrent>, NORMAL		;// ( mno:short, I:float - )

externdef	CurrentScaleFactor : real4

	invoke	GetMotorRecordOffset, [si-4]
	.if	!carry?
	  invoke fpmul,	real4 ptr [si], CurrentScaleFactor
	  invoke ftol, eax
	  mov	Motor[bx].Current, ax
	  sub	si, 8
	.endif
	ret

CurrentScaleFactor real4 60517.82364

Code_word	<GetCurrent>, NORMAL

	invoke	GetMotorRecordOffset, [si]
	mov	ax, Motor[bx].Current
	cwde
	invoke	ltof, eax
	invoke	fpdiv, eax, CurrentScaleFactor
	mov	real4 ptr [si], eax
	ret

Code_word	<GetCoilCurrents>, NORMAL


	invoke	GetDB6CoilCurrents, [si-4], [si]
	sub	si, 4
	jmp PokeShortAX


Code_word	<SetPitch>, NORMAL		;// ( mno:short, pitch:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		fld	MicrostepsPerHalfStep
		fdiv	real4 ptr [si]
		fstp	Motor[bx].Pitch
		fwait
		xor	ax, ax
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetPitch>, NORMAL		;// ( mno:short - )

	invoke GetMotorRecordOffset, [si]
	.if	carry?
	  mov	[si], eax
	.else
	  fld	MicrostepsPerHalfStep
	  fdiv	Motor[bx].Pitch; .. causes error in fdiv?
	  fstp	real4 ptr [si]
	  fwait
	.endif
	ret


Code_word	<SetBacklash>, NORMAL	;// ( mno:short, distance:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch
		frndint
		fistp	Motor[bx].Backlash
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetBacklash>, NORMAL	;// ( mno:short - backlash:float )


	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  fild	Motor[bx].Backlash
	  fmul	Motor[bx].Pitch
	  fstp	real4 ptr [si]
	  fwait
	.else
	  mov	[si], eax
	.endif
	ret


Code_word	<SetLimits>, NORMAL		;// ( mno:short, pos1:float, pos2:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-8]
	  .if	!carry?
		mov	eax, real4 ptr [si-4]
		mov	Motor[bx].LimitLow, eax
		mov	eax, real4 ptr [si]
		mov	Motor[bx].LimitHigh, eax
	  .endif
	.endif
	sub	si, 12
	ret


Code_word	<GetLimitLo>, NORMAL	;// ( mno:short - limit:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx].LimitLow
	.endif
	mov	[si], eax
	ret

Code_word	<GetLimitHi>, NORMAL		;// ( mno:short - limit:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx].LimitHigh
	.endif
	mov	[si], eax
	ret


Code_word	<SetLength>, NORMAL

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		mov	eax, real4 ptr [si]
		mov	Motor[bx].XLength, eax
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetLength>, NORMAL

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx].XLength
	.endif
	mov	[si], eax
	ret


Code_word	<SetRange>, NORMAL

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		mov	eax, real4 ptr [si]
		mov	Motor[bx].XRange, eax
	  .endif
	.endif
	sub	si, 8
	ret


Code_word	<GetRange>, NORMAL

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx].XRange
	.endif
	mov	[si], eax
	ret
	
Code_word <TestAdd>, NORMAL
		fld	real4 ptr [si-4]
		frndint
		fiadd word ptr [si]
		sub	si, 4
		fistp	dword ptr [si]
		fwait
		ret

	
Code_word	<GetPosition>, NORMAL	;// ( mno:short - position:float )

	invoke GetMotorRecordOffset, [si]
	fild	dword ptr Motor[bx-2].CycleCount
	movzx	eax, Motor[bx].PhaseOffset
	mov	[si], eax
	fisub	dword ptr [si]
	fmul	Motor[bx].Pitch
	fstp	real4 ptr [si]
	fwait
	ret


Code_word	<SetPosition>, NORMAL	;// ( mno:short, position:float - )

	.if	!stepError
		invoke GetMotorRecordOffset, [si-4]
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch	; produces a result in microsteps (65536/cycle)
		frndint
		mov	ax, word ptr Motor[bx+2].CyclePosition	; current Phase, which must be retained
		fistp	dword ptr Motor[bx-2].CycleCount
		fwait	
		xchg	ax, word ptr Motor[bx+2].CyclePosition
		mov	cx, word ptr Motor[bx+2].CyclePosition	; current Phase, which has been reimposed
		sub	cx, ax
		.if	carry?
			inc	word ptr Motor[bx].CycleCount
		.endif
		mov	Motor[bx].PhaseOffset, cx
		sub	si, 8

	.endif
	ret


Code_word	<GetStepPosition>, NORMAL 	;// ( mno:short - position:long )

	invoke	GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx+2].CyclePosition
	.endif
	mov	dword ptr [si], eax
	ret


Code_word	<SetPhase0>, NORMAL		;// ( mno:short - )

	.if	!stepError
	  invoke	GetMotorRecordOffset, [si]
	  .if	!carry?
	    mov	eax, Motor[bx+2].CyclePosition
	    xor	ax, ax
	    .if	!zero?
		mov	Motor[bx].TargetPosition, eax
	    .endif

	    invoke actuate, -1

	    mov	stepError, ax
	  .endif
	.endif
	sub	si, 4
	ret




Code_word	<uSteps>, NORMAL		;// ( mno:short, distance:float - )
	
	invoke GetMotorRecordOffset, [si]
	.if	!carry?
		sub	si, 4
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch	; produces a result in microsteps (256*256/cycle)
		frndint
		fistp	dword ptr [si]
		fwait
	.endif
	ret

Code_word	<MoveBy>, NORMAL		;// ( mno:short, distance:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		call	waitForCompletion
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch	; produces a result in microsteps (256*256/cycle)
		frndint
		fiadd	Motor[bx+2].CyclePosition
		fistp	Motor[bx].TargetPosition
		fwait
		xor	ax, ax
	  .endif
	  mov	stepError, ax
	.endif
	
	sub	si, 8
	ret


Code_word	<MoveTo>, NORMAL		;// ( mno:short, position:float - )

	.if	!stepError

	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		call	waitForCompletion

		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch	; produces a result in microsteps (256*256/cycle)
		frndint
		fistp	Motor[bx].TargetPosition
		movzx	eax, Motor[bx].PhaseOffset
		fwait
		add	Motor[bx].TargetPosition, eax
		xor	ax, ax
	  .endif
	  mov	stepError, ax
	.endif

	sub	si, 8
	ret


Code_word	<SetSpeed>, NORMAL		;// ( mno:short, speed:float - )

	jmp ___SetMaxSpeed

Code_word	<SetMaxSpeed>, NORMAL		;// ( mno:short, speed:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		mov	eax,	real4 ptr [si]
		mov	Motor[bx].Vmax, eax
	  .endif
	.endif
	jmp	___SetCurrentSpeed
	ret

Code_word	<SetAcceleration>, NORMAL		;// ( mno:short, speed:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch
		fabs
		fmul	TimeBaseFine
		fmul	TimeBase
		;frndint
		fistp	Motor[bx].Acceleration
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetAcceleration>, NORMAL	;// ( mno:short - speed:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  fild	Motor[bx].Acceleration
	  fmul	Motor[bx].Pitch
	  fabs
	  fdiv	TimeBaseFine
	  fdiv	TimeBase
	  fstp	real4 ptr [si]
	  fwait
	.else
	  mov	[si], eax
	.endif
	ret


Code_word	<SetDwellTime>, NORMAL		;// ( mno:short, speed:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		fld	real4 ptr [si]			; Dwell Time between moves (in seconds)
		fdiv	TimeBase
		frndint
		fistp	Motor[bx].DwellTime
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetDwellTime>, NORMAL	;// ( mno:short - speed:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  fild	Motor[bx].DwellTime
	  fmul	TimeBase
	  fstp	real4 ptr [si]
	  fwait
	.else
	  mov	[si], eax
	.endif
	ret


Code_word	<GetSpeed>, NORMAL		;// ( mno:short - speed:float )

	jmp	___GetMaxSpeed

Code_word	<GetMaxSpeed>, NORMAL	;// ( mno:short - speed:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  mov	eax, Motor[bx].Vmax
	.endif
	mov	[si], eax
	ret


Code_word	<SetCurrentSpeed>, NORMAL		;// ( mno:short, speed:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		mov	eax, Motor[bx].Vmax
		.if	eax<[si]
			mov	[si], eax			; substitute max speed, if trying to exceed
		.endif

		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch
		fabs
		fmul	TimeBaseFine
		frndint
		fistp	Motor[bx].Vrun
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetCurrentSpeed>, NORMAL	;// ( mno:short - speed:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  fild	Motor[bx].Vrun
	  fmul	Motor[bx].Pitch
	  fabs
	  fdiv	TimeBaseFine
	  fstp	real4 ptr [si]
	  fwait
	.else
	  mov	[si], eax
	.endif
	ret


Code_word	<SetSpeedFactor>, NORMAL	;// ( mno:short, factor:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?

		fld	Motor[bx].Vmax
		fmul	real4 ptr [si]
		fdiv	Motor[bx].Pitch
		fabs
		fmul	TimeBaseFine
		frndint
		fistp	Motor[bx].Vrun
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<SetStartSpeed>, NORMAL		;// ( mno:short, speed:float - )

	.if	!stepError
	  invoke GetMotorRecordOffset, [si-4]
	  .if	!carry?
		fld	real4 ptr [si]
		fdiv	Motor[bx].Pitch
		fabs
		fmul	TimeBaseFine
		frndint
		fistp	Motor[bx].Vstart
		fwait
	  .endif
	.endif
	sub	si, 8
	ret

Code_word	<GetStartSpeed>, NORMAL		;// ( mno:short - speed:float )

	invoke GetMotorRecordOffset, [si]
	.if	!carry?
	  fild	Motor[bx].Vstart
	  fmul	Motor[bx].Pitch
	  fabs
	  fdiv	TimeBaseFine
	  fstp	real4 ptr [si]
	  fwait
	.else
	  mov	[si], eax
	.endif
	ret



;**************************************************************


% lastStepLink =   _link&lastLink
public  lastStepLink

forth_step   endp

;//============================================================================


;**************************************************************

GetMotorRecordOffset proc C uses dx, mno: word

;**************************************************************

	mov	bx,mno
	dec	bx
	.if	bx >= nmotors
	  mov	eax, 0
	  mov	stepError, ERR_MOTOR
	  stc
	.else

	  ;	new Motor record addressing
	  ;	MotorRecord is 64 bytes long

	  mov	ax, sizeof(MotorRecord)
	  mul	bx
	  xchg	bx, ax
	.endif
	ret

GetMotorRecordOffset endp




_TEXT	ends

end
