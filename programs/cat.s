OPEN_FILE = $9D0F
CLOSE_FILE = $9D12
READ_FILE = $9D15

PRINT_STR = $9D18

CHROUT = $9D03

ZPBASE = $20

ARGC = $C07F 
ARGS = $C080


main:
	lda #<ARGS
	sta $20
	lda #>ARGS
	sta $21
	
	dec ARGC ; exclude program name as arg
loop:
	lda ARGC
	beq exit

@pass_loop:	
	lda ($20)
	inc $20
	bne @dont_inc_hi
	inc $21
@dont_inc_hi:
	cmp #0
	bne @pass_loop
	
@print_file:
	lda $20
	ldx $21
	jsr OPEN_FILE
	sta filenum
	
@print_loop:	
	ldy filenum
	lda #255
	pha ; number of bytes on stack
	lda #<read_buffer
	ldx #>read_buffer
	jsr READ_FILE
	
	sta bytes_read
	cmp #0
	beq @skip_output
	
	tax
	stz read_buffer, X
	lda #<read_buffer
	ldx #>read_buffer
	jsr PRINT_STR
	
@skip_output:
	
	lda bytes_read
	cmp #255
	bcs @print_loop
	
	lda filenum
	jsr CLOSE_FILE
	
	dec ARGC
	jmp loop
exit:
	rts

filenum:
	.byte 0
read_buffer:
	.res 256
	
bytes_read:
	.byte 0