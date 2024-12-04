.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

init:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	cpy #2
	bcs :+
	jmp print_no_operands
	:
	cpy #3
	bcs :+
	jmp print_operand_error
	:
	sty argc
	
	stz error_code
	stz no_more_options
	stz file_list_size
	stz file_list_ind
parse_args:
	dec argc
	bne :+
	jmp end_parse_args
	:

get_next_arg:	
	lda (ptr0)	
	beq found_end_word
	inc_word ptr0
	bra get_next_arg
found_end_word:
	inc_word ptr0
	
	lda no_more_options
	bne @not_option
	
	lda (ptr0)
	cmp #'-'
	bne @not_option
	ldy #1
	lda (ptr0), Y
	
	cmp #'h'
	bne :+
	jmp print_usage	
	:
	
	cmp #'-'
	bne :+
	iny
	lda (ptr0), Y
	bne :+
	lda #1
	sta no_more_options
	bra parse_args
	:
	
@not_option:
	ldx file_list_size
	lda ptr0
	sta file_list_lo, X
	lda ptr0 + 1
	sta file_list_hi, X
	inx
	stx file_list_size
	
	jmp parse_args
	
	
end_parse_args:
	; now we can copy file!
	lda #<start_cwd
	sta r0
	lda #>start_cwd
	sta r0 + 1
	lda #<(start_cwd_end - start_cwd)
	sta r1
	lda #>(start_cwd_end - start_cwd)
	sta r1 + 1
	jsr get_pwd
	
	ldy file_list_size
	dey
	lda file_list_hi, Y
	tax
	lda file_list_lo, Y
	jsr chdir
	pha
	
	lda #<start_cwd
	ldx #>start_cwd
	jsr chdir ; cd back
	
	pla
	cmp #0
	beq @target_is_dir
	
	lda file_list_size
	cmp #2 + 1
	bcc :+
	
	pha
	lda #<target_not_dir_error_msg_p1
	ldx #>target_not_dir_error_msg_p1
	jsr print_str
	ply
	dey
	lda file_list_hi, Y
	tax
	lda file_list_lo, Y
	jsr print_str
	lda #<target_not_dir_error_msg_p2
	ldx #>target_not_dir_error_msg_p2
	jsr print_str
	lda #1
	rts
	:
	
	tay
	dey
	lda file_list_hi, Y
	sta r0 + 1
	lda file_list_lo, Y
	sta r0
	dey
	lda file_list_hi, Y
	sta r1 + 1
	tax
	lda file_list_lo, Y
	sta r1
	ldy #0
	jsr open_file
	pha
	jsr close_file
	pla
	cmp #$FF
	bne :+
	ply
	lda r1
	ldx r1 + 1
	jsr source_file_doesnt_exist_err
	bra @exit
	:
	
	jsr copy_file
	cmp #0
	beq @exit
	jsr other_copy_err
@exit:
	lda error_code
	rts

@target_is_dir:
	stz r2
	stz r3
	lda #<start_cwd
	sta r0
	lda #>start_cwd
	sta r0 + 1
	
	ldy file_list_size
	dey
	lda file_list_lo, Y
	sta r1
	lda file_list_hi, Y
	sta r1 + 1
	
	lda #>(start_cwd_end - start_cwd)
	tax
	lda #<(start_cwd_end - start_cwd)
	jsr memmove_extmem
	
	lda #<start_cwd
	sta r0
	lda #>start_cwd
	sta r0 + 1
	ldy #0
	:
	lda (r0), Y
	beq :+
	iny
	bne :-
	:
	dey
	
	lda (r0), Y ; if last char != /, add it to the end
	iny
	cmp #'/'
	beq :+
	lda #'/'
	sta (r0), Y
	iny
	lda #0
	sta (r0), Y
	:
	
	dec file_list_size
	dec file_list_size
@copy_loop:
	phy
	ldy file_list_size
	lda file_list_hi, Y
	tax
	lda file_list_lo, Y
	ldy #0
	pha
	phx
	jsr open_file
	pha
	jsr close_file
	pla
	cmp #$FF
	bne :+
	plx
	pla
	ply
	jsr source_file_doesnt_exist_err
	jmp @end_copy_loop_iter
	:
	pla
	sta ptr1 + 1
	sta r1 + 1
	pla
	sta ptr1
	sta r1
	jsr set_ptr1_basename
	ply
	phy
