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
	
	ldx #alt_x16_art
	stx ascii_ptr
	
	lda #1
	sta still_print_ascii
	lda #1
	sta still_print_info
	
	jsr get_length_first_ascii_line
	
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
	lda #<@cx16os_str
	ldx #>@cx16os_str
	jsr print_str

	jmp print_cr
@cx16os_str:
	.asciiz "Commander X16 OS"

get_kernal_info:
	lda #<@x16_kern_str
	ldx #>@x16_kern_str
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
@x16_kern_str:
	.asciiz "X16 ROM "
@release_str:
	.asciiz "elease Version "
	
get_programs_info:
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
@path_str:
	.asciiz "/OS/bin"
@dir_listing_bank:
	.byte 0

get_shell_info:	
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

get_term_info:
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
@kernal_str:
	.asciiz "x16 kernal"
	
get_cpu_info:
	lda #<@cpu_name_str
	ldx #>@cpu_name_str
	jsr print_str

	; TODO: add a speed checker somehow
	
	;lda #<@sep_str
	;ldx #>@sep_str
	;jsr print_str
	
	jmp print_cr
@cpu_name_str:
	.asciiz "WDC 65c816"
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
	cpy #(r1 + 1) - r0 ; 3
	bcc @loop	
	
	jmp print_cr
@vera_str:
	.asciiz "VERA v"
	
get_memory_info:
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
	bne :+
	stz still_print_info
	jmp print_cr
	:
	phx
	txy
	
	iny
	lda info_function_strs, Y
	tax
	dey
	lda info_function_strs, Y
	jsr print_str
	
	lda #' '
	jsr CHROUT
	
	plx
	jmp (info_functions, X)
	

info_functions:
	.word get_os_info, get_kernal_info, get_programs_info, get_shell_info
	.word get_term_info, get_cpu_info, get_gpu_info, get_memory_info, print_cr
	.word print_colors, print_colors, 0
info_function_strs:
	.word @os_str, @kernal_str, @programs_str, @shell_str
	.word @term_str, @cpu_str, @gpu_str, @memory_str, @empty_str
	.word @empty_str, @empty_str
@os_str:
	.asciiz "OS:"
@kernal_str:
	.asciiz "Kernal:"
@programs_str:
	.asciiz "Programs:"
@shell_str:
	.asciiz "Shell:"
@term_str:
	.asciiz "Terminal:"
@cpu_str:
	.asciiz "CPU:"
@gpu_str:
	.asciiz "GPU:"
@memory_str:
	.asciiz "Memory:"
@empty_str:
	.asciiz ""

info_functions_index:
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

.segment "BSS"

filename_buffer:
	.res 128

file_contents_buff: