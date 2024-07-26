.include "routines.inc"
.segment "CODE"

r0 = $02
r1 = $04
r2 = $06

ptr0 = $30
ptr1 = $32
ptr2 = $34
ptr3 = $36

CMD_MAX_SIZE = 128

UNDERSCORE = $5F
LEFT_CURSOR = $9D
DOLLAR_SIGN = $24
SPACE = $20

COLOR_WHITE = 5
COLOR_GREEN = $1E
COLOR_BLUE = $1F

MODE_R = $52
MODE_W = $57

AMPERSAND = $26
GT = $3E
LT = $3C

init:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	sty argc
prog_args_loop:
	jsr get_next_arg
	cmp #0
	beq :+
	jmp welcome
	:

	lda (ptr0)
	cmp #'-'
	bne prog_args_error

	ldy #1
	lda (ptr0), Y
	cmp #'p' ; persist
	bne :+
	lda #1
	sta stay_alive_after_input_eof
	bra prog_args_loop
	:
	cmp #'s' ; skip
	bne :+
	stz print_startup_msg_flag
	bra prog_args_loop
	:
	cmp #'c' ; command
	bne :+
	jsr get_next_arg
	cmp #0
	bne prog_no_args_error
	lda ptr0
	sta first_command_addr
	lda ptr0 + 1
	sta first_command_addr + 1
	stz print_startup_msg_flag
	bra prog_args_loop
	:

	jmp prog_args_loop
prog_no_args_error:
	rep #$20
	dec ptr0
	sep #$20
	:
	lda (ptr0)
	bne :+
	rep #$20
	dec ptr0
	sep #$20
	bra :-
	:
	lda (ptr0)
	beq :+
	rep #$20
	dec ptr0
	sep #$20
	bra :-
	:
	rep #$20
	inc ptr0
	sep #$20
	lda #<no_prog_args_error_str
	ldx #>no_prog_args_error_str
	jsr print_str
prog_args_error:
	lda #<prog_args_error_str
	ldx #>prog_args_error_str
	jsr print_str

	lda #'''
	jsr CHROUT
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str

	lda #'''
	jsr CHROUT
	lda #$d
	jsr CHROUT

	lda #0
	rts
no_prog_args_error_str:
	.asciiz "no command provided: "
prog_args_error_str:
	.asciiz "invalid argument"

shrc_filename:
	.asciiz ".shrc"

welcome:
	lda print_startup_msg_flag
	beq :+
	lda #<welcome_string
	ldx #>welcome_string
	jsr print_str
	:

	stz new_stdin_fileno
	stz new_stdout_fileno

	lda curr_running_script
	bne new_line

	; open .shrc ? ;
	ldy #0
	lda #<shrc_filename
	ldx #>shrc_filename
	jsr open_file
	cmp #$FF
	beq new_line ; not successfully opened, that's fine

	ldx #0 ; move to stdin
	jsr move_fd

	lda #1
	sta curr_running_script

new_line:
	; close these files in case got through
	lda exit_after_exec
	beq :++
	lda curr_running_script
	ora stay_alive_after_input_eof
	bne :+
	jmp exit_shell
	:
	lda #0
	jsr close_file
	stz exit_after_exec
	stz curr_running_script
	stz stay_alive_after_input_eof
	:

	lda first_command_addr + 1
	bne skip_print_prompt
	lda curr_running_script
	bne skip_print_prompt

	lda new_stdin_fileno
	beq :+
	jsr close_file
	:
	lda new_stdout_fileno
	beq :+
	jsr close_file
	:
	
	lda #COLOR_GREEN
	jsr CHROUT
	lda #<stdin_filename
	sta r0
	lda #>stdin_filename
	sta r0 + 1
	lda #MAX_FILELEN
	sta r1
	stz r1 + 1
	jsr get_pwd
	lda #<stdin_filename
	ldx #>stdin_filename
	jsr print_str

	lda #COLOR_WHITE ; white color
	jsr CHROUT
	lda #DOLLAR_SIGN ; '$'
	jsr CHROUT
	lda #$20 ; space
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

skip_print_prompt:
	lda first_command_addr + 1
	beq @not_auto_command
	
	sta ptr0 + 1
	lda first_command_addr
	sta ptr0
	ldy #0
	:
	lda (ptr0), Y
	sta input, Y
	beq :+
	iny
	bra :-
	:
	lda #1
	sta exit_after_exec
	jmp not_empty_line
