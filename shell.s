CHRIN = $9D00
CHROUT = $9D03

EXEC = $9D06
PROCESS_INFO = $9D09

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
	sta buffer, X
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
    inx
    bne @input_loop
@newline:
    lda #0
    sta buffer, X
	
	lda #$20
	jsr CHROUT
    lda #$d
    jsr CHROUT

    lda #<buffer
    ldx #>buffer
    jsr EXEC
    sta child_pid
@wait_loop:
	brk
	lda child_pid
    jsr PROCESS_INFO
    cmp #0
    bne @wait_loop

    jmp take_input

welcome_message:
    .ascii "CX16 OS SHELL"
    .byte $0d, $00

child_pid:
    .byte 0
buffer:
    .res 80