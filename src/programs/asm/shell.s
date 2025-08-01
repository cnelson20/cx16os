.include "routines.inc"
.segment "CODE"

ptr0 = $30
ptr1 = $32
ptr2 = $34
ptr3 = $36

CMD_MAX_SIZE = 128

LEFT_CURSOR = $9D
RIGHT_CURSOR = $1D
UP_CURSOR = $91
BACKSPACE = $14
DEL = $19

TAB = 9
CARRIAGE_RETURN = $0D
LINE_FEED = $0A
NEWLINE = LINE_FEED

SINGLE_QUOTE = 39

SWAP_COLORS = 1
COLOR_WHITE = 5
COLOR_GREEN = $1E
COLOR_BLUE = $1F

MODE_R = 'R'
MODE_W = 'W'

init:
	lda #1
	jsr set_stdin_read_mode
	
	lda $00
	jsr get_process_info
	lda r0 + 1
	bne :+
	lda #<home_dir_path
	ldx #>home_dir_path
	jsr chdir
	:
	
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
	cmp #'c' ; command
	bne :+
	jsr get_next_arg
	cmp #0
	bne prog_no_args_error
	lda ptr0
	sta first_command_addr
	lda ptr0 + 1
	sta first_command_addr + 1
	bra prog_args_loop
	:
	
	cmp #'b'
	bne :+
	stz color_mode
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

	lda #SINGLE_QUOTE
	jsr CHROUT
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str

	lda #SINGLE_QUOTE
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT

	lda #0
	rts
no_prog_args_error_str:
	.asciiz "no command provided: "
prog_args_error_str:
	.asciiz "invalid argument"

home_dir_path:
	.asciiz "~/home"
shrc_filename:
	.asciiz "~/home/.shrc"
bootrc_filename:
	.asciiz "~/home/.bootrc"
stdin_stream_filename:
	.asciiz "#stdin"

welcome:
	stz new_stdin_fileno
	stz new_stdout_fileno
	stz prev_command
	
	jsr get_console_info
	sta fore_color
	txa
	sta back_color

	lda curr_running_script
	bne new_line

	; open .shrc ? ;
	jsr try_open_bootrc
	bne new_line ; file was opened
	
	jsr try_open_shrc

new_line:
	; close these files in case got through
	lda exit_after_exec
	beq @no_exit_after_exec
	lda curr_running_script
	ora stay_alive_after_input_eof
	bne :+
	jmp exit_shell
	:
	lda #0
	jsr close_file
	stz exit_after_exec
	
	lda curr_script_is_bootrc
	beq :+ ; wasn't bootrc
	stz curr_script_is_bootrc
	stz curr_running_script
	stz stay_alive_after_input_eof
	
	lda next_fd
	ldx #0
	jsr move_fd
	jsr try_open_shrc
	bne @no_exit_after_exec
	beq @couldnt_open_shrc
	
	:
	ldx #0
	lda next_fd
	cmp #$FF
	bne :+
	lda #2
	:
	jsr set_fd_stdin
@couldnt_open_shrc:
	lda next_running_script
	sta curr_running_script
	stz next_running_script
	lda next_stay_alive_after_eof
	sta stay_alive_after_input_eof
	stz next_stay_alive_after_eof
@no_exit_after_exec:
	lda last_background_alive ; if last_background_alive proc died, set var to 0
	beq :+
	lda last_background_pid
	jsr get_process_info
	cmp last_background_instance
	bne :+
	
	stz last_background_alive
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
	
	lda color_mode
	beq :+
	lda #COLOR_GREEN
	bra :++
	:
	lda fore_color
	:
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
	
	lda fore_color
	jsr CHROUT
	lda #'$' ; '$'
	jsr CHROUT
	lda #$20 ; space
	jsr CHROUT
	
	lda #SWAP_COLORS
	jsr CHROUT
	lda #' '
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

skip_print_prompt:
	lda curr_running_script
	bne @not_auto_command
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
	stz first_command_addr
	stz first_command_addr + 1
	jmp not_empty_line
@not_auto_command:
	lda #0
	jsr send_byte_chrout_hook
	
	stz high_input_strlen
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
	lda #NEWLINE ; if eof has been reached, exec what's in buffer (unless buffer is empty)
@not_end_of_file_input:
	cmp #0
	bne @key_buff_not_empty
	
	bra wait_for_input
	
@key_buff_not_empty:

	cmp #NEWLINE ; return
	beq :+
	cmp #$8D ; shifted return
	bne :++
	:
	jmp command_entered
	:
	
	ldy curr_running_script
	bne @no_script_movement_chars
	
	cmp #$14 ; backspace
	bne :+
	jmp backspace
	:
	cmp #$19 ; delete
	bne :+
	jmp delete
	:

	cmp #UP_CURSOR
	beq up_cursor
	cmp #LEFT_CURSOR
	bne :+
	jmp left_cursor
	:
	cmp #RIGHT_CURSOR
	bne :+
	jmp right_cursor
	:
	
@no_script_movement_chars:
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
	ldy curr_running_script
	bne :+
	jsr CHROUT ; print character
	pha
	phx
	jsr move_input_chars_forward
	plx
	pla
	:
	
	sta input, X
	inx
	cpx high_input_strlen
	bcc :+
	stx high_input_strlen
	inx ; for scripts when move_input_chars_forward doesn't already do this
	stz input, X
	dex
	:
	
	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
	
	jmp wait_for_input

high_input_strlen:
	.byte 0

up_cursor:
	; replace input with prev_command
	cpx #0
	beq :++ ; can jump fwd to next loop if x = 0
	:
	lda #' ' ; clear current line from screen
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	dex
	cpx #0
	bne :-
	
	ldx #0
	:
	lda prev_command, X ; copy to input while printing chars
	sta input, X
	beq :+
	jsr CHROUT
	inx
	bra :-
	:
	lda #SWAP_COLORS
	jsr CHROUT
	lda #' '
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	jmp wait_for_input

left_cursor:
	cpx #0
	beq @end_left_cursor
	
	lda #LEFT_CURSOR
	jsr CHROUT
	
	dex
	
	lda #SWAP_COLORS
	jsr CHROUT
	lda input, X
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda input + 1, X ; input, X + 1
	bne :+
	lda #$20
	:
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	
	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
	
@end_left_cursor:	
	jmp wait_for_input

right_cursor:
	lda input, X
	beq @end_right_cursor 
	
	lda input, X
	jsr CHROUT	
	inx
	lda #SWAP_COLORS
	jsr CHROUT
	lda input, X
	bne :+ 
	lda #' '
	:
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
@end_right_cursor:
	jmp wait_for_input

delete:
	lda input, X
	bne :+ ; if input strlen is 0, dont delete
	jmp wait_for_input
	:
	inx
	lda #1
	sta backspace_not_empty_mode
	jsr backspace_not_empty
	jmp wait_for_input
	
backspace:
	cpx #0
	bne :+ 
	jmp wait_for_input
	:
	stz backspace_not_empty_mode
	jsr backspace_not_empty
	jmp wait_for_input

backspace_not_empty_mode:
	.byte 0 ; 0 = backspace, 1 = delete
backspace_not_empty:
	phx
	:
	lda input, X
	sta input - 1, X
	beq :+
	inx
	bne :-
	:
	plx
	dex
	
	phx
	lda ptr0
	pha
	
	lda backspace_not_empty_mode
	bne :+
	ldy curr_running_script
	bne :+
	lda #' '
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	:
	
	lda #1
	sta ptr0 ; times to LEFT_CURSOR at end
@print_loop:
	lda input, X
	beq @end_print_loop
	ldy curr_running_script
	bne :+
	jsr CHROUT
	inc ptr0 ; print one time, need to go back
	:
	inx
	bne @print_loop
@end_print_loop:
	ldy curr_running_script
	bne :++
	lda #' '
	jsr CHROUT
	lda #LEFT_CURSOR
	:
	jsr CHROUT
	dec ptr0
	bne :-
	:	
	
	pla
	sta ptr0
	plx
	
	lda #SWAP_COLORS
	jsr CHROUT
	lda input, X
	bne :+
	lda #' '
	:
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	; backspace not implemented
	
	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
	
	rts

command_entered:
	lda curr_running_script
	bne @script_is_running
	lda input, X
	bne :+
	lda #' '
	:
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	
	; copy input to prev_command
	ldx #0
	:
	lda input, X
	sta prev_command, X
	inx
	cmp #0
	bne :-
