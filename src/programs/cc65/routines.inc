.setcpu "65816"

;
; simple defines
;
CLEAR = $93
LF = $0A
CR = $0D

;
; pseudo-registers
;
r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A
r5 := $0C

;
; System routines
;

getc := $9D00
GETIN := getc

putc := $9D03
CHROUT := putc

exec := $9D06

print_str := $9D09
PRINT_STR := print_str
get_console_info := $9DB4
set_console_mode := $9DB7
set_stdin_read_mode := $9DBA

get_process_info := $9D0C
get_args := $9D0F
get_process_name := $9D12
active_table_lookup := $9DA5

parse_num := $9D15
bin_to_bcd16 := $9D99

hex_num_to_string := $9D18
GET_HEX_NUM := hex_num_to_string

kill_process := $9D1B
open_file := $9D1E
close_file := $9D21
read_file := $9D24
write_file := $9D27
seek_file := $9DC0
tell_file := $9DC3
load_dir_listing_extmem := $9D2A
get_pwd := $9D2D
chdir := $9D30
move_fd := $9D9C
copy_fd := $9DA8
pipe := $9DBD

;
; Extmem routines ;
;

res_extmem_bank := $9D33
free_extmem_bank := $9D42
share_extmem_bank := $9D4B

set_extmem_wbank := $9D57
set_extmem_rbank := $9D36
set_extmem_rptr := $9D39
set_extmem_wptr := $9D3C

readf_byte_extmem_y := $9D3F
writef_byte_extmem_y := $9D48

vread_byte_extmem_y := $9D45
vwrite_byte_extmem_y := $9D4E

pread_extmem_xy := $9DAE
pwrite_extmem_xy := $9DB1

memmove_extmem := $9D51
fill_extmem := $9D54


;
; More system routines ;
;

wait_process := $9D5D
fgetc := $9D60
fputc := $9D63
unlink := $9D66
rename := $9D69
copy_file := $9D6C
mkdir := $9D6F
rmdir := $9D72

get_time := $9D9F
get_sys_info := $9DAB

setup_chrout_hook := $9D75
release_chrout_hook := $9D78
send_byte_chrout_hook := $9D87

lock_vera_regs := $9D93
unlock_vera_regs := $9D96

setup_general_hook := $9D7B
release_general_hook := $9D7E
get_general_hook_info := $9D81
send_message_general_hook := $9D84
mark_last_hook_message_received := $9D90

set_own_priority := $9D8A
surrender_process_time := $9D8D
detach_self := $9DA2


