.include "routines.inc"
.feature c_comments
.macpack longbranch

.segment "CODE"

ptr0 := $30
ptr1 := $32
ptr2 := $34

/* Working variables in zero page */
arg_ptr    := $36  /* pointer to current arg string */
char_idx   := $38  /* index into current arg string */
row_num    := $39  /* current row being printed (0-4) */
argc_left  := $3A  /* remaining arg count */
font_ptr   := $3C  /* pointer to font row string */

NEWLINE = $0A
NUM_ROWS = 5

main:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	sty argc_left

	/* Must have at least 2 args (program name + text) */
	cpy #2
	bcs @has_args
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	lda #1
	rts

@has_args:
	/* Skip program name: scan for null byte */
	ldy #0
@skip_name:
	lda (ptr0), Y
	beq @found_name_end
	iny
	bra @skip_name
@found_name_end:
	iny
	/* Advance ptr0 past program name */
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	dec argc_left  /* consumed program name */

	/* ptr0 now points to the first text arg */
	/* For each of 5 rows, iterate all args printing each char's row */

	stz row_num
@row_loop:
	/* Reset to first text arg for this row */
	lda ptr0
	sta arg_ptr
	lda ptr0 + 1
	sta arg_ptr + 1
	lda argc_left
	sta @args_remaining

	/* Process each arg word */
@next_arg:
	lda @args_remaining
	jeq @row_done

	/* If not the first word in this row, print a space between words */
	lda @args_remaining
	cmp argc_left
	beq @no_word_space
	/* Print a figlet-width space between words */
	lda #<font_space_r0
	sta font_ptr
	lda #>font_space_r0
	sta font_ptr + 1
	jsr get_row_for_current
	lda font_ptr
	ldx font_ptr + 1
	jsr print_str
@no_word_space:

	/* Iterate characters of current arg */
	stz char_idx
@char_loop:
	ldy char_idx
	lda (arg_ptr), Y
	beq @arg_done  /* null terminator = end of this arg */

	/* Convert lowercase to uppercase */
	cmp #'a'
	bcc @not_lower
	cmp #'z'+1
	bcs @not_lower
	and #$DF  /* clear bit 5 to uppercase */
@not_lower:

	/* Check if it's a space */
	cmp #' '
	beq @is_space

	/* Check if 0-9 */
	cmp #'0'
	bcc @skip_char
	cmp #'9'+1
	bcc @is_digit

	/* Check if A-Z */
	cmp #'A'
	bcc @skip_char
	cmp #'Z'+1
	bcs @skip_char

	/* Calculate index: (char - 'A') */
	sec
	sbc #'A'
	bra @lookup_char

@is_digit:
	/* Calculate index: (char - '0') + 27 */
	sec
	sbc #'0'
	clc
	adc #27
	bra @lookup_char

@is_space:
	lda #26  /* space is index 26 */

@lookup_char:
	/* Multiply by 2 to index into pointer table */
	asl A
	tax
	lda font_table, X
	sta font_ptr
	lda font_table + 1, X
	sta font_ptr + 1

	/* Now font_ptr points to row 0 of this character */
	/* Advance to the correct row */
	jsr get_row_for_current

	/* Print this row string */
	lda font_ptr
	ldx font_ptr + 1
	jsr print_str

	/* Print a one-char gap between letters */
	lda #' '
	jsr CHROUT

@skip_char:
	inc char_idx
	bra @char_loop

@arg_done:
	/* Advance arg_ptr past this arg's null terminator */
	ldy #0
@scan_arg:
	lda (arg_ptr), Y
	beq @found_arg_end
	iny
	bra @scan_arg
@found_arg_end:
	iny
	tya
	clc
	adc arg_ptr
	sta arg_ptr
	lda arg_ptr + 1
	adc #0
	sta arg_ptr + 1

	dec @args_remaining
	jmp @next_arg

@row_done:
	lda #NEWLINE
	jsr CHROUT

	inc row_num
	lda row_num
	cmp #NUM_ROWS
	jcc @row_loop

	lda #0
	rts

@args_remaining:
	.byte 0

/*
 * get_row_for_current
 * Advances font_ptr past (row_num) null-terminated strings
 * so it points to the string for the current row.
 */
get_row_for_current:
	lda row_num
	beq @done_advance  /* row 0, already pointing there */
	tax  /* X = number of rows to skip */
	ldy #0
@skip_row:
	lda (font_ptr), Y
	beq @end_of_row_str
	iny
	bra @skip_row
@end_of_row_str:
	iny  /* skip past null */
	dex
	beq @finish_advance
	bra @skip_row
@finish_advance:
	/* Add Y offset to font_ptr */
	tya
	clc
	adc font_ptr
	sta font_ptr
	lda font_ptr + 1
	adc #0
	sta font_ptr + 1
@done_advance:
	rts

usage_str:
	.byte "Usage: figlet <text>", NEWLINE
	.byte "Note: long input will overflow the screen width.", NEWLINE, 0

/* --------------------------------------------------------- */
/* Font pointer table: 27 entries (A-Z, space)               */
/* Each points to the first of 5 consecutive row strings     */
/* --------------------------------------------------------- */
font_table:
	.word font_A, font_B, font_C, font_D, font_E, font_F
	.word font_G, font_H, font_I, font_J, font_K, font_L
	.word font_M, font_N, font_O, font_P, font_Q, font_R
	.word font_S, font_T, font_U, font_V, font_W, font_X
	.word font_Y, font_Z, font_space
	.word font_0, font_1, font_2, font_3, font_4
	.word font_5, font_6, font_7, font_8, font_9

/* --------------------------------------------------------- */
/* Font data: 5 rows per character, null-terminated strings  */
/* Each character is at most 5 columns wide                  */
/* --------------------------------------------------------- */

font_A:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte "####", 0
	.byte "#  #", 0
	.byte "#  #", 0

font_B:
	.byte "### ", 0
	.byte "#  #", 0
	.byte "### ", 0
	.byte "#  #", 0
	.byte "### ", 0

font_C:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte "#   ", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_D:
	.byte "### ", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "### ", 0

font_E:
	.byte "####", 0
	.byte "#   ", 0
	.byte "### ", 0
	.byte "#   ", 0
	.byte "####", 0

font_F:
	.byte "####", 0
	.byte "#   ", 0
	.byte "### ", 0
	.byte "#   ", 0
	.byte "#   ", 0

font_G:
	.byte " ## ", 0
	.byte "#   ", 0
	.byte "# ##", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_H:
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "####", 0
	.byte "#  #", 0
	.byte "#  #", 0

font_I:
	.byte "###", 0
	.byte " # ", 0
	.byte " # ", 0
	.byte " # ", 0
	.byte "###", 0

font_J:
	.byte "####", 0
	.byte "   #", 0
	.byte "   #", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_K:
	.byte "#  #", 0
	.byte "# # ", 0
	.byte "##  ", 0
	.byte "# # ", 0
	.byte "#  #", 0

font_L:
	.byte "#   ", 0
	.byte "#   ", 0
	.byte "#   ", 0
	.byte "#   ", 0
	.byte "####", 0

font_M:
	.byte "#   #", 0
	.byte "## ##", 0
	.byte "# # #", 0
	.byte "#   #", 0
	.byte "#   #", 0

font_N:
	.byte "#   #", 0
	.byte "##  #", 0
	.byte "# # #", 0
	.byte "#  ##", 0
	.byte "#   #", 0

font_O:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_P:
	.byte "### ", 0
	.byte "#  #", 0
	.byte "### ", 0
	.byte "#   ", 0
	.byte "#   ", 0

font_Q:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "# # ", 0
	.byte " ## ", 0

font_R:
	.byte "### ", 0
	.byte "#  #", 0
	.byte "### ", 0
	.byte "# # ", 0
	.byte "#  #", 0

font_S:
	.byte " ## ", 0
	.byte "#   ", 0
	.byte " ## ", 0
	.byte "   #", 0
	.byte "### ", 0

font_T:
	.byte "#####", 0
	.byte "  #  ", 0
	.byte "  #  ", 0
	.byte "  #  ", 0
	.byte "  #  ", 0

font_U:
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_V:
	.byte "#   #", 0
	.byte "#   #", 0
	.byte " # # ", 0
	.byte " # # ", 0
	.byte "  #  ", 0

font_W:
	.byte "#   #", 0
	.byte "#   #", 0
	.byte "# # #", 0
	.byte "## ##", 0
	.byte "#   #", 0

font_X:
	.byte "#  #", 0
	.byte " ## ", 0
	.byte " ## ", 0
	.byte " ## ", 0
	.byte "#  #", 0

font_Y:
	.byte "#   #", 0
	.byte " # # ", 0
	.byte "  #  ", 0
	.byte "  #  ", 0
	.byte "  #  ", 0

font_Z:
	.byte "####", 0
	.byte "  # ", 0
	.byte " #  ", 0
	.byte "#   ", 0
	.byte "####", 0

font_space:
font_space_r0:
	.byte "    ", 0
	.byte "    ", 0
	.byte "    ", 0
	.byte "    ", 0
	.byte "    ", 0

font_0:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_1:
	.byte " # ", 0
	.byte "## ", 0
	.byte " # ", 0
	.byte " # ", 0
	.byte "###", 0

font_2:
	.byte "### ", 0
	.byte "   #", 0
	.byte " ## ", 0
	.byte "#   ", 0
	.byte "####", 0

font_3:
	.byte "### ", 0
	.byte "   #", 0
	.byte " ## ", 0
	.byte "   #", 0
	.byte "### ", 0

font_4:
	.byte "#  #", 0
	.byte "#  #", 0
	.byte "####", 0
	.byte "   #", 0
	.byte "   #", 0

font_5:
	.byte "####", 0
	.byte "#   ", 0
	.byte "### ", 0
	.byte "   #", 0
	.byte "### ", 0

font_6:
	.byte " ## ", 0
	.byte "#   ", 0
	.byte "### ", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_7:
	.byte "####", 0
	.byte "   #", 0
	.byte "  # ", 0
	.byte " #  ", 0
	.byte "#   ", 0

font_8:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte " ## ", 0
	.byte "#  #", 0
	.byte " ## ", 0

font_9:
	.byte " ## ", 0
	.byte "#  #", 0
	.byte " ## ", 0
	.byte "   #", 0
	.byte " ## ", 0
