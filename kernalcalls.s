.include "prog.inc"
.include "cx16.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import parse_num_kernal_ext
.import hex_num_to_string_kernal

.import get_process_name_kernal_ext
.import load_new_process
.import run_code_in_bank_kernal
.import kill_process_kernal
.import is_valid_process

.import open_file_kernal_ext, close_file_kernal, read_file_ext, write_file_ext, open_dir_listing_ext
.import get_pwd_ext, chdir_ext

.import res_extmem_bank, set_extmem_bank, read_byte_extmem_y, read_byte_extmem_x, read_word_extmem_y
.import write_byte_extmem_y, write_byte_extmem_x, write_word_extmem_y, memmove_extmem
	
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
	jmp getc ; $9D00
	jmp putc ; $9D03
	jmp exec ; $9D06
	jmp print_str_ext ; $9D09
	jmp get_process_info ; $9D0C
	jmp get_args ; $9D0F
	jmp get_process_name ; $9D12
	jmp parse_num ; $9D15
	jmp hex_num_to_string ; $9D18
	jmp kill_process ; $9D1B
	jmp open_file_kernal_ext ; $9D1E
	jmp close_file_kernal ; $9D21
	jmp read_file_ext ; $9D24
	jmp write_file_ext ; $9D27
	jmp open_dir_listing_ext ; $9D2A
	jmp get_pwd_ext ; $9D2D
	jmp chdir_ext ; $9D30
	jmp res_extmem_bank ; $9D33
	jmp set_extmem_bank ; $9D36
	jmp read_byte_extmem_y ; $9D39
	jmp read_word_extmem_y ; $9D3C
	jmp $0000
	jmp write_byte_extmem_y ; $9D42
	jmp write_word_extmem_y ; $9D45
	jmp $0000
	jmp memmove_extmem ; $9D4B
.export call_table_end
call_table_end:

;
; exec - calls load_new_process
;
; .AX holds pointer to process name & args
; .Y holds # of args
; r0.L = make new program active (0 = no, !0 = yes, only applicable if current process is active)	
; r2.L = redirect prog's stdin from file, r2.H redirect stdout
;
; return value: 0 on failure, otherwise return bank of new process
;
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
; calls fputc with stdout (#1)
;
.export putc
putc:
	phy
	phx
	pha
	
	ldx #1
	jsr fputc
	
	pla
	plx
	ply
	rts

;
; CHKOUT's a certain file, then calls CHROUT
;
.export fputc
fputc:
	pha
	inc RAM_BANK
	lda PV_OPEN_TABLE, X
	dec RAM_BANK
	tax
	pla
	cpx #$FF
	beq @exit_nsuch_file
	
	cpx #2 ; STDIN / STDOUT
	bcs :+
	jmp putc_v
	:
	
	ldy #1
	sty atomic_action_st
	
	pha
	jsr CHKOUT
	pla
	bcs @chkout_error
	
	; can just print normally to a file ;
	jsr CHROUT
	cmp #$d
	bne :+
	lda #$a
	jsr CHROUT
	:
	pha
	jsr CLRCHN
	pla
	stz atomic_action_st
	ldy #0
	rts
	
@exit_nsuch_file:
	ldy #$FF
	rts
@chkout_error:
	stz atomic_action_st
	tay
	rts
	

;
; filters certain invalid chars, then calls CHROUT 
;
putc_v:
	pha
	and #$7F
	cmp #$20
	bcc @unusual_char
@valid_char:
	pla
	jmp CHROUT	
	
@unusual_char:
	tax
	pla
	pha
	
	cmp #$d ; '\r'
	bne :+
	jsr CHROUT
	pla
	lda #$a ; '\n'
	jmp CHROUT
	:
	
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
	.byte 1, 0, 1, 0, 1, 1, 1, 1
valid_c_table_1:
	.byte 0, 1, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 1, 0, 0
	.byte 1, 1, 1, 1, 0, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1

;
; Returns char from stdin in .A
; preserves .X
;
.export getc	
getc:
	phx
	
	ldx #0
	jsr fgetc
	phx
	ply ; move possible error code from .X to .Y
	; CHRIN doesn't preserve .Y so this is fine
	
	plx
	rts

;
; Returns a byte in .A from fd .X
;	
.export fgetc
fgetc:
	pha
	inc RAM_BANK
	lda PV_OPEN_TABLE, X
	tax
	dec RAM_BANK
	pla
	
	cpx #$FF
	beq @exit_nsuch_file
	cpx #2
	bcs :+
	; reading from stdin
	jmp GETIN
	:
	
	lda #1
	sta atomic_action_st
	
	jsr CHKIN
	bcs @chkout_error
	
	jsr GETIN
	pha
	jsr CLRCHN
	pla
	ldx #0
	rts
	
@exit_nsuch_file:
	lda #0
	; .X = $FF already
	rts
@chkout_error:
	stz atomic_action_st
	tax
	rts
	
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
; open_file_kernal_ext	
;
; opens file with name in .AX
; read_mode ('r', 'w', etc.) in .Y
;
; returns fd in .A on success, else 0
; .X contains error if fail
;

;
; close_file
;
; closes file with fd .A
;	

;
; read_file
;
; reads r1 bytes from file .A into r0
;
; .A = fd 
; r0 = buff
; r1 = bytes to read
;

;
; write_file
;
; writes r1 bytes to file .A from r0
;
; .A = fd
; r0 = buff
; r1 = bytes to read
;