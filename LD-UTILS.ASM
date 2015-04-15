option language:c

include	..\include\loader.inc
include	..\include\hooks.inc
include	..\include\macros.inc

_TEXT	segment para public 'CODE'

	.486


HOOK_LOAD_DS		equ	1
HOOK_LOAD_STACK		equ	2
HOOK_LOAD_REGS		equ	4
HOOK_REENTRY		equ	8
HOOK_DEBUG		equ	16

HOOK_PRE_PROCESS	equ	128

MAXTASKS		equ	256

StackCheck proto near C

;===========================================================================

			hookInstall	proc	far

;===========================================================================

;	hook function 0
;	subfunction : 	0 - are you there?
;			1 - install

	.if !al
	  dec	al
	  ret
	.endif

; 	install function on chain

;	ah=0->'install'
;	al=function number to install
;	es:bx	as always is this function's HookBlock
;	ds:edi	points to new HookBlock - HookBlock is initialized by this function
;	cl	attribute byte
;	ch	chain position index (priority)
;	dx	gate mask - quick categorisation of applicability

	push	eax
	
	push	ax
	movzx	ebx, al
	mov	al, 6
	mul	bl
	mov	bx, ax
	add	bx, offset _TEXT:taskList
	pop	ax
	
	mov	lastEntrySeg, cs	;	point lastEntry to first installed block
	mov	lastEntry, ebx
	
	mov	es, cs:[bx+4]		; pick up pointer to first HookBlock from taskList maintained in CS segment
	mov	ebx, cs:[bx]			; es:ebx is pointer to current block in linked list.

	
	assume	bx:ptr HookBlock, di:ptr HookBlock
	.repeat
	  .if	ch< es:[ebx].HookBlockShort.index
	    .break
	  .endif
	  .if ch==es:[ebx].HookBlockShort.index && (cl&HOOK_PRE_PROCESS)
	    .break
	  .endif
	  mov	cs:lastEntrySeg, es
	  mov	cs:lastEntry, ebx
	  push	es:[ebx].HookBlockShort.linkseg
	  mov	eax, es:[ebx].HookBlockShort.hooklink
	  mov	ebx, eax
	  pop	es
	.until	!ebx
	mov	ebx, cs:lastEntry
	mov	es, cs:lastEntrySeg
	mov	eax, es:[ebx].HookBlockShort.hooklink
	mov	[edi].HookBlockShort.hooklink, eax
	mov	ax, es:[ebx].HookBlockShort.linkseg
	mov	[edi].HookBlockShort.linkseg, ax
	mov	es:[ebx].HookBlockShort.hooklink, edi
	mov	es:[ebx].HookBlockShort.linkseg, ds

	mov	word ptr ([edi].HookBlockShort.attributes), cx
	mov	[edi].HookBlockShort.count, 0
	mov	[edi].HookBlockShort.gatemask, dx
	.if	cl&HOOK_DEBUG
	  regprint	<offset msgDone>
	.endif
	pop	eax
	retf

msgDone	db	CR, LF, "HookBlock installed set :", 0

lastEntry			dd	0
lastEntrySeg	dw	0

hookInstall endp

;===========================================================================

interrupt_80	proc near C, oldCS:word, flags:word	; hook interrupt

;	changed to C-style routine to interface with C-FORTH.C 20-10-97

;===========================================================================
local fn : word, pointer : dword

;	on entry :

;		ah = function number	
;			0 : install new function
;			1 : unhook function
;		al = subfunction - 0=Are you there?

	mov	fn, ax
	mov	pointer, edx
	
	sti				; reenable all interrupts
	push	ds
	push	es
	push	ebx
	
	push	ax
	movzx	ebx, ah
	mov	al, 6
	mul	bl
	mov	bx, ax
	add	bx, offset _TEXT:taskList	; point to first HookBlock
	pop	ax
	

	.if	ah==10h
;		les	bx, cs:taskList[bx]	; for this function
		mov	es, word ptr cs:[bx+4]
		mov	ebx, dword ptr cs:[bx]		; pick up pointer to current HookBlock
	.else
;		les	bx, cs:taskList[bx]	; for this function
		mov	es, word ptr cs:[bx+4]
		mov	ebx, dword ptr cs:[bx]		; pick up pointer to current HookBlock
	.endif	

	assume	bx:ptr HookBlock
	.repeat
	  push	es
	  push	ebx
	  
	  .if	es:[ebx].HookBlockShort.attributes & HOOK_LOAD_DS
	    mov  ds, es:[ebx].HookBlockShort.regds
	  .endif
	  push	eax
	  .if fn==1001h
		  mov	eax,	es:[ebx].HookBlockShort.entry		; straight call
