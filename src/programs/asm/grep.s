.include "routines.inc"
.feature c_comments

CARRIAGE_RETURN = $0D
LINE_FEED = $0A
NEWLINE = LINE_FEED

SINGLE_QUOTE = $27

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

.segment "CODE"

init:
	jsr get_args
	sta args_pointer
	stx args_pointer + 1
	
	dey
	sty argc	
	rep #$10
	.i16
	
	lda argc
	bne :+
	lda #2
	rts
	:
	
	jsr get_next_arg
	ldx args_pointer
	jsr check_regex
	jsr build_regex_from_str
	cmp #0
	beq :+
	lda #2 ; major error
	rts
	:
	
	stz exit_code
@file_loop:
	lda argc
	bne :+
	lda have_read_file
	bne @end_file_loop
@use_stdin_input:
	lda #<stdin_str
	ldx #>stdin_str
	bra @open_text_file
	:
	jsr get_next_arg
	ldx args_pointer
	lda $00, X
	cmp #'-'
	bne @arg_not_flag
	
	lda $01, X
	beq @use_stdin_input ; if arg = "-", means to read from stdin
	cmp #'i'
	bne :+
	ldx #1
	stx match_case_ins
	bra @file_loop
	:
	
	pha
	lda #<invalid_flag_err_str
	ldx #>invalid_flag_err_str
	jsr print_str
	pla
	jsr CHROUT
	lda #SINGLE_QUOTE
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	lda #1
	rts
@arg_not_flag: ; not a flag
	lda args_pointer
	ldx args_pointer + 1	
@open_text_file:
	ldy #0 ; reading
	jsr open_file
	cmp #$FF
	bne :+
	lda #<file_err_str_p1
	ldx #>file_err_str_p1
	jsr print_str
	lda args_pointer
	ldx args_pointer + 1
	jsr print_str
	lda #<file_err_str_p2
	ldx #>file_err_str_p2
	jsr print_str
	lda #1
	sta exit_code
	jmp @file_loop
	:
	sta fd
	
	lda #1
	sta have_read_file
	
	jsr print_file_matches
	jmp @file_loop
@end_file_loop:
	
	lda exit_code
	rts

args_pointer:
	.word 0
argc:
	.word 0

fd:
	.word 0
exit_code:
	.word 0

have_read_file:
	.word 0

get_next_arg:
	dec argc
	
	ldx args_pointer
	dex
	:
	inx
	lda $00, X
	bne :-
	inx
	stx args_pointer
	rts

stdin_str:
	.asciiz "#stdin"

print_file_matches:
	lda #1
	sta @still_read

@read_file_loop:	
	ldy #0
	:
	phy
	ldx fd
	jsr fgetc
	ply
	cpx #0
	bne @out_bytes
	cmp #NEWLINE
	beq @newline
	sta temp_buff, Y
	iny
	cpy #(temp_buff_end - temp_buff) - 1
	bcc :-
	bra @newline
@out_bytes:
	stz @still_read
	cpy #temp_buff
	beq @end_loop_iteration
@newline:
	lda #0
	sta temp_buff, Y
	cpy #temp_buff
	beq :+
	dey
	lda temp_buff, Y
	iny
	cmp #CARRIAGE_RETURN
	bne :+
	lda #0
	sta temp_buff, Y
	dey
	:
	sty r1
	
	ldx #temp_buff
	stx r0
	jsr match_str
	cmp #0
	beq :+
	lda #1
	jsr write_file
	lda #NEWLINE
	jsr CHROUT
	:

@end_loop_iteration:	
	lda @still_read ; should we loop back?
	bne @read_file_loop
	
	lda fd
	jsr close_file
	rts
	
@still_read:
	.byte 0

TRANSITION_DATA_SIZE = STATE_TGT_IND_OFFSET + 2

MATCH_FUNCTION_OFFSET = 0
INDEX_ARG_OFFSET = 2
STATE_TGT_IND_OFFSET = 4

match_str:
	stx ptr0
	ldx #0
	:
	stz built_regex_activated, X
	stz built_regex_activated_next, X
	inx
	cpx built_regex_ptrs_list_size
	bcc	:-
	lda #1
	sta built_regex_activated + 0
	
@match_str_outer_loop:
	ldx ptr0
	lda $00, X
	beq @end_loop
	inx
	stx ptr0
	sta @cons_char
	
	; follow epsilons
	ldx #0
	stx ptr1
