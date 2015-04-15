HOOKS.INC
HookBlock	struct
	hooklink	dword	?
	entry		dword	?
	attributes	byte	80h
	index		byte	0ffh
	gatemask	word	0ffffh
	count		byte	0
	spare		byte	0
	regds		word	?
	regsp		word	?
	regss		word	?
	regebp		dword	?
	regedi		dword	?
	regesi		dword	?
HookBlock	ends

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

LD-UTILS
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
	push	bx
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
	  push	bx
	  .if	es:[bx].attributes & HOOK_LOAD_DS
	    mov  ds, es:[bx].regds
	  .endif
	  .if fn==1001h
		  call	es:[bx].entry		; straight call
	  .else
		  call	es:[bx].entry		; straight call
	  .endif
	  pop	bx
	  pop	es
	  les	bx, es:[bx].hooklink
	.until	bx==0

	pop	bx
	pop	es
	pop	ds
	iret

	assume	bx:nothing



interrupt_80	endp

ROMFORTH:794
processHook::
	push	esi
	push	edx
	push	ds
	mov	ax, ds

	mov	ds, FORTHds	; FORTHds is in _TEXT
	add	bx, 10h
	mov	si, 0ff00h ;	FORTHsi
	add	si, 4
	.if	ax==1001h
		mov	[si], edx	; far pointer to message
	.else
		mov	[si], edx	; far pointer to message
	.endif
	;mov	ax, es:[bx]	; call destination
	call	word ptr es:[bx]
	pop	ds
	pop	edx
	pop	esi
	retf

HOOKS.FTH:16
: hook	( number, attributes - )

	<builds
	  0 w, 0 w,			( link=0 )
	  'processHook w, cs> w,	( +4=execution address )
	  c, c,				( +8=attr=attributes , +9=index=number )
	  0 w, 0 c, 0 c, 		( +10=mask=0, +12=countw +13= spare )
	  ds> w,			( +14=data segment )
	  ['] hook 2- w@ w,		( +16=???? )
	  ColonDefinition		( +18=$12=FORTH execute address )
	  [compile] ]
	does>
	$12 + execute
;

HOOKS.FTH:94
$FF 0 hook pollDefault

	pollCount ++
	pollCount @ 100 >=
	if
	  es> >r $B800 >es
	  $16 nextDigit
	  r> >es
	  0 pollCount ! 
	endif
;

HOOKS.FTH:32
: installHook dword: pfa dword: fn

	( ." Installing hook with pfa = " pfa hex. cr )
	fn al c!		( function number eg message = 10h )
	pfa 2+ di w! 		( hb ptr )
	pfa 10 + c@ cl c!	( attributes )
	pfa 11 + c@ ch c!	( index )
	ds> ds w! 
	0 ah c!			( fn 0 = install )
	0 dx w!			( mask = 0 )
	$80 int drop
;

FTH-SYS.FTH:288
Code_word	<''processHook>, NORMAL, @processHook
	mov	ax, offset _TEXT:processHook
	jmp	PushAX

Code_word	<mpx>, NORMAL	; ( ptr, fn - ptr )

	mov	ax, [si]	; function/subfn
	sub	si, 4		
	mov	edx, [si]	; near ptr
	push	si
	add	si, 4
	mov	FORTHsi, si
	int	80h
	pop	si
	ret

Code_word	<poll>, NORMAL	;	( ptr - ptr )
	add	si, 4
	mov	dword ptr [si], 2001h	; message function = 20
	jmp	___mpx

Code_word	<broadcast>, NORMAL	;	( message - message )

	mov	bx, [si]		; dest = msg+2
	and	byte ptr [bx+2], 07fh	; and dest, NOT DONE
	add	si, 4
	mov	dword ptr [si], 1001h	; ah = fn 10 = message
					; al = subfn 1 = process message
	jmp	___mpx


