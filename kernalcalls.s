CHRIN := $FFE4
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
OPEN := $FFC0
CHKIN := $FFC6
CLOSE := $FFC3
MACPTR := $FF44
CLRCHN := $FFE7
CLALL := $FFCC
READST := $FFB7

ROM_BANK := $01

.include "prog.inc"

.import prog_bank
.import prog_addr

.import irq_handler

.import handle_prog_exit
.import clear_process_info

.import process_table
.import process_priority
.import return_table
.import mem_table
.import file_table

.SEGMENT "CODE"

getchar_kernal:
	lda ROM_BANK 
	sta prog_bank
	
	stz ROM_BANK
	jsr CHRIN
	
	pha
	lda prog_bank
	sta ROM_BANK
	pla 
	rts
	
putchar_kernal:
	pha
	lda ROM_BANK 
	sta prog_bank
	pla
	stz ROM_BANK
	
	jsr CHROUT
	
	lda prog_bank
	sta ROM_BANK
	rts


filename_buffer:
	.res 32
	
; filename in .AX, num args in .Y	
exec_kernal:
	sei 
	sta KZP1
	stx KZP1 + 1
	
	sta KZP3
	stx KZP3 + 1
	
	sty KZP2
	
	lda ROM_BANK
	sta prog_bank
	
	ldy #0
	:
	lda (KZP1), Y
	sta filename_buffer, Y
	beq :+
	iny
	bne :-
	:
	tya ; load filename length into .A
	
	stz ROM_BANK
	cli
	
	ldx #<filename_buffer
	ldy #>filename_buffer
	jsr SETNAM
	
	lda #KERNAL_USE_FILENUM
	ldx #8
	ldy #KERNAL_USE_FILENUM
	jsr SETLFS
	
	jsr OPEN
	jmp @find_bank
	; error occured in open ;
@open_kernal_error:
	ldx #KERNAL_USE_FILENUM
	jsr CLOSE
	jsr CLRCHN
	
	lda prog_bank
	sta ROM_BANK
	lda #0
	rts
	
@find_bank:	
	ldx #32
	:
	lda process_table, X
	beq :+
	inx 
	bne :-
	:
	stx prog_addr
	
	lda #1
	sta	@was_first_load_loop
	
	lda #<$C200
	sta KZP4
	lda #>$C200
	sta KZP4 + 1
	
@load_loop:	
	stz ROM_BANK
	cli
	
	ldx #KERNAL_USE_FILENUM
	jsr CHKIN
	
	lda #0
	ldx #<$9000
	ldy #>$9000
	clc
	jsr MACPTR
	
	bcs :+
	cpy #0
	bne @continue_load
	cpx #0 ; MACPTR has an off by one problem
	bne @continue_load
	:
	lda @was_first_load_loop
	beq @exec_kernal_end_load
	ldx prog_addr
	stz process_table, X
	jmp @open_kernal_error
@continue_load:
	lda prog_addr ; restore correct bank
	sei
	sta ROM_BANK
	
@copy_to_bank:

	lda #<$9000
	sta KZP1
	lda #>$9000
	sta KZP1 + 1
	
	inx
@copy_loop:
	dex 
	bne :+
	cpy #0
	beq @copy_loop_end
	dey 
	:
	lda (KZP1)
	sta (KZP4)
	
	inc KZP1
	bne :+
	inc KZP1 + 1
	:
	inc KZP4
	bne :+
	inc KZP4 + 1
	:
	jmp @copy_loop
	
@copy_loop_end:
	stz @was_first_load_loop
	jmp @load_loop
	
@exec_kernal_end_load:
	stz ROM_BANK
	
	ldx #KERNAL_USE_FILENUM
	jsr CLOSE
	jsr CLRCHN
	
; file loaded, setup program execution 	
	ldx prog_addr ; new program's pid/bank
	sei
	stx ROM_BANK
	
	lda #<irq_handler
	sta $FFFE
	lda #>irq_handler
	sta $FFFF
	
	stz STORE_REG_A
	stz STORE_REG_X
	stz STORE_REG_Y ; set registers to 0
	
	stz STORE_REG_STATUS
	stz STORE_RAM_BANK
	
	lda #<$C200
	sta STORE_PROG_ADDR
	lda #>$C200
	sta STORE_PROG_ADDR + 1
	
	
	lda #$FD
	sta STORE_PROG_SP ; set prog sp to $FA
	
	lda #< ( program_exit - 1)
	sta STORE_PROG_STACK + $FE 
	lda #> ( program_exit - 1)
	sta STORE_PROG_STACK + $FF
	
	lda #1
	sta process_table, X
	lda #10
	sta process_priority, X
	
	lda #<$C080
	sta KZP4
	lda #>$C080
	sta KZP4 + 1
	
	lda ROM_BANK
	sta @new_prog_bank
	
	ldx KZP2 ; number of args
	stx STORE_PROG_ARGC
	
@arg_copy_loop:	
	ldy prog_bank
	sty ROM_BANK
	lda (KZP3)
	ldy @new_prog_bank
	sty ROM_BANK
	sta (KZP4)
	
	inc KZP3
	bne :+
	inc KZP3 + 1
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
	sta ROM_BANK
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
	stx ROM_BANK ; restore bank 
	cli	
	rts 

@new_prog_bank:
	.byte 0
@was_first_load_loop:
	.byte 0

; if a program returns via rts instead of brk, return value in .A
program_exit:
	ldx ROM_BANK
	stx prog_bank
	
	jmp handle_prog_exit

; get info about a process in .A
process_info_kernal:
	tay
	ldx process_priority, Y
	lda process_table, Y
	rts

; allocate a bank of storage, returns bank in .A
alloc_bank_kernal:
	sei
	ldy #1
@loop:
	lda mem_table, Y
	bne :+
	lda ROM_BANK
	sta mem_table, Y
	tya
	bra @exit
	:
	iny 
	bne @loop
	; if no bank found, return 0
	lda #0
@exit:
	cli
	rts
	
; filename in .AX
open_file_kernal:
	sei
	sta KZP1
	stx KZP1 + 1

	ldx #3
	:
	lda file_table, X
	beq @obtained_filenum
	inx 
	cpx #15
	bne :-
	lda #0 ; fail
	jmp @end_open_file
@obtained_filenum:
	lda ROM_BANK
	sta prog_bank
	
	sta file_table, X
	
	ldy #0
	:
	lda (KZP1), Y
	sta filename_buffer, Y
	beq :+
	iny 
	bne :-
	:
	tya 
	
	phx 
	
	stz ROM_BANK
	ldx #<filename_buffer
	ldy #>filename_buffer
	jsr SETNAM
	
	pla
	pha
	tay
	ldx #8
	jsr SETLFS
	
	jsr OPEN
	plx
	bcc @noerror
	
	stz file_table, X
	ldx #0
@noerror:
	txa	
	
@end_open_file:
	ldx prog_bank
	stx ROM_BANK

	cli
	rts

; filenum in .A
close_file_kernal:
	ldy ROM_BANK
	phy
	
	sei
	tax
	stz file_table, X
	
	stz ROM_BANK
	jsr CLOSE
	cli
	
	ply
	sty ROM_BANK
	rts

; pointer to buffer in .AX, filenum in .Y, number of bytes on top stack
read_file_kernal:
	sei 
	
	sta KZP1
	stx KZP1 + 1
	
	lda ROM_BANK
	sta prog_bank
	
	lda file_table, Y
	beq @exit
	
	tsx 
	lda $103, X ; load number of bytes to load	
	sta KZP2
	
	lda $102, X
	sta $103, X
	
	pla ; increment stack pointer
	sta $102, X
	
	lda KZP2
	beq @exit
	
	phy
	plx
	stz ROM_BANK
	jsr CHKIN ; check in correct file
	
	lda KZP2 ; number of bytes to load in .A
	ldx #<$9000
	ldy #>$9000
	clc
	jsr MACPTR
	
	stx KZP2
	ldy KZP2
	
	lda prog_bank
	sta ROM_BANK
	:
	lda $9000, Y
	sta (KZP1), Y
	
	dey 
	bne :-
	lda $9000
	sta (KZP1)
	
	stz ROM_BANK
	jsr CLRCHN
	
	lda KZP2 ; return value is number of bytes read
@exit:	
	ldy prog_bank
	sty ROM_BANK
	cli
	rts 

print_string_kernal:
	sei
	
	sta KZP1
	stx KZP1 + 1
	
	ldy #0
	ldx ROM_BANK
	:
	stx ROM_BANK
	lda (KZP1), Y
	beq @end
	stz ROM_BANK
	jsr CHROUT
	
	iny
	bne :-
	inc KZP1 + 1
	bne :-
@end:
	stx ROM_BANK
	rts

; kill a process with PID in .A	
kill_process_kernal:
	tax
	cmp ROM_BANK
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
	rts 

; parse a byte number from a string in .AX with radix in .Y
parse_num_from_string_kernal:
	sei
	sta KZP1
	stx KZP1 + 1

	cpy #16
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
	lda (KZP1), Y
	sec 
	sbc #$30
	dey
	bmi @end_parse_decimal
	sta KZP3
	
	lda (KZP1), Y
	sec 
	sbc #$30
	jsr @mult_10
	clc 
	adc KZP3
	dey
	bmi @end_parse_decimal
	sta KZP3
	
	lda (KZP1), Y
	sec 
	sbc #$30
	jsr @mult_10
	jsr @mult_10
	clc 
	adc KZP3
@end_parse_decimal:
	cli
	rts
	
@mult_10:
	asl
	sta KZP2 ; 2x
	asl ; 4x 
	sta KZP2 + 1 
	clc 
	adc KZP2 + 1 ; 4x + 4x = 8x
	adc KZP2 ; 8x + 2x = 10x
	cli
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
	
	lda (KZP1), Y
	jsr @get_hex_digit
	
	asl 
	asl 
	asl 
	asl
	sta KZP2
	
	dey
	lda (KZP1), Y
	jsr @get_hex_digit
	ora KZP2
	
	cli
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

;
; system call table ; starts at $9d00
;
to_copy_call_table:
	jmp getchar_kernal
	jmp putchar_kernal
	jmp exec_kernal
	jmp process_info_kernal
	jmp alloc_bank_kernal
	jmp open_file_kernal
	jmp close_file_kernal
	jmp read_file_kernal
	jmp print_string_kernal
	jmp kill_process_kernal
	jmp parse_num_from_string_kernal
to_copy_call_table_end:	

.export setup_call_table
	
setup_call_table:
	ldx #0 
	:
	lda to_copy_call_table, X
	sta $9D00, X 
	inx
	cpx #to_copy_call_table_end - to_copy_call_table
	bcc :-
	rts

.import switch_prog
.word switch_prog