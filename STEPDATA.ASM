comment #=======================================================================

25-05-92 			MODULE	DATA.ASM


25-05-92 Version 2.01		Split PRIMS.ASM into :

					MOVES.ASM	+
					CTRL.ASM	+
					TIMING.ASM	+
					DATA.ASM

25-05-92 Version 2.01		DATA.ASM
				- all static variables declared here

25-05-92 Version 2.02		Set_Pitch  -   float motor_pitch[64] added.
				Set_Limits -   int limit_lo[64], int limit_hi[64]

26-05-92 Version 2.03		Set_BackLash - int backlash[64]
				Set_MaxSpeed - int motor_speed[64]

28-05-93 Version 3.00	~	most variables changed to 32 bit (for position/timing)

01-06-93 Version 3.10	~	old timing variables chopped for interrupt driven mode


				DB5 Version


06-03-96 Version 1.03	+	light_time for LEDs on DB5
21-01-98 Version 4.10	~	new segmentation to link with FORTH  (_DATA->_FORTH_DATA)
14-07-98 Version 4.20	+	motor_min_time[]
			-	motor_phase[]

Using VERSION.FTH version numbers :

23-05-00 Version 2.31	+	acceleration_time <accelerationTime>, delta_timer for
			+	Acceleration with actuate(ACCELERATION=256) by slewing 8253

02-06-00 Version 2.33	+	initial_period_factor for acceleration
2002-01-07 Version 2.57	-	prn_stat

2004-07-07 Version 2.98 +	(for DebugLog) DebugBlock, DebugMode, DebugPointer for
				logging realtime value histories.

=================================================================================#


	include	..\include\step.inc

_TEXT	segment

StandardTickInterrupt	dd	0
stepping_mode		dw	DEFAULT_MODE

_TEXT	ends

_FORTH_DATA	segment


light_time		db	16 dup(0)
NanoTicksElapsed	dd	0
MicrostepsPerHalfStep 	real4 	0.0001220703125 ; 1/32/256
stepError		dw	0
TicksPerSecond 		real4	1193148.416
TicksPerMillisecond 	real4	1193.148416


TimeBase	real4	0.000500							; default to 500 us
TimeBaseFine	real4	32.768							; default to 500 us
Motor		   MotorRecord	16 dup({?})
MotorPowerState					dw	0

; stepping_status[] definition (index constants defined in STEP.INC)

	stepping_status		dw	16  dup(0)

;	ssStatus		equ	0
;	ssBoard 		equ	2
;	ssInstruction		equ	4
;	ssAccessCount		equ	6
;	ssMaxAccessCount	equ	8
;	ssIntTime		equ	10
;	ssMaxIntTime		equ	12


PositionsValid		dw	0
HasStepped		dw	0
LimitSwitches		dd	0
LSQueue				dd	4*LSQLength dup(0)
LSIndex				db	4 dup(0)
;LSCount				dd	4 dup(0)


Board			db	3 dup(0)
SystemVoltage		db	12
			db	64 dup(0AAh)	; bytes for signature array
CardType		dw	0
LEDPortImage		db	0, 0, 0, 0
StepMask		dw	0;00FFh		; for testing - limits resolution of stepper chips
CoilCurrentTable	dw	SineTable
SineTable		label 	word		; half period = 128 words

;	Half Period Sine Table,  128 values ,  max = $8000=32768

	dw 00000, 00804, 01608, 02411, 03212, 04011, 04808, 05602
	dw 06393, 07180, 07962, 08740, 09512, 10279, 11039, 11793
	dw 12540, 13279, 14010, 14733, 15447, 16151, 16846, 17531
	dw 18205, 18868, 19520, 20160, 20788, 21403, 22006, 22595
	dw 23170, 23732, 24279, 24812, 25330, 25833, 26320, 26791
	dw 27246, 27684, 28106, 28511, 28899, 29269, 29622, 29957
	dw 30274, 30572, 30853, 31114, 31357, 31581, 31786, 31972
	dw 32138, 32286, 32413, 32522, 32610, 32679, 32729, 32758
	dw 32768, 32758, 32729, 32679, 32610, 32522, 32413, 32286
	dw 32138, 31972, 31786, 31581, 31357, 31114, 30853, 30572
	dw 30274, 29957, 29622, 29269, 28899, 28511, 28106, 27684
	dw 27246, 26791, 26320, 25833, 25330, 24812, 24279, 23732
	dw 23170, 22595, 22006, 21403, 20788, 20160, 19520, 18868
	dw 18205, 17531, 16846, 16151, 15447, 14733, 14010, 13279
	dw 12540, 11793, 11039, 10279, 09512, 08740, 07962, 07180
	dw 06393, 05602, 04808, 04011, 03212, 02411, 01608, 00804



CardAddress		dw	318h
LEDOffset		dw	5
LEDMap		db	0, 1, 3, 2, 12 dup(0)
DB6_Image01		db	88h		; should fix for Configure
decimalSeparator 	db	'.'		; settable with <separator>
global_status		dw	0

nmotors			dw	16
step_rate		dd	3000

			dw	0		; extra LSB accuracy for step_time
step_time		dd	65535
comment #
max_time		dd	0, 0
step_delay		dd	0
step_monitor		dw	0
timer_count		dw	0ffffh
delta_timer		dd	0
acceleration_time	dw	5
initial_period_factor	dw	512	; 256 = 100% so 512-> slow down by 2
acceleration_count	dw	0
deceleration_count	dw	20
deceleration_rate	dw	100
delay_factor		dw	500
add_back  		dd	0
#
pseudo_timer		dw	0

ten_us_count		dw	30
soft_period		dw	5000
PCIBusDelayCount	dd	100
MicrosecondDelayCount	dd 	4 dup(100)
UnitNoteDuration	db	32

interruptCounter	dw	0
PulseGeneratorInterval	dw	6
PulseOut		dw	0


DebugMode		dw	0
DebugPointer		dw	0
DebugBlock		dw	0, 1024 dup (0)

_FORTH_DATA	ends

	end
