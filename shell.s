CHRIN = $9D00
CHROUT = $9D03

EXEC = $9D06
PROCESS_INFO = $9D09
ALLOC_BANK = $9D0B

UNDERSCORE = $5F
LEFT_CURSOR = $9D

main:
    ldx #0
@welcome_loop:
    lda welcome_message, X
    beq @welcome_loop_end
    jsr CHROUT
    inx
    bne @welcome_loop
@welcome_loop_end:

take_input:
	lda #$24
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
	
	lda #$20
	jsr CHROUT
    lda #$d
    jsr CHROUT

    lda #<buffer
    ldx #>buffer
	ply ; num args
    jsr EXEC
    sta child_pid
	
	lda wait_for_child
	bne @wait_loop
	jmp take_input
@wait_loop:
	brk
	lda child_pid
    jsr PROCESS_INFO
    cmp #0
    bne @wait_loop

    jmp take_input

was_space_last:
	.byte 0

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