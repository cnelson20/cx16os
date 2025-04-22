.include "routines.inc"
.segment "CODE"

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

.macro copy_valid_array addr
	rep #$30
	.a16
	.i16
	lda #256 - 1
	ldx #addr
	ldy #valid_c_table
	mvn #$00, #$00
	sep #$30
	.a8
	.i8
.endmacro

NEWLINE = $0A

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
	
	lda (ptr0)
	cmp #'b'
	bne :+
	ldy #1
	lda (ptr0), Y
	bne :+
	copy_valid_array no_colors_table
	bra @args_loop
	:
	
	lda (ptr0)
	cmp #'c'
	bne :+
	ldy #1
	lda (ptr0), Y
	bne :+
	jsr enable_color_printing
	bra @args_loop
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

enable_color_printing:
	ldy #0
	:
	lda no_colors_table, Y
	eor #1
	ora valid_c_table, Y
	sta valid_c_table, Y
	iny
	bne :-
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
	.byte "Options:", NEWLINE
	.byte "  -b:    print all characters except for color-related control chars", NEWLINE
	.byte "  -c:    allow printing of control chars to change the term color", NEWLINE
	.byte "  -h:    print this message and exit", NEWLINE
	.byte NEWLINE
	.byte "By default, print the contents of stdin, removing", NEWLINE
	.byte "all non-printable characters other than LF and CR", NEWLINE
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

no_colors_table:
	.byte 1							; $0
	.byte 0							; $1: SWAP_COLORS
	.res $5 - $2, 1					; $2 - $4
	.byte 0							; $5: COLOR_WHITE
	.res $1C - $6, 1				; $6 - $1B
	.byte 0							; $1C: COLOR_RED
	.byte 1							; $1D (CURSOR_RIGHT)
	.res $20 - $1E, 0				; $1E - $1F: COLOR_GREEN + COLOR_BLUE
	.res $80 - $20, 1				; $20 - $7F: ascii chars
	.byte 1							; $80 (VERBATIM_MODE)
	.byte 0							; $81: COLOR_ORANGE
	.res $90 - $82, 1				; $82 - $8F
	.byte 0							; $90: COLOR_BLACK
	.res $95 - $91, 1				; $91 - $94
	.res $9D - $95, 0				; $95 - $9C: COLOR_BROWN to COLOR_PURPLE
	.byte 1							; $9D (CURSOR_LEFT)
	.res $A0 - $9E, 0				; $9E - $9F: COLOR_YELLOW + COLOR_CYAN
	.res $100 - $A0, 1				; $A0 - $FF: ext ascii chars
	
fd:
	.byte 0
