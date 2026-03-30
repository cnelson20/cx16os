.include "routines.inc"
.feature c_comments
.segment "CODE"

ptr0 := $30

NEWLINE = $0A

/* ============================
   Entry point
   ============================ */
main:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	dey
	sty argc

	lda argc
	beq @print_usage

	/* Skip program name */
	jsr get_next_arg

	/* Check for flags */
	lda (ptr0)
	cmp #'-'
	bne @no_flag

	ldy #1
	lda (ptr0), Y
	cmp #'d'
	bne @check_s
	lda #1
	sta delete_mode
	jsr get_next_arg
	bra @no_flag
@check_s:
	cmp #'s'
	bne @check_h
	lda #1
	sta squeeze_mode
	jsr get_next_arg
	bra @no_flag
@check_h:
	cmp #'h'
	bne @invalid_flag
	jmp print_help

@invalid_flag:
	lda #<invalid_flag_str
	ldx #>invalid_flag_str
	jsr print_str
	lda #1
	rts

@print_usage:
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	lda #1
	rts

@no_flag:
	/* Parse set1 */
	jsr parse_set_1
	sta set1_len

	/* If delete mode, only need set1 */
	lda delete_mode
	bne @start_processing

	/* Need set2 */
	lda argc
	beq @missing_set2
	jsr get_next_arg
	jsr parse_set_2
	sta set2_len
	bra @start_processing

@missing_set2:
	lda #<missing_set2_str
	ldx #>missing_set2_str
	jsr print_str
	lda #1
	rts

@start_processing:
	/* Build translation table (256 bytes, identity mapping initially) */
	ldx #0
@build_identity:
	txa
	sta table, X
	inx
	bne @build_identity

	lda delete_mode
	bne @build_delete_table

	/* Build translate table */
	ldy #0
@build_tr_loop:
	cpy set1_len
	bcs @process_input
	lda set1_expanded, Y
	tax
	/* Get corresponding set2 char (or last char if set2 is shorter) */
	phy
	tya
	cmp set2_len
	bcc :+
	lda set2_len
	dec A
	:
	tay
	lda set2_expanded, Y
	ply
	sta table, X
	iny
	bra @build_tr_loop

@build_delete_table:
	/* Zero out delete_flags first */
	ldx #0
	txa
@clear_del_flags:
	sta delete_flags, X
	inx
	bne @clear_del_flags

	ldy #0
@build_del_loop:
	cpy set1_len
	bcs @process_input
	lda set1_expanded, Y
	tax
	lda #$FF
	sta delete_flags, X
	iny
	bra @build_del_loop

/* ============================
   Process stdin -> stdout
   ============================ */
@process_input:
	stz last_char
@input_loop:
	ldx #0 /* stdin */
	jsr fgetc
	cpx #0
	bne @done

	ldx delete_mode
	bne @do_delete

	/* Translate mode */
	tax
	lda table, X

	/* Squeeze check */
	ldx squeeze_mode
	beq @output_char
	cmp last_char
	beq @input_loop
@output_char:
	sta last_char
	jsr CHROUT
	bra @input_loop

@do_delete:
	tax
	lda delete_flags, X
	bne @input_loop /* skip if flagged */
	txa
	jsr CHROUT
	bra @input_loop

@done:
	lda #0
	rts

/* ============================
   Parse set1: expand into set1_expanded
   Returns length in A
   ============================ */
parse_set_1:
	ldx #0 /* dest index */
	ldy #0 /* source index */
@loop:
	lda (ptr0), Y
	beq @done
	cmp #'\'
	beq @escape
	jsr @check_range
	bcs @loop
	sta set1_expanded, X
	inx
	iny
	bra @loop
@escape:
	iny
	lda (ptr0), Y
	beq @done
	jsr decode_escape
	sta set1_expanded, X
	inx
	iny
	bra @loop
@done:
	txa
	rts

