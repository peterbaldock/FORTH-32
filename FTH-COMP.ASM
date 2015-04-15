comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-COMP.ASM	:	FORTH compiling functions

21-02-96 Version 1.00	:	create, <builds>, does>, (literal)
				], [, :, ;
				current, context
				immediate, compile, [compile], ['], (compile)
				compiling?, definitions
				variable, constant, constant+, mask

23-02-96 Version 1.01	~	[compile] corrected to adjust cfa = pfa-2

13-01-01 Version 2.50	+	arguments, locals and objects added
2004-07-29 Version 3.00	+	virtual, override, indirect_execute, [pfa] for finding
				pfa of virtual constants etc.
================================================================================#

option language:c


include forthmac.asm
include ..\include\macros.inc
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include	..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include	FTH-ERRS.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern		lastSysLink:abs
extern		lastStkLink:abs
extern		lastMemLink:abs
extern		lastAluLink:abs
extern		lastStrLink:abs
extern		lastDicLink:abs
extern		lastBlkLink:abs
extern		lastDispLink:abs
extern		lastInpLink:abs
extern		lastFlowLink:abs

;externdef	_vocabulary:near
% _link400	equ	lastAluLink
% _link500	equ	lastStrLink
% _link600	equ	lastDicLink
% _link700	equ	lastBlkLink
% _link800	equ	lastDispLink
% _link900	equ	lastInpLink
% _link1000	equ	lastFlowLink

	thisLink textequ <1001>
	lastLink textequ <1000>

forth_comp	proc	near

	assume	si: ptr dword

header::
	xor	edx, edx
	mov	dx, offset WordBuffer		; copy up
	call	wsbword							;	leaves address on stack
	sub	si, 4									;	drop
XWordToHeader::
	push	si
	mov	si, offset WordBuffer			; point to here, where word has been copied up.
	mov	ebx, h
	movzx	cx, byte ptr [si]		; bx points to start of word
	mov	al, cl		; shift word back one byte
xmloop:	mov	ah, byte ptr [si+1]
	mov	[ebx],ah
	inc	si
	inc	ebx
	loop	xmloop
	xor	ah, ah
	mov	[ebx], ax	; and put 16 bit count at end
	inc	ebx
	inc	ebx
	mov	al, NORMAL
	xor	ax, visible
	.if	status & DEFINING_CLASS
	  or	ax, OBJECT
	.endif
	mov	[ebx],ax
	inc	ebx
	inc	ebx

	mov	esi, Current
	mov	eax, [esi]
	mov	[esi], ebx
	mov	[ebx], eax
	mov	last_link, ebx	; currently (2014-01-09) last_link and last_link are never read.
	add	ebx, 4	;	returns ebx pointing to next free byte in extended dictionary 
	mov	h, ebx	;	(will normally be the code field)
		
	pop	si
	
	ret
	
Code_word	<ColonDefinition>, NORMAL

	mov	ax, offset ___colon

PushShortAX::
	add	si, 4
PokeShortAX::
	and	eax, 0FFFFh
	mov	dword ptr [si], eax
	ret

Code_word	<status>, NORMAL
	mov	ax, offset status
	jmp	PushShortAX

Code_word	<_nv>, NORMAL		; ( link - vlink )
;	????????????

	mov	bx, word ptr [si]
	.while	!((byte ptr [bx-1])&VOCABULARY) && bx
	  mov	bx, [bx]
	.endw
	mov	word ptr [si], bx
	ret

Code_word <_create>, NORMAL, create	;	now Extended-compatible

	mov	ax, offset cs:pfa_return
	jmp	CreateExecutableHeader

Code_word <create>, NORMAL, SafeCreate	;	now Extended-compatible

	mov	ax, offset cs:pf_return
	call	CreateExecutableHeader
	call	___indirect							;	mark the created word as indexing its parameters on the static heap
	mov	eax, StaticTop
	call	PushEAX
	jmp	___enclose


Code_word	<]>, NORMAL, start_compiling	;	now Extended-compatible
	or	status, 80h
cont_comp:
	call	___find	;	leaves extended address on stack
	mov	ebx, dword ptr [si]
	or	ebx, ebx
	je	try_num_comp
	
	mov	ax, [ebx-10]
	.if	(al & IMMEDIATE)
		jmp	immed
	.endif

	sub	ebx, 4	;	to point to code field

		mov	dword ptr [si], ebx	;	long reference to 16-bit definition
		.if	(TypePopStack & AUTOPOP_TYPE) && (status & AUTOPOP_TYPE)
			sub	TypeSP, 2
			shr	TypePopStack, 1
		.endif
		call	___enclose

	.if	err_no
		jmp	comp_err
	.endif
	jmp	cont_comp

immed:	
	call	___execute	; expects extended address on stack
	cmp	err_no, 0
	je	cont_comp
	mov	ax, err_no
	call	FORTHabort
	db	' : Execution error of immediate', 10, 13, 0

try_num_comp:
	mov	ax, offset WordBuffer
	call PokeShortAX
	call	___number
	cmp	err_no, 0
	je	cont_num
	jmp	word_err

cont_num:

	.if	punct
		call	___compile_literal
	.else
		call	___compile_literal
	.endif
	
	cmp	err_no, 0
	je	cont_comp
comp_err:
	mov	ax, err_no
	call	FORTHabort
	db	' : Compiling error', 13, 10, 0

	
Code_word	<[>, NORMAL+IMMEDIATE, end_compiling
	and	status, not COMPILING		; 0ff7fh
	inc	sp
	inc	sp
	ret	;	jmp	___interpret

CreateColonHeader:: ; AX = offset of execution address in CS	;	now Extended-compatible

	xor	ecx, ecx
	mov	cx, offset	___colon	;	for structure checking - ';' will look for offset ___colon to validate
	add	si, 4
	mov	[si], ecx

CreateExecutableHeader:: ; AX = offset of execution address in CS	;	now Extended-compatible

	push	ax	; save execution address

	mov	hLocal, offset ds:FirstLocal
	mov	LocalSpaceSize, 0
	mov	ArgSpaceSize, 0
	mov	LocalsLink, 0
	or	status, RETURN_BYVAL	; default for parameters on stack
	and	status, not DEFINING_LOCALS ; assume stack references are args

	; first establish if this word has already been declared as virtual

	xor	edx, edx
	mov	dx, offset WordBuffer		; copy up
	call	wsbword					; leaves bx pointing to start of word
	call	___latefind   			; returns extended address or zero on stack
	mov	ebx, dword ptr [si]	; if [si]!=0, definition already exists
	.if	ebx								;	could be a virtual
		.if (byte ptr [ebx-10] & VIRTUAL)				;	test extended definition	
			mov	byte ptr [ebx-10], VIRTUAL			;	only keep the VIRTUAL bit, so that each redefinition has its own attributes
			or	status, OVERRIDING
			mov	CurrentHeader, ebx
		.endif
	.endif
	
	.if	ebx && (status & OVERRIDING)

		mov	[ebx-4], offset cs:new_word_indirect
		mov	eax, h		; and set pf
		mov	[ebx], eax	; to point to 'here'

		sub	si, 4			; drop virtual word address

	.else		;	new definition
	
		sub	si, 4			; drop virtual word address
		call	XWordToHeader	; returns bx pointing to here
		mov	eax, h
		add	eax, 4
		mov	CurrentHeader, eax
	
	.endif	;	/if OVERRIDING

	mov	ebx, h		; point to 'xhere'
	xor	eax, eax
	pop	ax
	mov	[ebx], eax		; pop original cfa value to 'xhere', with parameter length field = 0
	add	h, 4			; and increment dictionary pointer

	and	status, not OVERRIDING

	ret
		
CurrentHeader	dd	0


Code_word	<:>, NORMAL, colon	;	now Extended-compatible

	mov	ax, offset cs:new_word_pushBP
	call	CreateColonHeader
	jmp	___start_compiling

Code_word	<;>, NORMAL+IMMEDIATE, semi_colon
	mov	ax, offset ___colon
	call	CheckNesting

	mov	ebx, h
	mov	word ptr [ebx], offset @ds_exit
	mov	word ptr [ebx+2], 0
	add	h, 4
;	call	___wordLength
;	call	___protected
	jmp	___end_compiling
	
Code_word	<wordLength>, NORMAL
	mov	eax, h
	mov	ebx, Current
	mov	ebx, [ebx]
	sub	eax, ebx
	jmp	PushEAX

Code_word	<protected>, NORMAL
	mov	ebx, Current
	mov	ebx, [ebx]
	mov	eax, [si]
	sub	si, 4
	mov	word ptr [ebx+6], ax
	or		byte ptr [ebx-2], PROTECTED
	ret

msgNoExtendedVirtuals	  db	' CreateExecutableHeader : Cannot do extended virtuals', 13, 10, 0

Code_word	<immediate>, NORMAL

	mov	ebx, Current
	mov	ebx, [ebx]
	or	byte ptr [ebx-2], IMMEDIATE
	ret

Code_word	<indirect>, NORMAL

	mov	eax, CurrentHeader		;	pfa
	or	byte ptr [eax-10], INDIRECT
	ret

Code_word	<[literal]>, NORMAL, compile_literal									;	now Extended-compatible
		
		mov	ax, offset @ds_literal
		jmp	ExtendedCFAandEnclose

xCFAandWEnclose::		; 16-bit code offset in ax, 16-bit enclose value on data stack
		
		and	eax, 0FFFFh
		mov	ebx, h
		mov	[ebx], eax
		mov	ax, word ptr [si]
		sub	si, 4
		mov	[ebx+4], ax
		add	h, 6
		ret

ExtendedCFAandEnclose::		; 16-bit code offset in ax, 32-bit enclose value on data stack

		and	eax, 0FFFFh
		mov	ebx, h
		mov	[ebx], eax
		mov	eax, [si]
		mov	[ebx+4], eax
		sub	si, 4
		add	h, 8
		ret


		
Code_word	<compile>, NORMAL+IMMEDIATE									;	now Extended-compatible
	call	___find	;	leaves extended address on stack
	.if	ebx
		mov	ax, offset @ds_compile
		jmp	ExtendedCFAandEnclose
	.endif
	
bad_compile:
	mov	err_no, ERR_COMPILE
	ret
	
Code_word	<[compile]>, NORMAL+IMMEDIATE, compile_immediate	;	now Extended-compatible
	call	___find	;	leaves extended address on stack
	.if	ebx
		.if	dword ptr [si]
			sub	dword ptr [si], 4
		.else
			sub	dword ptr [si], 2
		.endif
		jmp	___enclose
	.endif
	jmp	bad_compile

Code_word	<(compile)>, NORMAL, _compile		;	low dictionary run-time code for compile = take next value (cf literal) and compile into dictionary
	add	edi, 4
	mov	eax, [edi]
	sub	eax, 4

	mov	ebx, h
	mov	[ebx], eax
	add	h, 4
	ret

Code_word	<(literal)>, NORMAL, _literal			;	run-time code for literal
	add	edi, 4
	add	si, 4
	mov	eax, [edi]
	mov	dword ptr [si], eax
	ret

Code_word	<(2literal)>, NORMAL, _2literal		;	run-time code for 2literal
	add	edi, 4
	mov	eax, [edi]
	add	si, 4
	mov	dword ptr [si], eax
	add	edi, 4
	mov	eax, [edi]
	jmp	PushEAX


Code_word	<literal>, NORMAL+IMMEDIATE, literal_immediate
	jmp	___compile_literal

Code_word	<['']>, NORMAL+IMMEDIATE, xbracket_tick_bracket
	call	___find	;	leaves extended address on stack
	.if	!ebx
		jmp	bad_compile
	.endif

	.if	status & COMPILING
		mov	ax, offset @ds_literal
		jmp	ExtendedCFAandEnclose
	.endif
	
	ret

Code_word	<[pfa]>, NORMAL+IMMEDIATE, xbracket_pfa_bracket
	call	___find	;	leaves extended address on stack
	.if	!ebx
		jmp	bad_compile
	.endif

	mov	al, byte ptr [ebx-10]
	.if	al & VIRTUAL
		mov	ebx, [ebx]	; indirect reference to cfa of
		add	ebx, 4		; current definition, +4 = pfa
		mov	dword ptr [si], ebx
	.endif

	.if	al & INDIRECT
		mov	ebx, [si]			; indirect reference to parameter field (eg on heap)
		mov	eax, [ebx] 
		mov	dword ptr [si], eax
	.endif
	
	.if	status & COMPILING

		mov	ax, offset @ds_literal
		jmp	ExtendedCFAandEnclose

	.endif
	ret

Code_word	<compiling?>, NORMAL
	movzx	eax, status
	and	ax, COMPILING
	jmp	PushEAX

codeword <_array>, NORMAL
	; as of 2014-02-19, only 16-bit size and length limit in both dictionaries.
	mov	ax, offset cs:xelement_address_return
		
	call	CreateExecutableHeader
	push	word ptr [si]
	call	___wenclose
	
	xor	eax, eax		;	set most significant word of eax to 0
	pop	ax
	
	mul	word ptr [si]
	dec	ax
	
	mov	ebx, h
	mov	word ptr [ebx], 0
	mov	[ebx+2], ax
	inc	ax
	add	eax, 4
	add	h, eax

	sub	si, 4
	ret

codeword <array>, NORMAL
	; as of 2014-02-19, only 16-bit size and length limit in both dictionaries.
	mov	ax, offset cs:selement_address_return
		
	call	CreateExecutableHeader
	call	___indirect							;	mark the created word as indexing its parameters on the static heap
	push	word ptr [si]
	call	___wenclose
	
	xor	eax, eax		;	set most significant word of eax to 0
	pop	ax
	
	mul	word ptr [si]
	dec	ax
	
	mov	ebx, h
	mov	word ptr [ebx], 0	;	set lower bound
	mov	[ebx+2], ax			;	upper bound
	add	h, 4
	inc	ax
	mov	[si], eax				;	put length on stack
	call	___staticallot
	jmp	___enclose	

codeword	<GetElementAddress>, NORMAL	; now takes long address

	mov	ebx, dword ptr [si]   ; pfa of array or table
	mov	ax, [ebx-4]
	sub	si, 4
	.if	(ax == offset xelement_value_return) || (ax==offset xelement_address_return)
		jmp	xear_noinc
	.else
		jmp	sear_noinc
	.endif

selement_address_return:
	add	ebx, 4
sear_noinc:
	mov	ax, word ptr [ebx]
	inc	ebx
	inc	ebx
	mul	word ptr [si]

	mov	dx, offset msgArrayIndex
	bound	ax, [ebx]
	add	ebx, 4
	and	eax, 0FFFFh		;	set most significant word of eax to 0
	add	eax, [ebx]
	mov	dword ptr [si], eax
	ret

msgArrayIndex	db	'MCC : Bad array index $', 0

xelement_address_return::
	add	ebx, 4        ; increment from cfa to pfa
xear_noinc:
	mov	ax, word ptr [ebx]
	inc	ebx
	inc	ebx
	mul	word ptr [si]
	mov	dx, offset msgArrayIndex
	bound	ax, [ebx]
	and	eax, 0FFFFh		;	set most significant word of eax to 0
	add	eax, ebx
	add	eax, 4
	mov	dword ptr [si], eax
	ret

codeword <_table>, NORMAL
	; as of 2014-02-19, only 16-bit size and length limit in both dictionaries.
	mov	ax, offset cs:xelement_value_return
	call	CreateExecutableHeader
	call	___wenclose
	call	___zero
	jmp	___enclose

codeword <table>, NORMAL
	; as of 2014-02-19, only 16-bit size and length limit in both dictionaries.
	mov	ax, offset cs:selement_value_return
	call	CreateExecutableHeader
	call	___wenclose
	call	___zero
	call	___enclose
	mov	eax, StaticTop
	call	PushEAX
	jmp	___enclose


xelement_value_return:
	movzx	eax, word ptr [ebx+4]
	mov	cx, ax
	mul	word ptr [si]
	mov	dx, offset msgArrayIndex
	bound ax, [ebx+6]
	add	ax, 10
	add	ebx, eax

	.if	cx==4
		mov	eax, dword ptr [ebx]
	.elseif cx==2
		movzx	eax, word ptr [ebx]
	.else
		movzx	eax, byte ptr [ebx]
	.endif
	mov	dword ptr [si], eax
	ret

selement_value_return:
	movzx	eax, word ptr [ebx+4]
	mov	cx, ax
	mul	word ptr [si]
	mov	dx, offset msgArrayIndex
	bound ax, [ebx+6]
	mov	ebx, [ebx+10]
	add	ebx, eax

	.if	cx==4
		mov	eax, dword ptr [ebx]
	.elseif cx==2
		movzx	eax, word ptr [ebx]
	.else
		movzx	eax, byte ptr [ebx]
	.endif
	mov	dword ptr [si], eax
	ret

codeword	<offset>, NORMAL
	mov	ax, offset xadd_pf
	call	CreateExecutableHeader
	jmp	___enclose

Code_word	<constant+>, NORMAL, conadd
	jmp	___offset

Code_word	<mask>, NORMAL

		mov	ax, offset xand_pf
		call	CreateExecutableHeader
		jmp	___enclose

Code_word	<Mirror>, NORMAL
	mov	ax, offset Mirror
	jmp	PushShortAX

Code_word	<!>Mirror>, NORMAL, to_Mirror
	mov	ebx, [si]
	sub	si, 4
	mov	cx, 1024
	push	si
	mov	si, offset Mirror
	.repeat
		mov	al, [ebx]
		mov	byte ptr [si], al
		inc	si
		inc	ebx
		dec	cx
	.untilcxz
	pop	si
	ret

Code_word	<variable>, NORMAL	;	value is on stack
	mov	ax, offset cs:pf_return
CreateIndirectValue:
	call	CreateExecutableHeader
	call	___indirect							;	mark the created word as indexing its parameters on the static heap
	
	push	dword ptr [si]					;	save value
	mov	dword ptr [si], 4					;	ask for 4 bytes
	call	___staticallot
	mov	ebx, [si]
	pop	dword ptr [ebx]						;	put value in allocated memory	
	jmp	___enclose
	
Code_word	<2variable>, NORMAL	;	value is on stack
	mov	ax, offset cs:pf_return
CreateIndirect2Value:
	call	CreateExecutableHeader
	call	___indirect							;	mark the created word as indexing its parameters on the static heap
	
	push	dword ptr [si]					;	save value
	mov	dword ptr [si], 8					;	ask for 8 bytes
	call	___staticallot
	mov	ebx, [si]								;	address of heap memory
	pop	dword ptr [ebx]						;	put value in allocated memory
	mov	eax, [si-4]
	mov	[ebx+4], eax
	call	___nip
	jmp	___enclose
	
Code_word	<fvariable>, NORMAL
	jmp	___variable

Code_word	<constant>, NORMAL
	mov	ax, offset cs:pf_return_indirect
	jmp	CreateIndirectValue
Code_word	<2constant>, NORMAL
	mov	ax, offset cs:pf_2return_indirect
	jmp	CreateIndirect2Value
Code_word	<fconstant>, NORMAL
	jmp	___constant

;	old fashioned dargerous direct constants

Code_word	<_constant>, NORMAL
	mov	ax, offset cs:pf_return
	call	CreateExecutableHeader
	jmp	___enclose

Code_word	<_2constant>, NORMAL
	mov	ax, offset cs:pf_2return
	call	CreateExecutableHeader
	call	___enclose
	jmp	___enclose
	
;	======================================================================================

;	virtual handling

Code_word	<virtual>, NORMAL

	mov	ax, offset new_word_indirect
	call	CreateExecutableHeader
	mov	ebx, h
	or	byte ptr [ebx-10], VIRTUAL
	xor	eax, eax
	mov	ax, offset @ds_UndefinedVirtual
	mov	dword ptr [ebx], eax
	mov	dword ptr [ebx+4], 0
	add	h, 8
	ret

UndefinedVirtual::	public UndefinedVirtual


	mov	ax, ERR_UNDEFINED_VIRTUAL
	call	FORTHabort
	db	' : Call of undefined virtual', 0


Code_word	<override>, NORMAL


	or	status, OVERRIDING
	ret

;	=============================================================================================

;	vocabulary control


Code_word	<definitions>, NORMAL
	mov	eax,  Context
	mov	Current, eax
	ret

Code_word	<+definitions>, NORMAL, pushdefinitions
	inc	CurrentIndex
	mov	bx, CurrentIndex
	shl	bx, 2
	mov	eax, Current
	mov	Current[bx], eax		; Current is stacked
	mov	bx, ContextIndex
	shl	bx, 2
	mov	eax, Context[bx]
	mov	Current, eax				;	Current is reloaded with top value of Context stack
	ret

Code_word	<-definitions>, NORMAL, popdefinitions
	mov	bx, CurrentIndex
	.if	bx
		shl	bx, 2
		mov	eax, Current[bx]
		mov	Current, eax				;	unstack Current
		dec	CurrentIndex
	.else
		mov	ax, ERR_CURRENT_UNDER
		call	FORTHabort
		db	' : Current stack underflow in -definitions', 0
	.endif
	ret

Code_word	<current>, NORMAL
	mov	ax, offset	Current
	jmp	PushShortAX

Code_word	<context>, NORMAL
	mov	ax, offset	Context
	jmp	PushShortAX
	
comment #
Code_word	<current+>, NORMAL, currentpush
	mov	eax, [si]
	sub	si, 4
	inc	CurrentIndex
	mov	bx, CurrentIndex
	shl	bx, 2
	mov	Current[bx], eax
	ret

Code_word	<current->, NORMAL, currentpop
	mov	bx, CurrentIndex
	shl	bx, 2
	mov	eax, Current[bx]
	dec	CurrentIndex
	jmp	PushEAX
#	

Code_word	<context+>, NORMAL, contextpush
	mov	eax, [si]
	sub	si, 4
	inc	ContextIndex
	mov	bx, ContextIndex
	shl	bx, 2
	mov	Context[bx], eax
	ret

Code_word	<context->, NORMAL, contextpop
	mov	bx, ContextIndex
	shl	bx, 2
	mov	eax, Context[bx]
	dec	ContextIndex
	jmp	PushEAX
	
Code_word	<contextIndex>, NORMAL
	mov	ax, offset ContextIndex
	jmp	PushShortAX
	

;	==================================================================================

;	Parameter passing and local variables
Code_word	<!>local>, NORMAL, to_local
	mov	eax, [si]
	PushLocal	eax
	sub	si, 4
	ret
	
Code_word	<2!>local>, NORMAL, 2to_local
	mov	eax, [si]
	PushLocal	eax
	mov	eax, [si-4]
	PushLocal	eax
	sub	si, 8
	ret
	
Code_word	<const>, NORMAL+IMMEDIATE
	or	status, RETURN_BYVAL		; force stack VALUE for locals
	ret

Code_word	<var>, NORMAL+IMMEDIATE
	and	status, not RETURN_BYVAL	; force stack REFERENCE
	ret

Code_word	<local>, NORMAL+IMMEDIATE
	or	status, DEFINING_LOCALS
	and	status, not RETURN_BYVAL	; default local is reference, not value
	ret

Code_word	<byte:>, NORMAL+IMMEDIATE, argByte
	jmp	___argShort

Code_word	<word:>, NORMAL+IMMEDIATE, argShort
	or	status, RSTACK_RELATIVE
	and	status, not ARG_DWORD
	jmp	compile_arg

Code_word	<word:>, NORMAL+IMMEDIATE, argWord
	jmp	___argDword


Code_word	<dword:>, NORMAL+IMMEDIATE, argDword
	or	status, RSTACK_RELATIVE+ARG_DWORD
	
compile_arg:

	; compile code to push data stack word onto return stack

	mov	ebx, h

	.if	status & ARG_DWORD
		mov	[ebx], offset @ds_to_local
		mov	al, ARG_DWORD
	.else
		mov	[ebx], offset @ds_to_local
		mov	al, ARG_WORD
	.endif
	mov	word ptr [ebx+2], 0
	add	ebx, 4
	mov	h, ebx
	
	add	LocalSpaceSize, al
	push	ax
	call	compile_local
	pop	ax

	;	  add	LocalSpaceSize, al
	.if	!(status&DEFINING_LOCALS)
		add	ArgSpaceSize, al
	.endif
	
	and	status, not (ARG_WORD+ARG_DWORD)
	
	.if	(status & DEFINING_LOCALS)
	  and	status, not RETURN_BYVAL
	.else
	  or	status, RETURN_BYVAL
	.endif
	
	ret


Code_word	<address:>, NORMAL+IMMEDIATE, argAddress
	jmp	___argDword

Code_word	<float:>, NORMAL+IMMEDIATE, argFloat
	jmp	___argDword


;	============================================================================================


;	Not yet migrated to Extended mode

Code_word	<!<_builds>, NORMAL, _builds

	mov	ax, offset	pfa_stack_does
	call	CreateExecutableHeader
	mov	ebx, h
	mov	dword ptr [ebx], 01234567h
	add	h, 4		; reserve space for the execution address
	ret

Code_word	<!<sbuilds>, NORMAL, _sbuilds

	mov	ax, offset	pfa_stack_does_indirect
	call	CreateExecutableHeader
	mov	ebx, h
	mov	dword ptr [ebx], 01234567h			; reserve space for the execution address
	mov	eax, StaticTop
	mov	[ebx+4], eax
	add	h, 8
	ret


____does::
	public	____does
	lea	eax, [edi+4]	; get pointer following (does) code pointer
	mov	ebx, last_link	; and place in 1st pf word following
	mov	[ebx+8], eax	; pfa_code_does code pointer
	jmp	ii_exit

____sdoes::
	public	____sdoes
	lea	eax, [edi+4]	; get pointer following (does) code pointer
	mov	ebx, last_link	; and place in 1st pf word following
	mov	[ebx+8], eax	; pfa_code_does code pointer
	jmp	ii_exit


Code_word	<does!>>, NORMAL+IMMEDIATE, does

	xor	eax, eax
	mov	ax, offset @ds_does
	mov	ebx, h
	mov	[ebx], eax
	add	h, 4
	ret

comment #
Code_word	<sdoes!>>, NORMAL+IMMEDIATE, sdoes

	xor	eax, eax
	mov	ax, offset @ds_sdoes
	mov	ebx, h
	mov	[ebx], eax
	add	h, 4
	ret
#

Code_word	<currentObject>, NORMAL
	mov	bx, TypeSP
	mov	ax, [bx]
	jmp	PushShortAX

Code_word	<::>, NORMAL, DefineClassMethod

	mov	ax, offset cs:new_class_word
	call	CreateColonHeader
	and	TypePopStack, not AUTOPOP_TYPE ; prevent type reverting
	jmp	___start_compiling

Code_word	<;;>, NORMAL+IMMEDIATE, EndClassMethod
	mov	ax, offset ___colon
	call	CheckNesting
	mov	bx, word ptr h
	mov	word ptr [bx], offset @ds_classExit
	add	word ptr h, 2
	jmp	___end_compiling


Code_word	<cleanstack>, NORMAL
	mov	si, bp
	ret

;adjust_stack_frame::
;	inc	di
;	mov	al, [di+1]
;	cbw
;	add	bp, ax
;	ret

adjust_stack_frame::
	inc	di
	inc	di
	mov	al, [di+2]
	cbw
	add	bp, ax
	ret

Code_word	<2local>, NORMAL+IMMEDIATE, _2local
	call	compile_local
	add	LocalSpaceSize, 4
	ret

;============================================================================

;	compile_local creates a named reference in local dictionary space
;
;	the named reference is an immediate word which when subsequently
;	encountered in the main word definition, compiles a call to
;	an appropriate stack reference operation, followed by a single byte
;	which is the signed offset for the stack reference operation.

;	stack reference operations are :

;	  PUSH BP+ARG		  - push rstack reference onto the data stack
;	  PUSH word ptr [BP+ARG]  - push rstack 2 byte value (const word:)
;	  PUSH dword ptr [BP+ARG] - push rstack 4 byte value (const dword:)

;	  PUSH FP+ARG		  - push dstack frame pointer reference onto dstack
;				    	FP is the data stack frame pointer for variables
;                                       defined inside a word (as opposed to locals)


;============================================================================

compile_local:
	push	h
	push	Current		; save normal dictionary pointers
	movzx	eax, hLocal
	mov	h, eax		; set dictionary pointer to local space
	mov	word ptr Current, offset LocalsLink
	mov	word ptr Current+2, 0

	call	header
	mov	ebx, h		; point to free dictionary space
	or	byte ptr [bx-6], IMMEDIATE	; properties byte
	
	.if	status & RSTACK_RELATIVE
	
		.if	status & RETURN_BYVAL

			.if	status & ARG_DWORD
				mov ax, offset compile_rstack_value
			.else
				mov ax, offset compile_rstack_value
			.endif

		.else
			mov	ax, offset compile_rstack_reference
		.endif
		
	.else

	.endif

	and	eax, 0FFFFh
	mov	dword ptr [bx], eax
	add	bx, 4
	
	.if	status & DEFINING_LOCALS
	  mov	al, LocalSpaceSize
	.else
	  mov	al, ArgSpaceSize
	.endif
	mov	[bx], al
	inc	bx
	
	mov	hLocal, bx

	pop	Current
	pop	h
	ret

compile_rstack_value:
	mov	dx, offset @ds_rstack_value
	jmp	compile_stack_reference

compile_rstack_2value:
	mov	dx, offset @ds_rstack_2value
	jmp	compile_stack_reference

compile_rstack_reference:
	mov	dx, offset @ds_rstack_reference

compile_stack_reference::	; dx=offset of forth Code_word pointer
	add	bx, 4
	mov	al, byte ptr [bx]
	.if	al<ArgSpaceSize
	  sub	al, ArgSpaceSize
	.else
	  neg	al
;	  .if	status & ARG_DWORD
;	    sub al, 4	;	@@@@@@@@@@@@@@ why???
;	  .else
;	    sub	al, 2
;	  .endif
	.endif
	
	mov	ebx, h
	mov	[ebx], dx
	mov	word ptr [ebx+2], 0
	cbw
	mov	[ebx+4], ax
	add	h, 6

	ret

push_rstack_reference::

	inc	edi
	inc	edi
	movsx	eax, word ptr [edi+2]
	add	eax, ebp
	jmp	PushEAX

push_rstack_value::

	inc	edi
	inc	edi
	movsx	ebx, word ptr [edi+2]
	add	ebx, ebp
	mov	eax, dword ptr [ebx]
	jmp	PushEAX


push_rstack_2value::

	inc	edi
	inc	edi
	movsx	ebx, word ptr [edi+2]
	add	ebx, ebp
	mov	eax, dword ptr [ebx]
	call	PushEAX
	mov	eax, dword ptr [ebx+4]
	jmp	PushEAX



pf_return:
	mov	eax, [ebx+4]
	jmp	PushEAX

pf_return_indirect:
	mov	ebx, [ebx+4]
	mov	eax, [ebx]
	jmp	PushEAX


pf_2return:
	mov	eax, dword ptr [ebx+4]
	call	PushEAX
	mov	eax, dword ptr [ebx+8]
	jmp	PushEAX

pf_2return_indirect:
	mov	ebx, [ebx+4]
	mov	eax, dword ptr [ebx]
	call	PushEAX
	mov	eax, dword ptr [ebx+4]
	jmp	PushEAX


add_pf:	inc	bx
	inc	ebx
	mov	eax, [ebx]
	add	dword ptr [si], eax
	ret

xadd_pf:	
	add	ebx, 4
	mov	eax, dword ptr [ebx]
	add	dword ptr [si], eax
	ret

and_pf:	inc	bx
	inc	bx
	mov	eax, [bx]
	and	dword ptr [si], eax
	ret

xand_pf:
	add	ebx, 4
	mov	eax, [ebx]
	and	dword ptr [si], eax
	ret

% lastCompLink =   _link&lastLink

public  lastCompLink

forth_comp	endp

_TEXT	ends

end
