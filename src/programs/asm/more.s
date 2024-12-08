.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30
ptr1 := $32

PAGE_DOWN = 2
NEWLINE = $a

init:
	jsr get_args
	stx ptr0 + 1
	sta ptr0
	dey
	sty argc
	
parse_options:
	lda argc
	bne :+
	jmp end_parse_options
	:
	jsr get_next_arg
	
	lda (ptr0)
	cmp #'-'
	beq @check_option
	lda ptr0
	sta input_filename
	lda ptr0 + 1
	sta input_filename + 1
	; bra parse_options
	jmp end_parse_options
@check_option:	
	ldy #1
	lda (ptr0), Y
	; compare to different flag letters
	cmp #'h'
	bne :+
	jmp print_usage
	:
	
@invalid_option:	
	; invalid option
	lda #<invalid_option_str
	ldx #>invalid_option_str
	bra @print_ax_ptr0_newline_exit
@option_requires_argument:
	lda #<opt_requires_arg_str
	ldx #>opt_requires_arg_str
@print_ax_ptr0_newline_exit:
	jsr print_str
	lda ptr0
	ldx ptr0 + 1
	inc A
	bne :+
	inx
	:
	jsr print_str
	lda #NEWLINE
	jsr CHROUT
	lda #1
	rts

get_next_arg:
	dec argc ; decrement argc	
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bra :-
	:
	tya
	sec ; like incrementing .A
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	rts

end_parse_options:
	rep #$10
	.i16
	
	lda input_filename
	ora input_filename + 1
	bne :+
	lda #0
	bra @print_file
	
	lda input_filename
	ldx input_filename + 1
	ldy #'R'
	jsr open_file
	cmp #$FF
	bne :+
	jsr file_error ; if = $FF , jmp to file_error
	lda #1
	rts
	:
@print_file:
	jsr print_file
	lda #0
	rts

print_file:
	sta fd
	lda #<stdin_str
	ldx #>stdin_str
	ldy #'R'
	jsr open_file
	sta keyboard_fd
	
	lda #1
	jsr set_stdin_read_mode
	jsr get_console_info
	lda r0
	sta term_width
	lda r0 + 1
	dec A
	sta term_height
	
	lda #<buff
	sta r0
	lda #>buff
	sta r0 + 1
	
	stz just_print_file
	stz ptr0
	stz ptr0 + 1
	stz ptr1 ; current term x
	stz ptr1 + 1 ; current term y
read_file_loop:
	ldx fd
	jsr fgetc
	cpx #0
	bne @file_out_bytes
	
	ldx just_print_file
	beq :+
	jsr CHROUT
	bra read_file_loop
	:
@got_char:
	ldx ptr0
	sta buff, X
	inx
	stx ptr0
	
	cmp #NEWLINE
	bne @byte_not_newline
	; char is newline
@found_newline_byte:
	ldx ptr0
	stx r1
	lda #1 ; stdout
	jsr write_file
	stz ptr0
	stz ptr0 + 1
	stz ptr1
	lda ptr1 + 1
	inc A
	sta ptr1 + 1
	cmp term_height
	bcc read_file_loop	
	; wait for a enter to be pressed ;
@wait_kbd_loop:
	ldx keyboard_fd
	jsr fgetc
	cpx #0
	bne @key_input_closed
	cmp #PAGE_DOWN
	bne :+
	stz ptr1 + 1
	bra read_file_loop
	:
	cmp #NEWLINE
	beq read_file_loop
	bra @wait_kbd_loop
	
@key_input_closed:
	lda #1
	sta just_print_file
	bra read_file_loop

@byte_not_newline:
	jsr is_printable_char
	beq read_file_loop
	lda ptr1
	inc A
	sta ptr1
	cmp term_width
	bcc read_file_loop
	bra @found_newline_byte
	
@file_out_bytes:
	lda fd
	jsr close_file
	
	rts
	
	
file_error_read:
	tya
	tax
file_error:
	stx err_num
	
	lda fd
	beq @dont_need_close
	jsr close_file
@dont_need_close:
	
	lda #<file_open_error_msg_p1
	ldx #>file_open_error_msg_p1
	jsr PRINT_STR
	
	lda ptr0
	ldx ptr0 + 1
	jsr PRINT_STR
	
	lda #<file_open_error_msg_p2
	ldx #>file_open_error_msg_p2
	jsr PRINT_STR
	
	lda #$01
	xba
	lda #$FD
	tcs
	lda #1
	rts

;
; Returns result in .X & Z flag
;
is_printable_char:
	pha
	and #$7F
	cmp #$20
	pla
	bcs :+
@no:
	ldx #0 ; No
	rts
	:
	cmp #$7F
	beq @no
	ldx #1 ; Yes
	rts

print_usage:
	lda #<@print_usage_txt
	ldx #>@print_usage_txt
	jsr print_str
	lda #0
	rts
@print_usage_txt:
	.byte "Usage: more [OPTION]... [FILE]", NEWLINE
	.byte "", NEWLINE
	.byte "Options", NEWLINE
	.byte "  -h:     show this message and exit", NEWLINE
	.byte "", NEWLINE
	.byte "If no FILE argument is provided, read from stdin", NEWLINE
	.byte "", NEWLINE
	.byte 0

stdin_str:
	.asciiz "#stdin"

; data

keyboard_fd:
	.word 0
fd:
	.word 0
err_num:
	.word 0
argc:
	.word 0

input_filename:
	.word 0

just_print_file:
	.word 0
term_width:
	.word 0
term_height:
	.word 0

invalid_option_str:
	.asciiz "ps: unknown option -- "
opt_requires_arg_str:
	.asciiz "ps: option requires an argument -- "
file_open_error_msg_p1:
	.asciiz "xxd: "
file_open_error_msg_p2:
	.byte ": No such file exists", NEWLINE, 0

.SEGMENT "BSS"

buff:
	.res 256