@not_auto_command:
	lda #0
	jsr send_byte_chrout_hook

	stz input
	ldx #0	
wait_for_input:
	phx
	ldx #0
	jsr fgetc
	txy
	plx
	cpy #0 ; check for end of input
	beq @not_end_of_file_input
	lda #1
	sta exit_after_exec
	cpx #0 ; is buffer empty?
	bne :+
	jmp new_line
	:
	lda #$0D ; if eof has been reached, exec what's in buffer (unless buffer is empty)
@not_end_of_file_input:
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
	
	; if char < $20 and not one of above chars, ignore
	cmp #$20
	bcc wait_for_input
	cmp #$A1
	bcs :+
	cmp #$7F
	bcc :+
	jmp wait_for_input
	:
char_entered:
	sta input, X
	inx
	
	pha
	lda curr_running_script
	cmp #1
	pla
	bcs :+

	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	lda #0
	phx
	jsr send_byte_chrout_hook
	plx

	:	
	jmp wait_for_input
	
backspace:
	cpx #0
	bne backspace_not_empty
	jmp wait_for_input
backspace_not_empty:
	dex
	lda #LEFT_CURSOR
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #$20
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	lda #0
	phx
	jsr send_byte_chrout_hook
	plx
	
	jmp wait_for_input

command_entered:
	lda curr_running_script
	bne :+

	lda #$20
	jsr CHROUT
	lda #$0d
	jsr CHROUT
	
	:
	stz in_quotes
	stz input, X	
	cpx #0
	bne not_empty_line
	jmp new_line
not_empty_line:
	stz num_args
	ldy #0 ; index in input
	ldx #0 ; index in output
go_until_next_nspace:
	lda input, Y
	beq end_loop
	cmp #$21
	bcs nspace_found
	iny
	jmp go_until_next_nspace
nspace_found:
	phy
	ldy num_args
	txa
	sta args_offset_arr, Y
	ply
	
	inc num_args
seperate_words_loop:
	lda input, Y
	beq end_loop
	cmp #$22 ; quotes
	bne char_not_quote
	; if in quotes, toggle quoted mode and dont include in command 
	lda in_quotes
	eor #$FF
	sta in_quotes
	iny
	jmp seperate_words_loop
char_not_quote:
	stx r1
	stz r2
	ldx in_quotes
	beq not_in_quotes
	sta r2
not_in_quotes:
	ldx r1
	cmp r2
	beq dont_check_whitespace
	cmp #$21
	bcc whitespace_found
dont_check_whitespace:
	sta output, X
	iny
	inx
	jmp seperate_words_loop
whitespace_found:
	iny
	stz output, X
	inx
	jmp go_until_next_nspace
end_loop:
	stz output, X
	stx command_length
	
	lda num_args
	bne narg_not_0
	jmp new_line
narg_not_0:
	lda #1
	sta do_wait_child
	sta r0 ; by default, new process is active 
	
	ldx num_args
	stz args_offset_arr, X
	stz curr_arg
	; by default prog stdin and stdout are normal ;
	stz stdin_filename
	stz stdout_filename
	; go through arguments to check for redirects / &
@parse_args_loop:	
	ldx curr_arg
	cpx num_args
	bcc :+
	jmp @end_parse_args_loop ; if carry set, jump
	:
	
	lda args_offset_arr, X
	tax
	lda output, X
	
	cmp #AMPERSAND
	bne @not_ampersand
	
	inx
	lda output, X
	bne @parse_loop_end_cmp
	; this args = "&" ;
	stz do_wait_child
	ldx #1
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_ampersand:
	cmp #LT
	bne @not_lt
	inx
	lda output, X
	bne @parse_loop_end_cmp
	; this is "<" ;
	ldx curr_arg
	inx
	lda args_offset_arr, X
	tax
	ldy #0
@stdin_copy_loop:
	lda output, X
	sta stdin_filename, Y
	beq @end_stdin_copy_loop
	inx
	iny
	jmp @stdin_copy_loop
@end_stdin_copy_loop:	
	ldx #2
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_lt:
	cmp #GT
	bne @not_gt
	inx
	lda output, X
	bne @parse_loop_end_cmp
	
	; this is ">" ;
	ldx curr_arg
	inx
	lda args_offset_arr, X
	tax
	ldy #0
