.include "routines.inc"
.segment "CODE"

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

NEWLINE = $0A

MAX_SECTION_NUMBER = 7

main:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	dey
	sty ptr1
	stz ptr1 + 1
	
	rep #$10
	.i16
	lda ptr1 ; argc
	bne :+
	
	lda #<no_args_str
	ldx #>no_args_str
	jsr print_str
	lda #1
	rts
	:
	
	jsr get_next_arg
	lda ptr1
	beq @no_section
	
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	cpy #0
	bne @no_section
	
	sta wanted_section
	txa
	sta wanted_section + 1	
	jsr get_next_arg
@no_section:
	ldx ptr0
	stx wanted_name
	
	jmp find_page
	
get_next_arg:
	dec ptr1
	
	ldx ptr0
	jsr strlen
	tyx
	inx
	stx ptr0
	rts
	
find_page:
	ldx #search_dir
	ldy #manpage_str
	jsr strcpy
	
	ldx wanted_name
	jsr strcpy
	
	tyx
	lda #'.'
	sta $00, X
	inx
	lda #'X'
	sta $00, X
	stx ptr2
	inx
	stz $00, X ; add .X to end of file
	
	lda wanted_section
	bne :+
	lda #1
	:
	sta ptr3
@find_page_loop:
	lda ptr3
	ora #'0'
	ldx ptr2
	sta $00, X
	
	lda #<manpage_str
	ldx #>manpage_str
	ldy #0
	jsr open_file
	cmp #$FF
	bne @found_page
	
	lda wanted_section
	bne :+
	lda ptr3
	cmp #MAX_SECTION_NUMBER
	bcs :+
	inc ptr3
	jmp @find_page_loop
	:
	jmp no_page_err

@found_page:	
	sta manpage_fd
	
	jsr pipe
	sta pipe_fds + 0
	txa
	sta pipe_fds + 1
	
	stz r2
	sta r2 + 1
	
	stz r0
	
	ldx #formatter
	ldy #exec_str
	jsr strcpy
	iny
	ldx #manpage_str
	jsr strcpy
	
	lda #<exec_str
	ldx #>exec_str
	ldy #2
	jsr exec
	
	lda manpage_fd
	jsr close_file
	lda pipe_fds + 1 ; write end
	jsr close_file
	
	lda pipe_fds + 0 ; read end
	sta r2
	stz r2 + 1
	
	lda #1
	sta r0
	lda #<manpager
	ldx #>manpager
	ldy #1
	jsr exec
	
	jsr wait_process
	
	lda #0
	rts

no_page_err:
	lda #<@no_man_str
	ldx #>@no_man_str
	jsr print_str
	
	lda wanted_name
	ldx wanted_name + 1
	jsr print_str
	
	lda wanted_section
	beq :+
	
	lda #<@section_str
	ldx #>@section_str
	jsr print_str	
	
	lda wanted_section
	ora #'0'
	jsr CHROUT
	:
	
	lda #NEWLINE
	jsr CHROUT
	jsr CHROUT
	
	lda #1
	rts
	
@no_man_str:
	.asciiz "No manual entry for "
@section_str:
	.asciiz " in section "

strcpy:
	:
	lda $00, X
	sta $00, Y
	beq :+
	inx
	iny
	bra :-
	:
	rts
	
strlen:
	phx
	ldy #$FFFF
	dex
	:
	iny
	inx
	lda $00, X
	bne :-
	rep #$20
	.a16
	tya
	sep #$20
	.a8
	txy
	plx
	rts

formatter:
	.asciiz "format"
manpager:
	.asciiz "less"

search_dir:
	.asciiz "~/usr/man/"

no_args_str:
	.byte "What manual page do you want?", NEWLINE
	.byte "For example, try 'man man'.", NEWLINE
	.byte NEWLINE
	.byte 0

exec_str:
	.res 128, 0
manpage_str:
	.res 128, 0

wanted_section:
	.word 0
wanted_name:
	.word 0

manpager_pid:
	.byte 0

pipe_fds:
	.word 0
manpage_fd:
	.byte 0
