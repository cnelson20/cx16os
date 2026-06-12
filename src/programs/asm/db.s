.include "routines.inc"
.macpack longbranch

.segment "CODE"
.byte $EA, $EA          ; bonk: use 24KB heap

;;; ============================================================
;;; db - a small sql database for cx16os
;;;
;;; usage: db file.db ["statement"]
;;;
;;; supports: CREATE TABLE / DROP TABLE / INSERT INTO ... VALUES
;;;           SELECT cols|* FROM t [WHERE col op val]
;;;           UPDATE t SET col = val [WHERE ...]
;;;           DELETE FROM t [WHERE ...]
;;; types: INT (signed 16-bit), TEXT (max 100 bytes)
;;;
;;; file format "X16D" v1:
;;;   header: "X16D", version(1), ntables(1), reserved(2)
;;;   per table: name(11) ncols(1) nrows(2) data_size(2)
;;;              coldefs(12 each: name(11) type(1))
;;;              packed row data
;;;   row: per column - INT = 2 bytes LE, TEXT = len byte + bytes
;;;
;;; each table lives in one 8KB extmem bank, mirroring the disk
;;; layout at $A000. the whole file is rewritten after every
;;; mutating statement (no update-in-place on this OS).
;;; ============================================================

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

ptr0 := $30
ptr1 := $32

MAX_TABLES = 8
MAX_COLS = 8
NAME_LEN = 10
NAME_FIELD = 11
COLDEF_SIZE = 12
TBL_HDR_SIZE = 16
MAX_TEXT = 100
MAX_LINE = 252

TYPE_INT = 0
TYPE_TEXT = 1

NEWLINE = $0A
QUOTE = $27

; token types
TK_EOF    = 0
TK_IDENT  = 1
TK_INT    = 2
TK_STR    = 3
TK_STAR   = 4
TK_COMMA  = 5
TK_LPAREN = 6
TK_RPAREN = 7
TK_SEMI   = 8
; relational ops: $10 | predicate mask (EQ=1, LT=2, GT=4)
TK_EQ = $11
TK_LT = $12
TK_LE = $13
TK_GT = $14
TK_GE = $15
TK_NE = $16
; keywords
TK_SELECT = $20
TK_INSERT = $21
TK_UPDATE = $22
TK_DELETE = $23
TK_CREATE = $24
TK_DROP   = $25
TK_TABLE  = $26
TK_INTO   = $27
TK_VALUES = $28
TK_FROM   = $29
TK_WHERE  = $2A
TK_SET    = $2B
TK_INT_KW = $2C
TK_TEXT_KW = $2D

MODE_UPDATE = 0
MODE_DELETE = 1

;;; ============================================================
;;; main / REPL
;;; ============================================================

main:
	lda #0
	jsr set_stdin_read_mode

	stz ntables
	stz scratch_bank
	stz one_shot
	stz quit_flag
	stz err_flag

	jsr get_args
	sta ptr0
	stx ptr0 + 1
	sty argc
	cpy #2
	bcs :+
	lda #<str_usage
	ldx #>str_usage
	jsr print_str
	lda #1
	rts
	:
	jsr next_arg ; skip argv[0]
	; copy argv[1] -> db_filename
	ldy #0
@copy_fname:
	lda (ptr0), Y
	sta db_filename, Y
	beq @fname_done
	iny
	cpy #127
	bcc @copy_fname
	lda #0
	sta db_filename, Y
@fname_done:
	lda argc
	cmp #3
	bcc @args_done
	; one-shot: copy argv[2] -> line_buf
	lda #1
	sta one_shot
	jsr next_arg
	ldy #0
@copy_stmt:
	lda (ptr0), Y
	sta line_buf, Y
	beq @args_done
	iny
	cpy #255
	bcc @copy_stmt
	lda #0
	sta line_buf, Y
@args_done:
	jsr load_db
	bcc :+
	lda #1
	rts
	:
	lda one_shot
	beq repl_loop
	jsr handle_line
	lda err_flag
	rts

repl_loop:
	lda #<str_prompt
	ldx #>str_prompt
	jsr print_str
	jsr read_line
	bcs @quit
	lda line_buf
	beq repl_loop
	jsr handle_line
	lda quit_flag
	beq repl_loop
@quit:
	lda #0
	rts

; advance ptr0 past one nul-terminated string
next_arg:
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bne :-
	:
	iny
	tya
	clc
	adc ptr0
	sta ptr0
	bcc :+
	inc ptr0 + 1
	:
	rts

; read a line from stdin into line_buf (nul-terminated)
; returns carry set on EOF
read_line:
	ldx #0
@loop:
	phx
	:
	ldx #0
	jsr fgetc
	cpx #0
	bne @eof
	cmp #0
	beq :-
	plx
	cmp #NEWLINE
	beq @done
	cpx #MAX_LINE
	bcs @loop
	sta line_buf, X
	inx
	bra @loop
@done:
	stz line_buf, X
	clc
	rts
@eof:
	plx
	stz line_buf, X
	lda #NEWLINE
	jsr putc
	sec
	rts

handle_line:
	stz err_flag
	lda line_buf
	cmp #'.'
	beq dot_command
	jmp exec_statement

;;; ============================================================
;;; dot commands
;;; ============================================================

dot_command:
	lda #<str_dot_quit
	ldx #>str_dot_quit
	jsr match_dot
	bcs @quit
	lda #<str_dot_exit
	ldx #>str_dot_exit
	jsr match_dot
	bcs @quit
	lda #<str_dot_tables
	ldx #>str_dot_tables
	jsr match_dot
	jcs dot_tables
	lda #<str_dot_schema
	ldx #>str_dot_schema
	jsr match_dot
	jcs dot_schema
	lda #<str_dot_help
	ldx #>str_dot_help
	jsr match_dot
	bcs @help
	lda #<err_unk_dot
	ldx #>err_unk_dot
	jmp parse_error
@quit:
	lda #1
	sta quit_flag
	rts
@help:
	lda #<str_help
	ldx #>str_help
	jmp print_str

; compare nul-terminated literal in AX against line_buf+1
; (terminated by nul or space). carry set on match
match_dot:
	sta ptr0
	stx ptr0 + 1
	ldy #0
@cmp:
	lda (ptr0), Y
	beq @end_lit
	cmp line_buf + 1, Y
	bne @no
	iny
	bra @cmp
@end_lit:
	lda line_buf + 1, Y
	beq @yes
	cmp #' '
	beq @yes
@no:
	clc
	rts
@yes:
	sec
	rts

dot_tables:
	ldx #0
@loop:
	cpx ntables
	bcs @done
	phx
	lda mult12, X
	clc
	adc #<catalog
	pha
	lda #>catalog
	adc #0
	tax
	pla
	jsr print_str
	lda #NEWLINE
	jsr putc
	plx
	inx
	bra @loop
@done:
	rts

dot_schema:
	stz tbl_i
@loop:
	lda tbl_i
	cmp ntables
	jcs @done
	jsr select_table
	lda #<str_create_tbl
	ldx #>str_create_tbl
	jsr print_str
	lda #<tbl_hdr_buf
	ldx #>tbl_hdr_buf
	jsr print_str
	lda #<str_open_paren
	ldx #>str_open_paren
	jsr print_str
	ldx #0
@col_loop:
	cpx cur_ncols
	bcs @close
	txa
	beq :+
	phx
	lda #<str_comma_sp
	ldx #>str_comma_sp
	jsr print_str
	plx
	:
	phx
	lda mult12, X
	clc
	adc #<(tbl_hdr_buf + TBL_HDR_SIZE)
	pha
	lda #>(tbl_hdr_buf + TBL_HDR_SIZE)
	adc #0
	tax
	pla
	jsr print_str
	lda #' '
	jsr putc
	plx
	ldy mult12, X
	lda tbl_hdr_buf + TBL_HDR_SIZE + NAME_FIELD, Y
	bne :+
	phx
	lda #<str_int
	ldx #>str_int
	jsr print_str
	plx
	bra @next_col
	:
	phx
	lda #<str_text
	ldx #>str_text
	jsr print_str
	plx
@next_col:
	inx
	bra @col_loop
@close:
	lda #<str_close_paren
	ldx #>str_close_paren
	jsr print_str
	inc tbl_i
	jmp @loop
@done:
	rts

;;; ============================================================
;;; tokenizer
;;; ============================================================

; reads next token from line_buf at scan_pos
; sets tok_type; for IDENT/STR: tok_buf + tok_len; for INT: tok_val
; on lexical error prints message, sets err_flag, tok_type = TK_EOF
next_token:
	ldx scan_pos
@skip_ws:
	lda line_buf, X
	cmp #' '
	beq @ws
	cmp #9
	beq @ws
	cmp #$0D
	bne @classify
@ws:
	inx
	bra @skip_ws
@classify:
	cmp #0
	bne :+
	stx scan_pos
	stz tok_type ; TK_EOF
	rts
	:
	jsr is_alpha
	jcs tok_ident
	cmp #'0'
	bcc :+
	cmp #'9' + 1
	jcc tok_number
	:
	cmp #'-'
	bne :+
	lda line_buf + 1, X
	cmp #'0'
	jcc @bad_char
	cmp #'9' + 1
	jcs @bad_char
	jmp tok_number_neg
	:
	cmp #QUOTE
	jeq tok_string
	; single/double char operators
	inx
	cmp #'*'
	bne :+
	lda #TK_STAR
	bra @store
	:
	cmp #','
	bne :+
	lda #TK_COMMA
	bra @store
	:
	cmp #'('
	bne :+
	lda #TK_LPAREN
	bra @store
	:
	cmp #')'
	bne :+
	lda #TK_RPAREN
	bra @store
	:
	cmp #';'
	bne :+
	lda #TK_SEMI
	bra @store
	:
	cmp #'='
	bne :+
	lda #TK_EQ
	bra @store
	:
	cmp #'<'
	bne @not_lt
	lda line_buf, X
	cmp #'='
	bne :+
	inx
	lda #TK_LE
	bra @store
	:
	cmp #'>'
	bne :+
	inx
	lda #TK_NE
	bra @store
	:
	lda #TK_LT
	bra @store
@not_lt:
	cmp #'>'
	bne @not_gt
	lda line_buf, X
	cmp #'='
	bne :+
	inx
	lda #TK_GE
	bra @store
	:
	lda #TK_GT
	bra @store
@not_gt:
	cmp #'!'
	jne @bad_char
	lda line_buf, X
	cmp #'='
	jne @bad_char
	inx
	lda #TK_NE
@store:
	sta tok_type
	stx scan_pos
	rts
@bad_char:
	stx scan_pos
	lda #<err_badchar
	ldx #>err_badchar
	jmp parse_error

; carry set if A is letter or underscore
is_alpha:
	cmp #'_'
	beq @yes
	cmp #'A'
	bcc @no
	cmp #'Z' + 1
	bcc @yes
	cmp #'a'
	bcc @no
	cmp #'z' + 1
	bcc @yes
@no:
	clc
	rts
@yes:
	sec
	rts

; carry set if A is letter, digit, or underscore
is_ident_char:
	cmp #'0'
	bcc is_alpha
	cmp #'9' + 1
	bcc @yes
	jmp is_alpha
@yes:
	sec
	rts

tok_ident:
	ldy #0
@loop:
	lda line_buf, X
	jsr is_ident_char
	bcc @done
	; uppercase
	cmp #'a'
	bcc :+
	cmp #'z' + 1
	bcs :+
	sec
	sbc #$20
	:
	cpy #31
	bcs :+
	sta tok_buf, Y
	iny
	:
	inx
	bra @loop
@done:
	lda #0
	sta tok_buf, Y
	sty tok_len
	stx scan_pos
	; keyword lookup
	lda #<kw_table
	sta ptr0
	lda #>kw_table
	sta ptr0 + 1
@entry:
	lda (ptr0)
	beq @not_kw
	ldy #0
@cmp:
	lda (ptr0), Y
	cmp tok_buf, Y
	bne @skip
	cmp #0
	beq @matched
	iny
	bra @cmp
@matched:
	iny
	lda (ptr0), Y
	sta tok_type
	rts
@skip:
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bra :-
	:
	iny
	iny
	tya
	clc
	adc ptr0
	sta ptr0
	bcc @entry
	inc ptr0 + 1
	bra @entry
@not_kw:
	lda #TK_IDENT
	sta tok_type
	rts

tok_number_neg:
	inx ; past '-'
	lda #1
	sta num_neg
	bra tok_number_go
tok_number:
	stz num_neg
tok_number_go:
	stz tok_val
	stz tok_val + 1
@loop:
	lda line_buf, X
	cmp #'0'
	bcc @done
	cmp #'9' + 1
	bcs @done
	sec
	sbc #'0'
	sta num_digit
	; tok_val = tok_val * 10 + digit
	asl tok_val
	rol tok_val + 1
	jcs @overflow
	lda tok_val
	sta num_t2
	lda tok_val + 1
	sta num_t2 + 1
	asl tok_val
	rol tok_val + 1
	jcs @overflow
	asl tok_val
	rol tok_val + 1
	jcs @overflow
	clc
	lda tok_val
	adc num_t2
	sta tok_val
	lda tok_val + 1
	adc num_t2 + 1
	sta tok_val + 1
	jcs @overflow
	lda tok_val
	clc
	adc num_digit
	sta tok_val
	bcc :+
	inc tok_val + 1
	beq @overflow
	:
	inx
	bra @loop
@done:
	stx scan_pos
	; range check: magnitude <= 32767, or 32768 if negative
	lda tok_val + 1
	bpl @range_ok
	lda num_neg
	beq @overflow
	lda tok_val + 1
	cmp #$80
	bne @overflow
	lda tok_val
	bne @overflow
	; -32768 == $8000, already in two's complement form
	lda #TK_INT
	sta tok_type
	rts
@range_ok:
	lda num_neg
	beq :+
	sec
	lda #0
	sbc tok_val
	sta tok_val
	lda #0
	sbc tok_val + 1
	sta tok_val + 1
	:
	lda #TK_INT
	sta tok_type
	rts
@overflow:
	stx scan_pos
	lda #<err_num_range
	ldx #>err_num_range
	jmp parse_error

tok_string:
	inx ; past opening quote
	ldy #0
@loop:
	lda line_buf, X
	bne :+
	stx scan_pos
	lda #<err_unterm
	ldx #>err_unterm
	jmp parse_error
	:
	cmp #QUOTE
	bne @char
	inx
	lda line_buf, X
	cmp #QUOTE
	beq @quote_lit
	; end of string
	stx scan_pos
	sty tok_len
	lda #0
	sta tok_buf, Y
	lda #TK_STR
	sta tok_type
	rts
@quote_lit:
	lda #QUOTE
