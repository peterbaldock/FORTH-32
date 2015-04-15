;	thisLink textequ <1>
;	lastLink textequ <0>

codeword macro	wordname, properties, cfalabel

	local	len, newlink, nfa, cfa, props	;; 2
nfa	db	'&wordname&'				;; 3
	len 	= sizeof nfa 				;; 4
	db	len					;; 5
	db	properties
% _link&thisLink	dw	offset _link&lastLink

	lastLink	textequ	%thisLink
	thisLink	textequ	%(thisLink+1)


	ifnb	<&cfalabel&>
@&cfalabel::
	public	@&cfalabel
	dw	offset cs:___&cfalabel				;; 36
___&cfalabel::
	public	___&cfalabel
	else
@&wordname::
	public	@&wordname
	dw	offset cs:___&wordname&				;; 42
___&wordname::
	public	___&wordname
	endif
endm

Code_word macro	wordname, properties, cfalabel

	local	len, newlink, nfa, cfa, props	;; 2
nfa	db	'&wordname&'				;; 3
	len 	= sizeof nfa 				;; 4
	db	len					;; 5
	db	properties
% _link&thisLink	dw	offset _link&lastLink

	lastLink	textequ	%thisLink
	thisLink	textequ	%(thisLink+1)

	ifnb	<&cfalabel&>
@&cfalabel::
	public	@&cfalabel
	dw	offset cs:___&cfalabel				;; 36
___&cfalabel::
	public	___&cfalabel
	else
@&wordname::
	public	@&wordname
	dw	offset cs:___&wordname&				;; 42
___&wordname::
	public	___&wordname
	endif
endm

Code_wordX macro	wordname, properties, cfalabel

	local	len, newlink, nfa, cfa, props	;; 2
nfa	db	'&wordname&'				;; 3
% _link&thisLink	dw	offset _link&lastLink+3
	db	properties
	len 	= sizeof nfa 				;; 4
	db	len					;; 5

	lastLink	textequ	%thisLink
	thisLink	textequ	%(thisLink+1)


	ifnb	<&cfalabel&>
@&cfalabel::
	public	@&cfalabel
	dw	offset cs:___&cfalabel				;; 36
___&cfalabel::
	public	___&cfalabel
	else
@&wordname::
	public	@&wordname
	dw	offset cs:___&wordname&				;; 42
___&wordname::
	public	___&wordname
	endif
endm


forthword macro	wordname, property, cfa, wordname2

	local	len, newlink, nfa, properties		;; 2
nfa	db	'&wordname&'				;; 3
	len 	= sizeof nfa 				;; 4
	db	len
	ifidni	<&property&>, <I>			;; 5
		properties = 80h
	endif
	ifidni	<&property&>, <H>			;; 8
		properties = 20h
	endif
	ifidni	<&property&>, <HI>			;; 11
		properties = 0a0h
	endif
	db	properties					;; 14
% _link&thisLink	dw	offset _link&lastLink

	lastLink	textequ	%thisLink
	thisLink	textequ	%(thisLink+1)


	ifnb	<&wordname2&>
@&wordname2::
	public	@&wordname2
	else
@&wordname::
	public	@&wordname
	endif

	dw	offset cs:&cfa				;; 18
endm

printmess	macro	charptr
	mov	dx,offset charptr
	mov	ah,9
	int	21h
	endm

forthcall	macro	address
	mov	bx, ds:word ptr h
	mov	[bx], offset cs:address
	add	bx, 2
	mov	ds:word ptr h, bx
	endm

PushLocal macro adr:REQ
	push	ebx
	sub	LocalSP, 4
	mov	ebx, LocalSP
	ifidni	<eax>, <adr>
		mov	[ebx], eax
	endif
	ifidni	<ebp>, <adr>
		mov	[ebx], ebp
	endif
	pop	ebx
endm

PopLocal		macro	adr:REQ
	ifdifi	<ebx>, <adr>
		push	ebx
		mov	ebx, LocalSP
		add	LocalSP, 4
		mov	adr, [ebx]
		pop	ebx
	else
		push	ebp
		mov	ebp, LocalSP
		add	LocalSP, 4
		mov	adr, [ebp]
		pop	ebp
	endif
endm

