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

.macro stax_addr addr
	sta addr
	stx addr + 1
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

.macro pha_byte addr
	lda addr
	pha
.endmacro

.macro pla_byte addr
	pla
	sta addr
.endmacro

.macro phy_word addr
	ldy addr
	phy
	ldy addr + 1
	phy
.endmacro

.macro ply_word addr
	ply
	sty addr + 1
	ply 
	sty addr
.endmacro

.macro phy_byte addr
	ldy addr
	phy
.endmacro

.macro ply_byte addr
	ply
	sty addr
.endmacro

.macro ldsta_word src, dest
	lda src
	sta dest
	lda src + 1
	sta dest + 1
.endmacro

.macro ldstx_word src, dest
	ldx src
	stx dest
	ldx src + 1
	stx dest + 1
.endmacro

.macro ldsty_word src, dest
	ldy src
	sty dest
	ldy src + 1
	sty dest + 1
.endmacro

.macro ldax_word addr
	lda addr
	ldx addr + 1
.endmacro

.macro set_atomic_st
	lda #1
	sta atomic_action_st
.endmacro

.macro clear_atomic_st
	stz atomic_action_st
.endmacro

.macro save_p_816_8bitmode
	php
	sep #$30
.endmacro

.macro restore_p_816
	plp
.endmacro