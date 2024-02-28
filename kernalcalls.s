.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"


.export call_table
call_table:
	jmp CHROUT
	jmp CHRIN
.export call_table_end
call_table_end: