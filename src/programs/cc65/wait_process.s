.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

;
; takes pid and waits for it to exit. If no process with pid .A exists, return -1, else wait and return the process's return value
;

.export _wait_process
_wait_process:
    jsr wait_process
    cpx #0
    beq :+
    txa ; return 0xFFFF (-1)
    :
    rts