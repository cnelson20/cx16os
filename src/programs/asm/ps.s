.include "routines.inc"
.segment "CODE"

r0 = $02

ptr0 := $30
ptr1 := $32

SINGLE_QUOTE = $27
NEWLINE = $d

main:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	dey
	sty ptr1
	
parse_options:
	lda ptr1
	beq end_parse_options
	jsr get_next_arg
	
	lda (ptr0)
	cmp #'-'
	bne @invalid_option ; options start w/ '-'
	ldy #1
	lda (ptr0), Y
	; compare to different flag letters
	cmp #'h'
	bne :+
	jmp print_usage
	:
	
	cmp #'a'
	beq :+
	cmp #'e'
	bne :++
	:
	lda #1
	sta disp_all_processes
	bra parse_options
	:
	
	cmp #'p'
	bne :+
	ldy ptr1 ; are there args left?
	beq @option_requires_argument
	jsr get_next_arg
	lda #1
	sta disp_only_processes_in_pid_list
	stz disp_only_processes_with_ancestor
	jsr add_to_pid_list
	bra parse_options
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
	dec ptr1 ; decrement argc	
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
	jsr get_true_parent
	sta ppid
	
	lda #<first_line
	ldx #>first_line
	jsr PRINT_STR
	
	lda #$10
	sta loop_pid
main_loop:
	lda loop_pid
	jsr get_process_info
	cmp #0
	bne :+
	jmp no_such_process
	:
	sta process_iid
	
	lda disp_all_processes
	bne do_print_process

	; based on diff flags, filter pids
	lda disp_only_processes_with_ancestor
	beq @dont_check_for_shared_ancestor
	
	lda loop_pid
	jsr check_process_ppid
	cmp #0
	bne :+
	jmp no_such_process
	:
@dont_check_for_shared_ancestor:

	lda disp_only_processes_in_pid_list
	beq @dont_check_in_pid_list
	
	ldx pid_list_size
	lda loop_pid
	:
	dex
	bmi :+
	cmp pid_list, X
	bne :-
	bra :++
	:
	jmp no_such_process
	:
@dont_check_in_pid_list:	

do_print_process:
	; print pid
	lda #$20 ; space
	jsr CHROUT

	lda loop_pid
	ldx #0
	jsr bin_to_bcd16
	pha

	cpx #0
	bne :+
	lda #$20
	jsr CHROUT
	bra :++
	:
	txa
	ora #$30
	jsr CHROUT

	:
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora #$30
	jsr CHROUT

	pla
	and #$0F
	ora #$30
	jsr CHROUT

	; print instance id ;
	lda #$20 ; space
	jsr CHROUT
	lda #'0'
	jsr CHROUT
	lda #'x'
	jsr CHROUT
	
	lda process_iid
	jsr GET_HEX_NUM
	jsr tolower
	jsr CHROUT
	txa
	jsr tolower
	jsr CHROUT
	
	; print ppid
	lda #$20
	jsr CHROUT
	jsr CHROUT

	lda r0 + 1
	ldx #0
	jsr bin_to_bcd16
	pha

	cpx #0
	bne :+
	lda #' '
	jsr CHROUT
	bra :++
	:
	txa
	ora #'0'
	jsr CHROUT

	:
	pla
	pha

	lsr
	lsr
	lsr
	lsr
	beq :+
	ora #'0'
	jsr CHROUT
	bra :++
	:
	lda #' '
	jsr CHROUT
	:

	pla
	and #$0F
	ora #$30
	jsr CHROUT
	

	lda #$20
	jsr CHROUT

	lda #128
	sta r0
	stz r0 + 1
	ldy loop_pid
	lda #<buffer
	ldx #>buffer
	jsr get_process_name
	stz buffer + 127
	
	lda #<buffer
	ldx #>buffer
	jsr PRINT_STR
	lda #$d
	jsr CHROUT
	
no_such_process:
	inc loop_pid
	beq :+
	jmp main_loop
	:
	rts

; helper functions

add_to_pid_list:
	; find a \0, ' ' or ','
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	cmp #' '
	beq :+
	cmp #','
	beq :+
	iny
	bra :-
	:
	; Is Y zero? ;
	cpy #0
	bne @not_empty_arg
	lda pid_list_size
	bne :+
	stz disp_only_processes_in_pid_list
	:
	rts
@not_empty_arg:
	
	pha ; push character zero'd out
	phy
	lda #0
	sta (ptr0), Y
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	; did the number parse correctly?
	; if so, just skip adding it to pid_list
	cpy #0
	bne @invalid_num_format
	
	; add to pid_list
	ldx pid_list_size
	sta pid_list, X
	inc pid_list_size
	
@invalid_num_format:	
	ply
	pla
	cmp #0
	beq @dont_repeat
	iny
	lda (ptr0), Y
	beq @dont_repeat
	
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	bra add_to_pid_list
	
@dont_repeat:
	rts
	
tolower:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	ora #$20
	:
	rts
	
get_hex_char:
	cmp #10
	bcs @greater10
	ora #$30
	rts
@greater10:
	sec
	sbc #10
	clc
	adc #$41
	rts

get_true_parent:
	lda $00
	:
	pha
	jsr get_process_info
	pla
	ldx r0 + 1
	beq :+
	txa
	bra :-
	:
	rts

check_process_ppid:
	cmp ppid
	beq @return ; return with non-zero value
	jsr get_process_info
	lda r0 + 1 ; ppid of process passed to get_process_info
	bne check_process_ppid
@return:
	rts

print_usage:
	lda #<@print_usage_txt
	ldx #>@print_usage_txt
	jsr print_str
	lda #0
	rts
@print_usage_txt:
	.byte "Usage: ps [-aeh] [-p PID[,PID2...]]", $d
	.byte "", $d
	.byte " -a,-e  show all processes", $d
	.byte " -h     show this message and exit", $d
	.byte " -p     show info for specified PIDs", $d
	.byte "", $d
	.byte "By default, ps shows info for processes with a shared ancestor", $d
	.byte "", $d
	.byte 0
; strings

first_line:
	.byte " PID  IID PPID CMD"
	.byte $0d, $00

invalid_option_str:
	.asciiz "ps: unknown option -- "
opt_requires_arg_str:
	.asciiz "ps: option requires an argument -- "

; flags to change which processes are displayed (set by program options)
disp_all_processes:
	.byte 0
disp_only_processes_with_ancestor:
	.byte 1
disp_only_processes_in_pid_list:
	.byte 0

loop_pid:
	.byte 0
process_iid:
	.byte 0
ppid:
	.byte 0
pid_list_size:
	.byte 0

.SEGMENT "BSS"

buffer:
	.res 128
pid_list:
	.res 128

