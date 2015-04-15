comment#=======================================================================

				Douglas Instruments

				FLASH Forth for STx Motion Control Centre

	FTH-MEM.ASM	:	memory functions

malloc		( longbytes - segment )
mfree		( address - )
flashReset	( - status )
flashStatus	( - status )
flashErase	( sectorbits - status )
flashWrite	( lsource, loffset, count - mismatch, impossible )
flashVerify	( lsource, loffset, count - mismatch, impossible )

26-02-96 Version 1.00	:	

================================================================================#

option language:c


include forthmac.asm
include ..\include\pcatkeys.inc
include ..\include\loader.inc
include ..\include\serial.inc
include ..\include\forth.inc
include ..\include\parallel.inc
include ..\include\macros.inc
include	FTH-ERRS.inc

_TEXT	segment	para public	'CODE'
_TEXT	ends

_FORTH_DATA	segment	para public	'DATA'
_FORTH_DATA	ends

_TEXT	segment

	.486

	assume	cs:_TEXT
	assume	ds:_FORTH_DATA


extern      lastStkLink:abs

% _link200  equ lastStkLink

    thisLink textequ <201>
    lastLink textequ <200>

;============================================================================

forth_mem	proc    near

;============================================================================
Code_word	<safe>, IMMEDIATE
	mov	Safe, -1
	ret
Code_word	</safe>, IMMEDIATE, unsafe
	mov	Safe, 0
	ret
	
Code_word	<!@>, NORMAL, fetch	;;	2014-02-04	expects 32-bit address, returns 32-bit result
	mov	ebx, dword ptr [si]
	mov	eax, [ebx]
	mov	dword ptr [si], eax
	ret

Code_word	<w!@>, NORMAL, wfetch
	mov	ebx, dword ptr [si]
	movzx	eax, word ptr [ebx]
	mov	[si], eax
	ret

Code_word	<c!@>, NORMAL, cfetch
	mov	ebx, dword ptr [si]
	movzx	eax, byte ptr [ebx]
	mov	dword ptr [si], eax
	ret

Code_word	<n@>, NORMAL, nfetch
	mov	cx, [si]
	sub	si, 4
	.if	cx==1
	  jmp	___cfetch
	.elseif	cx==2
	  jmp	___wfetch
	.elseif	cx==4
	  jmp	___fetch
	.endif
	movzx	ebx, word ptr [si]

	sub	si, 4
	.while	sword ptr cx>0
	  mov	eax, [ebx]
	  add	si, 4
	  mov	[si], eax
	  add	ebx, 4
	  sub	cx, 4
	.endw
	ret

Code_word	<f@>, NORMAL, ffetch
	jmp	___fetch

Code_word	<!@c!@>, NORMAL, fetchcfetch
	mov	ebx, [si]
	mov	ebx, [ebx]
	movzx	eax, byte ptr [ebx]
	mov	[si], eax
	ret

Code_word	<!@w!@>, NORMAL, fetchwfetch
	mov	ebx, [si]
	mov	ebx, [ebx]
	movzx	eax, word ptr [ebx]
	mov	[si], eax
	ret

Code_word	<!@!@>, NORMAL, fetchfetch
	mov	ebx, [si]
	mov	ebx, dword ptr [ebx]
	mov	eax, dword ptr [ebx]
	mov	[si], eax
	ret

;============================================================================

Code_word	<_!!>, NORMAL, UnsafeStore
	mov	ebx, dword ptr [si]
	mov	eax, dword ptr [si-4]
	mov	[ebx], eax
	sub	si, 8
	ret

Code_word	<_w!!>, NORMAL, UnsafeWStore
	mov	ebx, dword ptr [si]
	mov	ax, word ptr [si-4]
	mov	[ebx], ax
	sub	si, 8
	ret

Code_word	<_c!!>, NORMAL, UnsafeCStore
	mov	ebx, dword ptr [si]
	mov	ax, word ptr [si-4]
	mov	[ebx], al
	sub	si, 8
	ret

Code_word	<_!@!!>, NORMAL, UnsafeFetchStore
	mov	ebx, [si]
	mov	ebx, [ebx]
	mov	eax, [si-4]
	mov	[ebx], eax
	sub	si, 8
	ret

Code_word	<_!@w!!>, NORMAL, UnsafeFetchWStore
	mov	ebx, [si]
	mov	ebx, [ebx]
	mov	ax, [si-4]
	mov	[ebx], ax
	sub	si, 8
	ret

Code_word	<_!@c!!>, NORMAL, UnsafeFetchCStore
	mov	ebx, [si]
	mov	ebx, [ebx]
	mov	ax, [si-4]
	mov	[ebx], al
	sub	si, 8
	ret
	
SafeStore::
	mov	ebx, dword ptr [si]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	eax, dword ptr [si-4]
	mov	[ebx], eax
	sub	si, 8
	ret

msgSafeStore db	'MCC : Illegal write to $', 0

SafeWStore::
	mov	ebx, dword ptr [si]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	ax, word ptr [si-4]
	mov	[ebx], ax
	sub	si, 8
	ret

SafeCStore::
	mov	ebx, dword ptr [si]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	ax, word ptr [si-4]
	mov	[ebx], al
	sub	si, 8
	ret

	
SafeFetchStore::
	mov	ebx, dword ptr [si]
	mov	ebx, [ebx]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	eax, dword ptr [si-4]
	mov	[ebx], eax
	sub	si, 8
	ret

SafeFetchWStore::
	mov	ebx, dword ptr [si]
	mov	ebx, [ebx]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	ax, word ptr [si-4]
	mov	[ebx], ax
	sub	si, 8
	ret

SafeFetchCStore::
	mov	ebx, dword ptr [si]
	mov	ebx, [ebx]
	mov	dx, offset msgSafeStore
	bound ebx, HeapBase
	mov	ax, word ptr [si-4]
	mov	[ebx], al
	sub	si, 8
	ret


;	=======================================	Protected store compiling words	=====================

Code_word	<!!>, IMMEDIATE, store

	.if	Safe
		mov	ax, offset @ds_SafeStore
	.else
		mov	ax, offset @ds_UnsafeStore
	.endif

EncloseShortOffset:

	.if	status & COMPILING
		and	eax, 0FFFFh
		mov	ebx, ds:h
		mov	[ebx], eax
		add	h, 4
		ret
	.else
		mov	bx, ax
		mov	ax, [bx]
		jmp	ax
	.endif
	
Code_word	<w!!>, IMMEDIATE, wstore
	.if	Safe
		mov	ax, offset @ds_SafeWStore
	.else
		mov	ax, offset @ds_UnsafeWStore
	.endif
	jmp	EncloseShortOffset

Code_word	<c!!>, IMMEDIATE, cstore
	.if	Safe
		mov	ax, offset @ds_SafeCStore
	.else
		mov	ax, offset @ds_UnsafeCStore
	.endif
	jmp	EncloseShortOffset


Code_word	<!@!!>, NORMAL, fetchstore
	.if	Safe
		mov	ax, offset @ds_SafeFetchStore
	.else
		mov	ax, offset @ds_UnsafeFetchStore
	.endif
	jmp	EncloseShortOffset

Code_word	<!@w!!>, NORMAL, fetchwstore
	.if	Safe
		mov	ax, offset @ds_SafeFetchWStore
	.else
		mov	ax, offset @ds_UnsafeFetchWStore
	.endif
	jmp	EncloseShortOffset

Code_word	<!@c!!>, NORMAL, fetchcstore
	.if	Safe
		mov	ax, offset @ds_SafeFetchCStore
	.else
		mov	ax, offset @ds_UnsafeFetchCStore
	.endif
	jmp	EncloseShortOffset


Code_word	<f!!>, NORMAL, fstore
	jmp	___store

;Code_word	<2!!>, NORMAL, 2store
;	jmp	___store

Code_word	<!>far>, NORMAL, to_far_ptr 	;	 ( offset, segment - farpointer )
	mov	eax, [si-2]
	sub	si, 4
	mov	ax, [si]
	mov	[si], eax
	ret

Code_word	<far@>, NORMAL
	push	es
	mov	es, dword ptr [si]
	sub	si, 4
	mov	ebx, [si]
	mov	eax, es:[ebx]
	mov	[si], eax
	pop	es
	ret

Code_word	<farw@>, NORMAL
	push	es
	mov	es, dword ptr [si]
	sub	si, 4
	mov	ebx, [si]
	movzx	eax, word ptr es:[ebx]
	mov	[si], eax
	pop	es
	ret