@stdout_copy_loop:
	lda output, X
	sta stdout_filename, Y
	beq @end_stdout_copy_loop
	inx
	iny
	jmp @stdout_copy_loop
@end_stdout_copy_loop:	
	ldx #2
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_gt:	
	cmp #'$'
	bne @not_dsign
		
	jsr parse_env_var	
	inc curr_arg
	jmp @parse_args_loop
@not_dsign:

@parse_loop_end_cmp:	
	inc curr_arg
	jmp @parse_args_loop
	
@end_parse_args_loop:
	ldy num_args
	bne @nzero_args
	jmp new_line
@nzero_args:
	ldx command_length
@zero_out:
	stz output, X
	inx 
	cpx #CMD_MAX_SIZE
	bcc @zero_out
	jmp narg_not_0_amp

	
copy_back_args:
	; X is num of args to skip ;
	
	; subtract X many args from num_args ;
	lda num_args
	stx ptr0
	sec
	sbc ptr0
	sta num_args
	
	lda curr_arg
	cmp num_args
	bcc @not_over_args
	; curr_arg is not even in output ;
	tay
	lda args_offset_arr, Y
	dec A
	sta command_length
	lda #0
	sta args_offset_arr, Y
	rts
	
@not_over_args:
	txa
	clc
	adc curr_arg
	tay
	lda args_offset_arr, Y
	tax ; x holds offset for src
	ldy curr_arg
	lda args_offset_arr, Y
	tay ; y holds offset for dst 
	
	; move data if necessary ;
@copy_back_loop:
	cpx command_length
	bcs @end_copy_back_loop
	
	lda output, X
	sta output, Y
	
	inx
	iny
	jmp @copy_back_loop
@end_copy_back_loop:	
	lda #0
	sta output, Y
	sty command_length
	rts

parse_env_var:
	ldx curr_arg
	lda args_offset_arr, X
	
	sec ; + 1 to skip the $
	adc #<output
	sta ptr2
	lda #>output
	adc #0
	sta ptr2 + 1
	
	; compare against different strings
	lda #<question_str
	sta ptr3
	lda #>question_str
	sta ptr3 + 1
	jsr strcmp
	bne @not_q_mark

	lda last_return_val
	bra @repl_arg_hex_num
	
@not_q_mark:
	lda #<excl_str
	sta ptr3
	lda #>excl_str
	sta ptr3 + 1
	jsr strcmp
	bne @not_excl_mark

	; pid of last process put into background
	lda last_background_pid
	bra @repl_arg_hex_num

@not_excl_mark:
	lda #<dollar_str
	sta ptr3
	lda #>dollar_str
	sta ptr3 + 1
	jsr strcmp
	bne @not_self_pid

	; pid of last process put into background
	lda $00
	bra @repl_arg_hex_num
@not_self_pid:

	; look in extmem for env vars
	jmp search_env_vars

@repl_arg_hex_num:
	pha ; push val
	lda #4
	jsr shift_output
	
	ldy curr_arg
	lda args_offset_arr, Y
	tay
	lda #'$'
	sta output, Y
	iny
	pla ; pull val back
	phy
	jsr GET_HEX_NUM
	ply
	sta output, Y
	iny
	txa
	sta output, Y
	iny
	lda #0
	sta output, Y	
	rts

search_env_vars:
	lda env_extmem_bank ; is the bank initialized?
	bne :+
	jmp @out_slots
	:

	lda #<$A000
	sta ptr2
	lda #>$A000
	sta ptr2 + 1

	lda env_extmem_bank
	jsr set_extmem_rbank
	lda #<ptr2
	jsr set_extmem_rptr

	ldy #0
	ldx #$20
@search_loop:
	jsr readf_byte_extmem_y
	cmp #0
	bne @found

@cont_search_loop:
	inc ptr2 + 1
	dex
	bne @search_loop
	jmp @out_slots

@found:
	phx

	ldy curr_arg
	lda args_offset_arr, Y
	inc A
	tax
	ldy #0
	:
	jsr readf_byte_extmem_y
	cmp output, X
	bne :+
	lda output, X
	beq :+
	iny
	inx
	bpl :-
	lda #1 ; always unequal if > $7F (shouldn't happen)
	:
	plx
	ldy #0
	cmp #0
	bne @cont_search_loop

	lda #$80
	sta ptr2

	ldy #0
	:
	jsr readf_byte_extmem_y
	cmp #0
	beq :+
	iny
	bpl :-
	:
	iny

	lda ptr2 + 1
	pha

	tya
	jsr shift_output

	lda #$80
	sta ptr2
	pla
	sta ptr2 + 1

	ldy curr_arg
	lda args_offset_arr, Y
	tax
	ldy #0
	:
	jsr readf_byte_extmem_y
	sta output, X
	cmp #0
	beq :+
	inx
	iny
	bne :-
	:

	rts
@out_slots:
	; replace $whatever with empty string
	lda #1
	jsr shift_output
	ldy curr_arg
	lda args_offset_arr, Y
	tay
	lda #0
	sta output, Y
	rts
	
question_str:
	.asciiz "?"
excl_str:
	.asciiz "!"
dollar_str:
	.asciiz "$"

shift_output:
	ldy curr_arg
	iny
	cpy num_args
	dey
	bcc @not_last_arg
	
	clc
	adc	args_offset_arr, Y
	sta command_length
	rts
	
@not_last_arg:
	clc
	adc args_offset_arr, Y
	sta ptr2
	stz ptr2 + 1
	iny
	lda args_offset_arr, Y
	sta ptr3
	stz ptr3 + 1
	cmp ptr2
	beq @dont_move
	bcs @move_back
@move_forward:
	; ptr2 > ptr3
	lda command_length
	sec
	sbc ptr3
	
	rep #$30
	.a16
	.i16
	and #$00FF
	pha
	
	clc
	adc ptr3
	adc #output
	tax
	
	pla
	pha
	clc
	adc ptr2
	adc #output
	tay
	
	pla
	mvp #$00, #$00
	
	lda ptr2
	sec
	sbc ptr3
	clc
	adc command_length
	sta command_length
	
	sep #$30
	.a8
	.i8
	rts

@move_back:
	; ptr3 > ptr2
	lda command_length
	sec
	sbc ptr3
	
	rep #$30
	.a16
	.i16
	and #$00FF
	pha 
	
	lda ptr3
	clc
	adc #output
	tax
	
	lda ptr2
	clc
	adc #output
	tay	
	
	pla
	mvn #$00, #$00
	
	lda ptr3
	sec
	sbc ptr2
	sta ptr3
	lda command_length
	sec
	sbc ptr3
	sta command_length
	
	sep #$30
	.a8
	.i8
@dont_move:
	rts
	
	
narg_not_0_amp:
	jsr check_special_cmds
	beq :+
	jmp new_line
	:

	jsr setup_prog_redirects
	ldy num_args
	lda new_stdin_fileno
	sta r2
	lda new_stdout_fileno
	sta r2 + 1
	lda do_wait_child
	sta r0
	lda #<output
	ldx #>output
	jsr exec
	cmp #0
	beq exec_error
	
	stz new_stdin_fileno
	stz new_stdout_fileno
	
	sta child_id

	lda do_wait_child
	bne wait_child

	lda child_id
	sta last_background_pid

	jmp new_line
wait_child:	
	lda child_id
	jsr wait_process
	
	sta last_return_val
	jmp new_line
	
exec_error:
	lda new_stdin_fileno
	beq @new_stdin_file_zero
	jsr close_file
	stz new_stdin_fileno
@new_stdin_file_zero:
	lda new_stdout_fileno
	beq @new_stdout_file_zero
	jsr close_file
	stz new_stdout_fileno
@new_stdout_file_zero:
	
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

setup_prog_redirects:
	stz new_stdin_fileno
	stz new_stdout_fileno
	
	lda stdin_filename
	beq @no_stdin
	
	lda #<stdin_filename
	ldx #>stdin_filename
	ldy #MODE_R
	jsr open_file
	cmp #$FF
	beq @r_open_fail
	sta new_stdin_fileno	
@no_stdin:
	lda stdout_filename
	beq @no_stdout
	
	lda #<stdout_filename
	ldx #>stdout_filename
	ldy #MODE_W
	jsr open_file
	cmp #$FF
	beq @w_open_fail
	sta new_stdout_fileno	
