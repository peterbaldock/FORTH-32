;       Flat Real/Real Big mode (v1.2)

option language:c

include ..\include\step.inc
;include ..\include\forth.inc

_TEXT    segment public

	.486
	assume  cs:_TEXT

externdef	FLAT_tsr 	:near
externdef	FLAT_copy       :near
externdef	FLAT_install    :near
externdef	FLAT_destall    :near

FLAT_install    proc                    ; Installs FLAT_tsr

.486p                                   ; SMSW is a priviledged instruction(?)
	smsw    ax                      ; Check for real mode
.486
	test    al,1
	jnz     short V86
	pushf                           ; Save flags & DS register
	push    ds
	cli
	xor     eax,eax                 ; Get IRQ5 vector & Set FLAT_tsr
	mov     ds,ax
	mov     ebx,ds:[34h]
	mov     cs:old_IRQ5,ebx
	mov     word ptr ds:[34h],offset FLAT_tsr
	mov     ax,cs
	mov     ds:[36h],ax
	shl     eax,4                   ; Build Global Descriptor Table
	add     dword ptr cs:GDT[2],eax
	pop     ds                      ; Restore DS register & flags
	popf
	
	xor	ax, ax
	dec	ax	; flat access = TRUE
	clc	; no error
	ret

V86: 	; running in Virtual86 mode - eg EMM386.EXE installed
	xor	ax, ax ; no flat access
	stc	; flag error
	ret

;V86_msg         db      'Cannot run in a virtual environment!',10,'$'

FLAT_install    endp

FLAT_destall    proc                    ; Destalls FLAT_tsr

	push    ds                      ; Save DS register
	xor     ax,ax                   ; Restore old IRQ5 vector
	mov     ds,ax
	mov     eax,cs:old_IRQ5
	mov     ds:[34h],eax
	pop     ds                      ; Restore DS register
	ret

FLAT_destall    endp

	align   8
GDT             dw      15              ; Limit (16 bytes)
		dw      offset GDT,0    ; Offset within current segment...
		dw      ?               ; Unused

FLAT_desc       dw      0ffffh          ; Limit (bit 0..15)
		db      ?,?,?           ; Base (bit 0..23)
		db      92h             ; Access rights
		db      0cfh            ; Page granularity + Limit(16..19)
		db      ?               ; Base (bit 24..31)

FLAT_sel        equ     FLAT_desc - GDT


old_IRQ5        dd      0
last_Exc_13     dd      0
IRQ5_flag       db      0

FLAT_tsr proc

	test    cs:IRQ5_flag,1          ; Exception within IRQ5 handler?
	jnz     short Exc_13
	push    ax                      ; Ask PIC if IRQ5 is 'IN-SERVICE'
	mov     al,0Bh
	out     20h,al
	jmp     $+2
	in      al,20h
	test    al,20h
	pop     ax
	jz      short Exc_13

IRQ5:   mov     cs:IRQ5_flag,1          ; Call old IRQ5 handler
	pushf
	call    dword ptr cs:old_IRQ5
	mov     cs:IRQ5_flag,0
	iret

Exc_13: push	bp
	mov	bp, sp

	push    eax                     ; Save accumulator

	mov     eax, [bp+2]             ; Get address of SOE
	cmp     eax,cs:last_Exc_13      ; Same as last time?
	je      short SOE
	mov     cs:last_Exc_13,eax
.486p
	lgdt    fword ptr cs:GDT        ; Load GDT Register

	push    gs
	push	fs
	push	es
	push	ds
	push	bx          ; Save registers

	mov     eax,CR0
	or      al,1                    ; Enter Protected mode
	mov     CR0,eax

	jmp     $+2                     ; Flush instruction decode queue

	mov     bx,FLAT_sel             ; Load 4Gb limits
	mov     ds,bx
	mov     es,bx
	mov     fs,bx
	mov     gs,bx

	and     al,not 1                ; Back to Real mode
	mov     CR0,eax
.486
	pop     bx
	pop	ds
	pop	es
	pop	fs
	pop	gs          ; Restore registers

	pop     eax                     ; Restore accumulator
	pop	bp
	iret                            ; Done

SOE:    call    FLAT_destall            ; Remove FLAT_tsr
	mov     ah,0fh                  ; Clear screen
	int     10h
	mov     ah,00h
	int     10h
	mov     ah,09h                  ; Write message
	mov     dx,offset SOE_msg
	push    cs
	pop     ds
	int     21h
	mov     ax,4C0Dh                ; Terminate with error code 13
	int     21h

SOE_msg         db      'Segment Overrun Exception!',10,'$'

FLAT_tsr endp

	public  FLAT_copy

FLAT_copy       proc

	push    bp
	mov     bp,sp
	push    ds
	lds     esi,ss:[bp+14]
	les     edi,ss:[bp+8]
	mov     ecx,ss:[bp+4]
	shr     ecx,2
	rep     movs dword ptr es:[edi],ds:[esi]
	pop     ds
	pop     bp
	ret     16

FLAT_copy       endp


_TEXT	ends

end
