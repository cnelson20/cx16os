.include "routines.inc"
.feature  c_comments

.segment "CODE"

TWO_INPUT_FILES_ERR = 1
FILE_DOESNT_EXIST_ERR = 2
OPEN_WRITE_FAIL_ERR = 3

SINGLE_QUOTE = 39

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

C_INSTRUCTION = 0
C_LABEL = 1
C_DIRECTIVE = 2

C_DIRECTIVE_PROCESSED = 3

; format for C_DIRECTIVE_PROCESSED
; C_DIRECTIVE_PROCESSED | 2 bytes SIZE | SIZE bytes DATA |

init:
    jsr get_args
    sta ptr0
    stx ptr0 + 1

    sty argc

    ; arg pointer in .X ;
    rep #$10
    .i16

    ; default settings
    ldx #$A300
    stx starting_pc
	
	ldx #a_out_str
	stx output_filename_pointer

    ldx ptr0
parse_args:
    dec argc
    bne :+
    jmp end_parse_args
    :

    ; next arg ;
    ldx ptr0
    jsr next_arg
    stx ptr0
	
	; -o flag ;
    stp
	lda $00, X
    cmp #'-'
    bne @not_output_flag
    inx
	lda $00, X
	cmp #'o'
    bne @not_output_flag
@output_flag:	
	dec argc
	bne :+
	jmp flag_invalid_argument
	:
	
    ldx ptr0
    jsr next_arg
    stx ptr0

    stx output_filename_pointer

    jmp parse_args
@not_output_flag:

    lda input_fd
    beq :+
    lda #TWO_INPUT_FILES_ERR
    jmp gen_error
    :

    ldx ptr0 + 1
    lda ptr0
    ldy #0
    jsr open_file
    sta input_fd
    cmp #$FF
    bne :+

    lda #FILE_DOESNT_EXIST_ERR
    jmp gen_error

    :
    jmp parse_args

next_arg:
    :
    lda $00, X
    beq :+
    inx
    bne :-
    :
    lda $00, X
    bne :+
    inx
    bne :-
    :
    rts

end_parse_args:
    ; do first pass ;
    stz eof_flag

    ldx #$A000
    stx lines_extmem_ptr
    stx extmem_data_ptr

    jsr res_extmem_bank
    sta lines_extmem_bank
    inc A
    sta last_extmem_data_bank

	lda #1
	jsr print_parse_msg
first_parse:
    jsr get_next_line_input
    
    ldx #line_buf
    jsr find_non_whitespace
    stx ptr0

    jsr find_comment
    stz $00, X

    ldx ptr0
    jsr find_last_whitespace
    stz $00, X

    ldx ptr0
    lda $00, X
    bne :+
    jmp @end_parse_line ; empty line
    :

    cmp #'.'
    beq @parse_directive

    jsr strlen
    ; start of line still in .X
    dey
    lda $00, Y
    cmp #':'
    bne :+
    jmp @parse_label
    :
    jmp @parse_instruction

@parse_directive:
    inx
    jsr find_whitespace_char
    lda $00, X
    bne :+

    jmp first_parse_error
    
    :
    phx
    inx
    jsr find_non_whitespace
    lda $00, X
    bne :+

    plx
    jmp first_parse_error

    :
    stx ptr1
    plx
    stz $00, X

    ldx ptr0
    inx
    stx ptr0
    jsr strlen
    sta ptr2

    ldx ptr1
    jsr strlen
    clc
    adc ptr2 ; add length of other string
    adc #3 ; \0, \0, C_DIRECTIVE
    jsr alloc_extmem_space_for_line

    stx ptr2
    jsr set_extmem_wbank

    lda #ptr2
    jsr set_extmem_wptr

    ldy #0
    lda #C_DIRECTIVE
    jsr writef_byte_extmem_y

    iny
    ldx ptr0
    :
    stx ptr0
    lda (ptr0)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    iny
    ldx ptr1
    :
    stx ptr1
    lda (ptr1)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    jmp @end_parse_line

@parse_label:
    lda #0
    sta $00, Y

    ldx ptr0
    jsr strlen
    clc
    adc #2 ; \0 + C_LABEL
    jsr alloc_extmem_space_for_line

    stx ptr1
    jsr set_extmem_wbank

    lda #ptr1
    jsr set_extmem_wptr

    ldy #0
    lda #C_LABEL
    jsr writef_byte_extmem_y

    iny
    ldx ptr0
    :
    stx ptr0
    lda (ptr0)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    jmp @end_parse_line    

@parse_instruction:
    txy
    iny
    iny
    iny
    lda $00, Y
    jsr is_whitespace_char
    bcs :+
    ; not whitespace, error
    jmp first_parse_error
    :
    lda $00, Y
    pha
    lda #0
    sta $00, Y

    sty ptr1

    jsr makeupper ; instructions are all in table as uppercase

    jsr get_instr_num
    sta @curr_instr_num
    cmp #$FF
    
    pla
    ldx ptr1 ; byte that was there was in .A
    sta $00, X
    
    bcc :+ ; if num was $FF, carry will be set
    jmp first_parse_error
    :

    ; ptr1 in .X
    jsr find_non_whitespace
    stx ptr1
@find_addr_mode:
    lda $00, X
    bne :+
    ; implied addressing mode
    ;stx ptr1
    lda #MODE_IMP
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'#'
    bne :+
    ; immediate addressing mode
    inx
	jsr find_non_whitespace
    stx ptr1
    lda #MODE_IMM
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'('
    bne @not_ind_addressing
@ind_addressing:
    inx
    stx ptr1
    lda #')'
    jsr strchr
    cpx #0
    bne :+
    jmp first_parse_error ; no matching )
    :
    txy
    ldx ptr1
    lda #','
    jsr strchr
    cpx #0
    bne :+

    lda #0
    sta $00, Y
    lda #MODE_IND
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    stx ptr2
    cpy ptr2 ; is ) after the , ?
    bcc @ind_y_addressing ; either (ind, X) or (ind), Y
@ind_x_addressing:
    stz $00, X

    lda #MODE_INX
    sta @curr_instr_mode
    jmp @found_addr_mode
@ind_y_addressing:
    lda #0
    sta $00, Y
    
    lda #MODE_INY
    sta @curr_instr_mode
    jmp @found_addr_mode

@not_ind_addressing:
    stx ptr1
    lda #','
    jsr strchr
    cpx #0
    bne @not_abs_addressing

    ldx ptr1
    jsr strlen
    cmp #1
    bne @not_accum_addressing

    lda $00, X
    cmp #'A'
    beq :+
    cmp #'a'
    bne @not_accum_addressing
    :

    inx
    stx ptr1

    lda #MODE_ACC
    sta @curr_instr_mode
    jmp @found_addr_mode
@not_accum_addressing:
	lda @curr_instr_num
	jsr is_branching_instruction
	beq :+
	
	lda #MODE_REL
	sta @curr_instr_mode
	jmp @found_addr_mode

	:
    lda #MODE_ABS
    sta @curr_instr_mode
    jmp @found_addr_mode
@not_abs_addressing:
    stz $00, X
    inx
    jsr find_last_whitespace
    dex
    jsr makeupper
    lda $00, X
    cmp #'Y'
    bne :+
    
    lda #MODE_ABY
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'X'
    bne :+

    lda #MODE_ABX
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    ; no such addr mode ;
    jmp first_parse_error
@found_addr_mode:
    lda #'$'
    jsr CHROUT

    lda @curr_instr_num
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda #' '
    jsr CHROUT
    lda #'$'
    jsr CHROUT
    
    lda @curr_instr_mode
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda #' '
    jsr CHROUT
    lda #'"'
    jsr CHROUT

    lda ptr1
    ldx ptr1 + 1
    jsr print_str

    lda #'"'
    jsr CHROUT
    lda #$d
    jsr CHROUT

    ldx ptr1
    jsr strlen
    clc
    adc #4 ; \0, instr_mode, inst_num, C_INSTRUCTION
    jsr alloc_extmem_space_for_line


    stx ptr2

    jsr set_extmem_wbank

    lda #ptr2
    jsr set_extmem_wptr

    ldy #0
    lda #C_INSTRUCTION
    jsr writef_byte_extmem_y

    iny
    lda @curr_instr_num
    jsr writef_byte_extmem_y

    iny
    lda @curr_instr_mode
    jsr writef_byte_extmem_y

    iny
    ldx ptr1
    :
    lda (ptr1)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    stx ptr1
    bne :-
    :

    jmp @end_parse_line

@end_parse_line:
    lda eof_flag
    bne :+
    jmp first_parse
    :
	bra second_parse

@curr_instr_num:
    .byte 0
@curr_instr_mode:
    .byte 0

second_parse:
	lda #2
	jsr print_parse_msg

    ldx starting_pc
    stx current_pc
    
    jsr res_extmem_bank
    sta labels_values_banks + 0

    ldx #0
    stx labels_values_banks_last_index

    ldx #$A000
    stx ptr0

@second_parse_loop:
    jsr start_second_third_parse_loop_iter
    cmp #C_INSTRUCTION
    bne @not_directive

    ; C_INSTRUCTION INSTR_NUM INSTR_MODE
    ldy #1
    rep #$20
    .a16
    jsr readf_byte_extmem_y ; get INSTR_NUM and INSTR_MODE
    sta ptr2 ; write to ptr2
    and #$FF00 ; we want INSTR_MODE
    xba
    tax
    lda instruction_mode_lengths, X
    and #$00FF
    clc
    adc current_pc
    sta current_pc

    sep #$20
    .a8
    ; Most indirect addressing instructions use 2 bytes, but JMP and JSR (ind) and (ind,x) use 3.
    lda ptr2 + 1 ; INSTR_MODE
    cmp #MODE_IND
    beq :+
    cmp #MODE_INX
    beq :+
    jmp @end_second_parse_loop_iter
    :

    lda ptr2 ; INSTR_NUM
    cmp #INSTR_JMP
    beq :+
    cmp #INSTR_JSR
    bne :++
    :
    ldx current_pc ; increment pc if INSTR_MODE = MODE_IND or MODE_INX, INSTR_NUM = jmp or jsr
    inx
    stx current_pc
    :

    jmp @end_second_parse_loop_iter

@not_directive:
    cmp #C_LABEL
    bne @second_parse_directive

@second_parse_label:
    ; set value of label
    ldx #line_buf
    ldy #1
    :
    jsr readf_byte_extmem_y
    sta $00, X
    cmp #0
    beq :+
    inx
    iny
    bne :-
    :

    ldx #line_buf
    ldy current_pc
    jsr set_label_value

    jmp @end_second_parse_loop_iter

