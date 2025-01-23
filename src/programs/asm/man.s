.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

main:
	rep #$10
	.i16
	
	lda #<testfile
	ldx #>testfile
	ldy #0
	jsr open_file
	
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
	ldx #exec_str
	jsr strlen
	iny
	ldx #testfile
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
	
	
	
testfile:
	.asciiz "~/home/macbeth.txt"

formatter:
	.asciiz "cat"
manpager:
	.asciiz "less"

exec_str:
	.res 128, 0

manpager_pid:
	.byte 0

pipe_fds:
	.word 0
manpage_fd:
	.byte 0