@script_is_running:

	ldx #0
	jsr find_non_space_char_input
	lda input, X
	cmp #'#'
	bne :+
	jmp new_line
	:
	stz in_quotes
	:
	lda input, X
	beq :+
	inx
	bne :-
	: ; get strlen(input)
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
	cmp #'"' ; double quote
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
	
	cmp #'&'
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
	cmp #'<'
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
	cmp #'>'
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

move_input_chars_forward:
	phx
	lda ptr0
	pha ; save ptr0
	
	stz @print_count
	
	stx ptr0
	dec ptr0
@find_null_term_loop:
	lda input, X
	beq @end_find_null_term_loop
	
	jsr CHROUT
	inc @print_count
	inx	
	bne @find_null_term_loop
@end_find_null_term_loop:
	
	; copying loop ;
@copy_forward_loop:
	lda input, X
	sta input + 1, X
	dex
	cpx ptr0
	bne @copy_forward_loop
	
	lda @print_count
	beq :++
	lda #LEFT_CURSOR
	:
	jsr CHROUT
	dec @print_count
	bne :-
	:
	
	pla
	sta ptr0
	plx
	
	lda #SWAP_COLORS
	jsr CHROUT
	inx
	lda input, X
	bne :+
	lda #' '
	:
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	rts

@print_count:
	.byte 0

is_space_char:
	cmp #' '
	bne :+
	rts
	:
	cmp #TAB
	bne :+
	rts
	:
	cmp #CARRIAGE_RETURN
	bne :+
	rts
	:
	cmp #LINE_FEED
	bne :+
	rts
	:
	cmp #0
	rts

find_non_space_char_input:
	; takes in offset to input in X
	:
	lda input, X
	beq @return
	jsr is_space_char
	bne @return ; return if not whitespace char
	inx
	bne :-
	dex
@return:
	rts

parse_env_var:
	ldx curr_arg
	lda args_offset_arr, X
	
	clc
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

	; pid of this process
	lda $00 ; RAM_BANK
	bra @repl_arg_hex_num
@not_self_pid:

	; look in extmem for env vars
	jmp search_env_vars

@repl_arg_hex_num:
	pha ; push val
	
	lda #2 ; 1 digit number + \0
	sta @shift_val
	
	pla
	pha
	
	cmp #10
	bcc :+
	inc @shift_val ; another byte for 10s digit
	cmp #100
	bcc :+
	inc @shift_val ; another for 100s digit
	:
	
	lda @shift_val
	jsr shift_output
	
	ldy curr_arg
	lda args_offset_arr, Y
	tay
	pla ; pull val back
	phy
	ldx #0
	jsr bin_to_bcd16 ; Convert val to bcd string, .X = hundreds digit, .A = tens & ones digit
	ply
	cpx #0
	beq :+
	pha
	txa
	jsr GET_HEX_NUM
	txa
	sta output, Y
	iny
	pla ; Since num >= 100, always want to include tens digit
	jsr GET_HEX_NUM
	bra :++
	:
	jsr GET_HEX_NUM ; get last 2 digits
	cmp #'0' ; is the tens digit 0?
	beq :++ ; if so, branch ahead
	:
	sta output, Y
	iny
	:
	txa
	sta output, Y
	iny
	lda #0
	sta output, Y
	rts
@shift_val:
	.byte 0

check_aliases:
	ldx #0
	:
	jsr @check_alias_iter
	cmp #0
	beq :-
	rts
@check_alias_iter:
	txa
	jsr find_var_ptr
	cmp #0
	beq :+
	rts
	:
	phx
	
	lda #$7F
	sta ptr2
	jsr readf_byte_extmem_y
	pha
	tax
	lda #$80
	sta ptr2

	ldy #$FF
	:
	iny
	jsr readf_byte_extmem_y
	cmp #0
	bne :-
	dex
	bne :-
	iny

	lda ptr2 + 1
	pha
	tya
	jsr shift_output
	lda #$80
	sta ptr2
	pla
	sta ptr2 + 1
	pla
	tax
	dec A
	clc
	adc num_args
	sta num_args

	ldy curr_arg
	lda args_offset_arr, Y
	adc #<( output - 1 )
	sta ptr3
	lda #>( output - 1 )
	adc #0
	sta ptr3 + 1
	ldy #$FF