Code_word	<farc@>, NORMAL
	push	es
	mov	es, dword ptr [si]
	sub	si, 4
	mov	ebx, [si]
	movzx	eax, byte ptr es:[ebx]
	mov	[si], eax
	pop	es
	ret

Code_word	<far!!>, NORMAL, farstore
	push	es
	mov	es, dword ptr [si]
	sub	si, 12
	mov	ebx, [si+8]
	mov	eax, [si+4]
	mov	es:[ebx], eax
	pop	es
	ret

Code_word	<farw!!>, NORMAL, farwstore
	push	es
	mov	es, dword ptr [si]
	sub	si, 12
	mov	ebx, [si+8]
	mov	ax, [si+4]
	mov	es:[ebx], ax
	pop	es
	ret

Code_word	<farc!!>, NORMAL, farcstore
	push	es
	mov	es, dword ptr [si]
	sub	si, 12
	mov	ebx, [si+8]
	mov	ax, [si+4]
	mov	es:[ebx], al
	pop	es
	ret

codeword	<flat?>, NORMAL
	movzx	eax, FlatAccess
	jmp	PushEAX

codeword	<gs:c@>, NORMAL, gscfetch
	mov	ebx, dword ptr [si]
	movzx	eax, byte ptr gs:[ebx]
	mov	[si], eax
	ret

codeword	<gs:@>, NORMAL, gsfetch
	mov	ebx, dword ptr [si]
	movzx	eax, word ptr gs:[ebx]
	mov	[si], eax
	ret

codeword	<gs:2@>, NORMAL, gs2fetch
	mov	ebx, dword ptr [si]
	mov	eax, dword ptr gs:[ebx]
	mov	[si], eax
	ret

codeword	<gs:c!!>, NORMAL, gscstore
	mov	ebx, dword ptr [si]
	mov	ax, [si-4]
	mov byte ptr gs:[ebx], al
	sub	si, 8
	ret

codeword	<gs:w!!>, NORMAL, gswstore
	mov	ebx, dword ptr [si]
	mov	ax, [si-4]
	mov	word ptr gs:[ebx], ax
	sub	si, 8
	ret

codeword	<gs:!!>, NORMAL, gsstore
	mov	ebx, dword ptr [si]
	mov	eax, dword ptr [si-4]
	mov	dword ptr gs:[ebx], eax
	sub	si, 8
	ret

;============================================================================

Code_word	<cs!>>, NORMAL, cs_to
	mov	ax, cs
	jmp	PushShortAX

Code_word	<ds!>>, NORMAL, ds_to
	mov	ax, ds
	jmp	PushShortAX
	

Code_word	<es!>>, NORMAL, es_to
	mov	ax, es
	jmp	PushShortAX

Code_word	<fs!>>, NORMAL, fs_to
	mov	ax, fs
	jmp	PushShortAX

Code_word	<gs!>>, NORMAL, gs_to
	mov	ax, gs
	jmp	PushShortAX

Code_word	<ss!>>, NORMAL, ss_to
	mov	ax, ss
	jmp	PushShortAX

;include padding.asm ; 37 bytes 22DE:cured

;============================================================================

Code_word	<!>es>, NORMAL, to_es
	mov	ax, [si]
	mov	es , ax
	sub	si, 4
	ret

Code_word	<!>fs>, NORMAL, to_fs
	mov	ax,[si]
	mov	fs , ax
	sub	si, 4
	ret

Code_word	<!>gs>, NORMAL, to_gs
	mov	ax,[si]
	mov	gs , ax
	sub	si, 4
	ret

Code_word	<_DATA>, NORMAL
	mov	ax, seg _DATA
	jmp	PushShortAX

;============================================================================

Code_word	<cs:c@>, NORMAL, cs_cfetch
	mov	ebx,[si]
	movzx	eax, byte ptr cs:[ebx]
	mov	[si], eax
	ret

Code_word	<cs:@>, NORMAL, cs_fetch
	mov	ebx, [si]
	movzx	eax, word ptr cs:[ebx]
	mov	[si], eax
	ret

Code_word	<es:c@>, NORMAL, es_cfetch
	mov	ebx, [si]
	movzx	eax, byte ptr es:[ebx]
	mov	[si], eax
	ret

Code_word	<es:w@>, NORMAL, es_wfetch
	mov	ebx, [si]
	movzx	eax, word ptr es:[ebx]
	mov	[si], eax
	ret

