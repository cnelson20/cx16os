.include "routines.inc"
.include "time.inc"

.export _localtime

.import pushax

.import _localtime_r

;
; struct tm *localtime(const time_t *timep);
;
.proc _localtime: near
	jsr pushax
	lda #<_localtime_store
	ldx #>_localtime_store
	jmp _localtime_r
	
_localtime_store:
	.res .sizeof(tm)
.endproc
