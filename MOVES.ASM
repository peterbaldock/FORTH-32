comment#======================================================================

24-04-92  6:24:43 pm 	Version 1.53	nmotors, station_count added for
					reduced scan loop in actuate.

25-04-92 11:56:45 am 	Version 1.54	turning prims.asm into a module
					all references to BASE removed

22-05-92  6:29:01 pm 	Version 2.00	turning all functions into C callable


25-05-92  5:33:25 pm 	Version 2.01	Split PRIMS.ASM into :

					MOVES.ASM	+
					CTRL.ASM	+
					TIMING.ASM	+
					DATA.ASM

25-05-92  6:26:11 pm 	Version 2.02	functions added :

				Set_Pitch(int mno, float pitch);
				Set_Limits(int mno, float lower, float upper);

26-05-92  2:24:44 pm 	Version 2.03	functions added :

				Move_By(int mno, float distance);
				Move_To(int mno, float position);

27-05-92  5:39:56 pm 	Version 2.04	functions added :

				Set_Backlash(int mno, float distance);
				Set_Speed(int mno, float speed);
				Get_Position(int mno);


29-05-92 10:26:33 am 	Version	2.05	functions added :

				Get_Backlash(int mno);
				Get_Period(int mno);
				Get_Pitch(int mno);

02-06-92 12:45:06 pm 	Version 2.06	old SKIPPER s g sp functions :

				matched argument order with earlier versions.

2008-04-09	Version 4.10	Constant timebase, variable step algorithms

===============================================================================#


	include	..\include\step.inc
	include	..\include\fp.inc
	include ..\include\macros.inc

_TEXT	segment

	.486

FunctionNumber = 79

	assume	ds:_FORTH_DATA





;**************************************************************

x_motor	dw	0
y_motor	dw	0
slide	dw	0

% LastMOVESFunction = FunctionNumber
public LastMOVESFunction

_TEXT	ends


;**************************************************************

	end
