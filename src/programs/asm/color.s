.include "routines.inc"
.segment "CODE"

ptr0 := $30

init:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	cpy #1
	bne :+
	jmp no_args
	:
	sty argc
		
	ldy #0
@loop:
	lda (ptr0), Y
	beq :+
	iny
	bra @loop
	:
	iny
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	
	ldy #0
	lda (ptr0), Y
	sta first_byte
	iny
	lda (ptr0), Y
	sta second_byte
	
	jsr is_valid_num
	bne :+
	jmp invalid_arg
	:
	lda second_byte
	jsr get_byte
	sta second_byte
	
	lda first_byte
	jsr is_valid_num
	bne :+
	jmp invalid_arg
	:
	lda first_byte
	jsr get_byte
	sta first_byte
	
	; issue special term chars ;
	
	ldy first_byte
	lda color_table, Y
	jsr CHROUT
	
	lda #1
	jsr CHROUT
	
	ldy second_byte
	lda color_table, Y
	jsr CHROUT
	
	lda #$93
	jsr CHROUT ; clear screen
	
	lda #0
	rts
	
is_valid_num:
	cmp #'a'
	bcc :+
	cmp #'f' + 1
	bcs @no
	sec
	sbc #$20
	:
	
	cmp #'0'
	bcc @no
	cmp #'F' + 1
	bcs @no
	cmp #'9' + 1
	bcc @yes
	cmp #'A'
	bcs @yes	
@no:
	lda #0
	rts
@yes:
	lda #1
	rts

get_byte:
	cmp #'a'
	bcc :+
	; carry set
	sbc #$20
	:
	
	cmp #$40
	bcc :+
	; sec
	sbc #'A' - 10
	rts
	:
	sec
	sbc #'0'
	rts
	
invalid_arg:
	lda #<invalid_arg_string
	ldx #>invalid_arg_string
	jsr print_str
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	lda #$27 ; single quote
	jsr CHROUT
	lda #$a
	jsr CHROUT
	
	lda #1
	rts
	
invalid_arg_string:
	.byte "color: invalid operand '", 0

no_args:
	lda #<no_args_string
	ldx #>no_args_string
	jsr print_str
	
	lda #1
	rts
	
no_args_string:
	.byte "color: missing operand", $a, 0

color_table:
	.byte $90, $05, $1C, $9F, $9C, $1E, $1F, $9E
	.byte $81, $95, $96, $97, $98, $99, $9A, $9B

.SEGMENT "BSS"
	
argc:
	.byte 0
first_byte:
	.byte 0
second_byte:
	.byte 0

