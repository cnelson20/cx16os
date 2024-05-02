.setcpu "65c02"

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

hex_num_to_string := $9D18
GET_HEX_NUM := hex_num_to_string

kill_process := $9D1B
open_file := $9D1E
close_file := $9D21
read_file := $9D24
write_file := $9D27
open_dir_listing := $9D2A
get_pwd := $9D2D
chdir := $9D30

res_extmem_bank := $9D33
set_extmem_rbank := $9D36
set_extmem_rptr := $9D39
set_extmem_wptr := $9D3C

readf_byte_extmem_y := $9D3F
readf_word_extmem_y := $9D42
vread_byte_extmem_y := $9D45

writef_byte_extmem_y := $9D48
writef_word_extmem_y := $9D4B
vwrite_byte_extmem_y := $9D3E

memmove_extmem := $9D51
fill_extmem := $9D54
set_extmem_wbank := $9D57

wait_process := $9D5D
fgetc := $9D60
fputc := $9D63