@follow_epsilons_loop:
	ldx ptr1
	lda built_regex_activated, X
	beq :+
	jsr activate_state_epsilon_transitions
	ldx ptr1
	:
	inx
	stx ptr1
	cpx built_regex_ptrs_list_size
	bcc @follow_epsilons_loop
	
	; now check other rules that consume a char
	ldx #0
	stx ptr1
@check_consumes_loop:
	ldx ptr1
	lda built_regex_activated, X
	beq :+
	lda @cons_char
	jsr activate_state_cons_transitions
	ldx ptr1
	:
	inx
	stx ptr1
	cpx built_regex_ptrs_list_size
	bcc @check_consumes_loop

	; copy back one more time
	ldx #0
	:
	lda built_regex_activated_next, X
	stz built_regex_activated_next, X
	sta built_regex_activated, X
	inx
	cpx built_regex_ptrs_list_size
	bcc	:-
	
	jmp @match_str_outer_loop
@end_loop:
	; do epsilon loop one last time
	ldx #0
	stx ptr1
	:
	lda built_regex_activated, X
	beq :+
	jsr activate_state_epsilon_transitions
	ldx ptr1
	:
	inx
	stx ptr1
	cpx built_regex_ptrs_list_size
	bcc :--
	
	; if last state is activated, there is a match
	ldx built_regex_ptrs_list_size
	dex
	lda built_regex_activated, X
	rts

@cons_char:
	.byte 0

activate_state_epsilon_transitions:
	rep #$20
	txa
	asl A
	tax
	lda built_regex_ptrs_list, X
	sta ptr2
@loop:
	rep #$20
	.a16
	lda (ptr2)
	beq @end_loop
	cmp #epsilon_transition
	bne @not_epsilon
	ldy #STATE_TGT_IND_OFFSET
	lda (ptr2), Y
	tax
	sep #$20
	.a8
	lda built_regex_activated, X
	bne :++
	lda #1
	sta built_regex_activated, X
	dex
	bmi :+
	cpx ptr1
	bcs :++ ; want lowest ptr1 val
	:
	stx ptr1
	:
	rep #$20
	.a16
@not_epsilon:
	clc
	lda ptr2
	adc #TRANSITION_DATA_SIZE
	sta ptr2
	bra @loop
@end_loop:
	sep #$20
	.a8
	rts

activate_state_cons_transitions:
	sta @cons_char
	
	rep #$20
	txa
	asl A
	tax
	lda built_regex_ptrs_list, X
	sta ptr2
@loop:
	rep #$20
	.a16
	lda (ptr2)
	beq @end_loop
	sta ptr3
	ldy #INDEX_ARG_OFFSET
	lda (ptr2), Y
	tax
	sep #$20
	.a8
	per (:+) - 1
	lda @cons_char
	jmp (ptr3)
	:
	cmp #0 ; was the result a match?
	rep #$20
	.a16
	beq @not_match
	ldy #STATE_TGT_IND_OFFSET
	lda (ptr2), Y
	tax
	sep #$20
	.a8
	lda #1
	sta built_regex_activated_next, X
	rep #$20
	.a16
@not_match:
	clc
	lda ptr2
	adc #TRANSITION_DATA_SIZE
	sta ptr2
	bra @loop
@end_loop:
	sep #$20
	.a8
	rts

@cons_char:
	.word 0

check_regex:
	ldy #temp_buff
	lda $00, X
	cmp #'^'
	bne :+
	inx
	bra :++
	:
	lda #'\'
	sta $00, Y
	iny
	lda #'@'
	sta $00, Y
	iny
	lda #'*'
	sta $00, Y
	iny
	:
	sty ptr1
	phx
	jsr strlen
	plx
	rep #$20
	mvn #$00, #$00
	sep #$20
	
	dey
	dey
	sty ptr0
	lda $00, Y
	cmp #'$'
	bne @not_dollar_term
	ldx #0
	bra :++
	:
	lda $00, Y
	cmp #'\'
	bne :++
	inx
	:
	dey
	cpy ptr1
	bcs :--
	:
	txa
	and #1
	bne @not_dollar_term

	; last char in str is a $
	lda #0
	ldy ptr0
	sta $00, Y
	bra @return
@not_dollar_term:
	ldy ptr0
	iny
	lda #'\'
	sta $00, Y
	iny
	lda #'@'
	sta $00, Y
	iny
	lda #'*'
	sta $00, Y
	iny
	lda #0
	sta $00, Y

@return:
	ldx #temp_buff
	rts
	
build_regex_from_str:	
	stx ptr0 ; store string
	ldx #built_regex_ptrs_list
	stx ptr1 ; current state
	ldx #built_regex_data
	stx ptr2 ; current transition
	stx built_regex_ptrs_list + 0
	ldx #0
	stx ptr3 ; state index
	
	tsx
	stx @store_stack_ptr
	
	ldx #0
	stx built_regex_ptrs_list_size
	stx @forward_index_ptr		
	
	stz @last_char_was_backslash
	
@loop:
	ldx @forward_index_ptr
	beq :+
	lda ptr3
	sta $00, X
	:
	
	ldx ptr0
	lda $00, X
	bne :+
	jmp @end_str
	:
	inx
	stx ptr0
	
	ldx ptr3
	stx @backwards_reference_index
	ldx #0
	stx @forward_index_ptr
	
	ldx @last_char_was_backslash
	beq :+
	ldy #0
	jsr backslash_char_mapping
	bra @set_match_fxn
	:
@not_escaped_char:
	cmp #'\'
	bne :+
	lda #1
	sta @last_char_was_backslash
	bra @loop
	:
	cmp #'('
	bne @not_open_paren
	ldx ptr2
	lda ptr3
	jsr add_epsilon_transition
	ldx ptr2
	dex
	dex
	phx
	ldx ptr3 ; transition index
	phx
	bra @loop
@not_open_paren:
	cmp #')'
	bne @not_close_paren
	ldx ptr0
	lda $FFFE, X
	cmp #'('
	bne :++
	:
	lda #1 ; error
	jmp @return
	:
	tsx
	cpx @store_stack_ptr ; more )'s than ('s
	beq :--
	plx
	stx @backwards_reference_index
	plx
	stx @forward_index_ptr
	; check next quantifier
	jmp @check_next_char
@not_close_paren:
	ldy #0
	jsr normal_char_match_mapping
	bra @set_match_fxn
@is_literal_char:
	ldy #0
	bra @set_match_fxn
	
@set_match_fxn:
	cpy #0
	bne :+
	ldy #match_single_char
	:
	stz @last_char_was_backslash
	pha
	ldx ptr2
	rep #$20
	.a16
	tya
	sta $00, X
	sep #$20
	.a8
	inx
	inx
	pla
	sta $00, X
	inx
	stz $00, X
	inx
	lda ptr3
	inc A
	sta $00, X
	inx
	stz $00, X
	inx
	stx ptr2
	
@check_next_char:
	ldx ptr0
	lda $00, X
	bne :+
	jsr add_end_list_transition
	bra @end_str
	:
	jsr is_quantifier_char
	bne :+
	jsr add_end_list_transition
	jmp @loop
	:
	inx
	stx ptr0	
	pha ; push qualifier character
	cmp #'+'
	bne :+
	ldx @forward_index_ptr
	beq :++ ; if not set, don't add the epsilon transition
	ldx #0
	stx @forward_index_ptr
	:
	; add epsilon transition
	lda ptr3
	inc A
	jsr add_epsilon_transition
	:
	; end of this state's transition list
	jsr add_end_list_transition
	pla
	cmp #'*'
	beq @star_or_plus_qualifier
	cmp #'+'
	beq @star_or_plus_qualifier	
	jmp @loop
@star_or_plus_qualifier:
	lda @backwards_reference_index
	jsr add_epsilon_transition
	jmp @loop
	
@end_str:
	ldx ptr2
	stz $00, X
	stz $01, X
	
	lda ptr3 ; off by one depending on whether the last character was followed by a qualifier
	inc A
	sta built_regex_ptrs_list_size
	
	ldx ptr1
	inx
	inx
	lda ptr2
	sta $00, X
	lda ptr2 + 1
	sta $01, X
	stz $02, X
	stz $03, X
	
	lda #0
@return:	
	ldx @store_stack_ptr
	txs
	rts

@last_char_was_backslash:
	.word 0

@store_stack_ptr:
	.word 0
@backwards_reference_index:
	.word 0
@forward_index_ptr:
	.word 0

add_epsilon_transition:
	pha
	ldx ptr2
	lda #<epsilon_transition
	sta $00, X
	inx
	lda #>epsilon_transition
	sta $00, X
	inx
	
	lda #$EE ; dummy value to stand out when debugging
	sta $00, X
	inx
	sta $00, X
	inx
	
	pla
	sta $00, X
	inx
	stz $00, X
	inx
	stx ptr2
	rts

add_end_list_transition:
	ldx ptr2
	stz $00, X
	inx
	stz $00, X
	inx
	stx ptr2
	
	ldx ptr1
	inx
	inx 
	stx ptr1
	inc ptr3
	
	lda ptr2
	sta $00, X
	lda ptr2 + 1
	sta $01, X
	rts

is_quantifier_char:
	cmp #'?'
	beq @yes
	cmp #'*'
	beq @yes
	cmp #'+'
	beq @yes
@no:	
	lda #0
@yes:
	ora #0
	rts

backslash_char_mapping:
	cmp #'r'
	bne :+
	lda #CARRIAGE_RETURN ; \r
	rts
	:
	cmp #'n'
	bne :+
	lda #LINE_FEED ; \n
	rts
	:
	cmp #'t'
	bne :+
	lda #$9 ; \t
	rts
	:
	cmp #'d' ; \d
	bne :+
	ldy #match_digit
	rts
	:
	cmp #'D' ; \D
	bne :+
	ldy #match_not_digit
	rts
	:
	cmp #'s' ; \s
	bne :+
	ldy #match_whitespace
	rts
	:
	cmp #'S' ; \S
	bne :+
	ldy #match_not_whitespace
	rts
	:
	cmp #'w' ; \w
	bne :+
	ldy #match_word
	rts
	:
	cmp #'W' ; \W
	bne :+
	ldy #match_not_word
	rts
	:
	cmp #'@' ; \@
	bne :+
	ldy #match_any
	rts
	:
	
	ldy #0 ; default char mapping
	rts

normal_char_match_mapping:
	cmp #'.'
	bne :+
	ldy #match_dot
	rts
	:
	rts

; takes string in .X, returns strlen in .C
strlen:
	phy
	ldy #$FFFF
	dex
	:
	iny
	inx
	lda $00, X
	bne :-
	rep #$20
	tya
	sep #$20
	ply
	rts

;
; Different transition functions
;
match_case_ins:
	.word 0

match_single_char:
	ldy match_case_ins
	bne @match_single_char_ins
	stx @tmp_word
	cmp @tmp_word
	beq :+
	lda #0
	:
	rts
@match_single_char_ins:
	jsr tolower
	sta @tmp_word
	txa
	jsr tolower
	cmp @tmp_word
	beq :+
	lda #0
	:
	rts
@tmp_word:
	.word 0
	
tolower:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	adc #'a' - 'A' ; carry clear
	:
	rts

match_dot:
	cmp #CARRIAGE_RETURN
	bne :++
	:
	lda #0
	rts
	:
	cmp #LINE_FEED
	beq :--
	
	lda #1
	rts

match_whitespace:
	cmp #$9 ; \t
	bne :+
	rts
	:
	cmp #' '
	bne :+
	rts
	:
	jmp match_dot ; if not one of these, just see if the line breaks match
	
match_not_whitespace:
	jsr match_whitespace
invert_match:
	cmp #0
	beq :+
	lda #0
	rts
	:
	lda #1
	rts

match_word:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	rts ; A-Z
	:
	
	cmp #'a'
	bcc :+
	cmp #'z' + 1
	bcs :+
	rts ; a-z
	:
	
	cmp #'_'
	bne :+
	rts
	:
	
	jmp match_digit

match_not_word:
	jsr match_word
	jmp invert_match

match_digit:
	cmp #'0'
	bcc :+
	cmp #'9' + 1
	bcs :+
	rts ; return non-zero
	:
	lda #0
	rts

match_not_digit:
	jsr match_digit
	jmp invert_match

match_any:
	lda #1
	rts

;
; epsilon_transition
; this is hardcoded, you need to use this epsilon
;	
epsilon_transition:
	lda #0
	rts

;
; Error message
;
file_err_str_p1:
	.asciiz "grep: "
file_err_str_p2:
	.byte ": No such file or directory", NEWLINE, 0

invalid_flag_err_str:
	.asciiz "grep: unrecognized flag '-"

	
.SEGMENT "BSS"

TEMP_BUFF_SIZE = 512

temp_buff:
	.res TEMP_BUFF_SIZE
temp_buff_end:

built_regex_activated:
	.res 256
built_regex_activated_next:
	.res 256

built_regex_ptrs_list_size:
	.word 0
built_regex_ptrs_list:
	.res 256 * 2
built_regex_data:
; data will go here
