HOOKS.INC
HookBlockShort	struct
	hooklink	dword	0
	entry		dword	?
	attributes	byte	80h
	index		byte	0ffh
	gatemask	word	0ffffh
	count		byte	0
	spare		byte	0
	regds		word	?
HookBlockShort	ends

;=================================

Hooks.fth	-	build HookBlockShort

: hook	word: index word: attributes

	<builds
	  0 ,				( link=0 )
	  'processHook w, cs> w,	( +4=execution address CS:code-offset )
	  attributes c,			( +8=attr)
	  index c,					( +9=index=number )
	  0 w, 0 c, 0 c, 		( +10=mask=0, +12=countw +13= spare )
	  ds> w,					( +14=data segment )
	  ['] hook 4- @ ,		( +16=???? )	( does> part of hook
	  ColonDefinition		( +20=$14=FORTH execute address )
	  [compile] ]
	does>
	$14 + execute
;

;===============================================

: installHook dword: pfa dword: fn

	( ." Installing hook with pfa = " pfa hex. cr )
	fn al c!		( function number eg message = 10h )
	pfa 4+ edi ! 		( hb ptr )
	pfa 12 + c@ cl c!	( attributes )
	pfa 13 + c@ ch c!	( index )
	ds> ds w! 
	0 ah c!			( fn 0 = install )
	0 dx w!			( mask = 0 )
	$80 int drop
;

;===============================================

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
;	ds:di	points to new HookBlock - HookBlock is initialized by this function
;	cl	attribute byte
;	ch	chain position index (priority)
;	dx	gate mask - quick categorisation of applicability

	push	eax
	mov	bl, al
	xor	bh, bh
	shl	bx, 2
	add	bx, offset _TEXT:taskList
	mov	cs:lastEntrySeg, cs
	mov	cs:lastEntryOff, bx
	mov	ebx, cs:[bx]		; pick up pointer to current HookBlock

	assume	ebx:ptr HookBlock, edi:ptr HookBlock
	.repeat
	  .if	ch<[ebx].index
	    .break
	  .endif
	  .if ch==[ebx].index && (cl&HOOK_PRE_PROCESS)
	    .break
	  .endif
	  mov	cs:lastEntry, ebx
	  mov	ebx, [ebx].hooklink
	.until	!ebx
	mov	ebx, cs:lastEntry
	mov	eax, [ebx].hooklink
	.if	cl&HOOK_DEBUG
	  regprint	<offset msgDone>
	.endif
	mov	[edi].hooklink, eax
	mov	[ebx].hooklink, edi

	mov	word ptr ([edi].attributes), cx
	mov	[edi].count, 0
	mov	[edi].gatemask, dx
	pop	eax
	retf

msgDone	db	CR, LF, "Function set :", 0

lastEntry	label	dword
lastEntryOff	dw	0
lastEntrySeg	dw	0

hookInstall endp

;==========================================

Code_word	<poll>, NORMAL	;	( ptr - ptr )

	mov	ax, 2001h	; message function = 20
	mov	edx, [si]	; near ptr
	push	si
	add	si, 4
	mov	FORTHsi, si
	int	80h
	pop	si
	ret

;================================================

LD-UTILS : 95

interrupt_80	proc near C, oldCS:word, flags:word	; hook interrupt
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
	xor	bh, bh
	mov	bl, ah
	shl	bx, 2			; point to first HookBlock

	.if	ah==10h
		les	bx, cs:taskList[bx]	; for this function
	.else
		les	bx, cs:taskList[bx]	; for this function
	.endif	

	assume	bx:ptr HookBlock
	.repeat
	  push	es
	  push	ebx
	  .if	es:[bx].attributes & HOOK_LOAD_DS
	    mov  ds, es:[bx].regds
	  .endif
	  .if fn==1001h
		  call	es:[bx].entry		; straight call
	  .else
		  call	es:[bx].entry		; straight call
	  .endif
	  pop	ebx
	  pop	es
	  les	bx, es:[bx].hooklink
	.until	bx==0

	pop	ebx
	pop	es
	pop	ds
	iret
interrupt_80	endp


processHook::
	push	esi
	push	edx
	push	ds
	mov	ax, ds

	mov	ds, FORTHds	; FORTHds is in _TEXT
	add	ebx, 10h
	mov	si, 0ff00h ;	FORTHsi
	add	si, 4
	.if	ax==1001h
		mov	[si], edx	; far pointer to message
	.else
		mov	[si], edx	; far pointer to message
	.endif
	;mov	ax, es:[bx]	; call destination
	call	word ptr es:[ebx]
	pop	ds
	pop	edx
	pop	esi
	retf