@copy_loop:
	inc ptr3
	bne :+
	inc ptr3 + 1
	:
	iny
	jsr readf_byte_extmem_y
	sta (ptr3)
	cmp #0
	bne @copy_loop
	dex
	bne @copy_loop

	ldx #1
	ldy #$FF
	:
	iny
	lda output, Y
	bne :-
	iny
	tya
	sta args_offset_arr, X
	inx
	cpx num_args
	bcc :-
	lda #0
	plx
	rts

search_env_vars:
	lda #0
	jsr find_var_ptr
	cmp #0
	bne @out_slots
	
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

find_var_ptr:
	tax
	lda env_extmem_bank ; is the bank initialized?
	bne :+
	lda #1
	rts
	:

	stz ptr3
	lda #<( $C000 - $100 )
	sta ptr2
	lda #>( $C000 - $100 )
	sta ptr2 + 1
	
	phx
	lda env_extmem_bank
	jsr set_extmem_rbank
	lda #<ptr2
	jsr set_extmem_rptr
	plx
	ldy #0
@search_loop:
	jsr readf_byte_extmem_y
	cmp #0
	beq @cont_search_loop
	inc ptr3
	cpx #0
	beq @found
	dex
@cont_search_loop:
	lda ptr2 + 1
	dec A
	sta ptr2 + 1
	cmp #$A0
	bcs @search_loop

	lda #1
	rts

@found:
	phx

	ldy curr_arg
	lda args_offset_arr, Y
	tax
	ldy #0
	:
	jsr readf_byte_extmem_y
	cmp output, X
	bne :+
	lda output, X
	beq :++
	iny
	inx
	bpl :-
	:
	lda #1
	:
	plx
	ldy #0
	cmp #0
	bne @cont_search_loop

	ldx ptr3
	lda env_extmem_bank
	sta ptr3

	lda #0
	rts
	
question_str:
	.asciiz "$?"
excl_str:
	.asciiz "$!"
dollar_str:
	.asciiz "$$"

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
	stz curr_arg
	jsr check_aliases

	jsr check_special_cmds
	beq :+
	jmp new_line
	:
	
	; stp
	jsr setup_prog_redirects
	stz starting_arg
	stz num_cmds_ran

@pipe_loop:
	lda starting_arg
	beq :+
	sta curr_arg
	jsr check_aliases
	lda starting_arg
	:
	inc A
	jsr check_pipe
	cmp #$FF
	beq	@no_pipe
