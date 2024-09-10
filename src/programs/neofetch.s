.include "routines.inc"
.feature  c_comments

SWAP_COLORS = 1

COLOR_WHITE = $05
COLOR_RED = $1C
COLOR_GREEN = $1E
COLOR_BLUE = $1F
COLOR_ORANGE = $81
COLOR_BLACK = $90
COLOR_BROWN = $95
COLOR_LRED = $96

COLOR_DGRAY = $97
COLOR_MGRAY = $98
COLOR_LGREEN = $99
COLOR_LBLUE = $9A
COLOR_LGRAY = $9B
COLOR_PURPLE = $9C
COLOR_YELLOW = $9E
COLOR_CYAN = $9F

SINGLE_QUOTE = 39

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 := $30
ptr1 := $32
ptr2 := $34

.segment "CODE"
	rep #$10
	.i16
	
	ldx #0
	stx info_functions_size
	stx info_functions_index
	
	lda #<config_file_location
	ldx #>config_file_location
	ldy #0
	jsr open_file
	cmp #$FF
	beq :+
	sta config_file_fd
	jsr use_file_config
	bra :++
	:
	jsr use_default_config
	:
	
	lda #1
	sta still_print_ascii
	lda #1
	sta still_print_info
	
	jsr get_length_first_ascii_line
	jmp print_loop
	
print_loop:
	lda still_print_ascii
	ora still_print_info
	bne :+
	lda #0 ; done, exit
	rts
	:
	
	jsr print_ascii_line	
	jsr print_next_info_line
	
	jmp print_loop

use_file_config:
	; go through each line of file ;
@get_next_line:
	ldy #0
@get_next_line_loop:
	phy
	ldx config_file_fd
	jsr fgetc
	ply
	sta file_contents_buff, Y
	cpx #0
	beq :+
	ldx #1
	sta @eof
	bra @end_loop
	:
	cmp #$d
	beq @end_loop
	iny
	bra @get_next_line_loop
@end_loop:
	lda #0
	sta file_contents_buff, Y
	
	; now we can parse this line ;
	jsr parse_config_line
	
	lda @eof
	bne :+
	jmp @get_next_line
	:
	
	; close file ;
	lda config_file_fd
	jsr close_file
	
	ldx ascii_ptr
	bne @end
	lda filename_buffer
	bne :+
	; No ascii art set ;
	ldx #alt_x16_art
	stx ascii_ptr
	beq @end
	:
	
	lda #<filename_buffer
	ldx #>filename_buffer
	ldy #0
	jsr open_file
	cmp #$FF
	bne :+
	
	; file doesn't exist
	lda #<ascii_file_doesnt_exist_err_str
	ldx #>ascii_file_doesnt_exist_err_str
	jsr print_str
	
	lda #<filename_buffer	
	ldx #>filename_buffer
	jsr print_str
	
	lda #SINGLE_QUOTE
	jsr CHROUT
	jsr print_cr
	ldx #$01FD
	txs
	lda #1
	rts
	:	
	sta config_file_fd
	
	ldx #file_contents_buff
	stx r0
	ldx #$C000 - file_contents_buff
	stx r1
	stz r2
	lda config_file_fd
	jsr read_file
	
	clc
	adc #<file_contents_buff
	sta ptr0
	txa
	adc #>file_contents_buff
	sta ptr0 + 1	
	lda #0
	sta (ptr0)
	
	ldx #file_contents_buff
	stx ascii_ptr
	
	lda config_file_fd
	jsr close_file

@end:	
	rts
@eof:
	.word 0

ascii_file_doesnt_exist_err_str:
	.asciiz "neofetch: Error: No such ascii file '"

parse_config_line:
	ldx #file_contents_buff
	jsr split_string_by_first_space
	; ptr0 points to first word of line
	; ptr1 will point to rest of line (args, if there are any)
	
	ldx ptr0
	lda $00, X
	bne :+
	rts ; if string is empty, just ignore and move onto next line
	:
	
	ldx ptr0
	ldy #ascii_str_compare
	jsr compare_strings
	bne @not_ascii_comm
	
	ldx ptr1
	jsr split_string_by_first_space
	ldx ptr0
	ldy #default_str_compare
	jsr compare_strings
	bne :+
	ldx #alt_x16_art
	stx ascii_ptr
	rts
	:
	ldx ptr0
	ldy #alt_str_compare
	jsr compare_strings
	bne :+
	ldx #x16_ascii_art
	stx ascii_ptr
	rts
	:
	
	ldx ptr0
	ldy #0
	:
	lda $00, X
	beq :+
	sta filename_buffer, Y
	inx
	iny
	cpy #128 - 1 ; size of buffer - 1
	bcc :-
	:
	sta filename_buffer, Y
	rts	
