.include "routines.inc"
.segment "CODE"

COLOR_WHITE = $05
COLOR_BLUE = $9A ; light blue
COLOR_GREEN = $99 ; actually light green

NEWLINE = $0A

r0L = r0
r0H = r0 + 1
r1L = r1
r1H = r1 + 1

ptr0 = $30
ptr1 = $32
ptr2 = $34
ptr3 = $36

init:
	; get pwd ;
	lda #$80
	sta r1
	stz r1 + 1
	
	lda #<pwd_buff
	sta r0
	lda #>pwd_buff
	sta r0 + 1
	jsr get_pwd
	
	jsr res_extmem_bank
	sta extmem_bank
	
	jsr get_args
	sta ptr1
	stx ptr1 + 1
	sty ptr2
	
	jsr get_console_info
	sta foreground_color

	stz exit_code
	stz dir_names_size
	
args_loop:
	dec ptr2 ; argc
	bne @not_out_args

	jmp print_dirs_list
@not_out_args:
	jsr get_next_arg	
	
	lda (ptr1)
	cmp #'-'
	bne add_dir_list
	ldy #1
	lda (ptr1), Y
	bne :+
	jmp flag_error
	:
parse_flag:
	inc ptr1
	bne :+
	inc ptr1 + 1
	:
	lda (ptr1)
	beq args_loop

	cmp #'a'
	bne :+

	lda #1
	sta print_dotfiles_flag
	sta print_this_dir_parent_dir_flag
	bra parse_flag
	:

	cmp #'A'
	bne :+

	lda #1
	sta print_dotfiles_flag
	bra parse_flag
	:

	cmp #'C'
	bne :+

	lda #1
	sta use_colors_flag
	bra parse_flag
	:
	
	cmp #'F'
	bne :+

	lda #1
	sta classify_files_flag
	bra parse_flag
	:
	
	cmp #'l'
	bne :+
	
	lda #1
	sta list_details_flag
	bra parse_flag
	:

	cmp #'h'
	beq print_usage

	jmp flag_error

add_dir_list:
	ldx dir_names_size
	lda ptr1
	sta dir_names_lo, X
	lda ptr1 + 1
	sta dir_names_hi, X

	inc dir_names_size
	jmp args_loop

print_dirs_list:
	stz @dir_names_index
	
	lda dir_names_size
	bne :+

	stz dir_names_lo + 0
	stz dir_names_hi + 0

	inc dir_names_size
	:
@print_dirs_list_loop:
	ldx @dir_names_index
	lda dir_names_lo, X
	sta ptr1
	lda dir_names_hi, X
	sta ptr1 + 1
	jsr print_dir

	ldx @dir_names_index
	inx
	stx @dir_names_index
	cpx dir_names_size
	bcc @print_dirs_list_loop

	lda exit_code
	rts
	

@dir_names_index:
	.byte 0
@this_dir:
	.asciiz "."

print_usage:
	lda #<@str
	ldx #>@str
	jsr print_str
	
	lda #0
	rts
@str:
	.byte "Usage: ls [OPTION]... [FILE]...", NEWLINE
	.byte "List information about the FILEs (the current directory by default)", NEWLINE
	.byte NEWLINE
	.byte "Options:", NEWLINE
	.byte "  -a:     do not ignore entries starting with with .", NEWLINE
	.byte "  -A:     print all files except implied . and ..", NEWLINE
	.byte "  -C:     print entries in color", NEWLINE
	.byte "  -F:     append indicator (one of * or /) to entries", NEWLINE
	.byte "  -h:     print this message and exit", NEWLINE
	.byte "  -l:     use a long listing format", NEWLINE
	.byte NEWLINE
	.byte "Exit status:", NEWLINE
	.byte " 0  if OK,", NEWLINE
	.byte " 1  if minor problems (e.g., cannot access subdirectory),", NEWLINE
	.byte " 2  if serious trouble (e.g., cannot access command-line argument).", NEWLINE
	.byte NEWLINE, 0

print_dir:
	lda ptr1
	ora ptr1 + 1
	beq dont_change_dirs

	lda #<pwd_buff
	ldx #>pwd_buff
	jsr chdir
	
	; now cd to arg dir
	lda ptr1
	ldx ptr1 + 1
	jsr chdir
	; check if that was a success
	cmp #0
	beq :+

	lda #<no_such_dir_str_p1
	ldx #>no_such_dir_str_p1
	jsr print_str

	lda ptr1
	ldx ptr1 + 1
	jsr print_str

	lda #<no_such_dir_str_p2
	ldx #>no_such_dir_str_p2
	jsr print_str

	lda #1
	sta exit_code

	rts

	:	
	lda dir_names_size
	cmp #2
	bcc dont_change_dirs
	
	lda ptr1
	ldx ptr1 + 1
	jsr print_str
	
	lda #':'
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT	

dont_change_dirs:	
	lda #<$A000
	sta r0
	lda #>$A000
	sta r0 + 1

	lda #<$2000
	sta r1
	lda #>$2000
	sta r1 + 1

	lda extmem_bank
	jsr set_extmem_wbank

	lda #0
	jsr fill_extmem
	
	lda extmem_bank
	jsr load_dir_listing_extmem
	cpx #$FF
	bne :+
	jmp file_error
	rts
	:
	
	sta end_listing_addr
	stx end_listing_addr + 1
	
	rep #$10
	.i16
	ldx #$A004
	stx ptr3
	sep #$10
	.i8
	
	lda #1
	sta first_line

print_dir_loop:
	rep #$10
	.i16
	ldx #buff
	stx r0
	stz r2
	ldx ptr3
	stx r1
	lda extmem_bank
	sta r3
	sep #$10
	.i8
	lda #<128
	ldx #>128
	jsr memmove_extmem

	jsr get_strlen_buff
	rep #$20
	.a16
	and #$00FF
	clc
	adc #4 + 1
	adc ptr3
	sta ptr3

	cmp end_listing_addr ; don't print last line ; just says X KB FREE
	sep #$20
	.a8
	bcc @not_end_listing
	lda dir_names_size
	cmp #2
	bcc :+
	lda #NEWLINE
	jsr CHROUT
	:
	rts
@not_end_listing:

	lda first_line
	beq :+
	jmp end_print_dir_loop
	:

	;
	; print file names between quotes
	;
	rep #$10
	.i16
	ldx #buff
	lda #'"'
	jsr strchr
	inx
	stx file_name_ptr

	lda print_this_dir_parent_dir_flag
	bne @not_dotfile

	lda $00, X
	cmp #'.'
	bne @not_dotfile
	lda print_dotfiles_flag
	bne :+
	jmp end_print_dir_loop
	:
	txy
	iny
	lda $00, Y
	cmp #'"'
	beq :+
	cmp #'.'
	bne @not_dotfile
	iny
	lda $00, Y
	cmp #'"'
	bne @not_dotfile
	:
	jmp end_print_dir_loop
@not_dotfile:

@print_file:
	lda #'"'
	jsr strchr
	stz $00, X
	inx
	jsr find_non_space_char
	stz file_is_dir
	lda $00, X
	cmp #'D'
	bne :+
	lda #1
	sta file_is_dir
	:

	lda list_details_flag
	beq @done_print_file_details
	jsr find_space_char
	jsr find_non_space_char
	lda $00, X
	bne :+
	ldx #no_details_str
	jsr print_str_x
	bra @done_print_file_details
	:
	phx ; date/time of file edit/creation
	
	jsr find_space_char
	inx
	jsr find_space_char
	stz $00, X
	inx
	jsr find_space_char
	inx
	phx
	jsr find_space_char
	stz $00, X
	plx
	jsr print_str_x
	
	lda #' '
	jsr CHROUT
	plx
	jsr print_str_x
	lda #' '
	jsr CHROUT
@done_print_file_details:	
	
	lda use_colors_flag
	beq :++
	ldx #COLOR_BLUE
	lda file_is_dir
	bne :+
	ldx #COLOR_GREEN
	:
	txa
	jsr CHROUT
	:

	lda file_name_ptr
	ldx file_name_ptr + 1
	jsr print_str

	lda use_colors_flag
	beq :+
	lda foreground_color
	jsr CHROUT
	:
	
	lda classify_files_flag
	beq :++
	ldx #'/'
	lda file_is_dir
	bne :+
	ldx #'*'
	:
	txa
	jsr CHROUT
	:
	
	sep #$10
	.i8

	lda #NEWLINE
	jsr CHROUT

	; end of loop
end_print_dir_loop:
	stz first_line
	jmp print_dir_loop

file_is_dir:
	.word 0
file_name_ptr:
	.word 0


get_strlen_buff:
	rep #$10
	.i16
	ldx #buff
	ldy #0
	:
	lda $00, X
	beq :+
	inx
	iny
	bra :-
	:
	tya
	sep #$10
	.i8
	rts

;
; print_str_x
;
print_str_x:
	.i16
	rep #$20
	.a16
	txa
	xba
	tax
	xba
	sep #$20
	.a8
	jmp print_str
	.i8

;
; assumes 16-bit index mode
;
strchr:
	.i16
	cmp $00, X
	pha
	beq :+
	lda $00, X
	beq :+
	pla
	inx
	bne strchr
	:
	pla
	rts
	.i8

;
; assumes 16-bit index mode
;
find_non_space_char:
	.i16
	lda $00, X
	beq :+
	cmp #' '
	bne :+
	inx
	bne find_non_space_char
	:
	rts
	.i8
	
;
; assumes 16-bit index mode
;
find_space_char:
	.i16
	lda $00, X
	beq :+
	cmp #' '
	beq :+
	inx
	bne find_space_char
	:
	rts
	.i8

get_next_arg:
	ldy #0
	:
	lda (ptr1), Y
	beq :+
	iny
	bra :-
	: ; \0 found
	
	:
	lda (ptr1), Y
	bne :+
	iny
	bra :-
	:
	
	tya
	clc
	adc ptr1
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	
	rts

file_error:
	phx

	lda #<error_msg
	ldx #>error_msg
	jsr PRINT_STR
	
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #NEWLINE
	jsr CHROUT

	lda #1
	sta exit_code
	
	rts

flag_error:
	lda #<@flag_error_str
	ldx #>@flag_error_str
	jsr print_str

	lda ptr1
	ldx ptr1 + 1
	jsr print_str

	lda #NEWLINE
	jsr CHROUT

	lda #2
	rts
	
@flag_error_str:
	.asciiz "ls: unknown option -- "

;
; ls option flags
;
print_dotfiles_flag:
	.word 0
print_this_dir_parent_dir_flag:
	.word 0
use_colors_flag:
	.word 0
classify_files_flag:
	.word 0
list_details_flag:
	.word 0
	
end_listing_addr:
	.word 0
foreground_color:
	.byte 0

err_num:
	.byte 0
first_line:
	.byte 0
exit_code:
	.byte 0

extmem_bank:
	.byte 0	
error_msg:
	.asciiz "Error opening directory listing, code #:"

no_details_str:
	.asciiz "00000000                     "

no_such_dir_str_p1:
	.asciiz "ls: cannot access '"
no_such_dir_str_p2:
	.byte "': No such directory exists", NEWLINE, 0

.SEGMENT "BSS"
pwd_buff:
	.res $80
dir_names_lo:
	.res 128
dir_names_hi:
	.res 128
dir_names_size:
	.word 0	
buff: