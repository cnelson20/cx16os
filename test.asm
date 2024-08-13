lda #0  ; hello monitor
lda $0000
lda hello, X
lda array, Y
rts
jmp (label)
inc A
lda (welcome, X)
sta (goodbye), Y