@not_ascii_comm:
	ldx ptr0
	ldy #blank_str_compare
	jsr compare_strings
	bne @not_blank_comm
	
	rep #$20
	.a16
	lda info_functions_size
	asl A
	tax
	lda #print_cr
	sta info_functions, X
	
	inc info_functions_size
	sep #$20
	.a8
	rts
@not_blank_comm:
	ldx ptr0
	ldy #info_str_compare
	jsr compare_strings
	bne @not_info_comm
	
	jmp parse_info_command
	
@not_info_comm:
	; invalid command, we should error
	lda #<invalid_command_err_str
	ldx #>invalid_command_err_str
	jsr print_str

	lda ptr0
	ldx ptr0 + 1
	jsr print_str

	lda #SINGLE_QUOTE
	jsr CHROUT
	jsr print_cr
	
	ldx #$01FD
	txs
	lda #1
	rts
	
ascii_str_compare:
	.asciiz "ascii"
blank_str_compare:
	.asciiz "blank"
info_str_compare:
	.asciiz "info"
	
default_str_compare:
	.asciiz "default"
alt_str_compare:
	.asciiz "alt"

invalid_command_err_str:
	.asciiz "neofetch: Invalid command: '"

parse_info_command:
	ldx ptr1
	jsr split_string_by_first_space
	
	; os ;
	ldx ptr0
	ldy #info_os_str
	jsr compare_strings
	bne :+	
	ldx #get_os_info
	jmp add_function_list
	:

	; kernal ;
	ldx ptr0
	ldy #info_kernal_str
	jsr compare_strings
	bne :+
	ldx #get_kernal_info
	jmp add_function_list
	:
	
	; programs ;
	ldx ptr0
	ldy #info_programs_str
	jsr compare_strings
	bne :+	
	ldx #get_programs_info
	jmp add_function_list
	:
	
	; shell ;
	ldx ptr0
	ldy #info_shell_str
	jsr compare_strings
	bne :+	
	ldx #get_shell_info
	jmp add_function_list
	:
	
	; term ;
	ldx ptr0
	ldy #info_terminal_str
	jsr compare_strings
	bne :+
	ldx #get_term_info
	jmp add_function_list
	:
	
	; cpu ;
	ldx ptr0
	ldy #info_cpu_str
	jsr compare_strings
	bne :+
	ldx #get_cpu_info
	jmp add_function_list
	:
	
	; gpu ;
	ldx ptr0
	ldy #info_gpu_str
	jsr compare_strings
	bne :+
	ldx #get_gpu_info
	jmp add_function_list
	:
	
	; memory ;
	ldx ptr0
	ldy #info_memory_str
	jsr compare_strings
	bne :+
	ldx #get_memory_info
	jmp add_function_list
	:
	
	; colors ;
	ldx ptr0
	ldy #info_colors_str
	jsr compare_strings
	bne :+
	ldx #print_colors
	jsr add_function_list
	ldx #print_colors
	jmp add_function_list
	:
	
	; invalid option for info ;
	lda #<invalid_info_opt_err_str
	ldx #>invalid_info_opt_err_str
	jsr print_str

	lda ptr0
	ldx ptr0 + 1
	jsr print_str

	lda #SINGLE_QUOTE
	jsr CHROUT
	jsr print_cr
	
	ldx #$01FD
	txs
	lda #1
	rts

invalid_info_opt_err_str:
	.asciiz "neofetch: Invalid info option '"

add_function_list:
	phx
	rep #$20
	.a16
	lda info_functions_size
	asl A
	tax
	pla
	sta info_functions, X
	
	inc info_functions_size
	sep #$20
	.a8
	rts	

info_os_str:
	.asciiz "os"
info_kernal_str:
	.asciiz "kernal"
info_programs_str:
	.asciiz "programs"
info_shell_str:
	.asciiz "shell"
info_terminal_str:
	.asciiz "terminal"
info_cpu_str:
	.asciiz "cpu"
info_gpu_str:
	.asciiz "gpu"
