.include "cx16.inc"
.include "prog.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import process_priority_table, process_table
.import active_processes_table, in_active_processes_table
.import is_valid_process

;
; sets up scheduler tables
;
.export setup_scheduler
setup_scheduler:
	stz task_table_size
	stz task_table_size + 1
	
	ldx #ALIVE_IIDS_TABLE_SIZE - 1
	:
	stz alive_iids_table, X
	dex
	bpl :-
	
	rts

;
; adds a process with pid in .A to the scheduler
;
.export scheduler_add_task
scheduler_add_task:
	rts

;
; removes a process with pid in .A from the scheduler
;
.export scheduler_remove_task
scheduler_remove_task:
	rts

;
; scheduler_get_next_task
; takes a pid in .A and returns the next task's pid in .A, with time in .X
;
.export scheduler_get_next_task
scheduler_get_next_task:
	tax
	bra @not_valid_process
	
@loop: 
	txa
	jsr is_valid_process
	beq @not_valid_process
	
	lda process_priority_table, X
	bne @exit_loop
	
@not_valid_process:	
	inx
	inx
	bra @loop
@exit_loop:
	tay
	txa
	tyx
	rts

task_iids_table:
	.res $80
task_next_index_table:
	.res $80

task_waiting_for_table:
	.res $80
task_waiting_on_table:
	.res $80
	
task_table_size:
	.word 0

alive_iids_table:
	.res $80
ALIVE_IIDS_TABLE_SIZE = $80



	