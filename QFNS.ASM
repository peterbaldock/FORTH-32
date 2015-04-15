option language:c

_TEXT	segment	public 'CODE'
	.386

	assume	cs:_TEXT

comment/

;==================================================================================


	Structure of queue descriptor is as follows:


	Byte: | 0 - 1  | 2 - 3  |  4 - 5  | 6 - 7  | 8 - 9  |
	SI -> | status | entry  | removal | start  |  stop  |

	read_queue assumes a queue of integers, and returns the next
	integer available with C=0, or -1 with C=1 if queue is empty.


;==================================================================================/
Queue	struct
	qstatus		word	0
	qentry		word	0
	qremoval	word	0
	qstart		word	0
	qstop		word	0
	qdata		byte	?
Queue	ends

;Q_STATUS		equ	0
;Q_ENTRY		equ	2
;Q_REMOVAL		equ	4
;Q_START		equ	6
;Q_STOP			equ	8


FULL		=1
EMPTY		=2

	assume	si:ptr Queue

;==================================================================================

				public	q_read

;==================================================================================

q_read	proc	near


	.if	(word ptr [si].qstatus & EMPTY)

	  mov	ax, -1
	  stc					; queue is empty

	.else

	  mov	bx, [si].qremoval
	  mov	ax, [bx]
	  add	bx, 2

	  .if	bx>=[si].qstop
	    mov	bx, [si].qstart
	  .endif

	  mov	[si].qremoval, bx

	  .if	bx == [si].qentry
	    or	word ptr [si].qstatus, EMPTY
	  .endif

	  and	word ptr [si].qstatus, NOT FULL
	  clc

	.endif

	ret

q_read	endp

;==================================================================================

				public	q_look

;==================================================================================

q_look	proc	near



	push	bx
	mov	bx, [si].qremoval
	mov	ax, [bx]
	pop	bx
	ret

q_look	endp

;==================================================================================

				public	q_write

;==================================================================================

q_write	proc	near

	test	word ptr [si].qstatus, FULL
	jnz	wq4

	push	bx
	mov	bx, [si].qentry
	mov	[bx], ax
	xor	ax, ax
	add	bx, 2
	cmp	bx, [si].qstop
	jb	wq1
	mov	bx, [si].qstart
wq1:	mov	[si].qentry, bx
	cmp	bx, [si].qremoval
	jne	wq2
	or	word ptr [si].qstatus, FULL

wq2:	and	word ptr [si].qstatus, NOT EMPTY

wq3:	pop	bx
	clc
	ret

wq4:	mov	ax, -1
	stc
	ret

q_write	endp

;==================================================================================

				public	q_init

;==================================================================================

q_init	proc	near

	mov	ax, [si].qstart
	mov	[si].qentry, ax
	mov	[si].qremoval, ax
	mov	word ptr [si].qstatus, EMPTY
	ret

q_init	endp

;==================================================================================

				public	q_len

;==================================================================================

q_len	proc	near


	mov	ax, [si].qstop
	sub	ax, [si].qstart		; ax = length of queue
	mov	cx, [si].qentry
	sub	cx, [si].qremoval		; cx = distance apart of entry/removal
	.if	carry?				; if wrapped round
	  add	cx, ax				; add queue length
	.endif
	sub	ax, cx				; ax=bytes free
	.if	word ptr [si].qstatus & FULL
	  xchg	cx, ax				; 0 bytes free, count=length
	.endif
lq2:	ret

q_len	endp

;==================================================================================

_TEXT	ends

end

