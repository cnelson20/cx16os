GETIN := $FFE4
CHRIN := $FFE4
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
OPEN := $FFC0
LOAD := $FFD5
CHKIN := $FFC6
CLOSE := $FFC3
MACPTR := $FF44
CLRCHN := $FFE7
CLALL := $FFCC
READST := $FFB7

RAM_BANK := $00
ROM_BANK := $01

.include "prog.inc"

.import prog_bank
.import prog_addr
.import current_program_id
.import irq_handler

.import kernal_use

.import handle_prog_exit
.import clear_process_info

.import process_table
.import process_priority
.import return_table
.import mem_table
.import file_table

.SEGMENT "CODE"

getchar_kernal:
	php
	sei
	jsr CHRIN
	plp
	rts
	
putchar_kernal:
	php
	sei
	jsr CHROUT
	plp
	rts


filename_buffer:
	.res 32

; filename in .AX, num args in .Y	
exec_kernal:
	sei
	sta KZP1
	stx KZP1 + 1
	
	sty KZP2

	lda RAM_BANK
	sta prog_bank
	
	ldy #0 ; get length of file name
@filename_length_loop:
	lda (KZP1), Y
	sta filename_buffer, Y
	beq @filename_length_loop_exit
	iny
	bne @filename_length_loop
@filename_length_loop_exit:
	tya

	ldx #<filename_buffer
	ldy #>filename_buffer
	jsr SETNAM
	
	lda #$FF
	ldx #8
	ldy #2 ; header-less load
	jsr SETLFS
	
	jmp @find_bank
	; error occured in open ;
@open_kernal_error:	
	lda prog_addr ; failed program bank
	stz process_table, X

	lda prog_bank
	sta RAM_BANK
	lda #0 ; signifies error
	cli
	rts
	
@find_bank:	
	ldx #32
	:
	lda process_table, X
	beq :+
	inx 
	bne :-
	:
	stx prog_addr ; new prog bank stored in prog_addr

@setup_program_execution:
; file loaded, setup program execution 	
	ldx prog_addr ; new program's pid/bank
	stx RAM_BANK

	lda #0
	ldx #<$A200
	ldy #>$A200
	jsr LOAD

	; if carry set, an error occured
	bcs @open_kernal_error
	cpx #<$A200
	bne :+
	cpy #>$A200
	bne :+
	jmp @open_kernal_error
	:
	
	jsr setup_prog_vars
	
	lda #<$A080
	sta KZP4
	lda #>$A080
	sta KZP4 + 1
	
	lda prog_addr
	sta @new_prog_bank ; new program's bank was stored in prog_addr

	ldx KZP2 ; number of args
	stx STORE_PROG_ARGC
	
@arg_copy_loop:	
	ldy prog_bank
	sty RAM_BANK
	lda (KZP1)
	ldy @new_prog_bank
	sty RAM_BANK
	sta (KZP4)
	
	inc KZP1
	bne :+
	inc KZP1 + 1
	:
	inc KZP4
	bne :+
	inc KZP4 + 1
	:
	
	cmp #0
	bne @arg_copy_loop
	
@end_arg:
	dex
	beq @end_arg_copy_loop
	
	lda prog_bank
	sta RAM_BANK
@skip_repeat_spaces:
	lda (KZP3) 
	bne @arg_copy_loop ; if not \0, continue to next iteration of loop
	inc KZP3
	bra @skip_repeat_spaces
	inc KZP3 + 1
	bra @skip_repeat_spaces
	
@end_arg_copy_loop:
	lda @new_prog_bank
	
	ldx prog_bank
	stx RAM_BANK ; restore bank 

	ldx #1 ; success
	cli
	rts 

@new_prog_bank:
	.byte 0

; sets up the program structure for preexisting code in bank .A
; code must start @ $A200 as normal
run_bank_code_kernal:
	sei
	sta RAM_BANK
	jsr setup_prog_vars

	; 1 argument, bank name as hex
	lda #1
	sta STORE_PROG_ARGC
	lda RAM_BANK
	lsr 
	lsr 
	lsr 
	lsr
	jsr hex_to_char
	sta STORE_PROG_ARGS
	lda RAM_BANK
	and #$0F
	jsr hex_to_char
	sta STORE_PROG_ARGS + 1
	stz STORE_PROG_ARGS + 2

	lda current_program_id
	sta RAM_BANK
	cli
	rts

setup_prog_vars:
	stz STORE_REG_A
	stz STORE_REG_X
	stz STORE_REG_Y ; set registers to 0
	
	stz STORE_REG_STATUS
	
	lda #<$A200
	sta STORE_PROG_ADDR
	lda #>$A200
	sta STORE_PROG_ADDR + 1
	
	lda #$FD
	sta STORE_PROG_SP ; set prog sp to $FA
	
	lda #< ( program_exit - 1)
	sta STORE_PROG_STACK + $FE 
	lda #> ( program_exit - 1)
	sta STORE_PROG_STACK + $FF
	
	ldx RAM_BANK
	lda #1
	sta process_table, X
	lda #10
	sta process_priority, X

	rts

.import schedule_timer

; if a program returns, return value in .A
program_exit:
	ldx RAM_BANK
	stx prog_bank
	
	jmp handle_prog_exit

; get info about a process in .A, returns if active in .A and priority in .X
process_status_kernal:
	tay
	ldx process_priority, Y
	lda process_table, Y
	rts