Code_word	<es:@>, NORMAL, es_fetch
	mov	ebx, [si]
	mov	eax, es:[ebx]
	mov	[si], eax
	ret

Code_word	<fs:@>, NORMAL, fs_fetch
	mov	ebx, [si]
	mov	eax, fs:[ebx]
	mov	[si], eax
	ret

Code_word	<ss:@>, NORMAL, ss_fetch
	mov	ebx, [si]
	mov	eax, ss:[ebx]
	mov	[si], eax
	ret

;============================================================================

get_addr_pair:
	mov	ebx, [si]
	sub	si, 4
	mov	eax,[si]
	sub	si, 4
	retn

Code_word	<es!:c!!>, NORMAL, es_cstore
	call	get_addr_pair
	mov	es:[ebx], al
	ret

Code_word	<es:w!!>, NORMAL, es_wstore
	call	get_addr_pair
	mov	es:[ebx], ax
	ret
Code_word	<es:!!>, NORMAL, es_store
	call	get_addr_pair
	mov	es:[ebx], eax
	ret

Code_word	<es:2!!>, NORMAL, es_2store
	jmp	___es_store

Code_word	<fs!:c!!>, NORMAL, fs_cstore
	call	get_addr_pair
	mov	fs:[ebx],al
	ret

Code_word	<fs:!!>, NORMAL, fs_store
	call	get_addr_pair
	mov	fs:[ebx],ax
	ret


;============================================================================

Code_word	<fill>, NORMAL

;	2014-02-20	Adapted for extended addressing, but limiting the count to 16-bit

	mov	al, byte ptr [si]
	sub	si, 4
	mov	cx, word ptr [si]
	sub	si, 4
	and	cx,cx
	je	end_fill
	mov	ebx, [si]
do_fill:
	mov	[ebx], al
	inc	ebx
	loop	do_fill
end_fill:
	sub	si, 4
	ret

;============================================================================

Code_word	<cmove>, NORMAL

;	2014-02-24	Adapted for extended addressing

	mov	ecx, [si]
	sub	si, 12
	.if	ecx
		push	esi
		push	edi
		mov	edi, [si+8]
		mov	esi, [si+4]
		cmp	edi, esi
		je	end_cmov2
		ja	cmov_up
		.repeat
			mov	al, [esi]
			mov	[edi], al
			inc	esi
			inc	edi
		.untilcxz
	end_cmov2:
		pop	edi
		pop	esi
	.endif
	ret

cmov_up:
	add	edi, ecx
	add	esi, ecx
	.repeat
		dec	esi
		dec	edi
		mov	al, [esi]
		mov	[edi], al
	.untilcxz
	jmp	short	end_cmov2

Code_word	move, NORMAL

;	30-11-2000	NB. not yet adapted for automatic es reference or extended addressing

	mov	cx,[si]
	sub	si, 6
	and	cx,cx
	je	end_mov
	pushf
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	di,[si+4]
	mov	es ,ax
;	invoke	LoadSegment, 'es', ax, cs, 1000h
	mov	si,[si+2]
	cmp	di,si
	je	end_mov2
	ja	mov_up
	cld
	rep	movsw
end_mov2:
	pop	es
	pop	di
	pop	si
end_mov:
	popf
	ret

mov_up:
	add	di,cx
	add	si,cx
	dec	si
	dec	di
	std
	rep	movsw
	jmp	short	end_mov2

;============================================================================

Code_word	<DOSalloc>, NORMAL		; ( longbytes - segment )

	mov	ebx, [si]
	add	ebx, 15
	shr	ebx, 4
	mov	ah, 48h
	int	21h
	.if	carry?
	  xor	ax, ax
	.endif
	jmp PokeShortAX

;============================================================================

Code_word	<DOSfree>, NORMAL			; ( segment - flag )

	push	es
	mov	ax, [si]
	mov	es , ax
;	invoke	LoadSegment, 'es', ax, cs, 2800h
	mov	ah, 49h
	int	21h
	pop	es
	jmp PokeShortAX



;============================================================================

Code_word	<malloc>, NORMAL		; ( longbytes - handle )

	mov	ecx, [si]
	call	xalloc
	mov	[si], eax
	ret


xalloc::	

;	takes requested length in ecx	-	returns address of handle in eax
;	calculate length
	add	ecx, 31
	and	cx, 0FFF0h	; multiples of 16 + 16
	
