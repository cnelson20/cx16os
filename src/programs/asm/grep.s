.include "routines.inc"
.feature  c_comments

CARRIAGE_RETURN = $0D
LINE_FEED = $0A
NEWLINE = LINE_FEED

r0 := $02
r1 := $04
r2 := $06
r3 := $08

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
	cmp #2
	bcs :+
	lda #1
	rts
	:
	
	jsr get_next_arg
	ldx args_pointer
	jsr build_regex_from_str
	
	jsr get_next_arg
	ldx args_pointer
	jsr match_str
	
	jsr GET_HEX_NUM
	txa
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	
	lda #0
	rts

args_pointer:
	.word 0
argc:
	.word 0

get_next_arg:
	ldx args_pointer
	dex
	:
	inx
	lda $00, X
	bne :-
	inx
	stx args_pointer
	rts

TRANSITION_DATA_SIZE = STATE_TGT_IND_OFFSET + 2

MATCH_FUNCTION_OFFSET = 0
INDEX_ARG_OFFSET = 2
STATE_TGT_IND_OFFSET = 4

match_str:
	stx ptr0
	ldx #1
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
	ldy #4
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
	ldy #2
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
	ldy #4
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
	
build_regex_from_str:
	stx ptr0 ; store string
	ldx #built_regex_ptrs_list
	stx ptr1 ; current state
	ldx #0
	stx ptr3 ; state index
	ldx #built_regex_data
	stx ptr2 ; current transition
	stx built_regex_ptrs_list + 0
	
	stz built_regex_ptrs_list_size
	stz built_regex_ptrs_list_size + 1
	
	stz @last_char_was_backslash
	
@loop:
	ldx ptr0
	lda $00, X
	bne :+
	jmp @end_str
	:
	inx
	stx ptr0
	
	ldx @last_char_was_backslash
	beq :+
	ldy #0
	jsr backslash_char_mapping
	bra @set_match_fxn
	:
	cmp #'\'
	bne :+
	lda #1
	sta @last_char_was_backslash
	bra @loop
	:
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
	; add epsilon transition
	lda ptr3
	inc A
	jsr add_epsilon_transition
	; end of this state's transition list
	jsr add_end_list_transition
	pla
	cmp #'*'
	beq @star_qualifier
	jmp @loop
@star_qualifier:
	lda ptr3
	dec A
	jsr add_epsilon_transition
	jmp @loop
	
@end_str:
	ldx ptr2
	stz $00, X
	stz $01, X
	inx
	inx
	stx ptr2
	stz $00, X
	stz $01, X
	
	lda ptr3
	inc A
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
	rts

@last_char_was_backslash:
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
	
	stz $00, X
	inx
	stz $00, X
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
	
	ldy #0 ; default char mapping
	rts

normal_char_match_mapping:
	cmp #'.'
	bne :+
	ldy #match_dot
	rts
	:
	rts

;
; Different transition functions
;
match_single_char:
	stx @tmp_word
	cmp @tmp_word
	beq :+
	lda #0
	:
	rts
@tmp_word:
	.word 0

match_dot:
	cmp #CARRIAGE_RETURN
	bne :+
	rts
	:
	cmp #LINE_FEED
	bne :+
	rts
	:
	lda #0
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

;
; epsilon_transition
; this is hardcoded, you need to use this epsilon
;	
epsilon_transition:
	lda #0
	rts

testing_regex:
	.asciiz "a*b"

testing_match_str:
	.asciiz "aaaab"
	
.SEGMENT "BSS"

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