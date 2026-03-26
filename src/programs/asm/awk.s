.include "routines.inc"
.feature c_comments
.macpack longbranch

.segment "CODE"

ptr0 := $30
ptr1 := $32

NEWLINE = $0A
CARRIAGE_RETURN = $0D
TAB = $09
SPACE = $20
BACKSLASH = $5C

LINE_BUFF_SIZE = 256
MAX_FIELDS = 16
MAX_ACTIONS = 128
MAX_FILES = 8
PROG_BUFF_SIZE = 256

/* Action bytecodes for parsed program */
ACT_END = 0
ACT_FIELD = 1     /* next byte: field number (0=whole line, 1-9=field) */
ACT_NR = 2        /* print record number */
ACT_NF = 3        /* print field count */
ACT_LITERAL = 4   /* followed by inline null-terminated string */
ACT_OFS = 5       /* print output field separator (space) */

/* ============================
   Entry point
   ============================ */
main:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	dey
	sty argc

	/* Default field separator is whitespace */
	lda #SPACE
	sta field_sep

	lda argc
	jne parse_args_loop
	lda #1
	jmp print_usage

/* ============================
   Parse command-line arguments
   ============================ */
parse_args_loop:
	lda argc
	bne :+
	jmp end_parse_args
	:
	jsr get_next_arg

	ldy #0
	lda (ptr0), Y
	cmp #'-'
	jne @not_flag

	iny
	lda (ptr0), Y

	/* -F: field separator */
	cmp #'F'
	jne @check_h

	/* Check if separator char follows immediately (e.g., -F:) */
	iny
	lda (ptr0), Y
	jne @fs_inline

	/* Separator is next argument */
	lda argc
	bne :+
	jmp missing_arg_error
	:
	jsr get_next_arg
	ldy #0
	lda (ptr0), Y

@fs_inline:
	/* Check for \t and \n escapes */
	cmp #BACKSLASH
	jne @fs_store
	iny
	lda (ptr0), Y
	cmp #'t'
	bne :+
	lda #TAB
	jmp @fs_store
	:
	cmp #'n'
	jne @fs_store
	lda #NEWLINE
@fs_store:
	sta field_sep
	jmp parse_args_loop

@check_f:
	cmp #'f'
	jne @check_h

	/* -f: read program from file */
	lda argc
	bne :+
	jmp missing_arg_error
	:
	jsr get_next_arg
	jsr load_prog_file
	cmp #0
	beq :+
	rts /* load_prog_file already printed error */
	:
	jmp parse_args_loop

@check_h:
	cmp #'h'
	jne @invalid_flag
	jmp print_help

@invalid_flag:
	pha
	lda #<invalid_flag_str
	ldx #>invalid_flag_str
	jsr print_str
	pla
	jsr CHROUT
	lda #$27 /* single quote */
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	lda #1
	rts

@not_flag:
	/* First non-flag arg = program, rest = files */
	lda program_ptr + 1
	jne @is_file

	lda ptr0
	sta program_ptr
	lda ptr0 + 1
	sta program_ptr + 1
	jmp parse_args_loop

@is_file:
	ldy file_count
	cpy #MAX_FILES
	bcs :+
	lda ptr0
	sta file_ptrs_lo, Y
	lda ptr0 + 1
	sta file_ptrs_hi, Y
	inc file_count
	:
	jmp parse_args_loop

end_parse_args:
	/* Must have a program */
	lda program_ptr + 1
	bne :+
	lda #1
	jmp print_usage
	:

	/* Parse the program string into bytecode */
	jsr parse_program
	cmp #0
	beq :+
	lda #<parse_err_str
	ldx #>parse_err_str
	jsr print_str
	lda #1
	rts
	:

	/* Default to stdin if no files specified */
	lda file_count
	bne :+
	lda #<stdin_str
	sta file_ptrs_lo
	lda #>stdin_str
	sta file_ptrs_hi
	inc file_count
	:

	/* Process files */
	stz file_index
	stz record_num
	stz record_num + 1

/* ============================
   Main file processing loop
   ============================ */
file_loop:
	lda file_index
	cmp file_count
	bcc :+
	lda #0
	rts /* done, exit success */
	:

	ldy file_index
	lda file_ptrs_hi, Y
	tax
	lda file_ptrs_lo, Y
	ldy #0 /* read mode */
	jsr open_file
	cmp #$FF
	bne :+
	jmp file_error
	:
	sta fd

	lda #1
	sta still_reading