@char:
	cpy #MAX_TEXT
	jcs @too_long
	sta tok_buf, Y
	iny
	inx
	bra @loop
@too_long:
	stx scan_pos
	lda #<err_str_long
	ldx #>err_str_long
	jmp parse_error

;;; ============================================================
;;; parse helpers
;;; ============================================================

; print message in AX, set err_flag
parse_error:
	jsr print_str
	lda #NEWLINE
	jsr putc
	lda #1
	sta err_flag
	stz tok_type ; TK_EOF
	rts

; A = expected token type. reads next token.
; carry set on mismatch or error (message already printed)
expect:
	pha
	jsr next_token
	pla
	ldx err_flag
	jne @bad_silent
	cmp tok_type
	jne @bad
	clc
	rts
@bad:
	lda #<err_syntax
	ldx #>err_syntax
	jsr parse_error
@bad_silent:
	sec
	rts

; consume optional ';' then require end of line. carry set on error
stmt_end:
	jsr next_token
	lda err_flag
	jne @bad_silent
	lda tok_type
	cmp #TK_SEMI
	bne :+
	jsr next_token
	:
	lda tok_type
	beq @ok
	lda #<err_syntax
	ldx #>err_syntax
	jsr parse_error
@bad_silent:
	sec
	rts
@ok:
	clc
	rts

;;; ============================================================
;;; catalog / table info
;;; ============================================================

; find table named in tok_buf. returns A = index or $FF
catalog_find:
	ldx #0
@tbl_loop:
	cpx ntables
	bcs @not_found
	ldy mult12, X
	phx
	ldx #0
@cmp:
	lda catalog, Y
	cmp tok_buf, X
	bne @next
	cmp #0
	beq @found
	iny
	inx
	bra @cmp
@found:
	plx
	txa
	rts
@next:
	plx
	inx
	bra @tbl_loop
@not_found:
	lda #$FF
	rts

; A = catalog index. loads table header + coldefs into tbl_hdr_buf,
; sets cur_bank/cur_ncols/cur_nrows/cur_dsize/data_start
select_table:
	sta cur_tbl
	tax
	ldy mult12, X
	lda catalog + NAME_FIELD, Y
	sta cur_bank
	lda #<tbl_hdr_buf
	sta r0
	lda #>tbl_hdr_buf
	sta r0 + 1
	stz r2
	stz r1
	lda #$A0
	sta r1 + 1
	lda cur_bank
	sta r3
	lda #(TBL_HDR_SIZE + MAX_COLS * COLDEF_SIZE)
	ldx #0
	jsr memmove_extmem
	lda tbl_hdr_buf + 11
	sta cur_ncols
	lda tbl_hdr_buf + 12
	sta cur_nrows
	lda tbl_hdr_buf + 13
	sta cur_nrows + 1
	lda tbl_hdr_buf + 14
	sta cur_dsize
	lda tbl_hdr_buf + 15
	sta cur_dsize + 1
	; data_start = $A010 + 12 * ncols (low byte never carries)
	ldx cur_ncols
	lda mult12, X
	clc
	adc #TBL_HDR_SIZE
	sta data_start
	lda #$A0
	sta data_start + 1
	rts

; write nrows/dsize back into tbl_hdr_buf and the bank header
flush_table_header:
	lda cur_nrows
	sta tbl_hdr_buf + 12
	lda cur_nrows + 1
	sta tbl_hdr_buf + 13
	lda cur_dsize
	sta tbl_hdr_buf + 14
	lda cur_dsize + 1
	sta tbl_hdr_buf + 15
	stz r0
	lda #$A0
	sta r0 + 1
	lda cur_bank
	sta r2
	lda #<tbl_hdr_buf
	sta r1
	lda #>tbl_hdr_buf
	sta r1 + 1
	stz r3
	lda #TBL_HDR_SIZE
	ldx #0
	jsr memmove_extmem
	rts

; find column named in tok_buf in current table. A = index or $FF
resolve_column:
	ldx #0
@loop:
	cpx cur_ncols
	bcs @not_found
	ldy mult12, X
	phx
	ldx #0
@cmp:
	lda tbl_hdr_buf + TBL_HDR_SIZE, Y
	cmp tok_buf, X
	bne @next
	cmp #0
	beq @found
	iny
	inx
	bra @cmp
@found:
	plx
	txa
	rts
@next:
	plx
	inx
	bra @loop
@not_found:
	lda #$FF
	rts

; X = column index -> A = type byte
col_type:
	ldy mult12, X
	lda tbl_hdr_buf + TBL_HDR_SIZE + NAME_FIELD, Y
	rts

; reserve the scratch bank if not yet allocated. carry set on failure
ensure_scratch:
	lda scratch_bank
	bne @ok
	lda #0
	jsr res_extmem_bank
	sta scratch_bank
	bne @ok
	lda #<err_oom
	ldx #>err_oom
	jsr parse_error
	sec
	rts
@ok:
	clc
	rts

;;; ============================================================
;;; statement dispatch
;;; ============================================================

exec_statement:
	stz scan_pos
	jsr next_token
	lda err_flag
	bne @done
	lda tok_type
	cmp #TK_SELECT
	jeq do_select
	cmp #TK_INSERT
	jeq do_insert
	cmp #TK_UPDATE
	jeq do_update
	cmp #TK_DELETE
	jeq do_delete
	cmp #TK_CREATE
	jeq do_create
	cmp #TK_DROP
	jeq do_drop
	cmp #TK_EOF
	beq @done
	lda #<err_syntax
	ldx #>err_syntax
	jmp parse_error
@done:
	rts

;;; ============================================================
;;; CREATE TABLE name ( col type [, col type]* )
;;; ============================================================

do_create:
	lda #TK_TABLE
	jsr expect
	jcs @ret
	lda #TK_IDENT
	jsr expect
	jcs @ret
	lda tok_len
	jeq @bad_name
	cmp #NAME_LEN + 1
	jcs @bad_name
	jsr catalog_find
	cmp #$FF
	beq :+
	lda #<err_tbl_exists
	ldx #>err_tbl_exists
	jmp parse_error
	:
	lda ntables
	cmp #MAX_TABLES
	bcc :+
	lda #<err_too_many_tbl
	ldx #>err_too_many_tbl
	jmp parse_error
	:
	; zero the header buffer, then fill in the name
	ldx #0
	:
	stz tbl_hdr_buf, X
	inx
	cpx #(TBL_HDR_SIZE + MAX_COLS * COLDEF_SIZE)
	bcc :-
	ldx #0
	:
	lda tok_buf, X
	sta tbl_hdr_buf, X
	beq :+
	inx
	bra :-
	:
	lda #TK_LPAREN
	jsr expect
	jcs @ret
	stz cr_ncols
@col_loop:
	lda #TK_IDENT
	jsr expect
	jcs @ret
	lda tok_len
	jeq @bad_name
	cmp #NAME_LEN + 1
	jcs @bad_name
	lda cr_ncols
	cmp #MAX_COLS
	bcc :+
	lda #<err_too_many_cols
	ldx #>err_too_many_cols
	jmp parse_error
	:
	ldx cr_ncols
	ldy mult12, X
	ldx #0
	:
	lda tok_buf, X
	sta tbl_hdr_buf + TBL_HDR_SIZE, Y
	beq :+
	iny
	inx
	bra :-
	:
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_INT_KW
	bne :+
	lda #TYPE_INT
	bra @set_type
	:
	cmp #TK_TEXT_KW
	beq :+
	jmp @syntax
	:
	lda #TYPE_TEXT