@second_parse_directive:
    ; decipher if directive has data
    ; first copy data to prog mem to make stuff easier ;
    ldx #line_buf
    ldy #1
    :
    jsr readf_byte_extmem_y
    sta $00, X
    cmp #0
    beq :+
    inx
    iny
    bne :-
    :
    inx
    iny ; increment .X & .Y so string isn't appended
    :
    jsr readf_byte_extmem_y
    sta $00, X
    cmp #0
    beq :+
    inx
    iny
    bne :-
    :

    ldx #line_buf
    jsr get_directive_num
    cmp #$FF ; is this a valid directive
    bne :+
    jmp invalid_directive_err
    :
    xba
    lda #0
    xba
    tax
    lda directive_data_lens, X
    bne :+
    jmp @end_second_parse_loop_iter ; these have no data
    :
    
    cmp #$FF
    beq @determine_data_size

    ; data size = ( # of entries ) << (.A - 1)
    ; # of entries = # of commas + 1
    ; count commas in str
    sta @data_size_shifts

    ldx #line_buf
    jsr strlen
    iny ; point to data part of directive
    ; now we can count commas in rest of the string
    ldx #1
@count_comma_loop:
    lda $00, Y
    beq @end_count_comma_loop
    cmp #','
    bne :+
    inx ; found a comma
    :
    iny
    bne @count_comma_loop
@end_count_comma_loop:
    rep #$20
    .a16
    txa ; number of commas
    
    ; shift .A left (@data_size_shifts - 1) times
    :
    dec @data_size_shifts
    beq :+ ; end of loop
    asl A
    bra :-
    :

    clc
    adc current_pc
    sta current_pc

    sep #$20
    .a8

    jmp @end_second_parse_loop_iter
@data_size_shifts:
    .word 0

@determine_data_size:
    txa
    sta @data_size_shifts ; store DIR_NUM to tmp variable if needed

    cmp #DIR_STR
    beq :+
    cmp #DIR_STRZ
    beq :+
    jmp @not_str_directive ; if matches neither, branch ahead
    :
    ; find quotes
    ldx #line_buf
    jsr strlen
    tyx
    inx ; go to first char of data
    stx ptr1
    jsr find_non_whitespace
    lda $00, X
    cmp #'"'
    beq :+
    jmp str_not_quoted_error
    :
    stx ptr1
    jsr find_last_whitespace
    dex
    lda $00, X
    cmp #'"'
    beq :+
    jmp str_not_quoted_error
    :
    stz $00, X
    ldx ptr1
    inx ; go past quote
	stx ptr1
    jsr strlen
    ldy @data_size_shifts
    cpy #DIR_STRZ
    bne :+
    inc A ; add one for \0 byte
    :
    pha
	rep #$21 ; clear carry
    .a16
    and #$00FF
    adc current_pc
    sta current_pc
    sep #$20
    .a8
	pla
	pha ; push data size back to stack
	clc
	adc #3 ; 3 bytes: C_DIRECTIVE_PROCESSED & 2 bytes for size of data
    ; we are going to set entry in lines table to include data, so we don't have to do it later
    jsr alloc_extmem_data_space
	; pointer in .X
	stx ptr2
	sta r2 ; for memmove_extmem later, dest bank
	pha ; push data bank
	
	lda #ptr0
	jsr set_extmem_wptr
	lda lines_extmem_bank
	jsr set_extmem_wbank
	
	ldy ptr0
	dey
	dey
	dey
	sty ptr0 ; ptr0 -= 3 so points to this line's entry in mem
	
	pla ; pull data bank
	ldy #0
	jsr writef_byte_extmem_y
	
	iny ; y = 1
	rep #$20
	.a16
	lda ptr2
	jsr writef_byte_extmem_y
	clc
	adc #3 ; add three for same reason
	sta r0 ; dest ptr
	
	lda ptr0 ; add 3 back so next line pulled is the actual next line
	clc
	adc #3
	sta ptr0
	sep #$20
	.a8
	
	lda #ptr2
	jsr set_extmem_wptr
	lda r2 ; dest bank
	jsr set_extmem_wbank
	
	ldy #0
	lda #C_DIRECTIVE_PROCESSED
	jsr writef_byte_extmem_y
	
	pla
	pha ; pull data size off stack and push back
	iny
	rep #$20
	.a16
	and #$00FF
	jsr writef_byte_extmem_y
	sep #$20
	.a8
	
	lda #0
	sta r3 ; src bank
	
	ldx ptr1
	stx r1 ; src ptr
	
	ldx #0
	pla ; pull data size back off stack
	jsr memmove_extmem
    
    bra @end_second_parse_loop_iter

@not_str_directive:
	cmp #DIR_RES
	bne @not_res_directive
	
	bra @end_second_parse_loop_iter
@not_res_directive:
	; error here, invalid directive
    jmp invalid_directive_err

@end_second_parse_loop_iter:
    lda #'$'
    jsr CHROUT
    
    lda current_pc + 1
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda current_pc
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT
    
    lda #$d
    jsr CHROUT

    ldx ptr0 ; lines_extmem_ptr through loop
    cpx lines_extmem_ptr
    bcs :+
    jmp @second_parse_loop
    :

third_parse:
	lda #3
	jsr print_parse_msg
	
    ; open file for output
    lda output_filename_pointer
    ldx output_filename_pointer + 1
    ldy #'W' ; open file for writing
    jsr open_file
    cmp #$FF
    bne :+
    ; error occurred
    lda #OPEN_WRITE_FAIL_ERR
    jmp gen_error
    :
    sta output_fd
	
	ldx starting_pc
	stx current_pc
	
	ldx #$A000
    stx ptr0

@third_parse_loop:
	; this code identical to start of second_parse_loop
    jsr start_second_third_parse_loop_iter
	; have type of command (instruction / directive / label) in .A
	; ptr1 contains entry and extmem rbank & rptr calls are done	
	;ldy #0
	;jsr readf_byte_extmem_y
	cmp #C_LABEL
	bne :+
	jmp @end_third_parse_loop_iter ; don't need to touch labels
	:	
	cmp #C_DIRECTIVE_PROCESSED
	bne :+
	jmp @third_parse_processed_directive
	:
	cmp #C_DIRECTIVE
	bne :+
	jmp @third_parse_unprocessed_directive
	:
	
	cmp #C_INSTRUCTION
	beq @third_parse_instruction
	
	; Error, one of the following branches should have occured
	; TODO maybe handle this better?
	jmp @end_third_parse_loop_iter
	
@third_parse_instruction:
	ldy #3
	ldx #line_buf
	:
	jsr readf_byte_extmem_y
	sta $00, X
	cmp #0
	beq :+
	inx
	iny
	bne :-
	:
	
	ldy #1
	rep #$20
	.a16
	jsr readf_byte_extmem_y
	sta ptr2
	and #$00FF
	sep #$20
	.a8
	
	jsr get_instruction_opcode
	jsr write_byte_output
	
	lda #0
	xba
	lda ptr2 + 1 ; INSTR_MODE
	tax
	lda instruction_mode_lengths, X
	cmp #1
	bne @not_implied_instruction
	jmp @end_third_parse_loop_iter ; instruction is just 1 byte of opcode
@not_implied_instruction:
	phx
	ldx #line_buf
	jsr determine_symbol_value
	
	ply
	lda instruction_mode_lengths, Y
	cmp #3
	beq :+
	lda ptr2 
	cmp #INSTR_JMP
	beq :+
	cmp #INSTR_JSR
	beq :+
	bra @two_byte_instruction
	:
	; absolute / absolute, X / absolute, Y / (absolute) / (absolute, X)
	jsr write_word_output
	jmp @end_third_parse_loop_iter

@two_byte_instruction:
	; Either zp or relative addressing
	lda ptr2 + 1
	cmp #MODE_REL
	bne @not_relative_addressing
	
	; range error possibly
	; lda #127
	rep #$21 ; clear carry
	.a16
	lda current_pc ; already wrote one byte, so - 1 this
	adc #2 - 1 ; branching zero takes you to start of next instruction, 2 bytes ahead
	sta ptr2
	txa ; instruction argument
	sec
	sbc ptr2
	cmp #$0080
	bcc :+ ; in range [FF80 - 007F]
	cmp #$FF80
	bcs :+	
	sep #$20
	.a8
	lda #127
	ldx #line_buf
	jmp range_error
	:
	sep #$20
	.a8
	jsr write_byte_output
	jmp @end_third_parse_loop_iter
	
@not_relative_addressing:	
	cpx #$0100
	bcc :+
	; range error
	lda #255
	ldx #line_buf
	jmp range_error
	:
	txa
	jsr write_byte_output
	jmp @end_third_parse_loop_iter

@third_parse_processed_directive:
	iny
	rep #$20
	.a16
	jsr readf_byte_extmem_y
	tax
	sep #$20
	.a8
	ldy #3
@write_loop:
	cpx #0
	bne :+
	jmp @end_third_parse_loop_iter
	:
	jsr readf_byte_extmem_y
	phx
	phy
	jsr write_byte_output
	ply
	plx
	iny
	dex
	bra @write_loop
	
@third_parse_unprocessed_directive:
	; first copy data to prog mem to make stuff easier ;
    ldx #line_buf
    ldy #1
    :
    jsr readf_byte_extmem_y
    sta $00, X
    cmp #0
    beq :+
    inx
    iny
    bne :-
    :
    inx
    iny ; increment .X & .Y so string isn't appended
    :
    jsr readf_byte_extmem_y
    sta $00, X
    cmp #0
    beq :+
    inx
    iny
    bne :-
    :
	; a lot of this code is copied from second_parse_directive ;
	; let's look at the directive ;
	ldx #line_buf
    jsr get_directive_num
    cmp #$FF ; Has been checked before but why not do it again
    bne :+
    jmp invalid_directive_err
    :
	xba
    lda #0
    xba
    tax
    lda directive_data_lens, X
    beq :+
	cmp #$FF ; $FF's should have been parsed already
	bne :++
	:
    jmp @end_third_parse_loop_iter ; these have no data, can ignore
    :
	jsr handle_fixed_len_directives_data
	jmp @end_third_parse_loop_iter

@end_third_parse_loop_iter:	
	ldx ptr0 ; lines_extmem_ptr through loop
    cpx lines_extmem_ptr
    bcs :+
    jmp @third_parse_loop
    :
@end_third_parse:
    lda output_fd
    jsr close_file
	
    lda #0
    rts

LABEL_VALUE_SIZE = 32

handle_fixed_len_directives_data:
	sta @data_size
	
	lda #1
	sta @expecting_value
	sta @first_element
	
	ldx #line_buf
	jsr strlen
	iny
	tyx
	stx ptr1
@data_loop:
	jsr find_non_whitespace
	lda $00, X
	beq @end_data_loop
	stx ptr2
	
	cmp #','
	bne @search_for_symbols
@found_comma:
	lda @expecting_value
	beq :+
	jmp invalid_directive_err
	:
	inx
	lda $00, X
	beq @end_data_loop
	jsr is_whitespace_char
	bne :+
	jmp invalid_directive_err
	:
	lda #1
	sta @expecting_value
	bra @data_loop
@search_for_symbols:
	lda @expecting_value
	bne :+
	jmp invalid_directive_err
	:
	phx
	jsr find_whitespace_char_or_comma
	txy
	plx
	lda $00, Y
	pha
	phy
	lda #0
	sta $00, Y
	jsr determine_symbol_value
	ply
	pla
	sta $00, Y
	phy
	
	lda @data_size
	cmp #1
	bne :++
	cpx #$0100
	bcc :+
	; range error
	lda #0
	sta $00, Y
	ldx ptr2
	lda #255
	jmp range_error
	:
	txa
	jsr write_byte_output
	bra @done_writing_directive_data
	:
	jsr write_word_output
	lda @data_size
	cmp #4 ; either 2 or 4 bytes
	bne @done_writing_directive_data
	ldx #0
	jsr write_byte_output ; 2 blank padding bytes
@done_writing_directive_data:
	stz @expecting_value
	stz @first_element
	plx
	jmp @data_loop
	
@end_data_loop:
	lda @first_element
	beq :+
	jmp invalid_directive_err ; need at least one element
	:
	
	rts
	
@data_size:
	.word 0
@expecting_value:
	.word 0
@first_element:
	.word 0

write_word_output:
	phx
	txa
	jsr write_byte_output
	
	plx
	rep #$20
	.a16
	txa
	sep #$20
	.a8
	xba
	jmp write_byte_output
	
write_byte_output:
	ldx output_fd
	jsr fputc
	
	ldx current_pc
	inx
	stx current_pc
	rts

start_second_third_parse_loop_iter:
	lda lines_extmem_bank
    jsr set_extmem_rbank

    lda #ptr0
    jsr set_extmem_rptr

    ldx ptr0
    ldy #0
    jsr readf_byte_extmem_y
    pha
    
    inx
    stx ptr0
    jsr readf_byte_extmem_y
    sta ptr1

    inx
    stx ptr0
    jsr readf_byte_extmem_y
    sta ptr1 + 1

    inx
    stx ptr0

    pla
    jsr set_extmem_rbank

    lda #ptr1
    jsr set_extmem_rptr

    ; get type of command (instruction / directive / label)
    
    ldy #0
    jmp readf_byte_extmem_y ; return to caller after fetching byte from extmem
	

get_instruction_opcode:
	ldx ptr2
	phx
	
	lda #0
	xba
	lda ptr2 + 1
	tax
	
	stz ptr2 + 1
	rep #$20
	.a16
	asl ptr2
	asl ptr2
	lda ptr2
	asl A
	clc
	adc ptr2
	stx ptr2
	adc ptr2
	tax
	.a8
	sep #$20
	
	lda instruction_modes, X
	plx
	stx ptr2
	cmp #$FF
	; if $FF, invalid addressing mode, error
	beq :+
	rts
	:
@invalid_addressing_mode:
	jsr print_gen_err_str
	
	lda #<@invalid_addr_mode_str
	ldx #>@invalid_addr_mode_str
	jsr print_str
	
	lda ptr2
	rep #$20
	.a16
	and #$00FF
	asl A
	asl A
	adc #instruction_strs
	xba
	tax
	xba
	sep #$20
	.a8

	jsr print_str
	
	lda ptr2 + 1
	cmp #MODE_IMP
	beq :+
	
	lda #' '
	jsr CHROUT
	
	:
	lda ptr2 + 1
	cmp #MODE_IMM
	bne :+
	lda #'#'
	jsr CHROUT
	:
	lda ptr2 + 1
	cmp #MODE_ACC
	bne :+
	lda #'A'
	jsr CHROUT
	:
	
	lda #0
	xba
	lda ptr2 + 1
	tax
	lda @print_paren_flags, X
	beq :+
	lda #'('
	jsr CHROUT
	:	
	phx
	
	lda ptr2 + 1
	cmp #MODE_IMP
	beq :+
	cmp #MODE_ACC
	beq :+
	lda #<line_buf
	ldx #>line_buf
	jsr print_str
	:
	
	plx
	lda @print_x_flags, X
	beq :+
	lda #','
	jsr CHROUT
	lda #'X'
	jsr CHROUT
	:
	
	lda @print_paren_flags, X
	beq :+
	lda #')'
	jsr CHROUT
	:
	
	lda @print_y_flags, X
	beq :+
	lda #','
	jsr CHROUT
	lda #'Y'
	jsr CHROUT
	:
	
	jmp print_quote_terminate

@print_paren_flags:
	.byte 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0
@print_x_flags:
	.byte 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0
@print_y_flags:
	.byte 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0

@invalid_addr_mode_str:
	.asciiz "Invalid addressing mode '"

;
; determine_symbol_value
; returns the value (in .X) of a label. if there are errors parsing, will not return
;
determine_symbol_value:
	lda $00, X
	cmp #'<'
	bne @not_low_byte
	; take low byte of rest
	inx
	jsr determine_symbol_value
	txa
	rep #$20
	.a16
@clear_high_byte_tax_return:
	and #$00FF
	tax
	sep #$20
	.a8
	rts	
@not_low_byte:
	cmp #'>'
	bne @not_high_byte
	; take low byte of rest
	inx
	jsr determine_symbol_value
	rep #$20
	txa
	xba ; dont .a16 here so nothing gets screwed up in below code
	bra @clear_high_byte_tax_return
@not_high_byte:
	; $ means hex
	; 0-9 means number
	; otherwise means label
	cmp #'$'
	beq @parse_number
	cmp #'0'
	bcc @not_number
	cmp #'9' + 1
	bcs @not_number
@parse_number:
	rep #$20
	.a16
	txa
	sep #$20
	.a8
	xba
	tax
	xba
	jsr parse_num
	xba
	txa ; lower byte of .X to .A
	xba ;switch back
	tax ; transfer all 16 bits of .C to .X
	rts ; return
	
@not_number:
	; try looking for label
	phx
	jsr find_label_value
	cmp #0
	beq :+
	ply
	rts ; if it was found, just return value in .X
	:
	; Error!
	plx ; pull symbol that is undefined
	jmp undefined_symbol_err

;
; str in .X, value as int in .Y
; errors if label is already defined
;
set_label_value:
    phx
    phy
    jsr find_label_value
    ply
    plx
    cmp #0
    beq :+ 
    ; label already defined
    jmp label_already_defined_err
    :

    stx tmp_label
    sty tmp_value

    ldx labels_values_banks_last_index
    lda labels_values_banks, X
    jsr set_extmem_wbank

    lda #ptr0
    jsr set_extmem_wptr

    ldx ptr0
    phx ; save ptr0

    ldx labels_values_ptr
    stx ptr0

    ldy #30
    rep #$20
    .a16
    lda tmp_value
    jsr writef_byte_extmem_y
    sep #$20
    .a8

    ldy #0
    ldx tmp_label
    :
    lda $00, X
    beq :+
    jsr writef_byte_extmem_y
    inx
    iny
    cpy #29
    bcc :- ; loop back if not \0 or reached label length limit
    :
    lda #0
    jsr writef_byte_extmem_y

    plx
    stx ptr0
    ; increment labels_values_ptr by $20
    
    rep #$21
    .a16
    lda labels_values_ptr
    ; carry cleared from 
    adc #LABEL_VALUE_SIZE
    sta labels_values_ptr
    sep #$20
    .a8
    ldx labels_values_ptr
    cpx #$C000
    bcs :+
    rts
    :   

    ldx labels_values_banks_last_index
    lda labels_values_banks, X
    and #1
    beq :+

    jsr res_extmem_bank
    ldx labels_values_banks_last_index
    sta labels_values_banks, X

    bra :++
    :

    inc A
    inx
    sta labels_values_banks, X

    :
    inc labels_values_banks_last_index
    rts

;
; finds the value of a label passed in .X
; on return, .A holds whether it was found and .X holds the value (if it was)
;
find_label_value:
    stx tmp_label

    ldx ptr0
    phx

    ldx labels_values_banks_last_index
    stx @label_values_banks_index

    lda labels_values_banks, X
    jsr set_extmem_rbank

    ldx labels_values_ptr
    stx ptr0

    lda #ptr0
    jsr set_extmem_rptr

@check_loop:
    rep #$20
    .a16
    lda ptr0
    sec
    sbc #LABEL_VALUE_SIZE
    sta ptr0
    sep #$20
    .a8
    ldx ptr0
    cpx #$A000
    bcs :+

    dec @label_values_banks_index
    bmi @end_check_loop
    ldx @label_values_banks_index
    lda labels_values_banks, X
    jsr set_extmem_rbank

    ldx #$C000 - 32
    stx ptr0

    :

    ldx tmp_label
    ldy #0
    jsr strcmp_mainmem_extmem
    bne @check_loop

@found_label:
    ldy #30
    rep #$20
    .a16
    jsr readf_byte_extmem_y ; get value
    tax
    sep #$20
    .a8
    lda #1
    bra @pull_off_stack

@end_check_loop:
    ldx #0
	txa ; lda #0

@pull_off_stack:
    ply
    sty ptr0
    rts

@label_values_banks_index:
    .word 0

tmp_label:
    .word 0
tmp_value:
    .word 0

labels_values_ptr:
    .word $A000
labels_values_banks_last_index:
    .word 0
labels_values_banks:
    .res 128

;
; compares a string in prog mem in .X to a string in extmem that has its bank/ptr calls already set up
; .Y should also be set by caller
;
strcmp_mainmem_extmem:
    :
    jsr readf_byte_extmem_y
    sec
    sbc $00, X
    bne :++ ; not equal, exit early
    lda $00, X
    beq :+ ; strings are equal
    inx
    iny
    bne :- ; check other characters in string

    :
    lda #0
    :
    rts

;
; gets the directive num for a string passed in .X
; .A = $FF if the directive is invalid, otherwise returns the number
;
get_directive_num:
    ; .X stays preserved throughout function

    ldy #directive_strs
    sty ptr1

    ldy #0
    sty @directive_strs_index

@compare_loop:
    ldy ptr1
    jsr strcmp
    cmp #0
    beq @found_dir

    ; not equal
    lda @directive_strs_index
    inc A
    cmp #DIRECTIVES_STRS_LEN
    bcc :+

    lda #$FF ; not found
    rts
    :
    sta @directive_strs_index

    rep #$21 ; clear carry
    .a16
    lda ptr1
    adc #DIRECTIVE_STRSIZE
    sta ptr1
    sep #$20
    .a8    
    
    bra @compare_loop
    
@found_dir:
    lda @directive_strs_index
    rts

@directive_strs_index:
    .word 0

get_next_line_input:
    ldy #0
    :
    phy
    ldx input_fd
    jsr fgetc
    ply
    cpx #0
    bne @read_err

    cmp #$d ; newline
    beq @newline

    sta line_buf, Y

    iny
    cpy #128
    bne :-

    dey

@newline:
    lda #0
    sta line_buf, Y

    rts

@read_err:
    jsr @newline 
    lda #1
    sta eof_flag

    rts

eof_flag:
    .word 0

next_extmem_data_bank:
    lda last_extmem_data_bank
    and #1
    bne :+

    lda last_extmem_data_bank
    inc A
    sta last_extmem_data_bank
    rts

    :
    jsr res_extmem_bank
    sta last_extmem_data_bank
    rts


alloc_extmem_space_for_line:
	jsr alloc_extmem_data_space
	pha ; preserve bank
	
	rep #$21 ; clear carry
	.a16
	lda lines_extmem_ptr
    adc #3
    sta lines_extmem_ptr
	sep #$20
	.a8
	
	pla
	rts
	
alloc_extmem_data_space:
    ; .A = size of data
    rep #$20
    .a16
    and #$00FF
    sta @data_size
    clc
    adc extmem_data_ptr
    tax
    sep #$20
    .a8
    cpx #$C000
    
    lda last_extmem_data_bank

    bcc :+
    ldx #$A000
    stx extmem_data_ptr
    jsr next_extmem_data_bank
    rep #$20
    .a16
    lda @data_size
    clc
    adc #$A000
    tax
    sep #$20
    .a8
    lda last_extmem_data_bank
    :

    phx
    pha

    lda lines_extmem_bank
    jsr set_extmem_wbank

    ldx #lines_extmem_ptr
    ldy #0
    pla
    pha
    jsr vwrite_byte_extmem_y

    iny
    lda extmem_data_ptr
    jsr vwrite_byte_extmem_y

    iny
    lda extmem_data_ptr + 1
    jsr vwrite_byte_extmem_y

    pla
    ldx extmem_data_ptr

    ply
    sty extmem_data_ptr
    rts

@data_size:
    .word 0

get_instr_num:
    ldy #0
    sty @min
    ldy #INSTRUCTION_LIST_SIZE
    sty @max
@loop:
    lda @min
    cmp @max
    bcc :+
    lda #$FF
    rts ; not found
    :
    adc @max
    lsr A
    sta @mid

    rep #$20
    .a16
    and #$00FF
    asl A
    asl A
    adc #instruction_strs
    tay
    sep #$20
    .a8
    jsr strcmp
    cmp #0
    beq @found

    bmi @before_alpha
@after_alpha:
    lda @mid
    inc A
    sta @min
    bra @loop
@before_alpha:
    lda @mid
    sta @max
    bra @loop
@found:
    lda @mid
    rts

@min:
    .word 0
@max:
    .word 0
@mid:
    .word 0


;
; compares str in .X to in .Y
;
strcmp:
    phx
    phy
    jsr @check_loop
    ply
    plx
    rts

@check_loop:
    lda $00, X
    cmp $00, Y
    bne @not_equal

    cmp #0
    bne :+
    rts
    :
    inx
    iny
    bra @check_loop
@not_equal:
    sec
    sbc $00, Y
    rts

;
; takes string in .X, returns length in .A and pointer to \0 at end of string in .Y
; preserves .X
;
strlen:
    phx
    ldy #0
    :
    lda $00, X
    beq :+
    iny
    inx
    bne :-
    :
    tya
    txy ; end of string goes into .Y
    plx
    rts

strchr:
    cmp $00, X
    beq @found
    pha
    lda $00, X
    beq :+
    pla
    inx
    bra strchr
    :
    pla
    ldx #0
    rts
@found:
    rts

is_whitespace_char:
    pha
    cmp #' '
    beq @yes
    cmp #9 ; \t
    beq @yes
    cmp #$a ; \n
    beq @yes
    cmp #0
    beq @yes
    cmp #$d ; \r
    beq @yes

    ; no
    clc
    pla
    rts
@yes:
    sec
    pla
    rts

makeupper:
    phx
@loop:
    lda $00, X
    beq @done
    cmp #'a'
    bcc :+
    cmp #'z' + 1
    bcs :+
    ; carry clear
    sbc #$20 - 1
    sta $00, X
    :
    inx
    bne @loop
@done:
    plx
    rts

;
; returns pointer to first non-whitespace character in .X, otherwise returns pointer to null terminator if there are none
;
find_non_whitespace:
    lda $00, X
    beq :+
    jsr is_whitespace_char
    bcs @cont
    :

    rts
@cont:
    inx
    bne find_non_whitespace
    rts

;
; returns pointer to first whitespace character in .X (returns null terminator if there are none)
;
find_whitespace_char:
    lda $00, X
    beq :+
    jsr is_whitespace_char
    bcc @cont
    :

    rts
@cont:
    inx
    bne find_whitespace_char
    rts

;
; finds first ';' in a string
;
find_comment:
    lda $00, X
    bne :+
    rts
    :
    cmp #';'
    beq :+
    inx
    bra find_comment

    :
    rts

;
; find_whitespace_char_or_comma
;
find_whitespace_char_or_comma:
    lda $00, X
    beq :+
	cmp #','
	beq :+
    jsr is_whitespace_char
    bcc @cont
    :

    rts
@cont:
    inx
    bne find_whitespace_char_or_comma
    rts

find_last_whitespace:
    ldy #1

    :
    lda $00, X
    beq :+
    iny
    inx
    bne :-

    :
    dey
    beq @start_str
    dex
    lda $00, X
    jsr is_whitespace_char
    bcs :-

    inx
    rts
@start_str:
    rts

is_branching_instruction:
	cmp #INSTR_BCC
	beq @yes
	cmp #INSTR_BCS
	beq @yes
	cmp #INSTR_BEQ
	beq @yes
	cmp #INSTR_BMI
	beq @yes
	cmp #INSTR_BNE
	beq @yes
	cmp #INSTR_BPL
	beq @yes
	cmp #INSTR_BVC
	beq @yes
	cmp #INSTR_BVS
	beq @yes
@no:	
	lda #0
	rts
@yes:
	lda #1
	rts

;
;
; Error functions
;
;

flag_invalid_argument:
	phx
	
	jsr print_gen_err_str
	
	plx
	lda argc
	beq :+
	
	phx
	lda #<@invalid_arg_str
	ldx #>@invalid_arg_str
	jsr print_str
	
	plx
	rep #$20
	.a16
	txa
	xba
	tax
	xba
	sep #$20
	.a8
	jsr print_str
	
	lda #<@for_flag_str
	ldx #>@for_flag_str
	jsr print_str
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	jmp print_quote_terminate
	
	:
	lda #<@flag_str
	ldx #>@flag_str
	jsr print_str
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	lda #<@needs_arg_str
	ldx #>@needs_arg_str
	jsr print_str
	
	jmp print_newline_exit
	
@flag_str:
	.asciiz "Flag '"
@needs_arg_str:
	.asciiz "' needs argument, none provided"
@invalid_arg_str:
	.asciiz "Invalid argument '"
@for_flag_str:
	.asciiz "' for flag '"
	
range_error:
	pha
	phx
	
	jsr print_gen_err_str
	
	plx
	phx
	
	lda $00, X
	cmp #'$'
	beq @value
	cmp #'0'
	bcc @symbol
	cmp #'9' + 1
	bcs @symbol
@value:
	lda #<@range_err_str_p1_value
	ldx #>@range_err_str_p1_value
	bra @print_symbol_value
@symbol:
	lda #<@range_err_str_p1_symbol
	ldx #>@range_err_str_p1_symbol
@print_symbol_value:
	jsr print_str
	
	rep #$20
	.a16
	pla
	xba
	tax
	xba
	.a8
	sep #$20
	jsr print_str
	
	lda #<@range_err_str_p2
	ldx #>@range_err_str_p2
	jsr print_str
	
	pla
	cmp #255
	bne :+
	
	lda #<@range_err_255
	ldx #>@range_err_255
	bra :++
	:
	lda #<@range_err_127
	ldx #>@range_err_127
	:
	jsr print_str
	jmp print_newline_exit

@range_err_str_p1_symbol:
	.asciiz "Symbol '"	
@range_err_str_p1_value:
	.asciiz "Value '"
@range_err_str_p2:
	.asciiz "' is out of range "
@range_err_255:
	.asciiz "[0,255]"
@range_err_127:
	.asciiz "for a branch instruction"

label_already_defined_err:
    phx

    jsr print_gen_err_str

    lda #<@label_already_defined_str_p1
    ldx #>@label_already_defined_str_p1
    jsr print_str

    plx
    rep #$20
    .a16
    txa
    sep #$20
    .a8
    xba
    tax
    xba
    jsr print_str

    lda #<@label_already_defined_str_p2
    ldx #>@label_already_defined_str_p2
    jsr print_str

    jmp print_newline_exit

@label_already_defined_str_p1:
    .asciiz "label '"
@label_already_defined_str_p2:
    .asciiz "' already defined"

undefined_symbol_err:
	stx ptr0
	
	jsr print_gen_err_str
	
	lda #<@undefined_symbol_err_str
	ldx #>@undefined_symbol_err_str
	jsr print_str
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	jmp print_quote_terminate
@undefined_symbol_err_str:
	.asciiz "Encountered undefined symbol '"

invalid_directive_err:
    jsr print_gen_err_str
    
    lda #<@invalid_dir_str
    ldx #>@invalid_dir_str
    jsr print_str
	
	jsr print_line_buf
	
	lda #' '
	jsr CHROUT
	
	ldx #line_buf
	jsr strlen
	iny
	rep #$20
	.a16
	tya
	sep #$20
	.a8
	xba
	tax
	xba
	jsr print_str
    jsr print_quote_terminate
@invalid_dir_str:
    .asciiz "Invalid directive: '."

first_parse_error:
    jsr print_gen_err_str

    lda #<@invalid_line_str
    ldx #>@invalid_line_str
    jsr print_str

    bra print_line_buf_quote_terminate
@invalid_line_str:
    .asciiz "Invalid line: '"

print_line_buf:
	lda #<line_buf
    ldx #>line_buf
    jmp print_str
	
print_line_buf_quote_terminate:
    jsr print_line_buf
print_quote_terminate:
    lda #SINGLE_QUOTE
    jsr CHROUT

    jmp print_newline_exit

str_not_quoted_error:
    jsr print_gen_err_str

    lda #<@str_not_quoted_str_p1
    ldx #>@str_not_quoted_str_p1
    jsr print_str    

    lda #<line_buf
    ldx #>line_buf
    jsr print_str

    lda #<@str_not_quoted_str_p2
    ldx #>@str_not_quoted_str_p2
    jsr print_str

    lda ptr1
    ldx ptr1 + 1
    jsr print_str

    lda #SINGLE_QUOTE
    jsr CHROUT

    jmp print_newline_exit

@str_not_quoted_str_p1:
    .asciiz "Directive '"
@str_not_quoted_str_p2:
    .asciiz "' must be followed by double-quoted string literal, instead followed by '"

print_parse_msg:
	xba
	lda #0
	xba
	asl A
	tax
	lda parse_strs, X
	pha
	inx
	lda parse_strs, X
	tax
	pla
	
	jsr print_str
	
	lda #<@parse_str_literal
	ldx #>@parse_str_literal
	jmp print_str

@parse_str_literal:
	.byte " parse:"
	.byte $d, 0

print_gen_err_str:
    lda #<general_err_str
    ldx #>general_err_str
    jmp print_str


gen_error:
    pha

    jsr print_gen_err_str
    
    lda #0
    xba
    pla
    asl A
    tax

    inx
    lda error_str_list, X
    tay
    dex
    lda error_str_list, X
    tyx
    jsr print_str

print_newline_exit:
    lda #$d
    jsr CHROUT 

    lda #1   

    ldx #$01FD
    txs
    rts

error_str_list:
    .word $FFFF, two_inputs_str, no_such_file_str, open_write_fail_str

two_inputs_str:
    .asciiz "Input file already provided"
no_such_file_str:
    .asciiz "No such file exists"
open_write_fail_str:
    .asciiz "Couldn't open output file for writing"
general_err_str:
    .asciiz "Error: "

parse_strs:
	.word 0, first_str, second_str, third_str
first_str:
	.asciiz "first"
second_str:
	.asciiz "second"
third_str:
	.asciiz "third"	

argc:
    .word 0
input_fd:
    .word 0
output_fd:
    .word 0
output_filename_pointer:
    .word 0
starting_pc:
    .word 0

current_pc:
    .word 0

a_out_str:
	.asciiz "a.out"

;
; strings for diff directives
;
directive_strs:
/* 0s equal to 5 - strlen */
    .byte "byte", 0
    .byte "word", 0
    .byte "dw", 0, 0, 0
    .byte "res", 0, 0
    .byte "equ", 0, 0
    .byte "str", 0, 0
    .byte "strz", 0

DIR_BYTE = 0
DIR_WORD = 1
DIR_DW = 2
DIR_RES = 3
DIR_EQU = 4
DIR_STR = 5
DIR_STRZ = 6

DIRECTIVES_STRS_LEN = 7
DIRECTIVE_STRSIZE = 5

; 0 means directive outputs no data into final program
; 1+ (excl. $FF) means data is in multiples of that many bytes
; $FF means data size varies (needs to calc'd)
directive_data_lens:
    .byte 1 ; byte, * 1 = << (1 - 1)
    .byte 2 ; word, * 2 = << (2 - 1)
    .byte 3 ; dw, * 4 = << (3 - 1)
    .byte $FF ; res
    .byte 0 ; equ
    .byte $FF ; str
    .byte $FF ; strz

;
; Instruction data ;
;
instruction_strs:
    .asciiz "ADC" ; 0
    .asciiz "AND" ; 1
    .asciiz "ASL" ; 2
    .asciiz "BCC" ; 3
    .asciiz "BCS" ; 4
    .asciiz "BEQ" ; 5
    .asciiz "BIT" ; 6
    .asciiz "BMI" ; 7
    .asciiz "BNE" ; 8
    .asciiz "BPL" ; 9
    .asciiz "BRK" ; 10
    .asciiz "BVC" ; 11
    .asciiz "BVS" ; 12
    .asciiz "CLC" ; 13
    .asciiz "CLD" ; 14
    .asciiz "CLI" ; 15
    .asciiz "CLV" ; 16
    .asciiz "CMP" ; 17
    .asciiz "CPX" ; 18
    .asciiz "CPY" ; 19
    .asciiz "DEC" ; 20
    .asciiz "DEX" ; 21
    .asciiz "DEY" ; 22
    .asciiz "EOR" ; 23
    .asciiz "INC" ; 24
    .asciiz "INX" ; 25
    .asciiz "INY" ; 26
    .asciiz "JMP" ; 27
    .asciiz "JSR" ; 28
    .asciiz "LDA" ; 29
    .asciiz "LDX" ; 30
    .asciiz "LDY" ; 31
    .asciiz "LSR" ; 32
    .asciiz "NOP" ; 33
    .asciiz "ORA" ; 34
    .asciiz "PHA" ; 35
    .asciiz "PHP" ; 36
    .asciiz "PHX" ; 37
    .asciiz "PHY" ; 38
    .asciiz "PLA" ; 39
    .asciiz "PLP" ; 40
    .asciiz "PLX" ; 41
    .asciiz "PLY" ; 42
    .asciiz "ROL" ; 43
    .asciiz "ROR" ; 44
    .asciiz "RTI" ; 45
    .asciiz "RTS" ; 46
    .asciiz "SBC" ; 47
    .asciiz "SEC" ; 48
    .asciiz "SED" ; 49
    .asciiz "SEI" ; 50
    .asciiz "STA" ; 51
    .asciiz "STP" ; 52
    .asciiz "STX" ; 53
    .asciiz "STY" ; 54
    .asciiz "STZ" ; 55
    .asciiz "TAX" ; 56
    .asciiz "TAY" ; 57
    .asciiz "TXY" ; 58
    .asciiz "TYX" ; 59
    .asciiz "TSX" ; 60
    .asciiz "TXA" ; 61
    .asciiz "TXS" ; 62
    .asciiz "TYA" ; 63
    .asciiz "WAI" ; 64

INSTRUCTION_LIST_SIZE = 65

;
; jsr & jmp have different lengths of IND & INX addressing so they need specific definitions
;
INSTR_JMP = 27
INSTR_JSR = 28

INSTR_BCC = 3
INSTR_BCS = 4
INSTR_BEQ = 5
;INSTR_BIT = 6
INSTR_BMI = 7
INSTR_BNE = 8
INSTR_BPL = 9
;INSTR_BRK = 10
INSTR_BVC = 11
INSTR_BVS = 12

MODE_IMP = 0
MODE_IMM = 1
MODE_ZP = 2
MODE_ZPX = 3
MODE_ABS = 4
MODE_ABX = 5
MODE_ABY = 6
MODE_IND = 7
MODE_INX = 8
MODE_INY = 9
MODE_ACC = 10
MODE_REL = 11

instruction_mode_lengths:
/* length */ .byte 1,   2,   2,   2,   3,   3,   3,   2,   2,   2,   1,   2

; MODE             IMP, IMM,  ZP, ZPX, ABS, ABX, ABY, IND, INX, INY, ACC, REL
instruction_modes:
/*  0 ADC */ .byte $ff, $69, $65, $75, $6d, $7d, $79, $72, $61, $71, $ff, $ff
/*  1 AND */ .byte $ff, $29, $25, $35, $2d, $3d, $39, $32, $21, $31, $ff, $ff
/*  2 ASL */ .byte $ff, $ff, $06, $16, $0e, $1e, $ff, $ff, $ff, $ff, $0a, $ff
/*  3 BCC */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $90
/*  4 BCS */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $B0
/*  5 BEQ */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $F0
/*  6 BIT */ .byte $ff, $ff, $24, $ff, $2c, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/*  7 BMI */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $30
/*  8 BNE */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $D0
/*  9 BPL */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $10
/* 10 BRK */ .byte $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 11 BVC */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $50
/* 12 BVS */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $70
/* 13 CLC */ .byte $18, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 14 CLD */ .byte $38, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 15 CLI */ .byte $58, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 16 CLV */ .byte $b8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 17 CMP */ .byte $ff, $c9, $c5, $d5, $cd, $dd, $d9, $d2, $c1, $d1, $ff, $ff
/* 18 CPX */ .byte $ff, $e0, $e4, $ff, $ec, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 19 CPY */ .byte $ff, $c0, $c4, $ff, $cc, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 20 DEC */ .byte $ff, $ff, $c6, $d6, $ce, $de, $ff, $ff, $ff, $ff, $3a, $ff
/* 21 DEX */ .byte $ca, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 22 DEY */ .byte $88, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 23 EOR */ .byte $ff, $49, $45, $55, $4d, $5d, $59, $52, $41, $51, $ff, $ff
/* 24 INC */ .byte $ff, $ff, $e6, $f6, $EE, $FE, $ff, $ff, $ff, $ff, $1a, $ff
/* 25 INX */ .byte $e8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 26 INY */ .byte $c8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 27 JMP */ .byte $ff, $ff, $ff, $ff, $4C, $ff, $ff, $6C, $7C, $ff, $ff, $ff
/* 28 JSR */ .byte $ff, $ff, $ff, $ff, $20, $ff, $ff, $ff, $FC, $ff, $ff, $ff
/* 29 LDA */ .byte $ff, $a9, $a5, $b5, $ad, $bd, $b9, $b2, $a1, $b1, $ff, $ff
/* 30 LDX */ .byte $ff, $a2, $a6, $b6, $ae, $ff, $be, $ff, $ff, $ff, $ff, $ff ; Note: zp,Y addressing not supported. you can use abs,Y though
/* 31 LDY */ .byte $ff, $a0, $a4, $b4, $ac, $bc, $ff, $ff, $ff, $ff, $ff, $ff
/* 32 LSR */ .byte $ff, $ff, $46, $56, $4e, $5e, $ff, $ff, $ff, $ff, $4a, $ff
/* 33 NOP */ .byte $ea, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 34 ORA */ .byte $ff, $09, $05, $15, $0d, $1d, $19, $12, $01, $11, $ff, $ff
/* 35 PHA */ .byte $48, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 36 PHP */ .byte $08, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 37 PHX */ .byte $DA, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 38 PHY */ .byte $5A, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 39 PLA */ .byte $68, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 40 PLP */ .byte $28, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 41 PLX */ .byte $FA, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 42 PLY */ .byte $7A, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 43 ROL */ .byte $ff, $ff, $26, $36, $2e, $3e, $ff, $ff, $ff, $ff, $2a, $ff
/* 44 ROR */ .byte $ff, $ff, $66, $76, $6e, $7e, $ff, $ff, $ff, $ff, $6a, $ff
/* 45 RTI */ .byte $40, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 46 RTS */ .byte $60, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 47 SBC */ .byte $ff, $e9, $e5, $f5, $ed, $fd, $f9, $ff, $e1, $f1, $ff, $ff
/* 48 SEC */ .byte $38, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 49 SED */ .byte $f8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 50 SEI */ .byte $78, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 51 STA */ .byte $ff, $ff, $85, $95, $8d, $9d, $99, $92, $81, $91, $ff, $ff
/* 52 STP */ .byte $DB, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 52 STX */ .byte $ff, $ff, $86, $96, $8e, $ff, $ff, $ff, $ff, $ff, $ff, $ff ; Note: zp,Y addressing not supported. oops
/* 54 STY */ .byte $ff, $ff, $84, $94, $8c, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 55 STZ */ .byte $ff, $ff, $64, $74, $9c, $9e, $ff, $ff, $ff, $ff, $ff, $ff
/* 56 TAX */ .byte $aa, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 57 TAY */ .byte $a8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 58 TSX */ .byte $ba, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 59 TXA */ .byte $8a, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 60 TXS */ .byte $9a, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 61 TXY */ .byte $9b, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 62 TYX */ .byte $bb, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 63 TYA */ .byte $98, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 64 WAI */ .byte $cb, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff



.SEGMENT "BSS"

line_buf:
    .res 128 + 1

lines_extmem_bank:
    .word 0
lines_extmem_ptr:
    .word 0

last_extmem_data_bank:
    .word 0
extmem_data_ptr:
    .word 0

