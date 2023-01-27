PRINT_STR = $9D21
QUERY_DOS = $9D27
READ_DOS = $9D2A

READ_FILE = $9D1E
CLOSE_FILE = $9D1B

ARGC = $C07F
ARGS = $C080

ZP = $20
ZP_PL_1 = $21

ASCII_COLON = $3A
ASCII_DOLLAR = $24

main:
	stp
	lda #<ARGS
	sta ZP
	lda #>ARGS
	stx ZP_PL_1

	lda ARGC
	dec A
	bne arg_loop
	
	lda #<default_list
	sta ZP
	ldx #>default_list
	stx ZP_PL_1
	jmp run_kernal_dos_routine
	
default_list:
	.asciiz "$:*"

arg_loop:
	dec ARGC
	beq end

	ldy #0
@sloop:
	lda (ZP), Y
	beq @brk_sloop
	iny
	bne @sloop
@brk_sloop:
	tya
	sec
	adc ZP
	pha
	lda ZP_PL_1
	adc #0
	sta ZP_PL_1
	pha
	
	lda #ASCII_COLON
	sta (ZP), Y
	lda #ASCII_DOLLAR
	dey 
	sta (ZP), Y

run_kernal_dos_routine:
	lda ZP
	ldx ZP_PL_1
	stp
	jsr QUERY_DOS
	cmp #0
	beq dos_error
	
	; print listing ;
read_listing_loop:	
	ldy #255
	lda #<buffer
	ldx #>buffer
	jsr READ_DOS
	sta bytes_read
	tax
	stz buffer, X
	jsr PRINT_STR
	lda bytes_read
	cmp #255
	beq read_listing_loop
	
	lda #15
	jsr CLOSE_FILE
	
	pla
	sta ZP_PL_1
	pla 
	sta ZP
	
end: 
	rts
	
bytes_read:
	.byte 0
	
dos_error:
	lda #<error_msg
	ldx #>error_msg
	jsr PRINT_STR
	rts
error_msg:
	.ascii "Error opening directory!"
	.byte $0d, $00

	
buffer:
	.res 255
	