;	get handle
	mov	ebx, HandleSP
	.if	ebx>MemTop	;	out of handles
		mov	eax, ERR_NO_HEAP_HANDLES
		call	FORTHabort
		db	' : Memory manager out of handles', 0
	.endif

	;	calculate the address of the heap block pointer

	movzx	eax, word ptr [ebx]	; new handle in eax
	add	HandleSP, 2
	shl	eax, 2
	add	eax, HandleTable	;	eax now addresses handle
	
;	get next free area of heap	-	this can be by 
;													1.	fast allocation
;													2.	first match allocation	(first available block that is large enough)
;													2.	efficient allocation		(best fitting block)
;													3.	compaction 					(only called if necessary)

;	mov	edx, HeapLimit
;	sub	edx, HeapTop				;	gives remaining bytes available
	
	call	HeapMatchFree
	.if	!carry?
		call	HeapAggregate
		call	HeapMatchFree
	.endif

	.if	!carry?			;	fail
		sub	HandleSP, 2	;	put handle back on stack
		xor	eax, eax
	.endif
	
	ret
		
HeapMatchFree:	;	handle in eax, size required in ecx

	mov	ebx, HeapBase
	xor	edx, edx
	mov	BestBlock, edx
	dec	edx

	.repeat
	
		.if dword ptr [ebx+8]	== 0;	this block free
			
			cmp	ecx, [ebx]
			
			.if	zero?		;	same size, so allocate immediately
				mov	byte ptr [ebx+8], 1	;	mark as allocated
				mov	[ebx+4], eax				;	assign new handle
				mov	[eax], ebx
				stc
				ret
			.elseif carry?
				.if	edx>[ebx]
					mov	edx, [ebx]
					mov	BestBlock, ebx
				.endif
			.endif
		.endif
		
		add	ebx, [ebx]
		
	.until ebx>=HeapLimit
	
	mov	ebx, BestBlock

	.if	ebx
		mov	byte ptr [ebx+8], 1	;	mark as allocated
		mov	[ebx+4], eax				;	assign new handle
		mov	[eax], ebx
		mov	[ebx], ecx
		sub	edx, ecx
		add	ebx, [ebx]
		mov	[ebx], edx					;	block now split, so mark remainder as free
		xor	ecx, ecx
		mov	[ebx+4], ecx				;	no owner
		mov	[ebx+8], ecx				;	free
		stc									;	carry indicates success
	.else
		clc									;	no carry indicates failure
	.endif
	ret

		
HeapAggregate:
	push	eax
	push	ebx
	mov	ebx, HeapBase
	.repeat
		.if ! dword ptr [ebx+8]	;	this block free, so test succeeding blocks
			mov	eax,	ebx
			.repeat
				add	ebx, [ebx]
			.until	(ebx>=HeapLimit) || (dword ptr [ebx+8])
			xchg	eax, ebx
			sub	eax, ebx
			mov	[ebx], eax
		.endif
		add	ebx, [ebx]
	.until ebx>=HeapLimit
	pop	ebx
	pop	eax
	ret
	

BestBlock	dd	0


comment #	fast allocation

	.else
	
		;	========================	fast allocate	==========================================
		

		mov	ebx, HeapTop
		mov	[eax], ebx					;	set the heap pointer to point to the new block
		add	HeapTop, ecx			;	and advance the heaptop pointer

		mov	[ebx], ecx					;	mark the length of the new block
		mov	[ebx+4], eax				;	show that it is in use by saving the Handle address
		mov	dword ptr [ebx+8], 1	;	state=allocated (could be used as reference count)

		add	ebx, ecx					;	next available
		sub	edx, ecx
		mov	[ebx], edx					;	mark reduced size available
		mov	dword ptr [ebx+4], 0	; show that it is not indexed by a handle
		mov	dword ptr [ebx+8], 0	; show that it is free
	
	.endif
	
	mov	[si], eax	;	leave address of pointer (or null) as output of function
	ret

#

