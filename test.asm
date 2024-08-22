lda #0  ; hello monitor
test_label:
.equ value 5
lda $0000
lda hello, X
lda array, Y
rts
jmp (label)
inc A
lda (welcome, X)
sta (goodbye), Y
