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