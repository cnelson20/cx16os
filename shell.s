CHRIN = $9D00
CHROUT = $9D03

EXEC = $9D06
PROCESS_STATUS = $9D09

PRINT_STR = $9D12

UNDERSCORE = $5F
LEFT_CURSOR = $9D

main:
    lda #<welcome_message
	ldx #>welcome_message
	jsr PRINT_STR

take_input:
	lda #$24 ; $
	jsr CHROUT
	lda #$20
	jsr CHROUT
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
    ldx #0
@input_loop:
    phx
    jsr CHRIN
    plx
	cmp #0
	beq @input_loop
	cmp #$d
    beq @newline
	tay
	and #$7F
	cmp #$20
	bcs @type_key
	cmp #$19
	bne @input_loop
	cpx #0
	beq @left_side_line
	dex
	lda #$20
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
@left_side_line:
	jmp @input_loop
	
@type_key:
    jsr CHROUT
	tya
	cmp #$A0
	bne @dont_fix_reverse_space
	lda #$20
@dont_fix_reverse_space:	
	sta buffer, X
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
    inx
    bne @input_loop
@newline:
	
	lda #$20
	jsr CHROUT
    lda #$d
    jsr CHROUT ; print return

	cpx #0
	bne @not_empty_line
	jmp end_run_command
@not_empty_line:
	stz buffer, X
	stx buffer_strlength

parse_input:
	ldx #0
	ldy #1
@space_loop:
	lda buffer, X
	beq @end_space_loop
	cmp #$20
	bne @not_space
	stz buffer, X
	
	inx
	lda was_space_last
	stx was_space_last
	bne @space_loop
	iny	
	jmp @space_loop
@not_space:
	stz was_space_last
	inx 
	bne @space_loop
@end_space_loop:
	
; check for & as last arg	
	ldx buffer_strlength
	dex
	lda buffer, X
	cmp #$26 ; ampersand
	bne @will_wait_child
	dex 
	lda buffer, X
	cmp #0
	bne @will_wait_child
	
	stz wait_for_child
	dey ; decrement number of args by one, removing & from args list
	jmp run_child
	
@will_wait_child:
	lda #1
	sta wait_for_child
run_child:
	
	phy

    lda #<buffer
    ldx #>buffer
	ply ; num args
    jsr EXEC
	cmp #0
	beq @exec_error ; if pid = 0 that means error
    sta child_pid
	
	lda wait_for_child
	beq end_run_command ; if not waiting for child, jump to key clear check
@wait_loop:
	;stp
	wai
	lda child_pid
    jsr PROCESS_STATUS
    cmp #0
    bne @wait_loop
	jmp end_run_command
	
@exec_error:
	lda #<exec_error_message_p1
	ldx #>exec_error_message_p1
	jsr PRINT_STR
	
	lda #<buffer
	ldx #>buffer
	jsr PRINT_STR
	
	lda #<exec_error_message_p2
	ldx #>exec_error_message_p2
	jsr PRINT_STR
	
	jmp end_run_command

end_run_command:	
    jmp take_input

was_space_last:
	.byte 0

exec_error_message_p1:
	.asciiz "ERROR IN EXEC '"
exec_error_message_p2:
	.ascii "'"
	.byte $0d, $00

welcome_message:
    .ascii "CX16 OS SHELL"
    .byte $0d, $00


child_pid:
    .byte 0
wait_for_child:
	.byte 0
	
buffer:
    .res 80
buffer_strlength:
	.byte 0