@set_type:
	ldx cr_ncols
	ldy mult12, X
	sta tbl_hdr_buf + TBL_HDR_SIZE + NAME_FIELD, Y
	inc cr_ncols
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_COMMA
	jeq @col_loop
	cmp #TK_RPAREN
	bne @syntax
	jsr stmt_end
	jcs @ret
	; commit
	lda cr_ncols
	sta tbl_hdr_buf + 11
	lda #0
	jsr res_extmem_bank
	cmp #0
	bne :+
	lda #<err_oom
	ldx #>err_oom
	jmp parse_error
	:
	sta cur_bank
	; copy header + coldefs into the new bank
	stz r0
	lda #$A0
	sta r0 + 1
	lda cur_bank
	sta r2
	lda #<tbl_hdr_buf
	sta r1
	lda #>tbl_hdr_buf
	sta r1 + 1
	stz r3
	lda #(TBL_HDR_SIZE + MAX_COLS * COLDEF_SIZE)
	ldx #0
	jsr memmove_extmem
	; catalog entry
	ldx ntables
	ldy mult12, X
	ldx #0
	:
	lda tbl_hdr_buf, X
	sta catalog, Y
	iny
	inx
	cpx #NAME_FIELD
	bcc :-
	lda cur_bank
	sta catalog, Y
	inc ntables
	jmp save_db
@bad_name:
	lda #<err_name_long
	ldx #>err_name_long
	jmp parse_error
@syntax:
	lda #<err_syntax
	ldx #>err_syntax
	jmp parse_error
@ret:
	rts

;;; ============================================================
;;; DROP TABLE name
;;; ============================================================

do_drop:
	lda #TK_TABLE
	jsr expect
	jcs @ret
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr catalog_find
	cmp #$FF
	bne :+
	lda #<err_no_table
	ldx #>err_no_table
	jmp parse_error
	:
	sta dr_idx
	jsr stmt_end
	jcs @ret
	ldx dr_idx
	ldy mult12, X
	lda catalog + NAME_FIELD, Y
	jsr free_extmem_bank
	; shift catalog entries down over the removed one
	ldx ntables
	lda mult12, X
	sta cp_src ; end offset
	ldx dr_idx
	lda mult12, X
	tax        ; X = dst offset
	txa
	clc
	adc #COLDEF_SIZE
	tay        ; Y = src offset
@shift:
	cpy cp_src
	bcs @shift_done
	lda catalog, Y
	sta catalog, X
	inx
	iny
	bra @shift
@shift_done:
	dec ntables
	jmp save_db
@ret:
	rts

;;; ============================================================
;;; INSERT INTO name VALUES ( v [, v]* )
;;; ============================================================

do_insert:
	lda #TK_INTO
	jsr expect
	jcs @ret
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr catalog_find
	cmp #$FF
	bne :+
	lda #<err_no_table
	ldx #>err_no_table
	jmp parse_error
	:
	jsr select_table
	lda #TK_VALUES
	jsr expect
	jcs @ret
	lda #TK_LPAREN
	jsr expect
	jcs @ret
	stz ins_col
	stz ins_len
@val_loop:
	lda ins_col
	cmp cur_ncols
	bcc :+
	lda #<err_nvals
	ldx #>err_nvals
	jmp parse_error
	:
	ldx ins_col
	jsr col_type
	bne @val_text
	; INT value
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_INT
	jne @type_err
	lda ins_len
	cmp #$FE
	jcs @row_long
	ldy ins_len
	lda tok_val
	sta row_buf, Y
	iny
	lda tok_val + 1
	sta row_buf, Y
	iny
	sty ins_len
	bra @val_next
@val_text:
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_STR
	jne @type_err
	; need ins_len + 1 + tok_len <= 255
	lda ins_len
	sec
	adc tok_len ; +1 via carry
	jcs @row_long
	ldy ins_len
	lda tok_len
	sta row_buf, Y
	iny
	ldx #0
	:
	cpx tok_len
	bcs :+
	lda tok_buf, X
	sta row_buf, Y
	iny
	inx
	bra :-
	:
	sty ins_len
@val_next:
	inc ins_col
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_COMMA
	jeq @val_loop
	cmp #TK_RPAREN
	beq :+
	lda #<err_syntax
	ldx #>err_syntax
	jmp parse_error
	:
	lda ins_col
	cmp cur_ncols
	beq :+
	lda #<err_nvals
	ldx #>err_nvals
	jmp parse_error
	:
	jsr stmt_end
	jcs @ret
	; bounds: end of data + new row must stay within the bank window
	clc
	lda data_start
	adc cur_dsize
	sta wr_ptr
	lda data_start + 1
	adc cur_dsize + 1
	sta wr_ptr + 1
	lda wr_ptr
	clc
	adc ins_len
	sta tmpw
	lda wr_ptr + 1
	adc #0
	sta tmpw + 1
	cmp #$C0
	bcc @fits
	bne @full
	lda tmpw
	beq @fits
@full:
	lda #<err_tbl_full
	ldx #>err_tbl_full
	jmp parse_error
@fits:
	lda wr_ptr
	sta r0
	lda wr_ptr + 1
	sta r0 + 1
	lda cur_bank
	sta r2
	lda #<row_buf
	sta r1
	lda #>row_buf
	sta r1 + 1
	stz r3
	lda ins_len
	ldx #0
	jsr memmove_extmem
	inc_word cur_nrows
	lda cur_dsize
	clc
	adc ins_len
	sta cur_dsize
	bcc :+
	inc cur_dsize + 1
	:
	jsr flush_table_header
	jmp save_db
@type_err:
	lda #<err_type
	ldx #>err_type
	jmp parse_error
@row_long:
	lda #<err_row_long
	ldx #>err_row_long
	jmp parse_error
@ret:
	rts

;;; ============================================================
;;; WHERE clause (shared) - also consumes statement end
;;; ============================================================

; parses optional "WHERE col op literal" then end of statement.
; sets where_col ($FF = no predicate). carry set on error
parse_where:
	lda #$FF
	sta where_col
	jsr next_token
	lda err_flag
	jne @err
	lda tok_type
	cmp #TK_WHERE
	beq @have_where
	cmp #TK_SEMI
	bne :+
	jsr next_token
	lda tok_type
	:
	cmp #TK_EOF
	jeq @ok
	jmp @syntax
@have_where:
	lda #TK_IDENT
	jsr expect
	jcs @err
	jsr resolve_column
	cmp #$FF
	bne :+
	lda #<err_no_column
	ldx #>err_no_column
	jsr parse_error
	jmp @err
	:
	sta where_col
	tax
	jsr col_type
	sta where_type
	jsr next_token
	lda err_flag
	jne @err
	lda tok_type
	and #$F0
	cmp #$10
	bne @syntax
	lda tok_type
	and #$0F
	sta where_op
	lda where_type
	bne @text_lit
	jsr next_token
	lda err_flag
	jne @err
	lda tok_type
	cmp #TK_INT
	bne @type_err
	lda tok_val
	sta where_int
	lda tok_val + 1
	sta where_int + 1
	bra @end_check
@text_lit:
	; only = and != make sense for text
	lda where_op
	cmp #1
	beq :+
	cmp #6
	beq :+
	lda #<err_text_op
	ldx #>err_text_op
	jsr parse_error
	jmp @err
	:
	jsr next_token
	lda err_flag
	jne @err
	lda tok_type
	cmp #TK_STR
	bne @type_err
	lda tok_len
	sta where_len
	ldx #0
	:
	cpx tok_len
	bcs @end_check
	lda tok_buf, X
	sta where_text, X
	inx
	bra :-