read_line_loop:
	ldy #0
@rl_char_loop:
	phy
	ldx fd
	jsr fgetc
	ply
	cpx #0
	jne @rl_eof
	cmp #NEWLINE
	jeq @rl_end_line
	cmp #CARRIAGE_RETURN
	jeq @rl_char_loop /* skip CR */
	sta line_buff, Y
	iny
	cpy #LINE_BUFF_SIZE - 1
	jcc @rl_char_loop
	jmp @rl_end_line

@rl_eof:
	stz still_reading
	cpy #0
	jeq @rl_done_file

@rl_end_line:
	lda #0
	sta line_buff, Y
	sty line_len

	/* Increment NR */
	inc record_num
	bne :+
	inc record_num + 1
	:

	/* Copy line to line_copy for field splitting */
	ldy line_len
@rl_copy:
	lda line_buff, Y
	sta line_copy, Y
	dey
	jpl @rl_copy

	jsr split_fields
	jsr exec_program

	lda still_reading
	jne read_line_loop

@rl_done_file:
	lda fd
	jsr close_file
	inc file_index
	jmp file_loop

/* ============================
   Advance ptr0 to next argument
   ============================ */
get_next_arg:
	dec argc

	ldy #0
@gna_skip:
	lda (ptr0), Y
	jeq @gna_found
	iny
	jmp @gna_skip
@gna_found:
	iny /* skip past null */

	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	rts

/* ============================
   Load program from file into prog_file_buff
   ptr0 points to filename
   Returns A=0 success, A=1 error
   Sets program_ptr on success
   ============================ */
load_prog_file:
	lda ptr0
	ldx ptr0 + 1
	ldy #0 /* read mode */
	jsr open_file
	cmp #$FF
	jne @lpf_opened

	/* Could not open file */
	lda #<prog_file_err_p1
	ldx #>prog_file_err_p1
	jsr print_str
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	lda #<prog_file_err_p2
	ldx #>prog_file_err_p2
	jsr print_str
	lda #1
	rts

@lpf_opened:
	sta @lpf_fd

	/* Read file contents into prog_file_buff using fgetc */
	ldy #0
@lpf_read_loop:
	phy
	ldx @lpf_fd
	jsr fgetc
	ply
	cpx #0
	jne @lpf_eof
	/* Skip CR */
	cmp #CARRIAGE_RETURN
	jeq @lpf_read_loop
	/* Convert newlines to spaces (flatten multi-line programs) */
	cmp #NEWLINE
	bne :+
	lda #SPACE
	:
	sta prog_file_buff, Y
	iny
	cpy #PROG_BUFF_SIZE - 1
	jcc @lpf_read_loop

@lpf_eof:
	lda #0
	sta prog_file_buff, Y /* null-terminate */

	lda @lpf_fd
	jsr close_file

	/* Set program_ptr to the buffer */
	lda #<prog_file_buff
	sta program_ptr
	lda #>prog_file_buff
	sta program_ptr + 1

	lda #0
	rts

@lpf_fd:
	.byte 0

/* ============================
   Split line_copy into fields
   Replaces separators with \0
   Stores start offsets in field_offsets[]
   ============================ */
split_fields:
	stz field_count
	ldy #0

@sf_skip_leading:
	lda line_copy, Y
	jeq @sf_done
	jsr is_separator
	jcc @sf_field_start
	iny
	jmp @sf_skip_leading

@sf_field_start:
	ldx field_count
	cpx #MAX_FIELDS
	jcs @sf_done
	tya
	sta field_offsets, X
	inc field_count

@sf_in_field:
	lda line_copy, Y
	jeq @sf_done
	jsr is_separator
	jcs @sf_end_field
	iny
	jmp @sf_in_field

@sf_end_field:
	lda #0
	sta line_copy, Y /* null-terminate field */
	iny
	/* In whitespace mode, skip consecutive separators */
	ldx field_sep
	cpx #SPACE
	jne @sf_field_start /* non-whitespace: next char starts new field */
@sf_skip_consec:
	lda line_copy, Y
	jeq @sf_done
	jsr is_separator
	jcc @sf_field_start
	iny
	jmp @sf_skip_consec

@sf_done:
	rts

/* Check if char in A is a field separator
   Carry set = separator, carry clear = not */
is_separator:
	cmp field_sep
	jeq @is_sep_yes
	ldx field_sep
	cpx #SPACE
	jne @is_sep_no
	cmp #TAB
	jeq @is_sep_yes