; pointer to buffer of .Y bytes in .AX, stack = pid
process_name_kernal:
	sei
	sta KZP1
	stx KZP1 + 1
	
	sty KZP3
	
	tsx 
	lda $103, X ; pid on stack
	sta KZP2
	
	lda $102, X
	sta $103, X
	
	pla ; increment stack pointer
	sta $102, X
	
	lda current_program_id
	sta prog_bank
	
	ldy #0
	ldx KZP3
	beq @end_copy
@loop:	
	dex
	beq @end_loop
	lda KZP2
	sta RAM_BANK
	lda STORE_PROG_ARGS, Y
	beq @end_loop
	sta KZP4 ; like a pha 
	lda prog_bank
	sta RAM_BANK
	lda KZP4 ; like a pla 
	sta (KZP1), Y
	iny 
	bne @loop
@end_loop:
	lda prog_bank
	sta RAM_BANK
	lda #0
	sta (KZP1), Y
@end_copy:
	cli
	rts

print_string_kernal:
	sei
	sta KZP1
	stx KZP1 + 1
	
	ldy #0
	:
	lda (KZP1), Y
	beq @end
	jsr CHROUT
	
	iny
	bne :-
	inc KZP1 + 1
	bne :-
@end:
	cli
	rts

; kill a process with PID in .A	
kill_process_kernal:
	sei
	tax
	cmp RAM_BANK
	bne :+
	
	sta prog_bank
	lda #RETURN_SUICIDE
	jsr clear_process_info
	jmp switch_prog
	
	:
	lda process_table, X
	bne :+
	lda #1
	rts
	:
	lda #RETURN_KILL
	jsr clear_process_info
	lda #0
	cli
	rts 

; Parse a byte number from a string in .AX with radix in .Y
; Allowed options: .Y = 10, .Y = 16
parse_num_from_string_kernal:
	sta KZP1
	stx KZP1 + 1

	cpy #16 ; hexadecimal
	beq parse_hex
parse_decimal:
	ldy #0
	:
	lda (KZP1), Y
	beq :+
	iny 
	bra :-
	:
	dey
	; y + kzp1 = last byte of string
	
	stz KZP3 
	stz KZP3 + 1
	ldx #0
@parse_decimal_loop:
	lda (KZP1), Y
	sec 
	sbc #$30
	sta KZP2
	stz KZP2 + 1
	
	jsr @mult_pow_10
	
	clc
	lda KZP2
	adc KZP3
	sta KZP3
	lda KZP2 + 1
	adc KZP3 + 1
	sta KZP3 + 1
@end_of_loop:
	inx
	dey
	bmi @end_parse_decimal
	jmp @parse_decimal_loop	
@end_parse_decimal:
	lda KZP3
	ldx KZP3 + 1

	rts
@mult_pow_10:
	phy
	phx
	cpx #0
	beq :++
	:
	jsr @mult_10
	dex
	bne :-
	:
	plx
	ply	
	rts 
@mult_10:
	lda KZP2
	ldy KZP2 + 1
	
	asl KZP2
	rol KZP2 + 1
	asl KZP2
	rol KZP2 + 1
	
	clc
	adc KZP2
	pha
	tya
	adc KZP2 + 1
	sta KZP2 + 1
	
	pla
	asl A
	sta KZP2
	rol KZP2 + 1
	
	rts 
	
parse_hex:
	ldy #0
	:
	lda (KZP1), Y
	beq :+
	iny 
	bra :-
	:
	dey
	
	stz KZP2
	stz KZP2 + 1
	
	lda (KZP1), Y
	jsr @get_hex_digit
	sta KZP2
	dey
	bmi @end
	lda (KZP1), Y
	jsr @mult_16
	ora KZP2
	sta KZP2
	dey
	bmi @end
	
	lda (KZP1), Y
	jsr @get_hex_digit
	sta KZP2 + 1
	dey
	bmi @end
	lda (KZP1), Y
	jsr @mult_16
	ora KZP2 + 1
	sta KZP2 + 1
@end:
	lda KZP2
	ldx KZP2 + 1
	
	cli
	rts
@mult_16:
	asl A
	asl A
	asl A
	asl A
	rts
	
@get_hex_digit:
	cmp #$3A
	bcc :+
	and #31
	clc 
	adc #9 ; A = $41 -> $1 + $9 = 10
	rts
	:
	sec 
	sbc #$30
	rts

; prints base-10 representation of byte in .A
; preserves .X and .Y
print_hex_num_kernal:
	sei
	phx
	phy
	
	pha
	lsr
	lsr 
	lsr 
	lsr
	jsr hex_to_char
	jsr CHROUT
	
	pla
	and #$0F
	jsr hex_to_char
	jsr CHROUT

	ply
	plx
	cli
	rts
hex_to_char:
	cmp #10
	bcs @greater10
	ora #$30
	rts
@greater10:
	sec
	sbc #10
	clc
	adc #$41
	rts

;
; system call table ; starts at $9d00
;
to_copy_call_table:
	jmp getchar_kernal ; $9D00
	jmp putchar_kernal ; $9D03
	
	jmp exec_kernal ; $9D06
	jmp process_status_kernal ; $9D09
	jmp process_name_kernal ; $9D0C
	jmp kill_process_kernal ; $9D0F
	
	jmp print_string_kernal ; $9D12
	jmp parse_num_from_string_kernal ; $9D15
	jmp print_hex_num_kernal ; $9D18

	jmp run_bank_code_kernal ; $9D1B
	
to_copy_call_table_end:	

.export setup_call_table	
setup_call_table:
	ldx #0 
	:
	lda to_copy_call_table, X
	sta $9D00, X 
	inx
	cpx #(to_copy_call_table_end - to_copy_call_table)
	bcc :-
	rts

.import switch_prog
.word switch_prog