@end_check:
	jmp stmt_end
@ok:
	clc
	rts
@type_err:
	lda #<err_type
	ldx #>err_type
	jsr parse_error
	jmp @err
@syntax:
	lda #<err_syntax
	ldx #>err_syntax
	jsr parse_error
@err:
	sec
	rts

;;; ============================================================
;;; row scan core
;;; ============================================================

scan_init:
	lda data_start
	sta scan_ptr
	lda data_start + 1
	sta scan_ptr + 1
	lda cur_nrows
	sta scan_rows
	lda cur_nrows + 1
	sta scan_rows + 1
	clc
	lda data_start
	adc cur_dsize
	sta scan_end
	lda data_start + 1
	adc cur_dsize + 1
	sta scan_end + 1
	stz scan_err
	rts

; copy up to 256 bytes at scan_ptr from the table bank into row_buf
fetch_row:
	sec
	lda scan_end
	sbc scan_ptr
	sta tmpw
	lda scan_end + 1
	sbc scan_ptr + 1
	sta tmpw + 1
	ora tmpw
	bne :+
	; rows remain but no data left: corrupt
	jmp scan_corrupt
	:
	lda tmpw + 1
	beq @small
	stz cnt
	lda #1
	sta cnt + 1
	bra @go
@small:
	lda tmpw
	sta cnt
	stz cnt + 1
@go:
	lda #<row_buf
	sta r0
	lda #>row_buf
	sta r0 + 1
	stz r2
	lda scan_ptr
	sta r1
	lda scan_ptr + 1
	sta r1 + 1
	lda cur_bank
	sta r3
	lda cnt
	ldx cnt + 1
	jsr memmove_extmem
	rts

scan_corrupt:
	lda #1
	sta scan_err
	lda #<err_corrupt
	ldx #>err_corrupt
	jmp parse_error

; decode the row at row_buf: fills col_off/col_len per column, row_len
decode_row:
	stz dr_off
	ldx #0
@col:
	cpx cur_ncols
	bcs @done
	jsr col_type
	bne @text
	lda dr_off
	sta col_off, X
	lda #2
	sta col_len, X
	lda dr_off
	clc
	adc #2
	bcs @corrupt
	bra @advance
@text:
	ldy dr_off
	lda row_buf, Y
	sta col_len, X
	iny
	tya
	sta col_off, X
	clc
	adc col_len, X
	bcs @corrupt
@advance:
	sta dr_off
	inx
	bra @col
@done:
	lda dr_off
	sta row_len
	rts
@corrupt:
	jmp scan_corrupt

; evaluate WHERE against decoded row. returns A = 1 match, 0 no match
eval_where:
	lda where_col
	cmp #$FF
	bne :+
	lda #1
	rts
	:
	tax
	lda where_type
	bne @text
	; signed 16-bit compare of row value vs literal
	ldy col_off, X
	lda row_buf, Y
	sta cmp_lo
	iny
	lda row_buf, Y
	sta cmp_hi
	lda cmp_lo
	cmp where_int
	bne @neq
	lda cmp_hi
	cmp where_int + 1
	bne @neq
	lda #1
	bra @apply
@neq:
	lda cmp_lo
	cmp where_int
	lda cmp_hi
	sbc where_int + 1
	bvc :+
	eor #$80
	:
	bmi @lt
	lda #4
	bra @apply
@lt:
	lda #2
	bra @apply
@text:
	lda col_len, X
	cmp where_len
	bne @tneq
	phx
	ldy col_off, X
	lda col_len, X
	sta cmp_cnt
	ldx #0
@tcmp:
	cpx cmp_cnt
	bcs @teq
	lda row_buf, Y
	cmp where_text, X
	bne @tneq_pop
	iny
	inx
	bra @tcmp
@teq:
	plx
	lda #1
	bra @apply
@tneq_pop:
	plx
@tneq:
	lda #2
@apply:
	and where_op
	beq @no
	lda #1
	rts
@no:
	lda #0
	rts

; advance scan_ptr past current row, decrement scan_rows
scan_advance:
	lda scan_ptr
	clc
	adc row_len
	sta scan_ptr
	bcc :+
	inc scan_ptr + 1
	:
	lda scan_rows
	bne :+
	dec scan_rows + 1
	:
	dec scan_rows
	rts

;;; ============================================================
;;; SELECT [cols|*] FROM name [WHERE ...]
;;; ============================================================

do_select:
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_STAR
	bne @col_list
	lda #1
	sta sel_star
	lda #TK_FROM
	jsr expect
	jcs @ret
	bra @table
@col_list:
	stz sel_star
	stz proj_cnt
@cl_loop:
	lda tok_type
	cmp #TK_IDENT
	jne @syntax
	lda proj_cnt
	cmp #MAX_COLS
	bcc :+
	lda #<err_too_many_cols
	ldx #>err_too_many_cols
	jmp parse_error
	:
	ldx proj_cnt
	ldy mult11, X
	ldx #0
	:
	lda tok_buf, X
	sta proj_names, Y
	beq :+
	iny
	inx
	bra :-
	:
	inc proj_cnt
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_COMMA
	bne @cl_done
	jsr next_token
	lda err_flag
	jne @ret
	bra @cl_loop
@cl_done:
	cmp #TK_FROM
	jne @syntax
@table:
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr catalog_find
	cmp #$FF
	bne :+
	lda #<err_no_table
	ldx #>err_no_table
	jmp parse_error
	:
	jsr select_table
	lda sel_star
	beq @resolve
	lda cur_ncols
	sta proj_cnt
	ldx #0
	:
	txa
	sta proj_idx, X
	inx
	cpx cur_ncols
	bcc :-
	bra @where
@resolve:
	ldx #0
@res_loop:
	cpx proj_cnt
	bcs @where
	phx
	ldy mult11, X
	ldx #0
	:
	lda proj_names, Y
	sta tok_buf, X
	beq :+
	iny
	inx
	bra :-
	:
	jsr resolve_column
	plx
	cmp #$FF
	bne :+
	lda #<err_no_column
	ldx #>err_no_column
	jmp parse_error
	:
	sta proj_idx, X
	inx
	bra @res_loop
@where:
	jsr parse_where
	jcs @ret
	; execute
	jsr print_header
	jsr scan_init
@row_loop:
	lda scan_rows
	ora scan_rows + 1
	beq @ret
	jsr fetch_row
	lda scan_err
	bne @ret
	jsr decode_row
	lda scan_err
	bne @ret
	jsr eval_where
	cmp #0
	beq @next_row
	jsr print_row
@next_row:
	jsr scan_advance
	bra @row_loop
@syntax:
	lda #<err_syntax
	ldx #>err_syntax
	jmp parse_error
@ret:
	rts

print_header:
	ldx #0
@loop:
	cpx proj_cnt
	bcs @nl
	txa
	beq :+
	lda #'|'
	jsr putc
	:
	phx
	lda proj_idx, X
	tax
	lda mult12, X
	clc
	adc #<(tbl_hdr_buf + TBL_HDR_SIZE)
	pha
	lda #>(tbl_hdr_buf + TBL_HDR_SIZE)
	adc #0
	tax
	pla
	jsr print_str
	plx
	inx
	bra @loop
@nl:
	lda #NEWLINE
	jsr putc
	rts

print_row:
	ldx #0
@loop:
	cpx proj_cnt
	jcs @nl
	txa
	beq :+
	lda #'|'
	jsr putc
	:
	phx
	lda proj_idx, X
	tax
	jsr col_type
	bne @text
	ldy col_off, X
	lda row_buf, Y
	iny
	pha
	lda row_buf, Y
	tax
	pla
	jsr print_int
	bra @next
@text:
	lda col_len, X
	sta pr_cnt
	lda col_off, X
	sta pr_off
@text_loop:
	lda pr_cnt
	beq @next
	ldy pr_off
	lda row_buf, Y
	jsr putc
	inc pr_off
	dec pr_cnt
	bra @text_loop
@next:
	plx
	inx
	jmp @loop
@nl:
	lda #NEWLINE
	jsr putc
	rts

; print signed 16-bit value in AX (A = lo, X = hi)
print_int:
	sta pi_lo
	stx pi_hi
	lda pi_hi
	bpl :+
	lda #'-'
	jsr putc
	sec
	lda #0
	sbc pi_lo
	sta pi_lo
	lda #0
	sbc pi_hi
	sta pi_hi
	:
	lda pi_lo
	ldx pi_hi
	jsr bin_to_bcd16
	sta pi_bcd + 2
	stx pi_bcd + 1
	sty pi_bcd + 0
	; hex_num_to_string returns high digit in .A, low digit in .X
	lda pi_bcd + 0
	jsr hex_num_to_string
	sta pi_buf + 0
	stx pi_buf + 1
	lda pi_bcd + 1
	jsr hex_num_to_string
	sta pi_buf + 2
	stx pi_buf + 3
	lda pi_bcd + 2
	jsr hex_num_to_string
	sta pi_buf + 4
	stx pi_buf + 5
	ldx #0
	:
	cpx #5
	bcs @print
	lda pi_buf, X
	cmp #'0'
	bne @print
	inx
	bra :-
@print:
	lda pi_buf, X
	jsr putc
	inx
	cpx #6
	bcc @print
	rts

;;; ============================================================
;;; UPDATE name SET col = val [WHERE ...]
;;; ============================================================

do_update:
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr catalog_find
	cmp #$FF
	bne :+
	lda #<err_no_table
	ldx #>err_no_table
	jmp parse_error
	:
	jsr select_table
	lda #TK_SET
	jsr expect
	jcs @ret
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr resolve_column
	cmp #$FF
	bne :+
	lda #<err_no_column
	ldx #>err_no_column
	jmp parse_error
	:
	sta upd_col
	tax
	jsr col_type
	sta upd_type
	lda #TK_EQ
	jsr expect
	jcs @ret
	lda upd_type
	bne @text_val
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_INT
	jne @type_err
	lda tok_val
	sta upd_int
	lda tok_val + 1
	sta upd_int + 1
	bra @where
@text_val:
	jsr next_token
	lda err_flag
	jne @ret
	lda tok_type
	cmp #TK_STR
	jne @type_err
	lda tok_len
	sta upd_len
	ldx #0
	:
	cpx tok_len
	bcs @where
	lda tok_buf, X
	sta upd_text, X
	inx
	bra :-
@where:
	jsr parse_where
	jcs @ret
	lda #MODE_UPDATE
	sta rw_mode
	jmp exec_rewrite
@type_err:
	lda #<err_type
	ldx #>err_type
	jmp parse_error
@ret:
	rts

;;; ============================================================
;;; DELETE FROM name [WHERE ...]
;;; ============================================================

do_delete:
	lda #TK_FROM
	jsr expect
	jcs @ret
	lda #TK_IDENT
	jsr expect
	jcs @ret
	jsr catalog_find
	cmp #$FF
	bne :+
	lda #<err_no_table
	ldx #>err_no_table
	jmp parse_error
	:
	jsr select_table
	jsr parse_where
	jcs @ret
	lda #MODE_DELETE
	sta rw_mode
	jmp exec_rewrite
@ret:
	rts

;;; ============================================================
;;; rewrite engine for UPDATE / DELETE
;;;
;;; rows are streamed through row_buf into a scratch bank
;;; (matches modified or skipped), then the rebuilt data area is
;;; copied back over the table bank. nothing is committed if an
;;; error occurs mid-scan.
;;; ============================================================

exec_rewrite:
	jsr ensure_scratch
	jcs @ret
	jsr scan_init
	lda data_start
	sta out_ptr
	lda data_start + 1
	sta out_ptr + 1
	stz match_cnt
	stz match_cnt + 1
@row_loop:
	lda scan_rows
	ora scan_rows + 1
	jeq @finish
	jsr fetch_row
	lda scan_err
	jne @ret
	jsr decode_row
	lda scan_err
	jne @ret
	jsr eval_where
	cmp #0
	beq @emit
	inc_word match_cnt
	lda rw_mode
	cmp #MODE_DELETE
	beq @skip_row
	jsr apply_update
	jcs @ret
@emit:
	lda out_ptr
	sta r0
	lda out_ptr + 1
	sta r0 + 1
	lda scratch_bank
	sta r2
	lda #<row_buf
	sta r1
	lda #>row_buf
	sta r1 + 1
	stz r3
	lda row_len
	ldx #0
	jsr memmove_extmem
	lda out_ptr
	clc
	adc row_len
	sta out_ptr
	bcc @skip_row
	inc out_ptr + 1
@skip_row:
	jsr scan_advance
	jmp @row_loop
@finish:
	lda match_cnt
	ora match_cnt + 1
	beq @report
	; new data size = out_ptr - data_start
	sec
	lda out_ptr
	sbc data_start
	sta cur_dsize
	lda out_ptr + 1
	sbc data_start + 1
	sta cur_dsize + 1
	; copy rebuilt data scratch bank -> table bank
	lda cur_dsize
	ora cur_dsize + 1
	beq @no_data
	lda data_start
	sta r0
	sta r1
	lda data_start + 1
	sta r0 + 1
	sta r1 + 1
	lda cur_bank
	sta r2
	lda scratch_bank
	sta r3
	lda cur_dsize
	ldx cur_dsize + 1
	jsr memmove_extmem
@no_data:
	lda rw_mode
	cmp #MODE_DELETE
	bne :+
	sec
	lda cur_nrows
	sbc match_cnt
	sta cur_nrows
	lda cur_nrows + 1
	sbc match_cnt + 1
	sta cur_nrows + 1
	:
	jsr flush_table_header
	jsr save_db
@report:
	lda match_cnt
	ldx match_cnt + 1
	jsr print_int
	lda rw_mode
	cmp #MODE_DELETE
	bne :+
	lda #<str_deleted
	ldx #>str_deleted
	jmp print_str
	:
	lda #<str_updated
	ldx #>str_updated
	jmp print_str
@ret:
	rts

; replace column upd_col in the decoded row_buf row.
; carry set on error (row too long)
apply_update:
	ldx upd_col
	lda upd_type
	bne @text
	ldy col_off, X
	lda upd_int
	sta row_buf, Y
	iny
	lda upd_int + 1
	sta row_buf, Y
	clc
	rts