@inner_loop:
	lda (ptr1)
	sta (r0), Y
	beq @end_inner_loop
	iny
	inc_word ptr1
	bra @inner_loop
@end_inner_loop:
	jsr copy_file
	ply
	cmp #0
	bne @copy_error
	
@end_copy_loop_iter:
	dec file_list_size
	bpl @copy_loop
	
	lda error_code
	rts
@copy_error:
	jsr other_copy_err
	jmp @end_copy_loop_iter

source_file_doesnt_exist_err:
	pha
	phx
	lda #<@source_file_err_p1
	ldx #>@source_file_err_p1
	jsr print_str
	plx
	pla
	jsr print_str
	lda #<@source_file_err_p2
	ldx #>@source_file_err_p2
	jsr print_str
	
	lda #1
	sta error_code
	rts

@source_file_err_p1:
	.asciiz "cp: source file '"
@source_file_err_p2:
	.byte "' does not exist", $d, 0

other_copy_err:
	lda #<@other_copy_err_p1
	ldx #>@other_copy_err_p1
	jsr print_str
	lda r1
	ldx r1 + 1
	jsr print_str
	lda #<@other_copy_err_p2
	ldx #>@other_copy_err_p2
	jsr print_str
	lda r0
	ldx r0 + 1
	jsr print_str
	lda #$27
	jsr CHROUT
	lda #$d ; newline
	jsr CHROUT
	
	lda #1
	sta error_code
	rts
@other_copy_err_p1:
	.asciiz "cp: unable to copy file '"
@other_copy_err_p2:
	.asciiz "' to path '"

set_ptr1_basename:
	ldy #0
	:
	lda (ptr1), Y
	beq :+
	iny
	bne :-
	:
	cpy #2
	bcc :+ ; won't have a basename if its length is 0 or 1 chars
	dey
	lda (ptr1), Y
	bne :++ ; if last char is '/', is a dir and we can just exit early
	:
	rts
	:
@loop:
	lda (ptr1), Y
	cmp #'/'
	beq @found_slash

	cpy #0
	beq @end_loop
	dey
	bra @loop
@found_slash:
	iny
@end_loop:
	tya
	clc
	adc ptr1
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	rts

print_usage:
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	
	lda #0
	rts

usage_str:
	.byte "Usage: cp [OPTION]... [-T] SOURCE DEST", $d
	.byte "  or:  cp [OPTION]... SOURCE... DIRECTORY", $d
	.byte "Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY.", $d
	.byte $d
	.byte "Options:", $d
	.byte "  -h: display this message", $d
	.byte "  --: indicate all following arguments are files and not options", $d
	.byte $d
	.byte 0

print_no_operands:
	lda #<no_operands_error_msg
	ldx #>no_operands_error_msg
	jsr print_str
	
	lda #1
	rts
	
no_operands_error_msg:
	.byte "cp: missing file operand", $d, 0

target_not_dir_error_msg_p1:
	.asciiz "cp: target '"
target_not_dir_error_msg_p2:
	.byte "' is not a directory", $d, 0

print_operand_error:
	lda #<error_msg
	ldx #>error_msg
	jsr print_str
	
@loop:	
	lda (ptr0)
	beq @end_loop
	inc_word ptr0
	bra @loop
@end_loop:
	inc_word ptr0
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	lda #<error_msg_p2
	ldx #>error_msg_p2
	jsr print_str
	
	lda #1
	rts
	
error_msg:	
.asciiz "cp: missing destination file operand after '"
error_msg_p2:
	.byte "'", $d, 0

.segment "BSS"

no_more_options:
	.byte 0
error_code:
	.byte 0

argc:
	.byte 0
file_list_size:
	.byte 0
file_list_ind:
	.byte 0

file_list_lo:
	.res 128
file_list_hi:
	.res 128

start_cwd:
	.res 256
start_cwd_end: