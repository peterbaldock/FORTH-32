comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-SYS.ASM	:	operating system words

1996-21-02 Version 1.00	:
2001-06-06 Version 2.52	:	+ word length i/o : <inw>, <outw> for PCI bus DB6
2004-08-24 Version 3.02 :	+ MemSnap for debugging Allan D'Arcy's crashing problem
2004-11-30 Version 3.15	:	~ <reboot> : corrected wrong order of pushing
================================================================================#

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include	..\include\serial.inc
include ..\include\hooks.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include ..\include\step.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern		ROMForthLink:abs
% _link10	equ ROMForthLink

	thisLink textequ <11>
	lastLink textequ <10>


forth_sys	proc

Code_word	<DebugBits>, NORMAL
	mov	ax, offset DebugBits
	jmp	PushAX

Code_word	<LogIndex>, NORMAL
	mov	eax, LogIndex
	jmp	PushEAX
	
Code_word	<error>, NORMAL, _error
	mov	ax, offset ExecutionError
	jmp	PushShortAX

Code_word	<r0>, NORMAL
	mov	ax, offset ReturnStack
	jmp	PushShortAX

Code_word	<r@>, NORMAL
	mov	ax, sp
	jmp	PushShortAX

Code_word	<s0>, NORMAL
	mov	ax, offset dstack
	jmp	PushShortAX

Code_word	<sp@>, NORMAL
	mov	ax, si
	jmp	PushShortAX
Code_word	<!>sp>, NORMAL, toSP
	mov	si, [si]
	ret

Code_word	<spStart>, NORMAL
	mov	ax, spStart
PushAX::
	and	eax, 0FFFFh		;	set most significant word of eax to 0
PushEAX::
	add	si, 4
PokeEAX::
	mov	[si], eax
	ret

Code_word	<DOSds!>>, NORMAL, DOSdsto
	mov	ax, DOSds
	jmp	PushShortAX

Code_word	env, NORMAL
	mov	ax, env_p
	jmp	PushShortAX

Code_word	argc, NORMAL
	mov	ax, FORTHargc
	jmp	PushShortAX

Code_word	argv, NORMAL
	mov	ax, FORTHargv
	inc	si
	inc	si
	mov	[si], ax
	mov	ax, FORTHargvseg
	jmp	PushShortAX


Code_word	<LineNo>, NORMAL
	mov	ax, offset LineNo
	jmp	PushShortAX

Code_word	<!(version!)>, NORMAL, versionPtr
	mov	ax, offset FORTHversion
	jmp	PushShortAX

Code_word	<in>, NORMAL
	mov	dx,[si]
	call PCI_in
	and	eax, 0ffh
	mov	[si], eax
	ret

Code_word	<inw>, NORMAL
	mov	dx, [si]
	call PCI_inw
	and	eax, 0ffffh
	mov	[si], eax
	ret

Code_word	<ind>, NORMAL
	mov	dx, [si]
	call PCI_inw
	mov	[si], eax
	ret

Code_word	<ind_raw>, NORMAL
	mov	dx,[si]
	in		eax, dx
	mov	[si], eax
	ret

Code_word	<out>, NORMAL
	mov	dx, [si]
	mov	al,[si-4]
	sub	si, 8
	out	dx,al
	ret

Code_word	<outw>, NORMAL
	mov	dx, [si]
	mov	ax,[si-4]
	sub	si, 8
	out	dx, ax
	ret

Code_word	<outd>, NORMAL
	mov	dx, [si]
	mov	eax,[si-4]
	sub	si, 8
	out	dx,eax
	ret

Code_word	<ReadTimer0>, NORMAL
	call	ReadTimer0
	jmp	PushShortAX

Code_word	<@Timer0>, NORMAL, GetTimer0
	call	read_8253
	jmp	PushShortAX

Code_word	<TLoop>, NORMAL
	invoke	TLoop, [si]
	sub	si, 4
	ret

Code_word	<TLoopTime>, NORMAL
	invoke	TLoopTime, dword ptr [si]
	and	eax, 0ffffh
	mov	[si], eax
	ret

Code_word	<TLoopCalibrate>, NORMAL
	call	TLoopCalibrate
	jmp	PushEAX

Code_word	<us10dc>, NORMAL	; ( index - loopcount for 10^index us)
	mov	bx, [si]
	shl	bx, 2	; dword addressing
	mov	eax, MicrosecondDelayCount[bx]
	mov	[si], eax
	ret

Code_word	<ticks>, NORMAL
	call	GetTickCount
	jmp	PushEAX

Code_word	<cli>, NORMAL
	cli
	ret

Code_word	<sti>, NORMAL
	sti
	ret

Code_word	<CurrentRegisters>, NORMAL		;	pointer to extended memory image, so direct conventional memory access is avoided
	mov	ax, offset CurrentRegisters
	jmp	PushShortAX
	
Code_word	<int>, NORMAL	;	expects long on stack
;	dec	si
;	dec	si
	mov	ax, [si]
	mov	byte ptr cs:int_loc+1,al

	;	save principle registers to allow resumption of forth

	pop	[si]				;	return address
	mov	[si+4], edi
	mov	[si+8], es
	mov	[si+10], ebp
	mov	save_ds, ds
	mov	save_si, si

	;	copy extended image to conventional image
	
	mov	di, offset register_image
	mov	esi, CurrentRegisters
	mov	cx, 10
	.repeat
		mov	eax, [esi]
		mov	[di], eax
		add	esi, 4
		add	di, 4
	.untilcxz
	
	mov	eax, dword ptr _FORTH_DATA:register_image
	mov	ebx, dword ptr _FORTH_DATA:register_image+4
	mov	ecx, dword ptr _FORTH_DATA:register_image+8
	mov	edx, dword ptr _FORTH_DATA:register_image+12
	mov	edi, dword ptr _FORTH_DATA:register_image+16
	mov	esi, dword ptr _FORTH_DATA:register_image+20
	mov	ebp, dword ptr _FORTH_DATA:register_image+24
	mov	es , word ptr _FORTH_DATA:register_image+32
	mov	ds , word ptr _FORTH_DATA:register_image+28
	
int_loc:
	int	20
	push	ds
	mov	ds, save_ds	; save in cs space

	mov	_FORTH_DATA:register_image+32, es
	pushf
	pop	word ptr _FORTH_DATA:register_image+36
	mov	dword ptr _FORTH_DATA:register_image+24, ebp
	mov	dword ptr _FORTH_DATA:register_image+20, esi
	mov	dword ptr _FORTH_DATA:register_image+16, edi
	mov	dword ptr _FORTH_DATA:register_image+12, edx
	mov	dword ptr _FORTH_DATA:register_image+8,  ecx
	mov	dword ptr _FORTH_DATA:register_image+4,  ebx
	mov	dword ptr _FORTH_DATA:register_image,    eax
	pop	word ptr _FORTH_DATA:register_image+28	; actually returned ds

	;	copy conventional image to extended image

	mov	si, offset register_image
	mov	edi, CurrentRegisters
	mov	cx, 10
	.repeat
		mov	eax, [si]
		mov	[edi], eax
		add	si, 4
		add	edi, 4
	.untilcxz

	;	restore principle registers to resume forth
	
	mov	si, save_si
	mov	edi, [si+4]
	mov	es , [si+8]
	mov	ebp, [si+10]
	push	[si]				; return address

	movzx	eax, word ptr _FORTH_DATA:register_image+36
	mov	[si], eax			; carry flag etc
	ret

db	"SEGMENT REGISTERS"

save_ds	dw	0
save_es	dw	0
save_si	dw	0

Code_word	<SetRegisterImage>, NORMAL
	mov	eax, [si]
	mov	CurrentRegisters, eax
	sub	si, 4
	ret

Code_word	<exec>, NORMAL
	push	es
	mov	ax,ds
	mov	es ,ax
;	invoke	LoadSegment, 'es', ax, cs, 2000h
	mov	bx,[si]
	mov	dx,[bx]
	inc	bx
	inc	bx
	mov	ax, 4b00h
	int	21h
	mov	[si],ax
	pop	es
	ret

Code_word	<reboot>, NORMAL
	push	0ffffh		; bug until 2004-11-30 : wrong order of pushing
	push	0
	retf

Code_word	<nop>, NORMAL
	ret

Code_word	<''processHook>, NORMAL, @processHook
	mov	ax, offset _TEXT:processHook
	jmp	PushShortAX

Code_word	<mpx>, NORMAL	; ( ptr, fn - ptr )

	mov	ax, [si]	; function/subfn
	sub	si, 4		
	jmp	int_mpx

Code_word	<poll>, NORMAL	;	( ptr - ptr )
	mov	ax, 2001h	; message function = 20
int_mpx:
	mov	edx, [si]	; near ptr
	push	si
	add	si, 4
	mov	FORTHsi, si
	int	80h
	pop	si
	ret

Code_word	<broadcast>, NORMAL	;	( message - message )

	mov	ebx, [si]		; dest = msg+2
	and	byte ptr [ebx+2], 07fh	; and dest, NOT DONE
	mov	ax, 1001h	; ah = fn 10 = message
								; al = subfn 1 = process message
	jmp	int_mpx

Code_word	<taskList>, NORMAL	;	( message - message )
	mov	ax, offset	cs:taskList
	jmp	PushShortAX

Code_word	<CodeSeg>, NORMAL
	mov	ax, seg _TEXT
	jmp	PushShortAX

Code_word	<MemSnap>, NORMAL; ( SnapRecord, Function - )

comment #

	SnapRecord {
			Start: 		dword (extended)
			Len:	 	dword
			Image: 		dword (extended)
			MaskMap:	dword (extended)
			DifferenceMap 	dword (extended)
	}

	Functions:
		0. Initialize : Clear mask map, allocate memory
		1. Capture new image and build difference map.
		2. Add difference map to mask.
		3. Clear mask map.
		FF. Dispose - free memory, invalidate pointers.

#
	push	ds
	push	es
	push	edi
	
	mov	ax, ds
	mov	es, ax

	mov	ax, [si]
	sub	si, 4
	mov	ebx, [si]
	push	esi

	.if	ax==0
	  call	SnapInit
	.elseif	ax==1
	  call	SnapCapture
	.elseif ax==2
	  call	SnapMaskAdd
	.elseif	ax==3
	  call	SnapMaskClear
	.elseif	ax==-1
	  call	SnapDispose
	.endif


	pop	esi
	pop	edi
	pop	es
	pop	ds
	mov	[si], eax
	ret


	assume	ebx: near32 ptr SnapRecord

SnapInit:

	;	ds is unchanged - assumed ForthDS
	
	mov	eax, [ebx].Image
	mov	ecx, [ebx].Len
	add	ecx, 15
	and	ecx, 0fffffff0h
	add	eax, ecx
	mov	[ebx].MaskMap, eax
	shr	ecx, 3
	add	eax, ecx
	mov	[ebx].DifferenceMap, eax

	push	eax
	call	SnapMaskClear
	pop	eax
	retn



SnapCapture:

	mov	SnapPtr, ebx
	
	mov	esi, [ebx].Start
	mov	edi, [ebx].Image
	mov	ecx, [ebx].Len
	mov	eax, [ebx].SnapCount
	mov	SnapCount, eax
	mov	eax, [ebx].DifferenceMap
	mov	DifferencePtr, eax
	mov	es, [ebx].SourceSegment
	mov	ebx, [ebx].MaskMap

	assume	ebx: near32 ptr byte
	
	mov	DiffCount, 0

;	push	ds
;	mov	ds, ax	; Image segment

	mov	ah, [ebx] 	; get first mask byte
	mov	dx, 1
	.repeat
	  .if	dl & ah
	    mov	al, es:[esi]		;	source
	    .if	al != [edi]		;	image
	      mov [edi], al
	      or dh, dl
	      inc DiffCount
	    .endif
	  .endif
	  shl	dl, 1
	  .if	carry?
	  	mov	eax, DifferencePtr
	  	.if	SnapCount
	  		mov	[eax], dh
	  	.else
	  		mov	byte ptr [eax], 0
	  	.endif
	  	inc	DifferencePtr
	    mov	dx, 1
	    inc	ebx
	    mov	ah, [ebx] 	; get new mask byte
	  .endif
	  inc	esi
	  inc	edi
	  dec	ecx
	.until ecx==0

;	.if	dl>1
;	  add	ebx, MapLen      ; point to DifferenceMap
;	  mov	[ebx], dh
;	.endif

;	pop	ds
	mov	eax, DiffCount
	mov	ebx, SnapPtr
	assume	ebx: near32 ptr SnapRecord
	mov	[ebx].DifferenceCount, eax
	inc	[ebx].SnapCount
	retn

DiffCount			dd	0
DifferencePtr	dd	0
SnapPtr			dd	0
SnapCount		dd	0



SnapMaskAdd:

	assume	ebx: near32 ptr SnapRecord

	mov	esi, [ebx].MaskMap
	mov	edi, [ebx].DifferenceMap
	mov	ecx, [ebx].Len
	add	ecx, 15
	shr	ecx, 4

	.repeat
	  mov	ax, [edi]
	  not	ax
	  and	[esi], ax
	  add	esi, 2
	  add	edi, 2
	  dec	ecx
	.until ecx==0
	xor	eax, eax
	retn

SnapMaskClear:

	mov	edi, [ebx].MaskMap
	mov	ecx, [ebx].Len
	add	ecx, 15
	shr	ecx, 4
	mov	ax, -1
	push	ds
	pop	es

	cld
	db	67h
	rep	stosw
	xor	eax, eax
	retn


SnapDispose:

;	mov	es, [bx].Image
;	mov	ah, 49h
;	int	21h

	retn

Code_word <GetDiskData>, NORMAL	; ( diskno - s/c, a, b/s , c )

	mov	dx, [si]
	mov	ah, 36h
	int	21h
	movzx	eax, ax
	mov	[si], eax
	movzx	eax, bx
	mov	[si+4], eax
	movzx	eax, cx
	mov	[si+8], eax

	add	si, 12
	movzx	eax, dx
	mov	[si], eax
	ret

% lastSysLink =   _link&lastLink

public  lastSysLink

forth_sys	endp

_TEXT	ends

end