@text:
	; new row length = row_len - old_len + new_len, must be <= 255
	lda row_len
	sec
	sbc col_len, X
	clc
	adc upd_len
	jcs @too_long
	sta new_rowlen
	lda col_off, X
	sta uc_off
	; tail = bytes after the old value
	lda col_off, X
	clc
	adc col_len, X
	sta tail_src
	lda uc_off
	clc
	adc upd_len
	sta tail_dst
	sec
	lda row_len
	sbc tail_src
	sta tail_cnt
	lda upd_len
	cmp col_len, X
	beq @copy_in
	bcc @shrink
	; grow: copy tail backward, descending
	ldx tail_cnt
@grow_loop:
	cpx #0
	beq @copy_in
	dex
	txa
	clc
	adc tail_src
	tay
	lda row_buf, Y
	pha
	txa
	clc
	adc tail_dst
	tay
	pla
	sta row_buf, Y
	bra @grow_loop
@shrink:
	; shrink: copy tail forward, ascending
	ldx #0
@shrink_loop:
	cpx tail_cnt
	bcs @copy_in
	txa
	clc
	adc tail_src
	tay
	lda row_buf, Y
	pha
	txa
	clc
	adc tail_dst
	tay
	pla
	sta row_buf, Y
	inx
	bra @shrink_loop
@copy_in:
	ldy uc_off
	dey
	lda upd_len
	sta row_buf, Y
	ldx #0
@txt_loop:
	cpx upd_len
	bcs @fix_len
	txa
	clc
	adc uc_off
	tay
	lda upd_text, X
	sta row_buf, Y
	inx
	bra @txt_loop
@fix_len:
	; keep col_len current in case upd_col is also the where col next row
	ldx upd_col
	lda upd_len
	sta col_len, X
	lda new_rowlen
	sta row_len
	clc
	rts
@too_long:
	lda #<err_row_long
	ldx #>err_row_long
	jsr parse_error
	sec
	rts

;;; ============================================================
;;; database file load / save
;;; ============================================================

; load db_filename into extmem banks. carry set on fatal error
load_db:
	lda #<db_filename
	ldx #>db_filename
	ldy #'R'
	jsr open_file
	cmp #$FF
	bne :+
	clc ; no file yet: empty database
	rts
	:
	sta cur_fd
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	lda #8
	sta r1
	stz r1 + 1
	stz r2
	lda cur_fd
	jsr read_file
	cpy #0
	jne @bad
	cmp #0
	bne :+
	cpx #0
	bne :+
	; zero-byte file: treat as empty database
	jmp @close_ok
	:
	cmp #8
	jne @bad
	cpx #0
	jne @bad
	lda io_buf + 0
	cmp #'X'
	jne @bad
	lda io_buf + 1
	cmp #'1'
	jne @bad
	lda io_buf + 2
	cmp #'6'
	jne @bad
	lda io_buf + 3
	cmp #'D'
	jne @bad
	lda io_buf + 4
	cmp #1
	jne @bad
	lda io_buf + 5
	cmp #MAX_TABLES + 1
	jcs @bad
	sta load_cnt
	stz tbl_i
@tbl_loop:
	lda tbl_i
	cmp load_cnt
	jcs @close_ok
	; 16-byte table header
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	lda #TBL_HDR_SIZE
	sta r1
	stz r1 + 1
	stz r2
	lda cur_fd
	jsr read_file
	cpy #0
	jne @bad
	cmp #TBL_HDR_SIZE
	jne @bad
	cpx #0
	jne @bad
	lda io_buf + 11
	jeq @bad
	cmp #MAX_COLS + 1
	jcs @bad
	; remaining = 12 * ncols + data_size, must be <= 8176
	tax
	lda mult12, X
	clc
	adc io_buf + 14
	sta cnt
	lda io_buf + 15
	adc #0
	sta cnt + 1
	jcs @bad
	cmp #$1F
	bcc @size_ok
	jne @bad
	lda cnt
	cmp #$F1
	jcs @bad
@size_ok:
	lda #0
	jsr res_extmem_bank
	cmp #0
	jeq @oom
	sta cur_bank
	; copy 16-byte header into bank
	stz r0
	lda #$A0
	sta r0 + 1
	lda cur_bank
	sta r2
	lda #<io_buf
	sta r1
	lda #>io_buf
	sta r1 + 1
	stz r3
	lda #TBL_HDR_SIZE
	ldx #0
	jsr memmove_extmem
	; read coldefs + row data straight into the bank
	lda cnt
	ora cnt + 1
	beq @reg_table
	lda #$10
	sta r0
	lda #$A0
	sta r0 + 1
	lda cnt
	sta r1
	lda cnt + 1
	sta r1 + 1
	lda cur_bank
	sta r2
	lda cur_fd
	jsr read_file
	cpy #0
	jne @bad
	cmp cnt
	jne @bad
	cpx cnt + 1
	jne @bad
@reg_table:
	; catalog entry
	ldx tbl_i
	ldy mult12, X
	ldx #0
	:
	lda io_buf, X
	sta catalog, Y
	iny
	inx
	cpx #NAME_FIELD
	bcc :-
	lda cur_bank
	sta catalog, Y
	inc ntables
	inc tbl_i
	jmp @tbl_loop
@close_ok:
	lda cur_fd
	jsr close_file
	clc
	rts
@bad:
	lda cur_fd
	jsr close_file
	lda #<err_badfile
	ldx #>err_badfile
	jsr print_str
	lda #NEWLINE
	jsr putc
	sec
	rts
@oom:
	lda cur_fd
	jsr close_file
	lda #<err_oom
	ldx #>err_oom
	jsr print_str
	lda #NEWLINE
	jsr putc
	sec
	rts

; rewrite the whole database file from the in-memory banks
save_db:
	lda #<db_filename
	ldx #>db_filename
	ldy #'W'
	jsr open_file
	cmp #$FF
	bne :+
	lda #<err_write
	ldx #>err_write
	jmp parse_error
	:
	sta cur_fd
	; 8-byte file header
	lda #'X'
	sta io_buf + 0
	lda #'1'
	sta io_buf + 1
	lda #'6'
	sta io_buf + 2
	lda #'D'
	sta io_buf + 3
	lda #1
	sta io_buf + 4
	lda ntables
	sta io_buf + 5
	stz io_buf + 6
	stz io_buf + 7
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	lda #8
	sta r1
	stz r1 + 1
	lda cur_fd
	jsr write_file
	stz tbl_i
@tbl_loop:
	lda tbl_i
	cmp ntables
	jcs @done
	ldx tbl_i
	ldy mult12, X
	lda catalog + NAME_FIELD, Y
	sta sv_bank
	; pull the table header to learn ncols / data_size
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	stz r2
	stz r1
	lda #$A0
	sta r1 + 1
	lda sv_bank
	sta r3
	lda #TBL_HDR_SIZE
	ldx #0
	jsr memmove_extmem
	; total = 16 + 12 * ncols + data_size
	ldx io_buf + 11
	lda mult12, X
	clc
	adc #TBL_HDR_SIZE
	clc
	adc io_buf + 14
	sta sv_rem
	lda io_buf + 15
	adc #0
	sta sv_rem + 1
	stz sv_off
	lda #$A0
	sta sv_off + 1
@chunk_loop:
	lda sv_rem
	ora sv_rem + 1
	beq @next_tbl
	; chunk = min(256, sv_rem)
	lda sv_rem + 1
	beq @small
	stz cnt
	lda #1
	sta cnt + 1
	bra @copy
@small:
	lda sv_rem
	sta cnt
	stz cnt + 1
@copy:
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	stz r2
	lda sv_off
	sta r1
	lda sv_off + 1
	sta r1 + 1
	lda sv_bank
	sta r3
	lda cnt
	ldx cnt + 1
	jsr memmove_extmem
	lda #<io_buf
	sta r0
	lda #>io_buf
	sta r0 + 1
	lda cnt
	sta r1
	lda cnt + 1
	sta r1 + 1
	lda cur_fd
	jsr write_file
	cpy #0
	bne @write_err
	; sv_off += cnt; sv_rem -= cnt
	clc
	lda sv_off
	adc cnt
	sta sv_off
	lda sv_off + 1
	adc cnt + 1
	sta sv_off + 1
	sec
	lda sv_rem
	sbc cnt
	sta sv_rem
	lda sv_rem + 1
	sbc cnt + 1
	sta sv_rem + 1
	jmp @chunk_loop
@next_tbl:
	inc tbl_i
	jmp @tbl_loop
@done:
	lda cur_fd
	jsr close_file
	rts
@write_err:
	lda cur_fd
	jsr close_file
	lda #<err_write
	ldx #>err_write
	jmp parse_error

;;; ============================================================
;;; data
;;; ============================================================

; index * 12 (9 entries: also used for end offsets)
mult12:
	.byte 0, 12, 24, 36, 48, 60, 72, 84, 96
; index * 11
mult11:
	.byte 0, 11, 22, 33, 44, 55, 66, 77

kw_table:
	.byte "SELECT", 0, TK_SELECT
	.byte "INSERT", 0, TK_INSERT
	.byte "UPDATE", 0, TK_UPDATE
	.byte "DELETE", 0, TK_DELETE
	.byte "CREATE", 0, TK_CREATE
	.byte "DROP", 0, TK_DROP
	.byte "TABLE", 0, TK_TABLE
	.byte "INTO", 0, TK_INTO
	.byte "VALUES", 0, TK_VALUES
	.byte "FROM", 0, TK_FROM
	.byte "WHERE", 0, TK_WHERE
	.byte "SET", 0, TK_SET
	.byte "INT", 0, TK_INT_KW
	.byte "TEXT", 0, TK_TEXT_KW
	.byte 0

str_usage:
	.byte "usage: db file.db [", QUOTE, "statement", QUOTE, "]", NEWLINE, 0
str_prompt:
	.asciiz "db> "
str_help:
	.byte ".tables        list tables", NEWLINE
	.byte ".schema        show CREATE statements", NEWLINE
	.byte ".quit          exit", NEWLINE
	.byte "sql: CREATE TABLE t (c INT, c TEXT) / DROP TABLE t", NEWLINE
	.byte "     INSERT INTO t VALUES (1, 'a')", NEWLINE
	.byte "     SELECT c|* FROM t [WHERE c op val]", NEWLINE
	.byte "     UPDATE t SET c = val [WHERE ...]", NEWLINE
	.byte "     DELETE FROM t [WHERE ...]", NEWLINE, 0
str_dot_quit:
	.asciiz "quit"
str_dot_exit:
	.asciiz "exit"
str_dot_tables:
	.asciiz "tables"
str_dot_schema:
	.asciiz "schema"
str_dot_help:
	.asciiz "help"
str_create_tbl:
	.asciiz "CREATE TABLE "
str_open_paren:
	.asciiz " ("
str_close_paren:
	.byte ");", NEWLINE, 0
str_comma_sp:
	.asciiz ", "
str_int:
	.asciiz "INT"
str_text:
	.asciiz "TEXT"
str_updated:
	.byte " row(s) updated", NEWLINE, 0
str_deleted:
	.byte " row(s) deleted", NEWLINE, 0

err_syntax:
	.asciiz "err: syntax error"
err_badchar:
	.asciiz "err: bad character"
err_num_range:
	.asciiz "err: number out of range"
err_unterm:
	.asciiz "err: unterminated string"
err_str_long:
	.asciiz "err: string too long"
err_name_long:
	.asciiz "err: bad name"
err_tbl_exists:
	.asciiz "err: table already exists"
err_too_many_tbl:
	.asciiz "err: too many tables"
err_too_many_cols:
	.asciiz "err: too many columns"
err_no_table:
	.asciiz "err: no such table"
err_no_column:
	.asciiz "err: no such column"
err_type:
	.asciiz "err: type mismatch"
err_nvals:
	.asciiz "err: wrong number of values"
err_row_long:
	.asciiz "err: row too long"
err_tbl_full:
	.asciiz "err: table full"
err_oom:
	.asciiz "err: out of memory"
err_badfile:
	.asciiz "err: not a valid db file"
err_write:
	.asciiz "err: cannot write db file"
err_text_op:
	.asciiz "err: bad operator for text"
err_corrupt:
	.asciiz "err: corrupt table data"
err_unk_dot:
	.asciiz "err: unknown command"

;;; ============================================================
;;; bss
;;; ============================================================

.segment "BSS"

argc:
	.res 1
one_shot:
	.res 1
quit_flag:
	.res 1
err_flag:
	.res 1
scan_err:
	.res 1

db_filename:
	.res 128
line_buf:
	.res 256
tok_buf:
	.res 104
tok_type:
	.res 1
tok_len:
	.res 1
tok_val:
	.res 2
scan_pos:
	.res 1
num_neg:
	.res 1
num_digit:
	.res 1
num_t2:
	.res 2

catalog:
	.res MAX_TABLES * COLDEF_SIZE
ntables:
	.res 1
cur_fd:
	.res 1
load_cnt:
	.res 1
tbl_i:
	.res 1

tbl_hdr_buf:
	.res TBL_HDR_SIZE + MAX_COLS * COLDEF_SIZE
cur_tbl:
	.res 1
cur_bank:
	.res 1
cur_ncols:
	.res 1
cur_nrows:
	.res 2
cur_dsize:
	.res 2
data_start:
	.res 2
scratch_bank:
	.res 1

row_buf:
	.res 256
io_buf:
	.res 256

col_off:
	.res MAX_COLS
col_len:
	.res MAX_COLS
row_len:
	.res 1
dr_off:
	.res 1

proj_names:
	.res MAX_COLS * NAME_FIELD
proj_idx:
	.res MAX_COLS
proj_cnt:
	.res 1
sel_star:
	.res 1

where_col:
	.res 1
where_op:
	.res 1
where_type:
	.res 1
where_int:
	.res 2
where_len:
	.res 1
where_text:
	.res MAX_TEXT + 1

upd_col:
	.res 1
upd_type:
	.res 1
upd_int:
	.res 2
upd_len:
	.res 1
upd_text:
	.res MAX_TEXT + 1

ins_col:
	.res 1
ins_len:
	.res 1
cr_ncols:
	.res 1
dr_idx:
	.res 1
cp_src:
	.res 1

wr_ptr:
	.res 2
tmpw:
	.res 2
cnt:
	.res 2
scan_ptr:
	.res 2
scan_rows:
	.res 2
scan_end:
	.res 2
out_ptr:
	.res 2
match_cnt:
	.res 2
rw_mode:
	.res 1

new_rowlen:
	.res 1
tail_src:
	.res 1
tail_dst:
	.res 1
tail_cnt:
	.res 1
uc_off:
	.res 1

cmp_lo:
	.res 1
cmp_hi:
	.res 1
cmp_cnt:
	.res 1

sv_bank:
	.res 1
sv_off:
	.res 2
sv_rem:
	.res 2

pi_lo:
	.res 1
pi_hi:
	.res 1
pi_bcd:
	.res 3
pi_buf:
	.res 6
pr_cnt:
	.res 1
pr_off:
	.res 1
