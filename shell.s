CHRIN = $9D00
CHROUT = $9D03
exec = $9D06
print_str = $9D09
process_info = $9D0C

r0 = $02

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
	
	stz input, X	

	cpx #0
	bne not_empty_line
	jmp new_line
not_empty_line:
	lda #1
	sta num_args
	ldy #0 ; index in input
	ldx #0 ; index in output
go_until_next_nspace:
	lda input, Y
	beq end_loop
	cmp #$20
	bcs seperate_words_loop
	iny
	jmp go_until_next_nspace
seperate_words_loop:
	lda input, Y
	beq end_loop
	cmp #$21
	bcc whitespace_found
	sta output, X
	iny
	inx
	jmp seperate_words_loop
whitespace_found:
	iny
	stz output, X
	inx
	inc num_args
	jmp go_until_next_nspace
	
end_loop:
	stz output, X
	lda #1
	sta r0
	
	ldy num_args
	lda #<output
	ldx #>output
	jsr exec
	cmp #0
	beq exec_error
	
wait_child:	
	sta child_id
wait_child_loop:
	lda child_id
	jsr process_info
	cmp #0
	bne wait_child_loop
	
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