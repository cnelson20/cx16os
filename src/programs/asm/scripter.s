.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30

init:
	jsr get_args
	stx ptr0 + 1
	sta ptr0

	sty argc
	
	rep #$10
	.i16

parse_options:
	


	
main:
	lda #>input_file_ptr

;
; strlen
;
strlen:
	phx
	ldy #0
	:
	lda $00, X
	beq :+
	pla
	iny
	inx
	bne :-
	:
	tya
	txy
	plx
	rts

;
; print usage of scripter
;
print_usage:
	lda #<usage_string
	ldx #>usage_string
	jsr print_str
	
	lda #1
	rts
	
	
fd:
	.byte 0
err_num:
	.byte 0
argc:
	.byte 0

echo_commands:

input_file_ptr:
	.word 0

error_msg_p1:
	.asciiz "Error opening file '"

error_msg_p2:
	.asciiz "', code #:"

usage_string:
	.byte "Usage: cp [options] source_file", $d
	.byte "Run a scripter language file", $d
	.byte 0

.SEGMENT "BSS"

buff:
	.res 128
