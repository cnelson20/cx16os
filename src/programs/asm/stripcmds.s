.include "routines.inc"
.segment "CODE"

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

NEWLINE = $0A

r0 = $02
r1 = $04
r2 = $06
r3 = $08

ptr0 := $30
ptr1 := $32
ptr2 := $34

init:
	jsr get_args
	sty ptr1
	sta ptr0
	stx ptr0 + 1

@args_loop:	
	dec ptr1
	beq @no_args
	jsr get_next_arg
	
	lda (ptr0)
	cmp #'-'
	bne @args_loop
	inc_word ptr0

	lda (ptr0)
	cmp #'h'
	bne :+
	ldy #1
	lda (ptr0), Y
	bne :+
	jmp print_usage
	:

	bra @args_loop
@no_args:
	
	lda #0
	sta fd
@loop:	
	ldx fd
	jsr fgetc
	cpx #0
	bne end_of_file
	tax
	lda valid_c_table, X
	beq @loop
	txa
	jsr CHROUT
	bra @loop
end_of_file:
	lda #0
	rts

get_next_arg:
	; loop until (ptr0) is \0
@loop:
	lda (ptr0)
	beq @end_loop
	inc_word ptr0
	bra @loop
@end_loop:
	inc_word ptr0
	rts

print_usage:
	lda #<@usage_str
	ldx #>@usage_str
	jsr print_str
	lda #0
	rts

@usage_str:
	.byte "Usage:", NEWLINE
	.byte "  stripcmds [OPTIONS]", NEWLINE
	.byte NEWLINE
	.byte "Print the contents of stdin, removing all", NEWLINE
	.byte "non-printable characters other than LF and CR", NEWLINE
	.byte NEWLINE
	.byte "Options:", NEWLINE
	.byte "  -h:    print this message and exit", NEWLINE
	.byte NEWLINE
	.byte 0

valid_c_table:
	.byte 0, 0, 0, 0, 0, 0, 0, 0 	; $00 - $07
	.byte 0, 0, 1, 0, 0, 1, 0, 0 	; $08 - $0F
	.res $10, 0						; $10 - $1F
	.res $5F, 1						; $20 - $7E
	.byte 0							; $7F (DEL)
	.res $20, 0						; $80 - $9F
	.res $100 - $A0, 1				; $A0 - $FF

fd:
	.byte 0