@no_stdout:
	rts

@r_open_fail:
	stx new_stdin_fileno
	lda #<open_error_p1
	ldx #>open_error_p1
	jsr print_str
	lda #<stdin_filename
	ldx #>stdin_filename
	jsr print_str
	lda #<open_error_p2
	ldx #>open_error_p2
	jsr print_str
	lda new_stdin_fileno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #$d
	jsr CHROUT
	jmp new_line

@w_open_fail:
	stx new_stdout_fileno
	lda #<open_error_p1
	ldx #>open_error_p1
	jsr print_str
	lda #<stdout_filename
	ldx #>stdout_filename
	jsr print_str
	lda #<open_error_p2
	ldx #>open_error_p2
	jsr print_str
	lda new_stdout_fileno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #$d
	jsr CHROUT
	jmp new_line

; returns non-zero in .A if a special cmd was encountered
check_special_cmds:
	; check for cd ;
	lda #<string_cd
	ldx #>string_cd
	jsr cmd_cmp
	bne @not_cd
	
	ldx #1
	lda args_offset_arr, X
	clc 
	adc #<output
	tay
	lda #>output
	adc #0
	tax
	tya
	
	jsr chdir
	
	lda #1
	rts
@not_cd:

	lda #<string_setenv
	ldx #>string_setenv
	jsr cmd_cmp
	bne @not_setenv

	jsr set_env_var

	lda #1
	rts
@not_setenv:

	lda #<string_exit
	ldx #>string_exit
	jsr cmd_cmp
	bne @not_exit

	lda #0
	jmp exit_shell
@not_exit:

	lda #<string_source
	ldx #>string_source
	jsr cmd_cmp
	bne @not_source

	jsr open_shell_file

	lda #1
	rts
@not_source:
	lda #<string_detach
	ldx #>string_detach
	jsr cmd_cmp
	bne @not_detach

	lda #1 ; make shell active option
	jsr detach_self

	lda #1
	rts
@not_detach:

	lda #0
	rts

cmd_cmp:
	sta ptr2
	stx ptr2 + 1
	
	lda #<output
	sta ptr3
	lda #>output
	sta ptr3 + 1
strcmp:		
	ldy #0
	:
	sec
	lda (ptr2), Y
	sbc (ptr3), Y
	bne @ex ; unequal
	lda (ptr3), Y
	beq @ex ; equal
	iny
	bra :-
		
	rts
@ex:	
	rts

exit_shell:
	sta ptr0
	lda #>$01FD
	xba
	lda #<$01FD
	tcs
	lda ptr0
	rts

set_env_var:
	lda num_args
	cmp #3 ; setenv [name] [value]
	bcc @too_few_args

	ldy args_offset_arr + 1
	lda output, Y
	bne :+ ; Not empty string

@too_few_args:
	lda #<set_env_err_string
	ldx #>set_env_err_string
	jsr print_str
	rts

	:

	lda env_extmem_bank
	bne @already_have_bank
	jsr res_extmem_bank
	sta env_extmem_bank

	lda env_extmem_bank
	jsr set_extmem_wbank

	lda #<ptr2
	jsr set_extmem_wptr

	lda #<$A000
	sta ptr2
	lda #>$A000
	sta ptr2 + 1
	lda #0
	ldx #$20
	ldy #0
	:
	jsr writef_byte_extmem_y
	inc ptr2 + 1
	dex
	bne :- ; zero out $A000, $A100, $A200 ...
@already_have_bank:
	lda env_extmem_bank
	jsr set_extmem_rbank

	lda #<ptr2
	jsr set_extmem_rptr

	lda #<$A000
	sta ptr2
	lda #>$A000
	sta ptr2 + 1
	ldx #$20
	ldy #0
@find_space_loop:
	jsr readf_byte_extmem_y
	cmp #0
	beq @found_space

	; compare name to this entry in tbl
	; .Y = 0 already
	ldx args_offset_arr + 1
	:
	jsr readf_byte_extmem_y
	cmp output, X
	bne :+ ; branch out if unequal
	lda output, X
	beq :+ ; branch out if end of string (equal)
	inx
	iny
	bra :-
	:
	beq @found_space

	inc ptr2 + 1
	dex
	bne @find_space_loop

	lda #<set_env_out_space
	ldx #>set_env_out_space
	jsr print_str
	rts

