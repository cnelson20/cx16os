lda #0  ; hello monitor
test_label:
.strz "hello"
.word 0, 2
.equ value 5
lda $0000
lda hello, X
lda array, Y
rts
jmp (label)
inc A
lda (welcome, X)
sta (goodbye), Y