@yes_pipe:
	cmp #0
	beq @no_pipe
	tax
	inx
	cpx num_args
	bcs @no_pipe ; nothing after the pipe
	pha
	jsr pipe
	ldy new_stdin_fileno
	sta new_stdin_fileno
	sty r2
	stx r2 + 1
	lda #0
	sta r0
	pla
	pha
	sec
	sbc starting_arg
	tay ; number of args = (arg # of pipe) - starting_arg
	ldx starting_arg
	lda args_offset_arr, X
	clc
	adc #<output
	ldx #>output
	bcc :+
	inx
	:
	phy
	jsr exec
	cmp #0
	bne :+
	txa ; put error code in .A
	ply
	plx
	jmp exec_error
	:
	ldy num_cmds_ran
	sta child_id_table, Y
	txa
	sta child_instance_table, Y
	lda r2 ; process' stdin
	beq :+
	jsr close_file
	:
	lda r2 + 1 ; process' stdout
	beq :+
	jsr close_file
	:
	ply
	plx
	inc num_cmds_ran
	inx
	stx starting_arg
	bra @pipe_loop
	
@no_pipe:
	lda num_args
	sec
	sbc starting_arg
	tay ; number of args
	lda new_stdin_fileno
	sta r2
	lda new_stdout_fileno
	sta r2 + 1
	lda do_wait_child
	sta r0
	ldx starting_arg
	lda args_offset_arr, X
	clc
	adc #<output
	ldx #>output
	bcc :+
	inx
	:
	jsr exec
	cmp #0
	bne :+
	txa
	bra exec_error
	:

@store_child_info:
	phx
	pha
	lda new_stdin_fileno
	beq :+
	jsr close_file
	:
	lda new_stdout_fileno
	beq :+
	jsr close_file
	:
	stz new_stdin_fileno
	stz new_stdout_fileno
	pla
	plx
	
	ldy num_cmds_ran
	sta child_id_table, Y
	txa
	sta child_instance_table, Y
	inc num_cmds_ran
	
	lda do_wait_child
	bne wait_child
	
	ldy num_cmds_ran
	dey
	lda child_id_table, Y
	sta last_background_pid
	lda child_instance_table, Y
	sta last_background_instance

	lda #1
	sta last_background_alive

	jmp new_line
wait_child:
	ldy num_cmds_ran
	dey
	lda child_id_table, Y
	jsr wait_process
	
	; value in .A will be return code of last process in chain
	sta last_return_val
	jmp new_line
	
exec_error:
	pha ; push error code
	lda r2
	beq :+
	cmp new_stdin_fileno
	beq :+
	jsr close_file
	:
	lda new_stdin_fileno
	beq @new_stdin_file_zero
	jsr close_file
	stz new_stdin_fileno
@new_stdin_file_zero:
	lda r2 + 1
	beq :+
	cmp new_stdout_fileno
	beq :+
	jsr close_file
	:
	lda new_stdout_fileno
	beq @new_stdout_file_zero
	jsr close_file
	stz new_stdout_fileno
@new_stdout_file_zero:
	
	lda #<exec_error_p1_message
	ldx #>exec_error_p1_message
	jsr print_str
	
	ldx starting_arg
	lda args_offset_arr, X
	clc
	adc #<output
	ldx #>output
	bcc :+
	inx
	:
	jsr print_str
	
	lda #<exec_error_p2_message
	ldx #>exec_error_p2_message
	jsr print_str
	
	pla ; pull back error code
	jsr strerror
	jsr print_str
	
	lda #NEWLINE
	jsr CHROUT

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
	lda #NEWLINE
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
	lda #NEWLINE
	jsr CHROUT
	jmp new_line

; check pipe
check_pipe:
	tax
	inx
	cpx num_args
	bcs @not_found
	tay
@loop:
	tyx
	lda args_offset_arr, X
	tax
	lda output, X
	cmp #'|'
	bne :+
	inx
	lda output, X
	bne :+
	tya ; arg num now in .A
	rts
	:
	iny
	cpy num_args
	bcc @loop
@not_found:	
	lda #$FF
	rts

; returns non-zero in .A if a special cmd was encountered
check_special_cmds:
	; check for cd ;
	lda #<string_cd
	ldx #>string_cd
	jsr cmd_cmp
	bne @not_cd
	
	lda num_args
	cmp #2
	bcs :+
	lda #<home_dir_path
	ldx #>home_dir_path
	bra :++
	:
	ldx #1
	lda args_offset_arr, X
	clc 
	adc #<output
	tay
	lda #>output
	adc #0
	tax
	tya
	
	:
	stz last_return_val
	jsr chdir
	cmp #0
	beq :+
	
	lda #<cd_error_string
	ldx #>cd_error_string
	jsr print_str	
	
	lda #1
	sta last_return_val
	
	:
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
	
	stz last_return_val
	
	jsr open_shell_file
	sta last_return_val

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
	lda #<string_bw
	ldx #>string_bw
	jsr cmd_cmp
	bne @not_bw

	lda color_mode
	eor #1
	sta color_mode
	lda #1
	rts
@not_bw:
	lda #<string_color
	ldx #>string_color
	jsr cmd_cmp
	bne @not_color
	
	jsr change_shell_colors
	
	lda #1
	rts	
@not_color:
	lda #<string_alias
	ldx #>string_alias
	jsr cmd_cmp
	bne @not_alias
	
	jsr set_alias
	
	lda #1
	rts
@not_alias:
	
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

;
; both try_open_bootrc and try_open_shrc return 1 when the file is opened, 0 otherwise
;
try_open_bootrc:
	lda $00
	jsr get_process_info
	lda r0 + 1
	bne :+ ; if process has parent, don't open bootrc

	ldy #0
	lda #<bootrc_filename
	ldx #>bootrc_filename
	jsr open_file
	cmp #$FF
	beq :+
	; file was opened ;
	jsr set_script_fd_stdin
	
	lda #1
	sta curr_script_is_bootrc
	rts
	:
	lda #0
	rts

try_open_shrc:
	ldy #0
	lda #<shrc_filename
	ldx #>shrc_filename
	jsr open_file
	cmp #$FF
	bne :+
	lda #0
	rts
	:
	jsr set_script_fd_stdin
	lda #1
	rts

set_script_fd_stdin:
	pha
	lda #0
	jsr copy_fd
	sta next_fd ; whatever script was being run can be next

	lda curr_running_script
	sta next_running_script
	lda stay_alive_after_input_eof
	sta next_stay_alive_after_eof
	stz stay_alive_after_input_eof
	pla
	jsr set_fd_stdin

	lda #1
	sta curr_running_script
	rts

set_fd_stdin:
	ldx #0 ; move to stdin
	jsr move_fd
	cmp #0
	beq :+
	lda #<stdin_stream_filename
	ldx #>stdin_stream_filename
	ldy #0
	jsr open_file
	ldx #0
	jsr move_fd
	:
	rts

exit_shell:
	sta ptr0
	lda #>$01FD
	xba
	lda #<$01FD
	tcs
	lda ptr0
	rts

change_shell_colors:
	lda num_args
	cmp #2
	bcc @too_few_args
	
	ldy args_offset_arr + 1
	lda output, Y
	bne @enough_args ; Not empty string
@too_few_args:
	; print err msg
	lda #<color_no_args_err_string
	ldx #>color_no_args_err_string
	jsr print_str
	rts
@enough_args:
	lda output, Y
	jsr hex_digit_to_byte
	cmp #$FF
	beq @invalid_arg
	tax
	lda color_table, X
	pha
	tyx
	inx
	lda output, X
	jsr hex_digit_to_byte
	cmp #$FF
	bne :+
	pla
	bra @invalid_arg
	:
	tax
	lda color_table, X
	sta fore_color
	pla
	sta back_color
	
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda fore_color
	jsr CHROUT
	lda #$93
	jmp CHROUT
	
@invalid_arg:
	phy
	lda #<color_invalid_arg_err_string
	ldx #>color_invalid_arg_err_string
	jsr print_str
	pla
	clc
	adc #<output
	ldx #>output
	bcc :+
	inx
	:
	jsr print_str
	
	lda #SINGLE_QUOTE
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	rts

color_table:
	.byte $90, $05, $1C, $9F, $9C, $1E, $1F, $9E
	.byte $81, $95, $96, $97, $98, $99, $9A, $9B

hex_digit_to_byte:
	cmp #'0'
	bcc @invalid
	cmp #'9' + 1
	bcs :+
	sec
	sbc #'0'
	rts
	:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	sec
	sbc #'A' - 10
	:
	cmp #'a'
	bcc :+
	cmp #'z' + 1
	bcs :+
	sec
	sbc #'a' - 10
	:
@invalid:
	lda #$FF
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
	jsr find_env_space
	cmp #0
	beq :+
	lda #<set_env_out_space
	ldx #>set_env_out_space
	jsr print_str
	rts
	:
	
	lda ptr3 ; bank to write to returned in ptr3
	jsr set_extmem_wbank

	lda #<ptr2 ; ptr to write to returned in ptr2
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
	lda #'$'
	jsr writef_byte_extmem_y

	inc ptr2
	:
	lda (ptr3), Y
	cmp #0
	beq :+
	jsr writef_byte_extmem_y
	iny
	cpy #126
	bcc :-
	lda #0
	:
	jsr writef_byte_extmem_y

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

set_alias:
	lda num_args
	cmp #3
	bcs :+
	rts
	:

	jsr find_env_space
	cmp #0
	beq :+
	rts
	:
	
	lda ptr3 ; bank to write to returned in ptr3
	jsr set_extmem_wbank
	lda #<ptr2 ; ptr to write to returned in ptr2
	jsr set_extmem_wptr
	; write name to extmem
	
	ldx args_offset_arr + 1
	ldy #0
	:
	lda output, X
	cmp #0
	beq :+
	jsr writef_byte_extmem_y
	inx
	iny
	cpy #126
	bcc :-
	lda #0
	:
	jsr writef_byte_extmem_y

	; write value to extmem
	lda num_args
	dec A
	dec A
	ldy #$7F
	jsr writef_byte_extmem_y
	tax ; num of args to copy in X

	clc
	lda args_offset_arr + 2
	adc #<output
	sta ptr3
	lda #>output
	adc #0
	sta ptr3 + 1

	ldy #$80
@copy_val_loop:
	lda (ptr3)
	jsr writef_byte_extmem_y
	inc ptr3
	bne :+
	inc ptr3 + 1
	:
	iny
	beq :+
	cmp #0
	bne @copy_val_loop
	dex
	bne @copy_val_loop
	beq @end_loop
	:
	tya ; .Y = 0
	dey
	jsr writef_byte_extmem_y
@end_loop:
	rts

;
; takes second arg to cmd and compares to keys in extmem
; on success, returns a ptr to free extmem in ptr2, a bank in ptr3, and 0 in .A
; returns a non-zero val in .A on failure
;
find_env_space:
	lda env_extmem_bank
	bne @already_have_bank
	lda #0
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
	ldx #$C0 - $A0
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
@find_space_loop:
	ldy #0
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

	lda ptr2 + 1
	inc A
	sta ptr2 + 1
	cmp #$C0
	bcc @find_space_loop

@out_space:
	lda #1
	rts

@found_space:
	lda env_extmem_bank
	sta ptr3

	lda #0
	rts

open_shell_file:
	lda curr_running_script
	beq @not_within_script
	
	lda #<source_inception_str
	ldx #>source_inception_str
	jsr print_str
	
	lda #1
	rts
@not_within_script:

	lda num_args
	cmp #2
	bcs :+

	lda #<source_err_string
	ldx #>source_err_string
	jsr print_str ; print and return
	
	lda #1
	rts
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

	pha

	lda #0
	jsr copy_fd
	sta next_fd
	lda curr_running_script
	sta next_running_script
	lda stay_alive_after_input_eof
	sta next_stay_alive_after_eof
	stz stay_alive_after_input_eof

	pla
	ldx #0 ; move to stdin
	jsr move_fd
	ldx #$FF
	cmp #0
	bne @open_error

	plx
	plx ; pull two bytes off stack (pha & phx)

	lda #1
	sta curr_running_script
	
	lda #0 ; open_shell_file success
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

	lda #NEWLINE
	jsr CHROUT
	
	lda #1
	rts
	
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
	.byte NEWLINE, $00
exec_error_p1_message:
	.asciiz "Error in exec '"
exec_error_p2_message:
	.asciiz "': "

source_err_string:
	.byte "source: filename argument required"
	.byte NEWLINE, 0
source_inception_str:
	.byte "source: cannot run another script within a script"
	.byte NEWLINE, 0

set_env_err_string:
	.byte "setenv: need name and value argument"
	.byte NEWLINE, 0
set_env_out_space:
	.byte "setenv: no memory left for variables"
	.byte NEWLINE, 0

color_no_args_err_string:
	.byte "color: argument required"
	.byte NEWLINE, 0
color_invalid_arg_err_string:
	.byte "color: invalid operand '"
	.byte 0

cd_error_string:
	.byte "cd: error changing directory"
	.byte NEWLINE, 0

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
string_bw:
	.asciiz "bw"
string_color:
	.asciiz "color"
string_alias:
	.asciiz "alias"

; program vars 

in_quotes:
	.byte 0
do_wait_child:
	.byte 0
last_return_val:
	.byte 0
last_background_alive:
	.byte 0
last_background_pid:
	.byte 0
last_background_instance:
	.byte 0
env_extmem_bank:
	.byte 0
num_args:
	.byte 0
starting_arg:
	.byte 0
num_cmds_ran:
	.byte 0
child_id_table:
	.res 16, 0
child_instance_table:
	.res 16, 0
input:
	.res CMD_MAX_SIZE, 0
output:
	.res CMD_MAX_SIZE, 0
prev_command:
	.res CMD_MAX_SIZE, 0
command_length:
	.byte 0
curr_arg:
	.byte 0
flicker_tick:
	.byte 0
color_mode:
	.byte 1
fore_color:
	.byte 0
back_color:
	.byte 0

next_fd:
	.byte $FF
next_running_script:
	.byte 0
next_stay_alive_after_eof:
	.byte 0
exit_after_exec:
	.byte 0
curr_running_script:
	.byte 0
curr_script_is_bootrc:
	.byte 0
stay_alive_after_input_eof:
	.byte 0
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
