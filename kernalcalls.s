.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"

.import parse_num_kernal_ext
.import hex_num_to_string_kernal

.import get_process_name_kernal_ext
.import load_new_process
.import run_code_in_bank_kernal
.import kill_process_kernal
.import is_valid_process

.import open_file_kernal_ext, close_file_kernal, read_file_ext

.import irq_already_triggered
.import atomic_action_st
.import process_table
.import return_table
.import process_priority_table
.import active_process_stack
.import active_process_sp
.import current_program_id

.export call_table
call_table:
	jmp GETIN ; $9D00
	jmp putc ; $9D03
	jmp exec ; $9D06
	jmp print_str_ext ; $9D09
	jmp get_process_info ; $9D0C
	jmp get_args ; $9D0F
	jmp get_process_name ; $9D12
	jmp parse_num ; $9D15
	jmp hex_num_to_string ; $9D18
	jmp kill_process ; $9D1B
	jmp open_file ; $9D1E
	jmp close_file ; $9D21
	jmp read_file ; $9D24
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
;
;
putc:
	phx
	pha
	and #$7F
	cmp #$20
	bcc @unusual_char
@valid_char:
	pla
	plx
	jmp CHROUT	
	
@unusual_char:
	tax
	pla
	pha
	cmp #$80
	bcs :+
	lda valid_c_table_0, X
	bra :++
	:
	lda valid_c_table_1, X
	:
	bne @valid_char
	
	; needs to be appended ;
	lda #$80
	jsr CHROUT
	jmp @valid_char
	
valid_c_table_0:
	.byte 0, 0, 0, 0, 1, 1, 0, 1
	.byte 1, 1, 1, 1, 1, 1, 0, 0
	.byte 0, 0, 1, 1, 0, 0, 0, 0
	.byte 1, 0, 1, 0, 0, 1, 0, 0
valid_c_table_1:
	.byte 0, 1, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 1, 0, 0
	.byte 1, 1, 1, 1, 0, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1
	
	
;
; prints a null terminated string pointed to by .AX
;
.export print_str_ext
print_str_ext:
	sta r0
	stx r0 + 1
	ldy #0
	:
	lda (r0), Y
	beq :+
	jsr putc
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
	tax
	jsr is_valid_process
	bne :+
	rts

	:
	txa
	
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
	tax
	lda #1 ; already know process is valid
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
	pha 
	lda #1
	sta atomic_action_st
	pla
	
	jsr get_process_name_kernal_ext
	
	stz atomic_action_st
	rts

;
; Parse a number in the string pointed to by .AX
; if leading $ or 0x, treat as hex number 
;
parse_num:
	jmp parse_num_kernal_ext
	
;
; returns base-16 representation of byte in .A in .X & .A
; returns low nibble in .X, high nibble in .A, preserves .Y
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
; opens file with name in .AX
; read_mode ('r', 'w', etc.) in .Y
;
; returns fd in .A on success, else 0
; .X contains error if fail
;
open_file:
	jmp open_file_kernal_ext

;
; closes file with fd .A
;	
close_file:
	jmp close_file_kernal

;
; reads r1 bytes from file .A into r0
;
; .A = fd 
; r0 = buff
; r1 = bytes to read
;
read_file:
	jmp read_file_ext
