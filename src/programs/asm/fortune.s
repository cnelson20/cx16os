.include "routines.inc"
.feature c_comments

.segment "CODE"

ptr0 := $30

NEWLINE = $0A
NUM_FORTUNES = 30

main:
	/* Get a random index */
	jsr get_random	; .A = low byte of 24-bit entropy

	/* A mod NUM_FORTUNES */
	ldx #0
@mod_loop:
	cmp #NUM_FORTUNES
	bcc @mod_done
	sbc #NUM_FORTUNES
	bra @mod_loop
@mod_done:

	/* Index into fortune table: each entry is 2 bytes */
	asl A
	tax
	lda fortune_table, X
	sta ptr0
	lda fortune_table + 1, X
	sta ptr0 + 1

	/* Print the fortune */
	lda ptr0
	ldx ptr0 + 1
	jsr print_str

	/* Print trailing newline */
	lda #NEWLINE
	jsr CHROUT

	lda #0
	rts

fortune_table:
	.word f00, f01, f02, f03, f04, f05, f06, f07, f08, f09
	.word f10, f11, f12, f13, f14, f15, f16, f17, f18, f19
	.word f20, f21, f22, f23, f24, f25, f26, f27, f28, f29

f00: .byte "A journey of a thousand miles begins with a single step.", 0
f01: .byte "You will be fortunate in everything you put your hands to.", 0
f02: .byte "An unexamined life is not worth living. -- Socrates", 0
f03: .byte "The best time to plant a tree was 20 years ago. The second best time is now.", 0
f04: .byte "Fortune favors the bold.", 0
f05: .byte "It is not the stars to hold our destiny but in ourselves.", 0
f06: .byte "In the middle of difficulty lies opportunity. -- Einstein", 0
f07: .byte "No wind favors he who has no destined port. -- Montaigne", 0
f08: .byte "Do or do not. There is no try. -- Yoda", 0
f09: .byte "640K ought to be enough for anybody.", 0
f10: .byte "There are 10 kinds of people: those who know binary and those who don't.", 0
f11: .byte "To iterate is human, to recurse divine.", 0
f12: .byte "Premature optimization is the root of all evil. -- Knuth", 0
f13: .byte "It works on my machine.", 0
f14: .byte "Have you tried turning it off and on again?", 0
f15: .byte "The real treasure was the bugs we fixed along the way.", 0
f16: .byte "Weeks of coding can save you hours of planning.", 0
f17: .byte "There is no place like 127.0.0.1.", 0
f18: .byte "A clever person solves a problem. A wise person avoids it. -- Einstein", 0
f19: .byte "Everything that can be invented has been invented. -- 1899", 0
f20: .byte "Strstrstrstrstrstrstrstr... sorry, looping again.", 0
f21: .byte "Fear is the mind-killer. -- Frank Herbert", 0
f22: .byte "One does not simply walk into production.", 0
f23: .byte "If it hurts, do it more frequently, and bring the pain forward.", 0
f24: .byte "The only way to go fast is to go well. -- Robert C. Martin", 0
f25: .byte "Simplicity is the ultimate sophistication. -- Leonardo da Vinci", 0
f26: .byte "First, solve the problem. Then, write the code. -- John Johnson", 0
f27: .byte "Talk is cheap. Show me the code. -- Linus Torvalds", 0
f28: .byte "May your code compile on the first try.", 0
f29: .byte "Today is a good day to refactor.", 0