@check_range:
	/* A = current char. Check if next is '-' followed by a char */
	sta range_start
	phy
	iny
	lda (ptr0), Y
	cmp #'-'
	bne @not_range
	iny
	lda (ptr0), Y
	beq @not_range_dec
	sta range_end
	ply
	iny
	iny
	iny /* advance source past 'a-z' */
	lda range_start
@expand:
	sta set1_expanded, X
	inx
	cmp range_end
	beq @range_done
	inc A
	bra @expand
@range_done:
	sec /* carry set = handled */
	rts
@not_range_dec:
	dey
@not_range:
	ply
	lda range_start
	clc /* carry clear = not a range */
	rts

/* ============================
   Parse set2: expand into set2_expanded
   Returns length in A
   ============================ */
parse_set_2:
	ldx #0
	ldy #0
@loop:
	lda (ptr0), Y
	beq @done
	cmp #'\'
	beq @escape
	jsr @check_range
	bcs @loop
	sta set2_expanded, X
	inx
	iny
	bra @loop
@escape:
	iny
	lda (ptr0), Y
	beq @done
	jsr decode_escape
	sta set2_expanded, X
	inx
	iny
	bra @loop
@done:
	txa
	rts

@check_range:
	sta range_start
	phy
	iny
	lda (ptr0), Y
	cmp #'-'
	bne @not_range
	iny
	lda (ptr0), Y
	beq @not_range_dec
	sta range_end
	ply
	iny
	iny
	iny
	lda range_start
@expand:
	sta set2_expanded, X
	inx
	cmp range_end
	beq @range_done
	inc A
	bra @expand
@range_done:
	sec
	rts
@not_range_dec:
	dey
@not_range:
	ply
	lda range_start
	clc
	rts

/* ============================
   Decode escape char in A
   ============================ */
decode_escape:
	cmp #'n'
	bne :+
	lda #NEWLINE
	rts
	:
	cmp #'t'
	bne :+
	lda #$09
	rts
	:
	/* return char as-is (handles \\, \-) */
	rts

/* ============================
   Advance ptr0 to next argument
   ============================ */
get_next_arg:
	dec argc
	ldy #0
@skip:
	lda (ptr0), Y
	beq @found
	iny
	bra @skip
@found:
	iny
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	rts

/* ============================
   Help
   ============================ */
print_help:
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	lda #<help_str
	ldx #>help_str
	jsr print_str
	lda #0
	rts

/* ============================
   Data
   ============================ */
argc:
	.byte 0
delete_mode:
	.byte 0
squeeze_mode:
	.byte 0
set1_len:
	.byte 0
set2_len:
	.byte 0
last_char:
	.byte 0
range_start:
	.byte 0
range_end:
	.byte 0

invalid_flag_str:
	.byte "tr: invalid option", NEWLINE, 0

missing_set2_str:
	.byte "tr: missing SET2", NEWLINE, 0

usage_str:
	.byte "Usage: tr [-ds] SET1 [SET2]", NEWLINE, 0

help_str:
	.byte "Translate or delete characters from stdin.", NEWLINE
	.byte NEWLINE
	.byte "Options:", NEWLINE
	.byte "  -d   Delete characters in SET1", NEWLINE
	.byte "  -s   Squeeze repeated output characters", NEWLINE
	.byte "  -h   Display this help", NEWLINE
	.byte NEWLINE
	.byte "SET syntax:", NEWLINE
	.byte "  a-z  Character range", NEWLINE
	.byte "  ", $5C, "n   Newline  ", $5C, "t   Tab  ", $5C, $5C, "   Backslash", NEWLINE
	.byte NEWLINE
	.byte "Examples:", NEWLINE
	.byte "  echo hello | tr a-z A-Z", NEWLINE
	.byte "  echo hello | tr -d l", NEWLINE
	.byte "  echo aabbcc | tr -s a-z", NEWLINE
	.byte 0

.SEGMENT "BSS"
table:
	.res 256
delete_flags:
	.res 256
set1_expanded:
	.res 128
set2_expanded:
	.res 128