;		  call	es:[ebx].HookBlockShort.entry		; straight call
	  .else
		  mov	eax,	es:[ebx].HookBlockShort.entry		; straight call
;		  call	es:[ebx].HookBlockShort.entry		; straight call
	  .endif
	  mov	HookCallVector, eax
	  pop	eax
	  call		HookCallVector
	  
	  pop	ebx
	  pop	es
;	  les	bx, es:[ebx].HookBlockShort.hooklink
	  push	es:[ebx].HookBlockShort.linkseg
	  mov	ebx, es:[ebx].HookBlockShort.hooklink
	  pop	es
	.until	ebx==0

	pop	ebx
	pop	es
	pop	ds
	iret

HookCallVector	dd	0


interrupt_80	endp

;===========================================================================

		setHookHandler	proc far C	; initialize

;===========================================================================

;	set all tasks to dummy

	assume	bx:nothing

	xor	eax, eax
	mov	ax, offset _TEXT:hbDummy

	mov	bx, offset _TEXT:taskList
	mov	cx, MAXTASKS
	.repeat
	  mov	cs:[bx], eax
	  mov	cs:[bx+4], cs
	  add	bx, 6
	.untilcxz
	
;	overwrite tasks 0 and 1

	mov	word ptr taskList, offset hbInstall	; function 0 = install
	mov	word ptr taskList+6, offset hbUninstall	; function 1 = uninstall


;	set up hookBlocks for functions 0, 1 and default

	mov	ax, offset hookInstall
	mov	cs:hbInstall.entry, eax		; set hookBlock for function 0
	mov	word ptr cs:hbInstall.entry+2, cs

	mov	ax, offset hookUninstall
	mov	cs:hbUninstall.entry, eax	; set hookBlock for function 1
	mov	word ptr cs:hbUninstall.entry+2, cs

	mov	ax, offset hookDefault
	mov	cs:hbDummy.entry, eax		; set default hookBlock
	mov	word ptr cs:hbDummy.entry+2, cs

	ret

;===========================================================================
;HookBlock, HookBlockShort	struct
;	hooklink	dword	?
;	linkseg		word	?
;	entry		dword	?
;	attributes	byte	80h
;	index		byte	0ffh
;	gatemask	word	0ffffh
;	count		byte	0
;	spare		byte	0

;	regds		word	?
;	regsp		word	?
;	regss		word	?
;	regebp		dword	?
;	regedi		dword	?
;	regesi		dword	?
;HookBlock	ends


db 'hbInstall', 9
dd	0
hbInstall	HookBlock {0, 0, hookInstall, 0, 0}
db 'hbUninstall', 11
dd	0
hbUninstall	HookBlock {0, 0, hookUninstall, 0, 0}
db 'hbDummy', 7
dd	0
hbDummy		HookBlock {0, 0, hookDefault, 80h, 0ffh}
public		hbDummy
public		hbInstall
public		hbUninstall

taskList 	db	MAXTASKS*6 dup(0)
public		taskList

setHookHandler	endp

;===========================================================================

			hookUninstall	proc	far

;===========================================================================

;	hook function 1
;	subfunction : 0	- are you there?

	.if !al
	  dec	al
	  ret
	.endif

; 	remove function from chain

;	ah	1 ->'uninstall'
;	al	function number to uninstall
;	es:bx	as always is this function's HookBlock
;	ds:di	points to old HookBlock

;	regprint	<offset msgUninstallEntry>
	push	es
	push	ebx
	push	eax

	push	ax
	movzx	ebx, al
	mov	al, 6
	mul	bl
	mov	bx, ax
	add	bx, offset _TEXT:taskList
	pop	ax

	push	cs
	pop	es
;	push	ds
;	push	di
;	pop	eax

	assume	bx:ptr HookBlock, di:ptr HookBlock

	.while	(ebx!=0)&&(edi!=es:[ebx])
;	  les	bx, es:[bx]		; pick up pointer to current HookBlock
	  push	es:[ebx].HookBlockShort.linkseg
	  mov	ebx, es:[ebx].HookBlockShort.hooklink
	  pop	es
	.endw

	.if	ebx
;	regprint	<offset msgUninstallRemoving>
	  mov	eax, ds:[edi].HookBlockShort.hooklink
	  mov	es:[ebx].HookBlockShort.hooklink, eax
	  mov	ax, ds:[edi].HookBlockShort.linkseg
	  mov	es:[ebx].HookBlockShort.linkseg, ax
	.endif

	pop	eax
	pop	ebx
	pop	es
;	regprint	<offset msgUninstallExit>
	ret

msgUninstallEntry	db	"Uninstall:entry", 0
msgUninstallExit	db	"Uninstall:exit", 0
msgUninstallRemoving	db	"Uninstall:removing", 0

hookUninstall endp

;===========================================================================

			hookDefault	proc	far

;===========================================================================

	;regprint	<offset msgHookDefault>
	retf

msgHookDefault	db	LF, CR, "Default Hook called :", 0

hookDefault	endp

;===========================================================================

interrupt_7C	proc near C, oldCS:word, flags:word, fn:word, message:dword

;===========================================================================

	push	ds
	pushad
	
	pushf
	push	ds
	push	esi
	push	bx

	lds	si, message
	call	mess_out

	push	cs
	pop	ds

	.if	fn==1
	  mov	si, offset rpmsg1
	  call	mess_out
	  call	dwprint			; print ax value
	  call	mess_out
	  pop	bx				; retrieve bx value
	  mov	eax, ebx
	  call	dwprint
	  call	mess_out
	  mov	eax, ecx
	  call	dwprint
	  call	mess_out
	  mov	eax, edx
	  call	dwprint
	  call	mess_out
	  pop	eax				; retrieve si value
	  call	dwprint
	  call	mess_out
	  mov	eax, edi
	  call	dwprint
	  call	mess_out
	  mov	eax, ebp
	  call	dwprint
	  call	mess_out
	  mov	eax, esp
	  call	dwprint
	  call	mess_out
	  pop	ax				; retrieve ds
	  call	hexprint
	  call	mess_out
	  mov	ax, es
	  call	hexprint
	  call	mess_out
	  mov	ax, fs
	  call	hexprint
	  call	mess_out
	  mov	ax, gs
	  call	hexprint
	  call	mess_out
	  mov	ax, ss
	  call	hexprint
	  call	mess_out
	  mov	ax, oldCS
	  call	hexprint
	  call	mess_out
	  mov	ax, oldCS-2
	  call	hexprint
	  call	mess_out
	  pop	ax				; pop flags
	  call	hexprint
	  mov	si, offset newline
	  call	mess_out
	.else
	  pop	bx
	  pop	si
	  pop	ds
	  popf
	.endif
	
	popad
	pop	ds
	iret

rpmsg1	db	CR, LF, "EAX=", 0, " EBX=", 0, " ECX=", 0, " EDX=", 0
	db	CR, LF, "ESI=", 0, " EDI=", 0, " EBP=", 0, " ESP=", 0
	db	CR, LF, "DS=", 0, " ES=", 0, " FS=", 0, " GS=", 0, " SS=", 0
	db	" CS=", 0, " IP=", 0, " F=", 0

interrupt_7C	endp


;===========================================================================

			dwprint	proc	near

;===========================================================================
	push	eax
	shr	eax, 16
	call	hexprint
	pop	eax

hexprint::			public hexprint
	push	ax
	mov	al,ah
	call	byteprint
	pop	ax

byteprint::			public  byteprint
	push	ax
	shr	al, 1
	shr	al, 1
	shr	al, 1
	shr	al, 1
	call	nibbleprint
	pop	ax

nibbleprint::
	push	ax
	and	al, 0fh
	add	al, 30h
	cmp	al, '9'
	jle	decimal
	add	al, 7

decimal:
	push	bx
	charout
	pop	bx
	pop	ax
	ret


dwprint	endp

;===========================================================================

			mess_out	proc near

;===========================================================================

	push	ax
	push	bx
	.while	byte ptr ds:[si]
	  mov	al, ds:[si]
	  charout
	  inc	si
	.endw
	inc	si
	pop	bx
	pop	ax
	ret

mess_out	endp

;===========================================================================

				flashprogram	proc	near public

;===========================================================================


	; cx	= flash base segment
	; dx:bx	= program address offset (long)
	; al 	= program byte data

	assume	bx:nothing
	mov	es, cx
	mov	byte ptr es:[05555h], 0aah	; flashStart[ 0x5555 ] = 0xAA;
	mov	byte ptr es:[02AAAh], 055h	; flashStart[ 0x2AAA ] = 0x55;
	mov	byte ptr es:[05555h], 0a0h	; flashStart[ 0x5555 ] = 0xA0;

	mov	es, dx
	mov	es:[bx], al		; *address = byte;

	mov	cx, 1000		; for( i = 0; i<1000; i++ )
	.repeat
	  mov	ah, es:[bx]
	  xor	ah, al
	  and	ah, 80h
	.untilcxz ah==0
	mov	ah, es:[bx]
	.if	cx==0
	  mov	al, ah
	  mov	ah, 0ffh
	.else
	  xor	al, ah
	  sub	ah, ah
	.endif
	ret

flashprogram	endp

newline	db	CR, LF, 0

;===========================================================================

_TEXT	ends

	.list

end
