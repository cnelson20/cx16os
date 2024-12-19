.macro cnsta from, addr
	.assert .asize = 8, error, "Accumulator not 8 bits"
	lda #from
	sta addr
.endmacro

.macro cnsta_word from_word, addr
	.if .asize = 8
	cnsta <from_word, addr
	cnsta >from_word, addr + 1
	.else
	lda #from_word
	sta addr
	.endif
.endmacro

.macro ldax_addr addr
	lda #<addr
	ldx #>addr
.endmacro

.macro stax_word addr
	sta addr
	stx addr + 1
.endmacro

.macro pha_word addr
	.if .asize = 8
	lda addr + 1
	pha
	lda addr
	pha
	.else
	lda addr
	pha
	.endif
.endmacro

.macro pla_word addr
	.if .asize = 8
	pla 
	sta addr
	pla
	sta addr + 1
	.else
	pla
	sta addr
	.endif
.endmacro

.macro pha_byte addr
	.assert .asize = 8, error, "Accumulator not 8 bits"
	lda addr
	pha
.endmacro

.macro pla_byte addr
	.assert .asize = 8, error, "Accumulator not 8 bits"
	pla
	sta addr
.endmacro

.macro phy_word addr
	.if .isize = 8
	ldy addr + 1
	phy
	ldy addr
	phy
	.else 
	ldy addr
	phy
	.endif
.endmacro

.macro ply_word addr
	.if .isize = 8
	ply 
	sty addr
	ply
	sty addr + 1
	.else
	ply
	sty addr
	.endif
.endmacro

.macro phx_word addr
	.if .isize = 8
	ldx addr + 1
	phx
	ldx addr
	phx
	.else 
	ldx addr
	phx
	.endif
.endmacro

.macro plx_word addr
	.if .isize = 8
	plx 
	stx addr
	plx
	stx addr + 1
	.else
	plx
	stx addr
	.endif
.endmacro

.macro phx_byte addr
	.assert .isize = 8, error, "Y register 8 bits"
	ldx addr
	phx
.endmacro

.macro plx_byte addr
	.assert .isize = 8, error, "Y register not 8 bits"
	plx
	stx addr
.endmacro

.macro phy_byte addr
	.assert .isize = 8, error, "Y register 8 bits"
	ldy addr
	phy
.endmacro

.macro ply_byte addr
	.assert .isize = 8, error, "Y register not 8 bits"
	ply
	sty addr
.endmacro

.macro push_ax
	phx
	pha
.endmacro

.macro pull_ax
	pla
	plx
.endmacro

.macro push_zp_word addr
	pei (addr)
.endmacro
	

.macro ldsta_word src, dest
	.if .asize = 8
	lda src
	sta dest
	lda src + 1
	sta dest + 1
	.else
	lda src
	sta dest
	.endif
.endmacro

.macro ldstx_word src, dest
	.if .isize = 8
	ldx src
	stx dest
	ldx src + 1
	stx dest + 1
	.else
	ldx src
	stx dest
	.endif
.endmacro

.macro ldsty_word src, dest
	.if .isize = 8
	ldy src
	sty dest
	ldy src + 1
	sty dest + 1
	.else 
	ldy src
	sty dest
	.endif
.endmacro

.macro ldax_word addr
	lda addr
	ldx addr + 1
.endmacro

.macro inc_word addr
	.if .asize = 8
	inc addr
	bne :+
	inc addr + 1
	:
	.else
	inc addr
	.endif
.endmacro

.macro inc_ax
	inc A
	bne :+
	inx
	:
.endmacro

.macro set_atomic_st
	pha
	lda #1
	sta atomic_action_st
	pla
.endmacro

.macro set_atomic_st_disc_a
	lda #1
	sta atomic_action_st
.endmacro

.macro clear_atomic_st
	stz atomic_action_st
.endmacro

;
; Macros to deal with M/X flags of 65816
;

.macro save_p_816_8bitmode
	php
	sep #$30
.endmacro

.macro save_p_816
	php
.endmacro

.macro restore_p_816
	plp
.endmacro

.macro accum_8_bit
	sep #$20
.endmacro

.macro accum_16_bit
	rep #$20
.endmacro

.macro index_8_bit
	sep #$10
.endmacro

.macro index_16_bit
	rep #$10
.endmacro

.macro accum_index_16_bit
	rep #$30
.endmacro

.macro accum_index_8_bit
	sep #$30
.endmacro

.macro mv_a_16bit_ax
	phy
	save_p_816
	index_8_bit
	xba
	tax
	lda #0
	xba

	restore_p_816
	ply
.endmacro

.macro mv_x_16bit_ax
	save_p_816
	accum_8_bit
	txa
	pha
	lda #0
	xba
	tax
	pla
	restore_p_816
.endmacro

.macro mv_y_16bit_ax
	tyx
	mv_x_16bit_ax
.endmacro

;
; Macros to run a routine with different flags/registers set
;
.macro run_routine_8bit addr
	save_p_816_8bitmode
	jsr addr
	restore_p_816
.endmacro

.macro preserve_rom_run_routine_8bit addr
	save_p_816_8bitmode
	stz ROM_BANK
	jsr addr
	xba
	lda current_program_id
	sta ROM_BANK
	xba
	restore_p_816
.endmacro
