CHRIN = $9D00
CHROUT = $9D03
exec = $9D06
print_str = $9D09
process_info = $9D0C

r0 = $02
r1 = $04
r2 = $06

UNDERSCORE = $5F
LEFT_CURSOR = $9D

init:
	ldx #0
intro_loop:
	lda welcome_string, X
	beq intro_end_loop
	jsr CHROUT
	inx
	bne intro_loop
intro_end_loop:

new_line:
	lda #$24 ; '$'
	jsr CHROUT
	lda #$20 ; space
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT

	stz input
	ldx #0
wait_for_input:
	phx
	jsr CHRIN
	plx
	cmp #0
	beq wait_for_input

	cmp #$0D ; return
	beq command_entered
	cmp #$8D ; shifted return
	beq command_entered
	
	cmp #$14 ; backspace
	beq backspace
	cmp #$19 ; delete
	beq backspace
	
	tay
	and #$80 ; if >= $80, invalid char
	bne wait_for_input
	tya
char_entered:
	sta input, X
	inx
	
	tay
	lda #LEFT_CURSOR
	jsr CHROUT
	tya
	jsr CHROUT
	
	cmp #$22
	bne not_quote_entered
	lda #$22
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
not_quote_entered:
	
	lda #UNDERSCORE
	jsr CHROUT
	
	jmp wait_for_input
	
backspace:
	cpx #0
	bne backspace_not_empty
	jmp wait_for_input
backspace_not_empty:
	dex
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #$20
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	jmp wait_for_input

command_entered:
	lda #LEFT_CURSOR
	jsr CHROUT
	lda #$20
	jsr CHROUT
	lda #$0d
	jsr CHROUT
	
	stz in_quotes
	stz input, X	
	cpx #0
	bne not_empty_line
	jmp new_line
not_empty_line:
	stz num_args
	ldy #0 ; index in input
	ldx #0 ; index in output
go_until_next_nspace:
	lda input, Y
	beq end_loop
	cmp #$21
	bcs nspace_found
	iny
	jmp go_until_next_nspace
nspace_found:
	inc num_args
seperate_words_loop:
	lda input, Y
	beq end_loop
	cmp #$22 ; quotes
	bne char_not_quote
	; if in quotes, toggle quoted mode and dont include in command 
	lda in_quotes
	eor #$FF
	sta in_quotes
	iny
	jmp seperate_words_loop
char_not_quote:
	stx r1
	stz r2
	ldx in_quotes
	beq not_in_quotes
	sta r2
not_in_quotes:
	ldx r1
	cmp r2
	beq dont_check_whitespace
	cmp #$21
	bcc whitespace_found
dont_check_whitespace:
	sta output, X
	iny
	inx
	jmp seperate_words_loop
whitespace_found:
	iny
	stz output, X
	inx
	jmp go_until_next_nspace
end_loop:
	stz output, X
	stx command_length
	
	lda num_args
	bne narg_not_0
	jmp new_line
narg_not_0:
	
	lda #1
	sta do_wait_child
	sta r0 ; by default, new process is active 
	
	dex
	lda output, X
	cmp #$26
	bne no_ampersand
	dex 
	lda output, X
	bne no_ampersand
	; last argument is just an ampersand
	dec num_args
	stz do_wait_child
	stz r0
no_ampersand:	
	ldy num_args
	bne narg_not_0_amp
	jmp new_line
narg_not_0_amp:
	
	lda #<output
	ldx #>output
	jsr exec
	cmp #0
	beq exec_error
	sta child_id
	
	lda do_wait_child
	bne wait_child
	jmp new_line
wait_child:	
	lda child_id
	jsr process_info
	cmp #0
	bne wait_child
	
	stx last_return_val
	jmp new_line
	
exec_error:
	lda #<exec_error_p1_message
	ldx #>exec_error_p1_message
	jsr print_str
	
	lda #<output
	ldx #>output
	jsr print_str
	
	lda #<exec_error_p2_message
	ldx #>exec_error_p2_message
	jsr print_str
	
exec_error_done:	
	jmp new_line

in_quotes:
	.byte 0
do_wait_child:
	.byte 0
command_length:
	.byte 0
last_return_val:
	.byte 0
num_args:
	.byte 0
child_id:
	.byte 0
input:
	.res 128, 0
output:
	.res 128, 0

welcome_string:
	.ascii "Commander X16 OS Shell"
	.byte $0d, $00
exec_error_p1_message:
	.asciiz "Error in exec '"
exec_error_p2_message:
	.ascii "'"
	.byte $0d, $00