comment #	handle reclamation

		;	so check all released handles, to find the best matching size freed block
		
		mov	ebx, HandleSP

		.repeat

			movzx	eax, word ptr [ebx]	; get handle in eax
			shl	eax, 2
			add	eax, HandleTable		;

			.if	dword ptr [eax]
				mov	eax, [eax]					;	point to freed block

				.if	ecx==[eax]					;	matching block size
					push	eax
					mov	eax, HandleSP
					mov	ax, [eax]
					mov	[ebx], ax				;	swap handles
					add	HandleSP, 2

					pop	eax						;	restore original block pointer
					mov	dword ptr [eax+8], 1 ;	mark as in use
					mov	eax, [eax+4]			;	get handle address from block
					mov	[si], eax
					ret
				.endif
			.endif

			add	ebx, 2							;	next on handle stack

		.until	ebx>=MemTop

failed:

#

;============================================================================
Code_word	<MergeFree>, NORMAL			; ( segment - flag )
	jmp	HeapAggregate

Code_word	<mfree>, NORMAL			; ( handle/memory block - flag )
	mov	ebx, [si]
	.if	ebx<HandleTable	;	freeing the memory block, not the handle
		sub	ebx, 16
		mov	edx, [ebx+4]	;	get handle 
		.if	ebx != [edx]		;	handle contents does not match block address
			jmp	BadFree
		.endif
	.else
		mov	edx, ebx			;	edx is address of handle
		mov	ebx, [ebx]			;	point to block
	.endif
	mov	eax, [ebx+4]
	.if	eax==edx				;	valid handle
		xor	eax, eax
		xchg	eax, [ebx+8]	;	guaranty that block Usage/Reference Count is set to 'free'
		.if	!eax							;	already free
			mov	ax, ERR_FREED_BLOCK
			call	FORTHabort
			db	" : Attempt to free already freed memory block", 0
		.endif
		
		mov	eax, edx
		sub	eax, HandleTable
		shr	ax, 2
		sub	HandleSP, 2
		mov	ebx, HandleSP
		mov	[ebx], ax
		sub	si, 4
		ret
	.endif
			
BadFree:							;	attempt to free invalid memory block
	mov	ax, ERR_BAD_MEMORY_BLOCK
	call	FORTHabort
	db	" : Attempt to free invalid memory block", 0
	ret

Code_word	<handle!.data>, NORMAL, HandleToAddress		; ( handle - xaddress )
	mov	ebx, [si]
	mov	eax, [ebx]
	add	eax, 16
	mov	[si], eax
	ret

Code_word	<data!.handle>, NORMAL, AddressToHandle		; ( handle - xaddress )

	mov	ebx, [si]
	mov	eax, [ebx - 16]
	mov	[si], eax
	ret

Code_word	<MemTop>, NORMAL	;	return address of first byte of non-existent physical memory
	mov	eax, MemTop
	jmp PushEAX
	
Code_word	<HandleStack>, NORMAL	;	stack of available handles (indices into handle table)
	mov	eax, HandleStack
	jmp PushEAX
	
Code_word	<HandleSP>, NORMAL	;	pointer to next available handle
	mov	eax, HandleSP
	jmp PushEAX
	
Code_word	<HandleTable>, NORMAL	;	table of pointers to allocated heap blocks
	mov	eax, HandleTable
	jmp PushEAX
	
Code_word	<HeapBase>, NORMAL	;	start of heap
	mov	eax, HeapBase
	jmp PushEAX

Code_word	<HeapTop>, NORMAL	;	pointer to top of heap - increase as meory is allocated.
	mov	eax, HeapTop
	jmp PushEAX

Code_word	<HeapLimit>, NORMAL	;	address of first byte beyond area designated for heap use
	mov	eax, HeapLimit
	jmp PushEAX

Code_word	<LocalSP>, NORMAL	;	address of first byte beyond area designated for heap use
	mov	ax, offset LocalSP
	jmp PushShortAX

Code_word	<StaticTop>, NORMAL	;	address of first byte beyond area designated for heap use
	mov	eax, StaticTop
	jmp PushEAX

Code_word	<StaticLimit>, NORMAL	;	address of first byte beyond area designated for heap use
	mov	eax, StaticLimit
	jmp PushEAX

Code_word	<staticallot>, NORMAL	; allocates n bytes of static heap, and leaves starting address on stack
	mov	cx, word ptr [si]
	mov	ebx, StaticTop
	mov	[si], ebx

	.while	cx
	  mov	[ebx], bl
	  dec	cx
	  inc		ebx
	.endw

	mov	StaticTop, ebx

	ret


;============================================================================


% lastMemLink =   _link&lastLink
public  lastMemLink
    
forth_mem   endp

;============================================================================

_TEXT	ends

end
