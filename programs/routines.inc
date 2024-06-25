.setcpu "65816"

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

get_process_info := $9D0C
get_args := $9D0F
get_process_name := $9D12

parse_num := $9D15
bin_to_bcd16 := $9D99

hex_num_to_string := $9D18
GET_HEX_NUM := hex_num_to_string

kill_process := $9D1B
open_file := $9D1E
close_file := $9D21
read_file := $9D24
write_file := $9D27
load_dir_listing_extmem := $9D2A
get_pwd := $9D2D
chdir := $9D30

;
; Extmem routines ;
;

res_extmem_bank := $9D33
set_extmem_rbank := $9D36
set_extmem_rptr := $9D39
set_extmem_wptr := $9D3C

readf_byte_extmem_y := $9D3F
free_extmem_bank := $9D42
vread_byte_extmem_y := $9D45

writef_byte_extmem_y := $9D48
share_extmem_bank := $9D4B
vwrite_byte_extmem_y := $9D4E

memmove_extmem := $9D51
fill_extmem := $9D54
set_extmem_wbank := $9D57

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