@is_sep_no:
	clc
	rts
@is_sep_yes:
	sec
	rts

/* ============================
   Parse program string
   Converts '{print $1, $2}' into bytecodes
   Returns A=0 on success, A=1 on error
   ============================ */
parse_program:
	lda program_ptr
	sta ptr1
	lda program_ptr + 1
	sta ptr1 + 1
	stz action_count

	ldy #0
	/* Skip leading whitespace */
@pp_skip1:
	lda (ptr1), Y
	jeq @pp_error
	cmp #SPACE
	beq :+
	cmp #TAB
	jne @pp_check_brace
	:
	iny
	jmp @pp_skip1

@pp_check_brace:
	cmp #'{'
	jne @pp_error
	iny

	/* Skip whitespace after { */
@pp_skip2:
	lda (ptr1), Y
	cmp #SPACE
	beq :+
	cmp #TAB
	beq :+
	jmp @pp_check_keyword
	:
	iny
	jmp @pp_skip2

@pp_check_keyword:
	/* Check for "print" keyword */
	cmp #'p'
	jne @pp_check_close
	iny
	lda (ptr1), Y
	cmp #'r'
	jne @pp_error
	iny
	lda (ptr1), Y
	cmp #'i'
	jne @pp_error
	iny
	lda (ptr1), Y
	cmp #'n'
	jne @pp_error
	iny
	lda (ptr1), Y
	cmp #'t'
	jne @pp_error
	iny

	/* After "print": must be whitespace, }, or \0 */
	lda (ptr1), Y
	cmp #'}'
	jeq @pp_print_line
	cmp #0
	jeq @pp_print_line
	cmp #SPACE
	beq :+
	cmp #TAB
	beq :+
	jmp @pp_error
	:

	/* Skip whitespace after "print" */
@pp_skip3:
	iny
	lda (ptr1), Y
	cmp #SPACE
	jeq @pp_skip3
	cmp #TAB
	jeq @pp_skip3

	cmp #'}'
	jeq @pp_print_line
	cmp #0
	jeq @pp_print_line

	jmp @pp_parse_args

@pp_print_line:
	/* {print} or {print } = print $0 */
	ldx action_count
	lda #ACT_FIELD
	sta actions, X
	inx
	lda #0 /* $0 = whole line */
	sta actions, X
	inx
	stx action_count
	jmp @pp_finalize

@pp_parse_args:
	lda (ptr1), Y
	cmp #'}'
	jeq @pp_finalize
	cmp #0
	jeq @pp_finalize

	cmp #'$'
	jeq @pp_field_ref
	cmp #'N'
	jeq @pp_check_var
	cmp #'"'
	jeq @pp_literal
	jmp @pp_error

@pp_field_ref:
	iny
	lda (ptr1), Y
	sec
	sbc #'0'
	jcc @pp_error
	cmp #10
	jcs @pp_error
	pha
	ldx action_count
	lda #ACT_FIELD
	sta actions, X
	inx
	pla
	sta actions, X
	inx
	stx action_count
	iny
	jmp @pp_after_arg

@pp_check_var:
	iny
	lda (ptr1), Y
	cmp #'R'
	bne :+
	iny
	ldx action_count
	lda #ACT_NR
	sta actions, X
	inx
	stx action_count
	jmp @pp_after_arg
	:
	cmp #'F'
	jne @pp_error
	iny
	ldx action_count
	lda #ACT_NF
	sta actions, X
	inx
	stx action_count
	jmp @pp_after_arg

@pp_literal:
	ldx action_count
	lda #ACT_LITERAL
	sta actions, X
	inx
	iny /* skip opening quote */
@pp_lit_loop:
	lda (ptr1), Y
	jeq @pp_error /* unterminated string */
	cmp #'"'
	jeq @pp_lit_end
	cmp #BACKSLASH
	jne @pp_lit_store
	/* Handle escape sequences */
	iny
	lda (ptr1), Y
	jeq @pp_error
	cmp #'n'
	bne :+
	lda #NEWLINE
	jmp @pp_lit_store
	:
	cmp #'t'
	bne :+
	lda #TAB
	jmp @pp_lit_store
	:
	/* Unknown escape: store char as-is */
@pp_lit_store:
	sta actions, X
	inx
	iny
	jmp @pp_lit_loop
@pp_lit_end:
	lda #0
	sta actions, X /* null-terminate */
	inx
	stx action_count
	iny /* skip closing quote */
	jmp @pp_after_arg

@pp_after_arg:
	/* Skip whitespace */
	lda (ptr1), Y
	cmp #SPACE
	beq :+
	cmp #TAB
	beq :+
	jmp @pp_check_comma
	:
	iny
	jmp @pp_after_arg

@pp_check_comma:
	cmp #','
	jne @pp_no_comma
	/* Comma: insert OFS action */
	ldx action_count
	lda #ACT_OFS
	sta actions, X
	inx
	stx action_count
	iny /* skip comma */
@pp_comma_ws:
	lda (ptr1), Y
	cmp #SPACE
	beq :+
	cmp #TAB
	beq :+
	jmp @pp_parse_args
	:
	iny
	jmp @pp_comma_ws

@pp_no_comma:
	cmp #'}'
	jeq @pp_finalize
	cmp #0
	jeq @pp_finalize
	/* Space-separated: concatenate without OFS */
	jmp @pp_parse_args

@pp_check_close:
	cmp #'}'
	jeq @pp_print_line
	/* fall through to error */

@pp_error:
	lda #1
	rts

@pp_finalize:
	ldx action_count
	lda #ACT_END
	sta actions, X
	lda #0
	rts

/* ============================
   Execute parsed program actions
   ============================ */
exec_program:
	stz action_idx

@ep_loop:
	ldy action_idx
	lda actions, Y
	jeq @ep_done /* ACT_END */

	cmp #ACT_FIELD
	jne @ep_not_field
	iny
	lda actions, Y
	iny
	sty action_idx
	jsr print_field
	jmp @ep_loop

@ep_not_field:
	cmp #ACT_NR
	jne @ep_not_nr
	iny
	sty action_idx
	jsr print_nr
	jmp @ep_loop

@ep_not_nr:
	cmp #ACT_NF
	jne @ep_not_nf
	iny
	sty action_idx
	jsr print_nf
	jmp @ep_loop

@ep_not_nf:
	cmp #ACT_LITERAL
	jne @ep_not_lit
	iny
@ep_lit_loop:
	lda actions, Y
	jeq @ep_lit_done
	phy
	jsr CHROUT
	ply
	iny
	jmp @ep_lit_loop
@ep_lit_done:
	iny /* skip null */
	sty action_idx
	jmp @ep_loop

@ep_not_lit:
	cmp #ACT_OFS
	jne @ep_skip
	iny
	sty action_idx
	lda #SPACE
	jsr CHROUT
	jmp @ep_loop

@ep_skip:
	iny
	sty action_idx
	jmp @ep_loop

@ep_done:
	lda #NEWLINE
	jsr CHROUT
	rts

/* ============================
   Print field $N (field number in A)
   ============================ */
print_field:
	cmp #0
	jne @pf_specific
	/* $0 = whole line (unmodified) */
	lda #<line_buff
	ldx #>line_buff
	jsr print_str
	rts

@pf_specific:
	/* Check field exists: A should be 1..field_count */
	cmp field_count
	beq :+
	jcs @pf_empty /* field number > field_count */
	:

	sec
	sbc #1 /* convert 1-based to 0-based index */
	tax
	lda field_offsets, X
	tay
	/* Print chars from line_copy at offset Y */
@pf_loop:
	lda line_copy, Y
	jeq @pf_empty
	phy
	jsr CHROUT
	ply
	iny
	jmp @pf_loop

@pf_empty:
	rts

/* ============================
   Print record number (NR)
   ============================ */
print_nr:
	lda record_num
	sta temp_num
	lda record_num + 1
	sta temp_num + 1
	jmp print_decimal

/* ============================
   Print field count (NF)
   ============================ */
print_nf:
	lda field_count
	sta temp_num
	stz temp_num + 1
	jmp print_decimal

/* ============================
   Print 16-bit decimal from temp_num
   Suppresses leading zeros
   ============================ */
print_decimal:
	lda #1
	sta suppress_zero

	/* 10000 */
	lda #<10000
	sta pow10
	lda #>10000
	sta pow10 + 1
	jsr @pd_digit

	/* 1000 */
	lda #<1000
	sta pow10
	lda #>1000
	sta pow10 + 1
	jsr @pd_digit

	/* 100 */
	lda #100
	sta pow10
	stz pow10 + 1
	jsr @pd_digit

	/* 10 */
	lda #10
	sta pow10
	stz pow10 + 1
	jsr @pd_digit

	/* 1: always print */
	lda temp_num
	clc
	adc #'0'
	jsr CHROUT
	rts

@pd_digit:
	stz digit_val
@pd_sub:
	lda temp_num
	sec
	sbc pow10
	pha
	lda temp_num + 1
	sbc pow10 + 1
	jcc @pd_done /* went negative */
	sta temp_num + 1
	pla
	sta temp_num
	inc digit_val
	jmp @pd_sub

@pd_done:
	pla /* discard partial result */
	lda digit_val
	jne @pd_print
	lda suppress_zero
	jne @pd_skip /* still suppressing leading zeros */
@pd_print:
	stz suppress_zero
	lda digit_val
	clc
	adc #'0'
	jsr CHROUT
@pd_skip:
	rts

/* ============================
   Error handlers
   ============================ */
file_error:
	lda #<file_err_p1
	ldx #>file_err_p1
	jsr print_str

	ldy file_index
	lda file_ptrs_hi, Y
	tax
	lda file_ptrs_lo, Y
	jsr print_str

	lda #<file_err_p2
	ldx #>file_err_p2
	jsr print_str

	inc file_index
	jmp file_loop

missing_arg_error:
	lda #<missing_arg_str
	ldx #>missing_arg_str
	jsr print_str
	lda #1
	rts

print_usage:
	pha
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	lda #<reminder_str
	ldx #>reminder_str
	jsr print_str
	pla
	rts

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
fd:
	.byte 0
still_reading:
	.byte 0
line_len:
	.byte 0
field_sep:
	.byte SPACE
field_count:
	.byte 0
file_count:
	.byte 0
file_index:
	.byte 0
record_num:
	.word 0
action_count:
	.byte 0
action_idx:
	.byte 0
program_ptr:
	.word 0

suppress_zero:
	.byte 0
digit_val:
	.byte 0
pow10:
	.word 0
temp_num:
	.word 0

file_ptrs_lo:
	.res MAX_FILES, 0
file_ptrs_hi:
	.res MAX_FILES, 0

field_offsets:
	.res MAX_FIELDS, 0

stdin_str:
	.asciiz "#stdin"

invalid_flag_str:
	.byte "awk: invalid option -- '", 0

missing_arg_str:
	.byte "awk: option requires an argument", NEWLINE, 0

parse_err_str:
	.byte "awk: syntax error in program", NEWLINE, 0

file_err_p1:
	.byte "awk: can't open file '", 0
file_err_p2:
	.byte "' for reading", NEWLINE, 0

prog_file_err_p1:
	.byte "awk: can't open program file '", 0
prog_file_err_p2:
	.byte "'", NEWLINE, 0

usage_str:
	.byte "Usage: awk [OPTIONS] 'program' [FILE ...]", NEWLINE
	.byte "       awk [OPTIONS] -f progfile [FILE ...]", NEWLINE, 0

reminder_str:
	.byte "Try 'awk -h' for more information.", NEWLINE, 0

help_str:
	.byte "A pattern scanning and processing language.", NEWLINE
	.byte NEWLINE
	.byte "Options:", NEWLINE
	.byte "  -f file Read program from file", NEWLINE
	.byte "  -F fs   Use fs as the field separator", NEWLINE
	.byte "  -h      Display this help and exit", NEWLINE
	.byte NEWLINE
	.byte "Program syntax:", NEWLINE
	.byte "  {print}              Print entire line ($0)", NEWLINE
	.byte "  {print $N}           Print field N (1-9)", NEWLINE
	.byte "  {print $1, $2}       Print fields with space between", NEWLINE
	.byte "  {print $1 $2}        Print fields concatenated", NEWLINE
	.byte "  {print NR}           Print record (line) number", NEWLINE
	.byte "  {print NF}           Print number of fields", NEWLINE
	.byte "  {print ", $22, "text", $22, "}     Print literal string", NEWLINE
	.byte NEWLINE
	.byte "Escape sequences in strings and -F:", NEWLINE
	.byte "  \t   Tab     \n   Newline", NEWLINE
	.byte NEWLINE
	.byte "Examples:", NEWLINE
	.byte "  awk '{print $1}' file.txt", NEWLINE
	.byte "  awk -F: '{print $1, $3}' data", NEWLINE
	.byte "  awk '{print NR, $0}' file.txt", NEWLINE
	.byte 0

.SEGMENT "BSS"
line_buff:
	.res LINE_BUFF_SIZE
line_copy:
	.res LINE_BUFF_SIZE
actions:
	.res MAX_ACTIONS
prog_file_buff:
	.res PROG_BUFF_SIZE
