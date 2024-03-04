.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"

.import load_new_process
.import parse_num_kernal
.import kill_process_kernal
.import hex_num_to_string_kernal
.import run_code_in_bank_kernal

.import irq_already_triggered
.import process_table
.import return_table
.import process_priority_table
.import active_process_stack
.import active_process_sp
.import current_program_id

.export call_table
call_table:
	jmp CHRIN ; $9D00
	jmp CHROUT ; $9D03
	jmp exec ; $9D06
	jmp print_str ; $9D09
	jmp get_process_info ; $9D0C
	jmp get_args ; $9D0F
	jmp get_process_name ; $9D12
	jmp parse_num ; $9D15
	jmp hex_num_to_string ; $9D18
	jmp kill_process ; $9D1B
	jmp run_code_in_bank ; $9D1E
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
get_process_info:
	ldx active_process_sp
	cmp active_process_stack, X
	bne @not_active_process
	; active ;
	ldy #1
	sty r0
	jmp @done_active_inactive
@not_active_process:
	stz r0
@done_active_inactive:
	stz r0 + 1 ; zero high byte of r0
	
	tax
	lda process_priority_table, X
	tay
	lda return_table, X
	pha
	lda process_table, X
	plx
	rts

;
; Return pointer to args in .AX and argc in .Y
;
get_args:
	lda #<STORE_PROG_ARGS
	ldx #>STORE_PROG_ARGS
	ldy STORE_PROG_ARGC
	rts
	
;
; Read first r0.L bytes of the name of the process at .Y
; and store into .AX
;
; no return value
;
get_process_name:
	sta r2 
	stx r2 + 1
	
	lda #1
	sta irq_already_triggered
	
	sty r1
	ldy current_program_id
	sty r1 + 1
	
	ldy #0 ; index
	inc r0
@loop:
	dec r0
	beq @loop_end
	
	ldx r1
	stx RAM_BANK
	lda STORE_PROG_ARGS, Y
	ldx r1 + 1
	stx RAM_BANK
	
	cmp #0
	beq @loop_end
	sta (r2), Y
	
	iny
	bra @loop
@loop_end:
	lda #0
	sta (r2), Y

	lda current_program_id
	sta RAM_BANK
	
	stz irq_already_triggered
	rts
@process_bank:
	.byte 0

;
; Parse a number in the string pointed to by .AX
; if leading $ or 0x, treat as hex number 
;
parse_num:
	jmp parse_num_kernal
	
;
; returns base-16 representation of byte in .A in .X & .A
; returns low byte in .X, high byte in .A, preserves .Y
;
hex_num_to_string:
	jmp hex_num_to_string_kernal

;
; kills the process in bank .A
; may not return if current process = one being exited
;
; return val: .AX = 0 -> no process to kill, .X = 1 -> process .A killed
;	
kill_process:
	jmp kill_process_kernal

;
; if bank .A not in use, setup a program assuming code is already in said bank
; if .X != 0, a name for the program is in r0
; if active process & .Y != 0, new process will be active
; return val: .A = 0 -> failure, .A != 0 -> new process in .A
;
run_code_in_bank:
	jmp run_code_in_bank_kernal