@found_space:
	lda env_extmem_bank
	jsr set_extmem_wbank

	lda #<ptr2
	jsr set_extmem_wptr

	; write name to extmem
	lda args_offset_arr + 1
	clc
	adc #<output
	sta ptr3
	lda #>output
	adc #0
	sta ptr3 + 1

	ldy #0
	:
	lda (ptr3), Y
	jsr writef_byte_extmem_y
	cmp #0
	beq :+
	iny
	bpl :-
	:

	; write value to extmem
	lda #$80
	sta ptr2

	lda args_offset_arr + 2
	clc
	adc #<output
	sta ptr3
	lda #>output
	adc #0
	sta ptr3 + 1

	ldy #0
	:
	lda (ptr3), Y
	jsr writef_byte_extmem_y
	cmp #0
	beq :+
	iny
	bpl :-
	:

	rts

open_shell_file:
	lda curr_running_script
	beq :+
	lda #<source_inception_str
	ldx #>source_inception_str
	jsr print_str
	rts
	:

	lda num_args
	cmp #2
	bcs :+

	lda #<source_err_string
	ldx #>source_err_string
	jmp print_str ; print and return
	:

	ldy #1
	lda args_offset_arr, Y
	clc
	adc #<output
	pha
	lda #>output
	adc #0
	tax
	pla

	ldy #0
	pha
	phx
	jsr open_file
	cmp #$FF
	beq @open_error

	ldx #0 ; move to stdin
	jsr move_fd
	ldx #$FF
	cmp #0
	bne @open_error

	plx
	plx ; pull two bytes off stack (pha & phx)

	lda #1
	sta curr_running_script
	rts

@open_error:
	stx ptr2

	lda #<open_error_p1
	ldx #>open_error_p1
	jsr print_str

	plx
	pla
	jsr print_str

	lda #<open_error_p2
	ldx #>open_error_p2
	jsr print_str

	lda #'$'
	jsr CHROUT
	lda ptr2
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT

	lda #$d
	jmp CHROUT
	
get_next_arg:
	dec argc
	bne :+
	lda #$FF ; out of args
	rts
	:

	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bra :-
	: ; \0 found
	
	:
	lda (ptr0), Y
	bne :+
	iny
	bra :-
	:
	
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	
	lda #0
	rts

;
; Error & intro messages
;
welcome_string:
	.byte "Commander X16 OS Shell"
	.byte $0d, $00
exec_error_p1_message:
	.asciiz "Error in exec '"
exec_error_p2_message:
	.byte "'"
	.byte $0d, $00

source_err_string:
	.byte "source: filename argument required"
	.byte $d, 0
source_inception_str:
	.byte "source: no sourception allowed"
	.byte $d, 0

set_env_err_string:
	.byte "setenv: need name and value argument"
	.byte $d, 0
set_env_out_space:
	.byte "setenv: no memory left for variables"
	.byte $d, 0

open_error_p1:
	.asciiz "Error opening file '"

open_error_p2:
	.asciiz "', code #:"

; special cmd strings
string_cd:
	.asciiz "cd"
string_exit:
	.asciiz "exit"
string_setenv:
	.asciiz "setenv"
string_source:
	.asciiz "source"
string_detach:
	.asciiz "detach"

; program vars 

in_quotes:
	.byte 0
do_wait_child:
	.byte 0
last_return_val:
	.byte 0
last_background_pid:
	.byte 0
env_extmem_bank:
	.byte 0
num_args:
	.byte 0
child_id:
	.byte 0
input:
	.res CMD_MAX_SIZE, 0
output:
	.res CMD_MAX_SIZE, 0
command_length:
	.byte 0
curr_arg:
	.byte 0

exit_after_exec:
	.byte 0
curr_running_script:
	.byte 0
stay_alive_after_input_eof:
	.byte 0
print_startup_msg_flag:
	.byte 1
first_command_addr:
	.word 0
argc:
	.byte 0

args_offset_arr:
	.res 16, 0
	
MAX_FILELEN = 128

stdin_filename:
	.res MAX_FILELEN, 0
stdout_filename:
	.res MAX_FILELEN, 0

new_stdin_fileno:
	.byte 0
new_stdout_fileno:
	.byte 0
