comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-DATA.ASM	:	all static variables

21-02-96 Version 1.00	:	
04-04-96 Version 1.01	+	automatic 'fload FORTH.FTH' by presetting in_buff

================================================================================#

option language:c


.nolist

include	..\include\forth-ab.inc
include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include	..\include\serial.inc
include ..\include\forth.inc
include ..\include\step.inc
include ..\include\parallel.inc

_TEXT	segment

DOSds		dw	0
DOSpresent	db	0
BIOSstack	label	dword
BIOSsp		dw	0
BIOSss		dw	0
FORTHds		dw	0
FORTHsi		dw	0
instr_seg	dw	0
FlatAccess	dw	0

_TEXT	ends

_FORTH_DATA	segment

	org	0

.list
FORTHdseg	label 	byte
		public	FORTHdseg

hLocal		dw	FirstLocal
ArgSpaceSize	db	0
LocalSpaceSize	db	0
LocalsLink	dd 	0
FirstLocal 	db	256 dup(0)

ReturnStack	dw	600 dup(StackFillWord)
StackTop	dw	0
CurrentRegisters	dd	0
scrname		label	word
scrnamelen	sizestr	<BLOCK#00.FTH>
scr_name	db	"BLOCK#00.FTH"
LineNo		dw	0
spStart		dw	0
nmax		db	255
len_buff	db	0
DOSpad_point	dw	DOSpad_stop
b1_blk		dw	0
b1_stat		dw	0
buf_ptr1	dw	buffer1
b2_blk		dw	0
b2_stat		dw	0
buf_ptr2	dw	buffer2
env_p		dw	0
FORTHargc	dw	0
FORTHargv	dw	0
FORTHargvseg	dw	0
FORTHversion	label dword
dw	initVersion, 0
initVersion	db	25, '8.00   -   January 2015  ',0
last_blk	dw	buf_ptr1
last_link	dd	0
status		dw	0
instream	dw	0
instr_offset	dw	in_buffer
inputSource	db	0
number?		dw	0

FileError		dw	0
Comms	label word
HostControl	dw	0				; 0
HostPort		dw	0				; 1
HostError		dw	0				; 2
InputDataBuffer	dd	0		; 3
FileWriteBuffer 	dd	0		; 5
currentOut	dw	0				; 7
InState			db	0				; 8
OutState		db	0
inCount		dw	0				; 9
outCount		dw	0				; 10
inID				dw	0				; 11
;	Corrupt			dw	8 dup(0)	; 2013-08-15 For testing corrupted outID - no problem showed
outID			dw	0				; 12
inProgress	db	0				; 13
outProgress	db	0
requestCommsReset 	db	0	; 14
waitingForReset		db	0
DropData		dw	0				; 15
CorruptData		dw	0			; 16
USBPort		dw	0		; 17
CommsLogHandle dw 0;
PRNPort		dw	0378h		; 18
CommPort	label	CommRecord
COM1		CommRecord	{ 0, 'COM1', 3F8h, 38400 }
COM2		CommRecord	{ 0, 'COM2', 2F8h, 9600, 0E3h, 0.25, 0.25, 0, 0}

DebugBits	dd	DEBUG_COMMS


h		label dword
;wh	dw	0		; low word
;xon	dw	0		;	enable extended dictionary

objects				dd	0		; must follow h for correct addressing

Current				dd	16 dup(0)		;forthlink
CurrentIndex	dw	0
Context			dd	16 dup(0)		;forthlink
ContextIndex	dw	0



xobjects	dd	0		; must follow h for correct addressing

TypeSP		dw	offset TypeStack
TypeStack	dw	32 dup(0)
TypePopStack	dd	0

;			dynamic memory management

MemTop			dd	0	;	address of first byte of non-existent physical memory
HandleStack	dd 	0	;	stack of available handles (indices into handle table)
HandleSP		dd	0	;	pointer to next available handle
HandleTable	dd	0	;	table of pointers to allocated heap blocks
HeapBase		dd	0	;	start of heap
HeapLimit		dd	0	;	address of first byte beyond area designated for heap use
HeapTop			dd	0	;	pointer to top of heap - increase as memory is allocated.
LocalSP			dd	0	;	for new implementation of frames normally using sp & bp
LocalTop			dd	0	;	top of local area
StaticBase		dd	0	;	for statically allocated variables
StaticLimit		dd	0	;	pointer to next byte above static area
StaticTop			dd	0	;	rises as variables are allocated
Safe					db	0	;	determines if bounds of addresses are tested to be within heap

base		dw	10
visible		dw	NORMAL
blk_addr	dw	0
punct		db	0
places		db	0
colour		db	0Eh		; yellow on black
videopage	db	0
pagesize	dw	8 dup(1903h)	;1906h = 25 06 start at 6, end at 25
err_no		dw	0

debugvector	dd	?		; should be initialized to 'drop'
idlevector	dd	0
idlecount	dd	0
ExecutionError	dd	0


;	packet communications variables

outDACK		db	'D'
outNACK		db	'N'
outZERO		db	0
outRSET		db	'r'
outRACK		db	'R'


;	stub code pointers to locate into dataseg
@ds_SafeStore	dw	offset _TEXT:SafeStore
@ds_SafeWStore	dw	offset _TEXT:SafeWStore
@ds_SafeCStore	dw	offset _TEXT:SafeCStore
@ds_UnsafeStore	dw	offset _TEXT:___UnsafeStore
@ds_UnsafeWStore	dw	offset _TEXT:___UnsafeWStore
@ds_UnsafeCStore	dw	offset _TEXT:___UnsafeCStore
@ds_SafeFetchStore	dw	offset _TEXT:SafeFetchStore
@ds_SafeFetchWStore	dw	offset _TEXT:SafeFetchWStore
@ds_SafeFetchCStore	dw	offset _TEXT:SafeFetchCStore
@ds_UnsafeFetchStore	dw	offset _TEXT:___UnsafeFetchStore
@ds_UnsafeFetchWStore	dw	offset _TEXT:___UnsafeFetchWStore
@ds_UnsafeFetchCStore	dw	offset _TEXT:___UnsafeFetchCStore

@ds_if			dw	offset _TEXT:____if
@ds_else		dw	offset _TEXT:____else
@ds_until		dw	offset _TEXT:____until
@ds_do			dw	offset _TEXT:____do
@ds_loop		dw	offset _TEXT:____loop
@ds_plus_loop		dw	offset _TEXT:____plus_loop
@ds_select		dw	offset _TEXT:____select
@ds_endselect		dw	offset _TEXT:____endselect
@ds_case		dw	offset _TEXT:____case
@ds_?case		dw	offset _TEXT:____?case
@ds_cases		dw	offset _TEXT:____cases
@ds_endcase		dw	offset _TEXT:____endcase
@ds_does		dw	offset _TEXT:____does
@ds_sdoes		dw	offset _TEXT:____sdoes
@ds_literal		dw	offset _TEXT:____literal
@ds_2literal		dw	offset _TEXT:____2literal
@ds_dot_quote		dw	offset _TEXT:____dot_quote
@ds_compile	dw	offset _TEXT:____compile
@ds_quote		dw	offset _TEXT:____quote
@ds_exit		dw	offset _TEXT:ii_exit
@ds_classExit		dw	offset _TEXT:class_exit
;@ds_MemberRun		dw	offset _TEXT:_MemberRun
;@ds_PushThis		dw	offset _TEXT:_PushThis
;@ds_MemberOffset	dw	offset _TEXT:_MemberOffset
@ds_to_r		dw	offset _TEXT:___to_r
@ds_2to_r		dw	offset _TEXT:___2to_r
@ds_to_local		dw	offset _TEXT:___to_local
@ds_2to_local		dw	offset _TEXT:___2to_local
@ds_adjust_stack_frame	dw	offset _TEXT:adjust_stack_frame
@ds_rstack_reference	dw	offset _TEXT:push_rstack_reference
@ds_rstack_value	dw	offset _TEXT:push_rstack_value
@ds_rstack_2value	dw	offset _TEXT:push_rstack_2value
@ds_UndefinedVirtual	dw	offset _TEXT:UndefinedVirtual
@@ds_UndefinedVirtual	dw	offset _FORTH_DATA:@ds_UndefinedVirtual


BadStructure	db	' : Bad word definition structure', 0
BadAccessMessage	db ' : Bad memory write', 0

File0		db	12, 'command line', 0
File1		db	14 dup(0)
File2		db	14 dup(0)
File3		db	14 dup(0)
CurrentFileName	dw	File0
ShutdownCommand	db	8, 'shutdown', 0

in_buffer	db	'fload FORTH.FTH', 0, 240 dup(0)
WordBuffer db 257 dup(0)
_DOSBuffer1 db 256 dup(20)
_DOSBuffer2 db 256 dup(20)

Mirror	db	1024 dup(0AAh)

_FORTH_DATA	ends


_FORTH_DATA?	segment	at 0

org	8000h
buffer1	label byte
org	0C000h
buffer2	label byte
;org	0F800h

_FORTH_DATA?	ends

_UDS	segment

DOSpad_start	db	255 dup(?)	;(20h)
DOSpad_stop	db	4 dup(?)	;20h
register_image	dd	16 dup(?)	;(0)
editBuffer_line	db	256 dup(?)
packetInBuffer	db	258 dup(?)

inDATA		PacketHeader	{}		;	create	inDATA	ascii d c, 0 ,
outDATA		ShortPacket	{}		;	create	outDATA	ascii d c, 0 ,

dictionaryStart	db	256 dup(?)	;	label byte


;dictionaryStart	db	'forth', 5, 091h
;forthlink	dw	0	;	link is 0, as last word in linked list
;				dw	offset _TEXT:_vocabulary
;forthPFA	dw	0
;dictionaryContinue label byte

_UDS	ends

.nolist

end

