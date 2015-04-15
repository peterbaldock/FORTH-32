lmul	macro	source

	push	cx
	mov	cx,dx
	mul	source
	push	dx
	xchg	cx,ax
	mul	source
	pop	dx
	add	dx,ax
	mov	ax,cx
	pop	cx
	endm

ldiv	macro	source

	mov	cx,ax
	mov	ax,dx
	xor	dx,dx
	div	source
	xchg	ax,cx
	div	source
	xchg	cx,dx

	endm	
