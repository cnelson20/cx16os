.byte $ea, $EA
ldx #0
loop:
lda hello, X
beq end
jsr $9D03
inx
bne loop
end:
rts

hello:
.str "hello"
.byte $d, 0
