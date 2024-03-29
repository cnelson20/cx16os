.macro cnsta from, addr
	lda #from
	sta addr
.endmacro

.macro cnsta_word from_word, addr
	cnsta <from_word, addr
	cnsta >from_word, addr + 1
.endmacro

.macro ldax_addr addr
	lda #<addr
	ldx #>addr
.endmacro

.macro pha_word addr
	lda addr
	pha
	lda addr + 1
	pha
.endmacro

.macro pla_word addr
	pla
	sta addr + 1
	pla 
	sta addr
.endmacro