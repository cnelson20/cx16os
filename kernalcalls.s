.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"

.import load_new_process
.import irq_already_triggered

.import process_table
.import return_table
.import process_priority_table
.import active_process_stack
.import active_process_sp

.export call_table
call_table:
	jmp CHRIN ; $9D00
	jmp CHROUT ; $9D03
	jmp exec ; $9D06
	jmp print_str ; $9D09
	jmp process_info ; $9D0C
.export call_table_end
call_table_end:

exec:
	sta $02 + 1
	
	lda #1
	sta irq_already_triggered
	
	lda RAM_BANK
	pha
	lda $02 + 1
	
	; arguments in .AXY, r0.L
	jsr load_new_process ; return val in .A
	
	plx
	stx RAM_BANK
	
	stz irq_already_triggered
	rts
	
;
; prints a null terminated string pointed to by .AX
;
print_str:
	sta r0
	stx r0 + 1
	ldy #0
	:
	lda (r0), Y
	beq :+
	jsr CHROUT
	iny
	bne :-
	:
	rts

;
; returns info about the process using bank .A 
;
; return values: .A = alive/dead, .X = return value
; .Y = priority value, r0.L = active process or not
;
process_info:
	ldx active_process_sp
	cmp active_process_stack, X
	bne @not_active_process
	; active ;
	ldy #1
	sta r0
	jmp @done_active_inactive
@not_active_process:
	stz 0
@done_active_inactive:
	stz r0 + 1
	
	tax
	lda process_priority_table, X
	tay
	lda return_table, X
	pha
	lda process_table, X
	plx
	rts
	