info_memory_str:
	.asciiz "memory"
info_colors_str:
	.asciiz "colors"

compare_strings:
	lda $00, X
	cmp $00, Y
	bne @not_equal
	lda $00, X
	beq @equal
	inx
	iny
	bra compare_strings
@equal:
	lda #0
	rts
@not_equal:
	lda #1
	rts

split_string_by_first_space:
	:	
	lda $00, X
	beq @end_find_non_whitespace_loop
	cmp #$20
	bcc :+
	cmp #$80
	bcc @end_find_non_whitespace_loop
	:
	inx
	bra :--
@end_find_non_whitespace_loop:
	stx ptr0
	
	:
	lda $00, X
	beq @end_find_space_loop
	cmp #$20
	beq :+
	inx
	bra :-
	:
	stz $00, X
	inx
@end_find_space_loop:
	stx ptr1
	rts

use_default_config:
	ldx #alt_x16_art
	stx ascii_ptr
	
	rep #$20
	.a16
	ldy #0
	ldx #0
	:
	lda default_info_functions, X
	beq :+
	sta info_functions, X
	iny
	inx
	inx
	bra :-
	:
	sty info_functions_size
	
	sep #$20
	.a8
	rts

get_length_first_ascii_line:
	ldx ascii_ptr
	ldy #0
	:
	lda $00, X
	cmp #$d
	beq :+
	iny
	inx
	bra :-
	:
	tya
	clc
	adc #3
	sta ascii_line_length
	rts
ascii_line_length:
	.word 0

print_ascii_line:
	lda still_print_ascii
	bne @print_next_line
	
	ldy #0
	bra @done_printing_line	
@print_next_line:	
	ldx ascii_ptr
	ldy #0
	:
	lda $00, X
	cmp #$d
	beq :+
	jsr CHROUT
	iny
	inx
	bra :-
	:
	inx
	stx ascii_ptr
@done_printing_line:
	:
	cpy ascii_line_length
	bcs :+
	lda #' '
	jsr CHROUT
	iny
	bra :-
	:
	
	lda $00, X
	bne :+
	stz still_print_ascii
	:
	rts	
still_print_ascii:
	.byte 0

get_os_info:
	lda #<@os_str
	ldx #>@os_str
	jsr print_str
	
	lda #<@cx16os_str
	ldx #>@cx16os_str
	jsr print_str

	jmp print_cr
@os_str:
	.asciiz "OS: "
@cx16os_str:
	.asciiz "Commander X16 OS"

get_kernal_info:
	lda #<@kernal_str
	ldx #>@kernal_str
	jsr print_str
	
	jsr get_sys_info
	tya
	cmp #128
	bcc :+
	; prerelease version / github commit
	pha
	lda #'P'
	jsr CHROUT
	lda #'r'
	jsr CHROUT
	lda #<@release_str
	ldx #>@release_str
	jsr print_str
	pla
	eor #$FF
	; value now in .A was last release, .A + 1 will be next release
	pha
	ldx #0
	jsr bin_to_bcd16
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #'-'
	jsr CHROUT
	pla
	inc A
	ldx #0
	jsr bin_to_bcd16
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	bra :++
	:
	; Release version ;
	pha
	lda #'R'
	jsr CHROUT
	lda #<@release_str
	ldx #>@release_str
	jsr print_str	
	pla
	ldx #0
	jsr bin_to_bcd16
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	:
	jmp print_cr
@kernal_str:
	.asciiz "Kernal: X16 ROM "
@release_str:
	.asciiz "elease Version "
	
get_programs_info:
	lda #<@programs_str
	ldx #>@programs_str
	jsr print_str
	
	lda #<@path_str
	ldx #>@path_str
	jsr chdir

	jsr res_extmem_bank
	sta @dir_listing_bank
	jsr load_dir_listing_extmem
	
	sta ptr1
	stx ptr1 + 1 ; end of the listing ;
	
	ldx #0
	stx ptr2 ; count of newlines
	
	lda #ptr0
	jsr set_extmem_rptr
	lda @dir_listing_bank
	jsr set_extmem_rbank
	
	ldx #$A000
	stx ptr0	
@count_files_loop:
	inx
	inx
	inx
	inx
	stx ptr0 ; binary bytes
	ldy #0
	; now go until we find \0
	:
	jsr readf_byte_extmem_y
	cmp #0
	beq :+
	
	inx
	stx ptr0
	bra :-
	:
	inc ptr2
	
	inx
	cpx ptr1
	bcc @count_files_loop
	
	lda ptr2
	sec
	sbc #5
	sta ptr2
	ldx #0
	jsr bin_to_bcd16
	cpx #0
	beq :+
	pha
	txa
	jsr GET_HEX_NUM
	jsr CHROUT
	pla
	:
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #' '
	jsr CHROUT
	lda #'('
	jsr CHROUT
	
	lda #<@path_str
	ldx #>@path_str
	jsr print_str
	
	lda #')'
	jsr CHROUT

	jmp print_cr
@programs_str:
	.asciiz "Programs: "
@path_str:
	.asciiz "/OS/bin"
@dir_listing_bank:
	.byte 0

get_shell_info:	
	lda #<@shell_str
	ldx #>@shell_str
	jsr print_str
	
	lda $00
	jsr get_process_info
	lda r0 + 1
	beq :+
	
	tay
	ldx #128
	stx r0
	lda #<filename_buffer
	ldx #>filename_buffer
	jsr get_process_name
	
	lda #<filename_buffer
	ldx #>filename_buffer
	jsr print_str
	
	:
	jmp print_cr
@shell_str:
	.asciiz "Shell: "

get_term_info:
	lda #<@term_str
	ldx #>@term_str
	jsr print_str

	jsr release_chrout_hook
	cmp #$FF
	beq @term_is_kernal
	
	tay
	ldx #128
	stx r0
	lda #<filename_buffer
	ldx #>filename_buffer
	jsr get_process_name
	
	lda #<filename_buffer
	ldx #>filename_buffer
	jsr print_str
	
	bra @end_fxn
@term_is_kernal:
	lda #<@kernal_str
	ldx #>@kernal_str
	jsr print_str

@end_fxn:
	jmp print_cr
@term_str:
	.asciiz "Terminal: "
@kernal_str:
	.asciiz "X16 Kernal"
	
get_cpu_info:
	lda #<@cpu_str
	ldx #>@cpu_str
	jsr print_str

	; TODO: add a speed checker somehow
	
	;lda #<@sep_str
	;ldx #>@sep_str
	;jsr print_str
	
	jmp print_cr
@cpu_str:
	.asciiz "CPU: WDC 65c816"
@sep_str:
	.asciiz " @ "
	
get_gpu_info:
	lda #<@vera_str
	ldx #>@vera_str
	jsr print_str
	
	jsr get_sys_info
	
	ldy #0
@loop:
	cpy #0
	beq :+
	lda #'.'
	jsr CHROUT
	:
	
	lda r0, Y
	phy
	ldx #0
	jsr bin_to_bcd16
	cpx #0
	beq :+
	pha
	txa
	jsr GET_HEX_NUM
	txa
	jsr CHROUT
	pla
	:
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT	
	ply
	iny
	cpy #r1 - r0 ; 2
	bcc @loop	
	
	jmp print_cr
@vera_str:
	.asciiz "GPU: VERA v"
	
get_memory_info:
	lda #<@memory_str
	ldx #>@memory_str
	jsr print_str
	
	jsr get_sys_info
	rep #$20
	.a16
	txa
	inc A
	; multiply by 8k per bank
	asl A
	asl A
	asl A
	xba
	tax
	xba
	sep #$20
	.a8
	jsr bin_to_bcd16
	pha
	txa
	jsr GET_HEX_NUM
	cmp #'0'
	beq :+
	jsr CHROUT
	:
	txa
	jsr CHROUT
	
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #<@ram_str
	ldx #>@ram_str
	jsr print_str
	
	jsr get_sys_info
	txa
	ldx #0
	inc A
	bne :+
	inx
	:
	jsr bin_to_bcd16
	cpx #0
	beq :+
	pha
	txa
	jsr GET_HEX_NUM
	txa
	jsr CHROUT
	pla
	:
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #<@banks_str
	ldx #>@banks_str
	jsr print_str
	
	jmp print_cr
@memory_str:
	.asciiz "Memory: "
@ram_str:
	.asciiz "KB Banked RAM ("
@banks_str:
	.asciiz " banks)"
	
print_colors:
	lda #SWAP_COLORS
	jsr CHROUT
	
	ldx #0
	ldy @colors_index
	:
	lda #SWAP_COLORS
	jsr CHROUT
	lda @colors_table, Y
	jsr CHROUT
	lda #SWAP_COLORS
	jsr CHROUT
	lda #' '
	jsr CHROUT
	jsr CHROUT
	iny
	inx
	cpx #8
	bcc :-	

	sty @colors_index
	
	lda #SWAP_COLORS
	jsr CHROUT
	lda #COLOR_WHITE
	jsr CHROUT
	
	jmp print_cr
@colors_index:
	.word 0
@colors_table:
	.byte COLOR_BLACK, COLOR_RED,  COLOR_GREEN,  COLOR_BROWN,  COLOR_BLUE,  COLOR_PURPLE, COLOR_MGRAY, COLOR_LGRAY
	.byte COLOR_DGRAY, COLOR_LRED, COLOR_LGREEN, COLOR_ORANGE, COLOR_LBLUE, COLOR_YELLOW, COLOR_CYAN,  COLOR_WHITE

print_next_info_line:
	lda #COLOR_WHITE
	jsr CHROUT
	
	ldx info_functions_index
	cpx info_functions_size
	bcc :+
	stz still_print_info
	:
	
	lda still_print_info
	bne :+
	jmp print_cr
	:
	
	ldx info_functions_index
	rep #$20
	.a16
	txa
	inx
	stx info_functions_index
	
	asl A
	tax
	lda info_functions, X
	sep #$20
	.a8	
	
	jmp (info_functions, X)
	

default_info_functions:
	.word get_os_info, get_kernal_info, get_programs_info, get_shell_info
	.word get_term_info, get_cpu_info, get_gpu_info, get_memory_info, print_cr
	.word print_colors, print_colors, 0

info_functions_index:
	.word 0
info_functions_size:
	.word 0
	
config_file_location:
	.asciiz "/OS/etc/neofetch.conf"
config_file_fd:
	.word 0
	
print_cr:
	lda #$d
	jmp CHROUT

ascii_ptr:
	.word 0
still_print_info:
	.byte 1

x16_ascii_art:
	.byte COLOR_WHITE,  "                            ", $d
	.byte COLOR_PURPLE, "   |-----\          /-----| ", $d
	.byte COLOR_PURPLE, "   |\\\\\\\        ///////| ", $d
	.byte COLOR_LBLUE,  "     \\\\\\\      ///////   ", $d
	.byte COLOR_LBLUE,  "      \\\\\\\    ///////    ", $d
	.byte COLOR_CYAN,   "       \\\\\\\  ///////     ", $d
	.byte COLOR_CYAN,   "        \-\\\|  |///-/      ", $d
	.byte COLOR_LGREEN, "          \\\|  |///        ", $d
	.byte COLOR_LGREEN, "          ///|  |\\\        ", $d
	.byte COLOR_YELLOW, "        /-///|  |\\\-\      ", $d
	.byte COLOR_YELLOW, "       ///////  \\\\\\\     ", $d
	.byte COLOR_ORANGE, "      ///////    \\\\\\\    ", $d
	.byte COLOR_ORANGE, "     ///////      \\\\\\\   ", $d
	.byte COLOR_RED,    "   |///////        \\\\\\\| ", $d
	.byte COLOR_RED,    "   |-----/          \-----| ", $d
	.byte COLOR_WHITE,  "                            ", $d
	.byte 0

alt_x16_art:
	.byte COLOR_PURPLE, "o                   o", $d
	.byte COLOR_PURPLE, "M@\               /@M", $d
	.byte COLOR_LBLUE,  "M@@@\           /@@@M", $d
	.byte COLOR_LBLUE,  ":@@@@@\       /@@@@@:", $d
	.byte COLOR_CYAN,   " \@@@@@@\   /@@@@@@/ ", $d
	.byte COLOR_CYAN,   "   ''''**N N**''''   ", $d
	.byte COLOR_LGREEN, "         N N         ", $d
	.byte COLOR_YELLOW, "     ..-*N N*-..     ", $d
	.byte COLOR_YELLOW, "  :@@@@@/   \@@@@@:  ", $d
	.byte COLOR_ORANGE, "  M@@@/       \@@@M  ", $d
	.byte COLOR_RED,    "  M@/           \@M  ", $d
	.byte 0

filename_buffer:
	.res 128, 0

.segment "BSS"

info_functions:
	.res 64 * 2

file_contents_buff:

